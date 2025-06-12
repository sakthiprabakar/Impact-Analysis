import streamlit as st
import os
import json
import shutil
import dotenv
import re
from openai import AzureOpenAI  # Keep this for LLM-based parse_table_changes_with_llm
from gemini_v2 import run_impact_analysis
import traceback
import time
import stat

# Load environment variables
dotenv.load_dotenv()

# Azure OpenAI Config (Keep for parse_table_changes_with_llm)
API_KEY = os.getenv('AZURE_OPENAI_API_KEY')
ENDPOINT = os.getenv('AZURE_OPENAI_ENDPOINT')
DEPLOYMENT_NAME = os.getenv('AZURE_OPENAI_DEPLOYMENT_NAME')
API_VERSION = os.getenv('API_VERSION')

# Folder Paths
INPUT_JSON_FOLDER = "input_json"
STORED_PROC_SRC_FOLDER = "D:/Gen AI/Impact analysis main/Stored Procedures"
STORED_PROC_DEST_FOLDER = "stored_procedures"
OUTPUT_FOLDER = "output"

# Ensure base folders exist
os.makedirs(INPUT_JSON_FOLDER, exist_ok=True)
os.makedirs(STORED_PROC_DEST_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


# Function to extract table name from the filename
def extract_table_name_from_filename(filename):
    """Extracts the table name from the filename (without extension)."""
    base_name = os.path.splitext(filename)[0]  # Remove extension (.txt)
    return base_name


# Function to parse table changes from text file (LLM-based, using Azure OpenAI)
def parse_table_changes_with_llm(file_content, table_name):  # Added table_name argument
    if not file_content.strip():
        raise ValueError("Input file is empty. Please provide valid data.")

    client = AzureOpenAI(api_key=API_KEY, api_version=API_VERSION, azure_endpoint=ENDPOINT)

    prompt = f"""
    You are an expert in database modernization. Convert the provided text into structured JSON for impact analysis.

    **IMPORTANT: Your ENTIRE response MUST be valid JSON. Do not include ANY other text outside of the JSON structure.** The JSON MUST be a single object with the following structure:

    {{
        "{table_name}": {{
            "primary_key_changes": {{
                "new_primary_key": "column_name",
                "justification": ["SQL Query 1"]
            }},
            "column_changes": [
                {{
                    "column": "column_name",
                    "change_type": "datatype_change",
                    "from": "old_datatype",
                    "to": "new_datatype"
                }}
            ]
        }}
    }}

    **Input Data:**
    {file_content}

    **Output JSON:**
    """

    try:
        response = client.chat.completions.create(
            model=DEPLOYMENT_NAME,
            messages=[{"role": "user", "content": prompt}],
            temperature=0
        )

        json_str = response.choices[0].message.content.strip()

        # Attempt to remove any ```json or ``` block
        json_str = re.sub(r"```json\s*|\s*```", "", json_str, flags=re.MULTILINE).strip()

        try:
            return json.loads(json_str)  # Return JSON data directly
        except json.JSONDecodeError as e:
            raise ValueError(f"Failed to parse JSON. Check LLM response format. Error: {e}\nResponse: {json_str}")
    except Exception as e:
        raise Exception(f"Error calling Azure OpenAI: {e}")


# Function to copy relevant stored procedures to table-specific folder
def copy_files(file_list, src_folder, dest_folder, table_name):
    table_folder = os.path.join(dest_folder, table_name)  # Create folder per table

    #Robustly remove a directory
    def robust_rmtree(path):
        """Robustly removes a directory, handling permission errors."""
        if not os.path.exists(path):
            return

        def onerror(func, path, exc_info):
            """Error handler for rmtree."""
            if not os.access(path, os.W_OK):
                os.chmod(path, stat.S_IWUSR) # Try to make it writeable
                try:
                    func(path) # Try again
                except Exception as e:
                    st.error(f"Failed to delete {path} even after chmod: {e}")

        try:
            shutil.rmtree(path, onerror=onerror)
        except Exception as e:
            st.error(f"Failed to delete directory {path}: {e}")
            raise e

    # Check if the folder already exists and remove it
    if os.path.exists(table_folder):
        try:
            robust_rmtree(table_folder)
            time.sleep(0.1)  # Add a small delay (0.1 seconds)
        except Exception as e:
            st.error(f"Error deleting existing folder: {e}")
            return [], table_folder # Exit

    os.makedirs(table_folder, exist_ok=True)

    copied_files = []
    for file_name in file_list:
        file_path = os.path.join(src_folder, file_name)
        if os.path.isfile(file_path):
            try:
                shutil.copy(file_path, os.path.join(table_folder, file_name))
                copied_files.append(file_name)
            except Exception as e:
                st.error(f"Error copying file {file_name}: {e}")
                # If one file fails, stop copying and return what you have
                return copied_files, table_folder

    return copied_files, table_folder


# Streamlit UI
st.title("🔍 Automated Impact Analysis Tool")

# File list input section (before file upload)
st.subheader("📜 Enter Stored Procedure File Names")
file_list_input = st.text_area("Enter one stored procedure filename per line:", height=150)

# Convert user input into a list
file_list = [line.strip() for line in file_list_input.split("\n") if line.strip()]

# State variable to store the table_proc_folder
if 'table_proc_folder' not in st.session_state:
    st.session_state['table_proc_folder'] = None

# Button to process files (copies the files)
if st.button("📂 Copy Stored Procedures"):
    if not file_list:
        st.warning("⚠️ Please enter at least one stored procedure filename.")
    else:
        # Placeholder table name (will be updated later).  A temporary value.
        if 'table_name' not in st.session_state:
             st.session_state['table_name'] = "temp_table"
        copied_files, table_proc_folder = copy_files(file_list, STORED_PROC_SRC_FOLDER, STORED_PROC_DEST_FOLDER, st.session_state['table_name'])
        st.success(f"✅ {len(copied_files)} Stored Procedures copied to `{table_proc_folder}`.  Now upload the table changes file.")
        st.session_state['table_proc_folder'] = table_proc_folder # Store the path

# File upload section (after copying files)
uploaded_file = st.file_uploader("📤 Upload a text file with table changes", type=["txt"])

if uploaded_file:
    file_content = uploaded_file.read().decode("utf-8")
    filename = uploaded_file.name # Get filename
    table_name = extract_table_name_from_filename(filename)
    st.session_state['table_name'] = table_name

    with st.spinner("Processing with Azure OpenAI..."):
        try:
            # Extract table name and generate JSON
            json_data = parse_table_changes_with_llm(file_content, table_name)  # Pass table_name

            # Update the stored procedures destination folder with the actual table name
            if st.session_state['table_proc_folder']:
                old_folder = st.session_state['table_proc_folder']
                new_folder = os.path.join(STORED_PROC_DEST_FOLDER, table_name)
                if os.path.exists(old_folder):  # Check if the folder exists
                    try:
                        os.rename(old_folder, new_folder)
                        table_proc_folder = new_folder # Update the variable
                    except Exception as e:
                        st.error(f"Error renaming folder: {e}") # added error handling
                        table_proc_folder = old_folder # Use old folder
                else:
                    st.error(f"Source folder {old_folder} not found. Skipping rename.")
                    table_proc_folder = old_folder
            else:
                raise ValueError("Stored procedure folder was not properly initialized.")


            # Save JSON file
            json_path = os.path.join(INPUT_JSON_FOLDER, f"{table_name}.json")
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(json_data, f, indent=4)

            st.success(f"✅ JSON file created: {json_path}")

            # Run impact analysis
            output_excel = run_impact_analysis(json_path, table_proc_folder, OUTPUT_FOLDER)
            st.success(f"📊 Impact Analysis saved at: {output_excel}")

            # Provide download link
            with open(output_excel, "rb") as file:
                st.download_button(label="📥 Download Impact Report", data=file, file_name=f"{table_name}.xlsx")

        except Exception as e:
            st.error(f"❌ An unexpected error occurred: {type(e).__name__} - {str(e)}")  # Show error to user
            st.error(e) #Show Error details