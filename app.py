import streamlit as st
import os
import json
import shutil
import dotenv
import re
from openai import AzureOpenAI
from gemini_v2 import run_impact_analysis
import traceback
import time
import stat

# Load environment variables
dotenv.load_dotenv()

# Azure OpenAI Config
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

# Session State Initialization
for key in ['table_proc_folder', 'table_name', 'output_excel', 'processed']:
    if key not in st.session_state:
        st.session_state[key] = None if key != 'processed' else False

# Utility Functions
def extract_table_name_from_filename(filename):
    return os.path.splitext(filename)[0]

def parse_table_changes_with_llm(file_content, table_name):  
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

    max_retries = 3
    retry_delay = 5

    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=DEPLOYMENT_NAME,
                messages=[{"role": "user", "content": prompt}],
                temperature=0
            )

            json_str = response.choices[0].message.content.strip()
            json_str = re.sub(r"```json\s*|\s*```", "", json_str, flags=re.MULTILINE).strip()
            return json.loads(json_str)

        except Exception as e:
            st.error(f"Attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                st.warning(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                raise Exception(f"Error calling Azure OpenAI: {e}")

def copy_files(file_list, src_folder, dest_folder, table_name):
    table_folder = os.path.join(dest_folder, table_name)

    def robust_rmtree(path):
        if not os.path.exists(path): return
        def onerror(func, path, exc_info):
            if not os.access(path, os.W_OK):
                os.chmod(path, stat.S_IWUSR)
                try: func(path)
                except Exception as e: st.error(f"Failed to delete {path}: {e}")
        shutil.rmtree(path, onerror=onerror)

    if os.path.exists(table_folder):
        try:
            robust_rmtree(table_folder)
            time.sleep(0.1)
        except Exception as e:
            st.error(f"Error deleting existing folder: {e}")
            return [], table_folder

    os.makedirs(table_folder, exist_ok=True)
    copied_files = []

    for file_name in file_list:
        src_path = os.path.join(src_folder, file_name)
        if os.path.isfile(src_path):
            try:
                shutil.copy(src_path, os.path.join(table_folder, file_name))
                copied_files.append(file_name)
            except Exception as e:
                st.error(f"Error copying file {file_name}: {e}")
                return copied_files, table_folder

    return copied_files, table_folder

# Streamlit UI
st.title("🔍 Automated Impact Analysis Tool")
st.subheader("📜 Enter Stored Procedure File Names")

file_list_input = st.text_area("Enter one stored procedure filename per line:", height=150)
file_list = [line.strip() for line in file_list_input.split("\n") if line.strip()]

if st.button("📂 Copy Stored Procedures"):
    if not file_list:
        st.warning("⚠️ Please enter at least one stored procedure filename.")
    else:
        st.session_state['table_name'] = "temp_table"
        copied_files, table_proc_folder = copy_files(file_list, STORED_PROC_SRC_FOLDER, STORED_PROC_DEST_FOLDER, st.session_state['table_name'])
        st.success(f"✅ {len(copied_files)} Stored Procedures copied to `{table_proc_folder}`.")
        st.session_state['table_proc_folder'] = table_proc_folder
        st.session_state['processed'] = False

uploaded_file = st.file_uploader("📤 Upload a text file with table changes", type=["txt"])

# Only run processing logic if not already processed
if uploaded_file and not st.session_state['processed']:
    file_content = uploaded_file.read().decode("utf-8")
    table_name = extract_table_name_from_filename(uploaded_file.name)
    st.session_state['table_name'] = table_name

    with st.spinner("Processing with Azure OpenAI..."):
        try:
            json_data = parse_table_changes_with_llm(file_content, table_name)

            if st.session_state['table_proc_folder']:
                old_folder = st.session_state['table_proc_folder']
                new_folder = os.path.join(STORED_PROC_DEST_FOLDER, table_name)
                if os.path.exists(old_folder):
                    try:
                        os.rename(old_folder, new_folder)
                        table_proc_folder = new_folder
                    except Exception as e:
                        st.error(f"Error renaming folder: {e}")
                        table_proc_folder = old_folder
                else:
                    st.error(f"Source folder {old_folder} not found.")
                    table_proc_folder = old_folder
            else:
                raise ValueError("Stored procedure folder was not initialized.")

            json_path = os.path.join(INPUT_JSON_FOLDER, f"{table_name}.json")
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(json_data, f, indent=4)

            st.success(f"✅ JSON file created: {json_path}")

            output_excel = run_impact_analysis(json_path, table_proc_folder, OUTPUT_FOLDER)
            st.success(f"📊 Impact Analysis saved at: {output_excel}")

            st.session_state['output_excel'] = output_excel
            st.session_state['processed'] = True

        except Exception as e:
            st.error(f"❌ An error occurred: {type(e).__name__} - {str(e)}")
            st.session_state['processed'] = False

# Show download button if processing is complete
if st.session_state['processed'] and st.session_state['output_excel']:
    with open(st.session_state['output_excel'], "rb") as file:
        st.download_button(label="📥 Download Impact Report", data=file, file_name=f"{st.session_state['table_name']}.xlsx")

    if st.button("🔁 Start New Analysis"):
        for key in ['table_proc_folder', 'table_name', 'output_excel']:
            st.session_state[key] = None
        st.session_state['processed'] = False
        st.experimental_rerun()
