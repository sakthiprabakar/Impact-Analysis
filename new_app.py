import streamlit as st
import os
import json
import shutil
import dotenv
import re
import traceback
import time
import stat # For robust_rmtree permissions
# Make sure to install the openai library: pip install openai
from openai import (
    AzureOpenAI,
    RateLimitError,     # Specific error for rate limits
    APIError,           # Specific error for general API issues (like 5xx errors)
    APIConnectionError, # Specific error for network issues
    AuthenticationError,# Specific error for key/auth problems
    BadRequestError     # Specific error for invalid requests (4xx errors, including content filtering)
)
# Assuming gemini_v2.py exists in the same directory or is installable
try:
    from gemini_v2 import run_impact_analysis
except ImportError:
    st.error("ERROR: Could not import 'run_impact_analysis' from 'gemini_v2'. Make sure gemini_v2.py exists.")
    # Define a dummy function to allow the rest of the app to load initially
    def run_impact_analysis(json_path, sp_folder, output_folder):
        st.warning("Using dummy 'run_impact_analysis'. Real analysis will not occur.")
        dummy_path = os.path.join(output_folder, f"{os.path.splitext(os.path.basename(json_path))[0]}_dummy_report.xlsx")
        # Create a dummy file to avoid download errors
        with open(dummy_path, "w") as f:
            f.write("This is a dummy report because gemini_v2 was not found.")
        return dummy_path # Return a plausible path


# --- Configuration ---

# Load environment variables from .env file
dotenv.load_dotenv()

# Azure OpenAI Config (Ensure these are set in your .env file or environment)
API_KEY = os.getenv('AZURE_OPENAI_API_KEY')
ENDPOINT = os.getenv('AZURE_OPENAI_ENDPOINT')
DEPLOYMENT_NAME = os.getenv('AZURE_OPENAI_DEPLOYMENT_NAME')
API_VERSION = os.getenv('API_VERSION') # e.g., "2024-02-15-preview" or newer

# Check if essential Azure configs are loaded
if not all([API_KEY, ENDPOINT, DEPLOYMENT_NAME, API_VERSION]):
    st.error("❌ Critical Azure OpenAI environment variables (API_KEY, ENDPOINT, DEPLOYMENT_NAME, API_VERSION) are missing. Please check your .env file or environment settings.")
    st.stop() # Halt execution if config is missing


# Folder Paths
INPUT_JSON_FOLDER = "input_json"
STORED_PROC_SRC_FOLDER = "D:/Gen AI/Impact analysis main/Stored Procedures" # Use forward slashes or raw strings for paths
STORED_PROC_DEST_FOLDER = "stored_procedures"
OUTPUT_FOLDER = "output"

# Ensure base folders exist
os.makedirs(INPUT_JSON_FOLDER, exist_ok=True)
os.makedirs(STORED_PROC_DEST_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


# --- Helper Functions ---

def extract_table_name_from_filename(filename):
    """Extracts the table name from the filename (without extension)."""
    if not filename:
        return "unknown_table"
    base_name = os.path.splitext(filename)[0]
    return base_name


def robust_rmtree(path):
    """Robustly removes a directory, handling potential permission errors on Windows."""
    if not os.path.exists(path):
        return

    def onerror(func, path, exc_info):
        """Error handler for shutil.rmtree.
        Handles Read-only errors common on Windows.
        """
        # Check if the error is due to readonly access.
        # Check if the file exists before trying to change permissions
        if os.path.exists(path) and not os.access(path, os.W_OK):
            # Try to change the permission.
            os.chmod(path, stat.S_IWUSR)
            # Retry the function.
            try:
                func(path)
            except Exception as e:
                 st.warning(f"Still failed to remove {path} after chmod: {e}")
                 # Propagate the error if chmod+retry fails
                 raise
        else:
            # If the error is not related to write permissions or file doesn't exist, raise it
             st.warning(f"Failed to remove {path} due to: {exc_info[1]}")
             raise exc_info[1] # Raise the original error captured in exc_info

    try:
        shutil.rmtree(path, onerror=onerror)
        # Add a small delay after deletion, sometimes helps with filesystem lag
        time.sleep(0.2)
        # Verify deletion
        if os.path.exists(path):
             st.warning(f"Directory {path} still exists after rmtree attempt.")

    except FileNotFoundError:
        pass # It's already gone, which is fine
    except Exception as e:
        st.error(f"Failed to delete directory {path}: {e}")
        # Depending on severity, you might want to re-raise or just warn
        # raise # Uncomment if deletion failure should stop the process


def parse_table_changes_with_llm(file_content, table_name):
    """
    Parses table changes using Azure OpenAI with improved retry logic
    and specific exception handling.
    """
    if not file_content.strip():
        raise ValueError("Input file content is empty. Please provide valid data.")
    if not table_name or table_name == "unknown_table":
        raise ValueError("Invalid table name derived from filename.")

    # Ensure client is initialized with necessary credentials
    try:
        client = AzureOpenAI(
            api_key=API_KEY,
            api_version=API_VERSION,
            azure_endpoint=ENDPOINT
        )
    except Exception as e:
        st.error(f"Failed to initialize AzureOpenAI client: {e}")
        raise ConnectionError(f"Could not initialize Azure OpenAI client. Check endpoint and API version. Error: {e}")


    # Construct the prompt exactly as before
    prompt = f"""
    You are an expert in database modernization. Convert the provided text into structured JSON for impact analysis.

    **IMPORTANT: Your ENTIRE response MUST be valid JSON. Do not include ANY other text outside of the JSON structure.** The JSON MUST be a single object with the following structure:
    For *each* stored procedure in the batch, follow these rules:

    **Important: DO NOT HALLUCINATE DATA. Only provide information explicitly present within the provided stored procedure code and the provided schema changes. If there is NO direct impact, state that there is no direct impact. Do not invent or infer any other information.**

    1. **Direct Impact Only:** A stored procedure is *directly* impacted *only if* its *own SQL code (the specific SQL statements directly within the stored procedure definition)* directly references any of the **tables or columns mentioned in the schema changes**. A "direct reference" means that these table or column names appear explicitly in the stored procedure's SQL statements (e.g., in a `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `JOIN` clause). If the stored procedure accesses these elements *indirectly* through another table, it is *not* considered directly impacted and should be marked as "not impacted."

    2. **Column Deletion Impact:** If any column listed under `"deletion_changes"` in the schema changes is referenced in the stored procedure’s SQL statements—including `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, or variable assignments—the procedure should be considered *impacted* with an **impactType** of `"Column Deletion"`. If the deleted column is used in conditions, calculations, or joins, specify the risk of query failure due to missing columns.

    3. **JSON Output Format:** Your output *must* be a valid JSON array containing *one* JSON object for *each* stored procedure analyzed. The JSON object *must* follow one of the three formats described below: DO NOT include any other text outside of this JSON structure. All keys and string values *must* be enclosed in double quotes (`"`). The example outputs are to be used as a guide:
    {{
        "{table_name}": {{
            "primary_key_changes": {{
                "new_primary_key": "column_name_or_null",
                "justification": ["SQL Query 1 or relevant note"]
            }},
            "column_changes": [
                {{
                    "column": "column_name",
                    "change_type": "datatype_change_or_other",
                    "from": "old_value",
                    "to": "new_value"
                }}
                // Add more column changes objects as needed
            ]
        }}
    }}
    
    **Guidance:**
    - If there are no primary key changes, set "new_primary_key" to null or an empty string.
    - If there are no column changes, the "column_changes" array should be empty ([]).
    - Ensure all string values within the JSON are properly escaped if needed.

    **Input Data:**
    ```
    {file_content}
    ```

    **Output JSON:**
    """

    max_retries = 3
    retry_delay = 5  # seconds (consider exponential backoff for production: 5, 10, 20)

    for attempt in range(max_retries):
        try:
            st.info(f"Attempt {attempt + 1}/{max_retries}: Calling Azure OpenAI (Model: {DEPLOYMENT_NAME})...")
            response = client.chat.completions.create(
                model=DEPLOYMENT_NAME, # Your deployment name
                messages=[{"role": "user", "content": prompt}],
                temperature=0 # For deterministic output
            )

            # Check if response or choices are valid before accessing
            if not response or not response.choices:
                 raise APIError("Received an invalid or empty response from API.", response=response) # Use APIError or a custom one

            json_str = response.choices[0].message.content.strip()

            # Clean potential markdown code blocks
            json_str = re.sub(r"^```json\s*", "", json_str, flags=re.MULTILINE)
            json_str = re.sub(r"\s*```$", "", json_str, flags=re.MULTILINE)
            json_str = json_str.strip()

            if not json_str:
                raise ValueError("LLM returned an empty response after cleaning.")

            try:
                # Attempt to parse the JSON
                parsed_json = json.loads(json_str)
                st.info("✅ Azure OpenAI call successful and JSON parsed.")
                # Basic validation of structure (optional but recommended)
                if table_name not in parsed_json:
                    raise ValueError(f"LLM JSON response missing expected top-level key: '{table_name}'")
                # Add more validation as needed
                return parsed_json

            except json.JSONDecodeError as json_e:
                # If JSON parsing fails even after successful API call
                st.error(f"❌ API call succeeded (Attempt {attempt + 1}), but failed to parse JSON response.")
                st.error(f"JSON Parsing Error: {json_e}")
                st.text_area("LLM Response causing JSON Error:", json_str, height=250, key=f"json_error_{attempt}")
                # Don't retry on JSON errors, raise immediately as it indicates an LLM formatting issue
                raise ValueError(f"LLM response is not valid JSON. Please check the format. Error: {json_e}") from json_e


        # --- Specific, Retryable OpenAI Error Handling ---
        except (RateLimitError) as e:
            error_type = type(e).__name__
            st.warning(f"⚠️ Attempt {attempt + 1} failed: {error_type} - {e}. Rate limit likely exceeded.")
            if attempt < max_retries - 1:
                st.warning(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
                # Optional: Increase delay for next retry (exponential backoff)
                # retry_delay *= 2
            else:
                st.error(f"❌ {error_type} after {max_retries} attempts. Please check your Azure OpenAI quota and usage limits.")
                raise Exception(f"Azure OpenAI API failed after {max_retries} retries due to {error_type}: {e}") from e

        except (APIError, APIConnectionError) as e:
            # Includes server-side errors (5xx) or connection problems
            error_type = type(e).__name__
            st.warning(f"⚠️ Attempt {attempt + 1} failed with API/Connection error: {error_type} - {e}")
            if attempt < max_retries - 1:
                st.warning(f"This might be a temporary service issue. Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
                # Optional: Increase delay
                # retry_delay *= 2
            else:
                st.error(f"❌ API/Connection Error persisted after {max_retries} attempts: {error_type} - {e}. Check Azure service status or network.")
                raise Exception(f"Azure OpenAI API failed after {max_retries} retries due to {error_type}: {e}") from e

        # --- Specific, Non-Retryable OpenAI Error Handling ---
        except (AuthenticationError) as e:
            error_type = type(e).__name__
            st.error(f"❌ Critical API Error: {error_type} - {e}")
            st.error("Authentication failed. Please verify your AZURE_OPENAI_API_KEY is correct and has permissions for the specified endpoint and deployment.")
            raise Exception(f"Azure OpenAI API failed due to {error_type}. Check credentials.") from e

        except (BadRequestError) as e:
            # Includes invalid requests, potentially content filtering triggers
            error_type = type(e).__name__
            st.error(f"❌ Critical API Error: {error_type} - {e}")
            st.error("Invalid request sent to Azure OpenAI. This could be due to:")
            st.error("  - An issue with the prompt structure.")
            st.error("  - Invalid parameters (like model name).")
            st.error("  - Input data triggering Azure's content safety filters.")
            st.error("  - The API version being incompatible.")
            st.error("Please review the prompt, input data, and your Azure deployment settings.")
            # Optionally display the prompt that caused the error if feasible and safe
            # st.text_area("Prompt causing error:", prompt, height=300)
            raise Exception(f"Azure OpenAI API failed due to {error_type}. Check request and content filters.") from e

        # --- Catch Other Potential Exceptions (like ValueError from checks) ---
        except ValueError as ve:
             # Catch ValueErrors raised explicitly within the try block (e.g., empty response, bad table name)
             st.error(f"❌ Data Validation Error: {ve}")
             # These are usually not retryable as they indicate data issues
             raise # Re-raise the ValueError to be caught by the outer handler

        except Exception as e:
            # Catch any other unexpected errors during the API call process
            error_type = type(e).__name__
            st.error(f"❌ An unexpected error occurred during API call on attempt {attempt + 1}: {error_type} - {e}")
            st.error(f"Traceback:\n{traceback.format_exc()}")
            # Decide whether to retry unexpected errors or not. Generally safer not to unless you know they might be transient.
            if attempt < max_retries - 1:
                 st.warning(f"Retrying unexpected error in {retry_delay} seconds...")
                 time.sleep(retry_delay)
            else:
                 st.error(f"❌ Unexpected error persisted after {max_retries} attempts.")
                 raise Exception(f"Unexpected error during Azure OpenAI call: {error_type} - {e}") from e

    # This part should ideally not be reached if logic is correct, but acts as a safeguard
    raise Exception(f"Failed to get a valid response from Azure OpenAI for table '{table_name}' after {max_retries} attempts.")


def copy_files(file_list, src_folder, dest_base_folder, table_name):
    """
    Copies specified files from src_folder to a table-specific subfolder
    within dest_base_folder. Creates/replaces the table-specific folder.
    """
    if not table_name:
        st.error("Cannot copy files: Table name is missing.")
        return [], None # Return empty list and None path

    table_folder = os.path.join(dest_base_folder, table_name)

    st.info(f"Preparing destination folder: {table_folder}")
    # Remove existing folder robustly before copying
    robust_rmtree(table_folder)

    # Create the folder (it should not exist now)
    try:
        os.makedirs(table_folder, exist_ok=False) # exist_ok=False to ensure it was deleted
        st.info(f"Created destination folder: {table_folder}")
    except FileExistsError:
         st.warning(f"Destination folder {table_folder} unexpectedly still exists. Trying to proceed.")
         # You might choose to raise an error here if deletion is critical
    except Exception as e:
        st.error(f"Error creating directory {table_folder}: {e}")
        return [], None # Return empty list and None path

    copied_files = []
    error_occurred = False
    for file_name in file_list:
        src_file_path = os.path.join(src_folder, file_name)
        dest_file_path = os.path.join(table_folder, file_name)

        if os.path.isfile(src_file_path):
            try:
                shutil.copy2(src_file_path, dest_file_path) # copy2 preserves metadata
                copied_files.append(file_name)
                # st.write(f"  - Copied: {file_name}") # Optional: more verbose logging
            except Exception as e:
                st.error(f"Error copying file '{file_name}' from '{src_folder}' to '{table_folder}': {e}")
                error_occurred = True
                # Decide if you want to stop on first error or continue copying others
                # break # Uncomment to stop on first error
        else:
            st.warning(f"File not found in source directory '{src_folder}': {file_name}")
            error_occurred = True # Treat missing file as an issue to report

    if error_occurred:
         st.warning(f"Finished copying process with one or more issues. Copied {len(copied_files)} files.")
    else:
         st.info(f"Successfully copied {len(copied_files)} files to {table_folder}.")

    return copied_files, table_folder


# --- Streamlit UI ---
st.set_page_config(layout="wide")
st.title("🔍 Automated Impact Analysis Tool")
st.markdown("Analyzes the impact of table changes on specified stored procedures using Azure OpenAI and Gemini.")
st.markdown("---")

# --- Step 1: Specify Stored Procedures ---
col1, col2 = st.columns([1, 2])

with col1:
    st.subheader("Step 1: Enter Stored Procedure Filenames")
    st.markdown(f"Enter the names of the stored procedure files (found in `{STORED_PROC_SRC_FOLDER}`) that need to be analyzed. One filename per line.")
    file_list_input = st.text_area("Stored Procedure Filenames:", height=200, label_visibility="collapsed")
    # Convert user input into a list, removing empty lines and whitespace
    proc_file_list = [line.strip() for line in file_list_input.split("\n") if line.strip()]

    if proc_file_list:
        st.write(f"**{len(proc_file_list)} procedures listed for analysis:**")
        st.dataframe(proc_file_list, use_container_width=True)
    else:
        st.info("Enter filenames above.")


# --- Step 2: Upload Table Changes ---
with col2:
    st.subheader("Step 2: Upload Table Changes File")
    st.markdown("Upload a `.txt` file describing the changes to **one specific table**. The filename (without `.txt`) should be the **table name** (e.g., `Customers.txt` for the `Customers` table).")
    uploaded_file = st.file_uploader(
        "Upload table changes file (.txt):",
        type=["txt"],
        label_visibility="collapsed"
        )


# --- Step 3: Run Analysis (Button becomes active when ready) ---
st.subheader("Step 3: Perform Analysis")
analysis_ready = bool(proc_file_list and uploaded_file)
analysis_button_disabled = not analysis_ready

# Placeholders for results
if 'analysis_output_path' not in st.session_state:
    st.session_state['analysis_output_path'] = None
if 'analysis_table_name' not in st.session_state:
    st.session_state['analysis_table_name'] = None


if st.button("🚀 Run Impact Analysis", disabled=analysis_button_disabled):
    if not analysis_ready:
        st.warning("⚠️ Please complete Step 1 (enter filenames) and Step 2 (upload file) first.")
    else:
        st.session_state['analysis_output_path'] = None # Reset previous results
        st.session_state['analysis_table_name'] = None

        # --- Processing Logic ---
        try:
            with st.spinner("Processing... Please wait."):
                # 1. Extract info from uploaded file
                st.info(f"Processing uploaded file: {uploaded_file.name}")
                file_content = uploaded_file.read().decode("utf-8")
                filename = uploaded_file.name
                table_name = extract_table_name_from_filename(filename)
                st.session_state['analysis_table_name'] = table_name # Store for potential download filename
                st.info(f"Extracted Table Name: {table_name}")

                if not table_name or table_name == "unknown_table":
                     raise ValueError("Could not determine a valid table name from the uploaded filename.")

                # 2. Copy relevant stored procedures to a temporary, table-specific folder
                st.info(f"Copying {len(proc_file_list)} specified stored procedures for table '{table_name}'...")
                copied_files, table_proc_folder = copy_files(proc_file_list, STORED_PROC_SRC_FOLDER, STORED_PROC_DEST_FOLDER, table_name)

                if not table_proc_folder:
                    raise RuntimeError("Failed to create or access the stored procedure destination folder. Cannot proceed.")
                if not copied_files:
                     st.warning("No stored procedure files were successfully copied. Analysis might be incomplete or fail.")
                     # Decide if this is a fatal error
                     # raise RuntimeError("Failed to copy any specified stored procedures.")

                # 3. Parse table changes using LLM (includes retries)
                st.info("Parsing table changes using Azure OpenAI...")
                json_data = parse_table_changes_with_llm(file_content, table_name)

                # 4. Save the generated JSON definition
                json_filename = f"{table_name}.json"
                json_path = os.path.join(INPUT_JSON_FOLDER, json_filename)
                st.info(f"Saving parsed table changes to: {json_path}")
                with open(json_path, "w", encoding="utf-8") as f:
                    json.dump(json_data, f, indent=4)
                st.success(f"✅ Table changes JSON created: `{json_path}`")
                with st.expander("View Generated JSON"):
                    st.json(json_data)

                # 5. Run the core impact analysis using gemini_v2
                st.info(f"Running impact analysis using '{table_proc_folder}' and '{json_path}'...")
                # Ensure the gemini_v2 function exists and is callable
                if 'run_impact_analysis' in globals() and callable(run_impact_analysis):
                    output_excel = run_impact_analysis(json_path, table_proc_folder, OUTPUT_FOLDER)
                    st.success(f"📊 Impact Analysis Complete! Report generated.")
                    st.session_state['analysis_output_path'] = output_excel # Store path for download
                else:
                     st.error("Critical Error: 'run_impact_analysis' function is not available. Cannot perform analysis.")
                     raise RuntimeError("Impact analysis function not found.")


        # --- Comprehensive Error Handling ---
        except ValueError as ve:
             st.error(f"❌ Input Data Error: {ve}")
             st.error("Please check the uploaded file content or filename format.")
             st.exception(ve) # Show traceback for debugging
        except ConnectionError as ce:
             st.error(f"❌ Connection Error: {ce}")
             st.error("Could not connect to required services. Check network and Azure credentials/endpoint.")
             st.exception(ce)
        except FileNotFoundError as fnfe:
             st.error(f"❌ File Not Found Error: {fnfe}")
             st.error(f"Ensure the source stored procedure folder exists: {STORED_PROC_SRC_FOLDER}")
             st.exception(fnfe)
        except RuntimeError as rte:
             st.error(f"❌ Runtime Error: {rte}")
             st.exception(rte)
        except Exception as e:
            # Catch any other unexpected error from the process
            st.error(f"❌ An unexpected error occurred during the analysis process:")
            # Display the error type and message clearly
            st.error(f"Error Type: {type(e).__name__}")
            st.error(f"Error Details: {str(e)}")
            # Provide the full traceback for detailed debugging
            st.exception(e) # Streamlit's way to show the full traceback


# --- Step 4: Download Results ---
st.markdown("---")
st.subheader("Step 4: Download Report")

if st.session_state.get('analysis_output_path'):
    output_path = st.session_state['analysis_output_path']
    table_name_for_download = st.session_state.get('analysis_table_name', 'impact_report')
    download_filename = f"{table_name_for_download}_impact_analysis.xlsx"

    if os.path.exists(output_path):
        try:
            with open(output_path, "rb") as fp:
                st.download_button(
                    label="📥 Download Impact Analysis Report (.xlsx)",
                    data=fp,
                    file_name=download_filename,
                    mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                )
            st.success(f"Report ready for download: `{output_path}`")
        except Exception as e:
            st.error(f"Error preparing download for {output_path}: {e}")
    else:
        st.error(f"Report file not found at the expected location: {output_path}. Analysis may have failed.")
else:
    st.info("Complete the analysis steps above to generate a report.")

st.markdown("---")
st.markdown("Developed for Database Modernization Impact Analysis")