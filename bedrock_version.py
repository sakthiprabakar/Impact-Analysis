import streamlit as st
import os
import json
import shutil
import re
import traceback
import time
import stat # For robust_rmtree permissions
# Make sure to install the boto3 library: pip install boto3
import boto3
from botocore.exceptions import (
    ClientError,
    BotoCoreError,
    EndpointConnectionError,
    NoCredentialsError,
    PartialCredentialsError,
    TokenRetrievalError
)
# Assuming bedrock_v2.py exists in the same directory or is installable
try:
    from bedrock_v2 import run_impact_analysis
except ImportError:
    st.error("ERROR: Could not import 'run_impact_analysis' from 'bedrock_v2'. Make sure bedrock_v2.py exists.")
    # Define a dummy function to allow the rest of the app to load initially
    def run_impact_analysis(json_path, sp_folder, output_folder):
        st.warning("Using dummy 'run_impact_analysis'. Real analysis will not occur.")
        dummy_path = os.path.join(output_folder, f"{os.path.splitext(os.path.basename(json_path))[0]}_dummy_report.xlsx")
        # Create a dummy file to avoid download errors
        with open(dummy_path, "w") as f:
            f.write("This is a dummy report because bedrock_v2 was not found.")
        return dummy_path # Return a plausible path


# --- Configuration ---

# AWS Bedrock Config (Get from Streamlit secrets)
try:
    AWS_ACCESS_KEY_ID = st.secrets["AWS_ACCESS_KEY_ID"]
    AWS_SECRET_ACCESS_KEY = st.secrets["AWS_SECRET_ACCESS_KEY"]
    AWS_REGION = st.secrets.get("AWS_REGION", "us-east-1")  # Default to us-east-1
    MODEL_ID = st.secrets.get("BEDROCK_MODEL_ID", "anthropic.claude-3-sonnet-20240229-v1:0")  # Default model
    
    # Get stored procedures source folder from secrets (optional, with fallback)
    STORED_PROC_SRC_FOLDER = st.secrets.get("STORED_PROC_SRC_FOLDER", "stored_procedures_source")
    
except KeyError as e:
    st.error(f"❌ Missing required secret: {e}")
    st.error("Please ensure the following secrets are configured in Streamlit Cloud:")
    st.code("""
    # Required secrets in Streamlit Cloud:
    AWS_ACCESS_KEY_ID = "your_aws_access_key"
    AWS_SECRET_ACCESS_KEY = "your_aws_secret_key"
    
    # Optional secrets (will use defaults if not provided):
    AWS_REGION = "us-east-1"
    BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
    STORED_PROC_SRC_FOLDER = "stored_procedures_source"
    """)
    st.stop() # Halt execution if config is missing

# Check if essential AWS configs are loaded
if not all([AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY]):
    st.error("❌ Critical AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) are missing. Please check your Streamlit secrets configuration.")
    st.stop() # Halt execution if config is missing


# Folder Paths
INPUT_JSON_FOLDER = "input_json"
STORED_PROC_DEST_FOLDER = "stored_procedures"
OUTPUT_FOLDER = "output"

# Ensure base folders exist
os.makedirs(INPUT_JSON_FOLDER, exist_ok=True)
os.makedirs(STORED_PROC_DEST_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# Create source folder if it doesn't exist (for Streamlit Cloud deployment)
os.makedirs(STORED_PROC_SRC_FOLDER, exist_ok=True)


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
    Parses table changes using AWS Bedrock with improved retry logic
    and specific exception handling.
    """
    if not file_content.strip():
        raise ValueError("Input file content is empty. Please provide valid data.")
    if not table_name or table_name == "unknown_table":
        raise ValueError("Invalid table name derived from filename.")

    # Ensure Bedrock client is initialized with necessary credentials
    try:
        bedrock_client = boto3.client(
            'bedrock-runtime',
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
            region_name=AWS_REGION
        )
    except Exception as e:
        st.error(f"Failed to initialize AWS Bedrock client: {e}")
        raise ConnectionError(f"Could not initialize AWS Bedrock client. Check credentials and region. Error: {e}")


    # Construct the prompt exactly as before
    prompt = f"""
    You are an expert in database modernization. Convert the provided text into structured JSON for impact analysis.

    **IMPORTANT: Your ENTIRE response MUST be valid JSON. Do not include ANY other text outside of the JSON structure.** The JSON MUST be a single object with the following structure:
    For *each* stored procedure in the batch, follow these rules:

    **Important: DO NOT HALLUCINATE DATA. Only provide information explicitly present within the provided stored procedure code and the provided schema changes. If there is NO direct impact, state that there is no direct impact. Do not invent or infer any other information.**

    1. **Direct Impact Only:** A stored procedure is *directly* impacted *only if* its *own SQL code (the specific SQL statements directly within the stored procedure definition)* directly references any of the **tables or columns mentioned in the schema changes**. A "direct reference" means that these table or column names appear explicitly in the stored procedure's SQL statements (e.g., in a `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `JOIN` clause). If the stored procedure accesses these elements *indirectly* through another table, it is *not* considered directly impacted and should be marked as "not impacted."

    2. **Column Deletion Impact:** If any column listed under `"deletion_changes"` in the schema changes is referenced in the stored procedure's SQL statements—including `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, or variable assignments—the procedure should be considered *impacted* with an **impactType** of `"Column Deletion"`. If the deleted column is used in conditions, calculations, or joins, specify the risk of query failure due to missing columns.

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
            st.info(f"Attempt {attempt + 1}/{max_retries}: Calling AWS Bedrock (Model: {MODEL_ID})...")
            
            # Prepare the request body based on the model type
            if 'anthropic.claude' in MODEL_ID:
                # Claude model format
                request_body = {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 4000,
                    "temperature": 0,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                }
            elif 'amazon.titan' in MODEL_ID:
                # Titan model format
                request_body = {
                    "inputText": prompt,
                    "textGenerationConfig": {
                        "maxTokenCount": 4000,
                        "temperature": 0,
                        "topP": 1
                    }
                }
            else:
                # Generic format - adjust as needed for other models
                request_body = {
                    "prompt": prompt,
                    "max_tokens": 4000,
                    "temperature": 0
                }

            response = bedrock_client.invoke_model(
                modelId=MODEL_ID,
                body=json.dumps(request_body),
                contentType='application/json'
            )

            # Parse the response
            response_body = json.loads(response['body'].read())
            
            # Extract content based on model type
            if 'anthropic.claude' in MODEL_ID:
                if 'content' in response_body and response_body['content']:
                    json_str = response_body['content'][0]['text']
                else:
                    raise ValueError("No content in Claude response")
            elif 'amazon.titan' in MODEL_ID:
                if 'results' in response_body and response_body['results']:
                    json_str = response_body['results'][0]['outputText']
                else:
                    raise ValueError("No results in Titan response")
            else:
                # Generic extraction - adjust as needed
                json_str = response_body.get('completion', response_body.get('text', ''))

            if not json_str:
                raise ValueError("Model returned an empty response.")

            # Clean potential markdown code blocks
            json_str = re.sub(r"^```json\s*", "", json_str, flags=re.MULTILINE)
            json_str = re.sub(r"\s*```$", "", json_str, flags=re.MULTILINE)
            json_str = json_str.strip()

            if not json_str:
                raise ValueError("Model returned an empty response after cleaning.")

            try:
                # Attempt to parse the JSON
                parsed_json = json.loads(json_str)
                st.info("✅ AWS Bedrock call successful and JSON parsed.")
                # Basic validation of structure (optional but recommended)
                if table_name not in parsed_json:
                    raise ValueError(f"Model JSON response missing expected top-level key: '{table_name}'")
                # Add more validation as needed
                return parsed_json

            except json.JSONDecodeError as json_e:
                # If JSON parsing fails even after successful API call
                st.error(f"❌ API call succeeded (Attempt {attempt + 1}), but failed to parse JSON response.")
                st.error(f"JSON Parsing Error: {json_e}")
                st.text_area("Model Response causing JSON Error:", json_str, height=250, key=f"json_error_{attempt}")
                # Don't retry on JSON errors, raise immediately as it indicates a model formatting issue
                raise ValueError(f"Model response is not valid JSON. Please check the format. Error: {json_e}") from json_e


        # --- Specific, Retryable AWS Error Handling ---
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            if error_code in ['ThrottlingException', 'TooManyRequestsException']:
                st.warning(f"⚠️ Attempt {attempt + 1} failed: Rate limit exceeded - {error_message}")
                if attempt < max_retries - 1:
                    st.warning(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    # Optional: Increase delay for next retry (exponential backoff)
                    # retry_delay *= 2
                else:
                    st.error(f"❌ Rate limit exceeded after {max_retries} attempts. Please wait and try again later.")
                    raise Exception(f"AWS Bedrock API failed after {max_retries} retries due to rate limiting: {error_message}") from e
            
            elif error_code in ['InternalServerException', 'ServiceUnavailableException']:
                st.warning(f"⚠️ Attempt {attempt + 1} failed with server error: {error_code} - {error_message}")
                if attempt < max_retries - 1:
                    st.warning(f"This might be a temporary service issue. Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    st.error(f"❌ Server Error persisted after {max_retries} attempts: {error_code} - {error_message}")
                    raise Exception(f"AWS Bedrock API failed after {max_retries} retries due to server error: {error_message}") from e
            
            elif error_code in ['UnauthorizedOperation', 'AccessDeniedException']:
                st.error(f"❌ Critical API Error: {error_code} - {error_message}")
                st.error("Access denied. Please verify your AWS credentials have permissions for Bedrock and the specified model.")
                raise Exception(f"AWS Bedrock API failed due to access error. Check credentials and permissions.") from e
            
            elif error_code in ['ValidationException', 'InvalidRequestException']:
                st.error(f"❌ Critical API Error: {error_code} - {error_message}")
                st.error("Invalid request sent to AWS Bedrock. This could be due to:")
                st.error("  - An issue with the request structure.")
                st.error("  - Invalid model ID.")
                st.error("  - Input data exceeding model limits.")
                st.error("Please review the request parameters and model specifications.")
                raise Exception(f"AWS Bedrock API failed due to validation error. Check request format.") from e
            
            else:
                # Other ClientErrors
                st.error(f"❌ AWS Client Error: {error_code} - {error_message}")
                if attempt < max_retries - 1:
                    st.warning(f"Retrying unknown client error in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    st.error(f"❌ Client error persisted after {max_retries} attempts.")
                    raise Exception(f"AWS Bedrock API failed with client error: {error_code} - {error_message}") from e

        except (EndpointConnectionError, BotoCoreError) as e:
            error_type = type(e).__name__
            st.warning(f"⚠️ Attempt {attempt + 1} failed with connection error: {error_type} - {e}")
            if attempt < max_retries - 1:
                st.warning(f"This might be a temporary network issue. Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                st.error(f"❌ Connection Error persisted after {max_retries} attempts: {error_type} - {e}. Check network connectivity and AWS region.")
                raise Exception(f"AWS Bedrock API failed after {max_retries} retries due to connection error: {e}") from e

        except (NoCredentialsError, PartialCredentialsError, TokenRetrievalError) as e:
            error_type = type(e).__name__
            st.error(f"❌ Critical Credentials Error: {error_type} - {e}")
            st.error("AWS credentials are missing or invalid. Please verify your AWS configuration.")
            raise Exception(f"AWS Bedrock API failed due to credentials error. Check AWS setup.") from e

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
                 raise Exception(f"Unexpected error during AWS Bedrock call: {error_type} - {e}") from e

    # This part should ideally not be reached if logic is correct, but acts as a safeguard
    raise Exception(f"Failed to get a valid response from AWS Bedrock for table '{table_name}' after {max_retries} attempts.")


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
st.markdown("Analyzes the impact of table changes on specified stored procedures using AWS Bedrock and Bedrock v2.")

# Display configuration info in sidebar
with st.sidebar:
    st.subheader("⚙️ Configuration")
    st.write(f"**AWS Region:** {AWS_REGION}")
    st.write(f"**Model:** {MODEL_ID}")
    st.write(f"**Source Folder:** {STORED_PROC_SRC_FOLDER}")
    
    # Show folder status
    src_exists = os.path.exists(STORED_PROC_SRC_FOLDER)
    st.write(f"**Source Folder Exists:** {'✅' if src_exists else '❌'}")
    
    if not src_exists:
        st.warning("⚠️ Source folder for stored procedures doesn't exist. It will be created, but you may need to upload your stored procedure files.")

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
                st.info("Parsing table changes using AWS Bedrock...")
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

                # 5. Run the core impact analysis using bedrock_v2
                st.info(f"Running impact analysis using '{table_proc_folder}' and '{json_path}'...")
                # Ensure the bedrock_v2 function exists and is callable
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
             st.error("Could not connect to required services. Check network and AWS credentials/region.")
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