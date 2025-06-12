import os
import json
import time
import re
import streamlit as st
import boto3
from botocore.exceptions import ClientError
import logging
import pandas as pd
import jsonschema

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Configure AWS Bedrock using Streamlit secrets
try:
    # Access AWS credentials from Streamlit secrets
    aws_access_key_id = st.secrets["AWS_ACCESS_KEY_ID"]
    aws_secret_access_key = st.secrets["AWS_SECRET_ACCESS_KEY"]
    aws_region = st.secrets.get("AWS_REGION", "us-east-1")
    
    # Create boto3 client with explicit credentials
    bedrock = boto3.client(
        'bedrock-runtime',
        region_name=aws_region,
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key
    )
    
    model_id = "anthropic.claude-3-5-sonnet-20240620-v1:0"
    
except KeyError as e:
    logging.error(f"Missing required AWS credential in Streamlit secrets: {e}")
    st.error(f"Missing required AWS credential: {e}")
    st.stop()
except Exception as e:
    logging.error(f"Error configuring AWS Bedrock: {e}")
    st.error(f"Error configuring AWS Bedrock: {e}")
    st.stop()

# JSON Schema for validation (adjust as needed)
JSON_SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "storedProcedure": {"type": "string"},
            "impacted": {"type": "boolean"},
            "impactedTable": {"type": "string", "nullable": True}, #Making those field nullable
            "impactedColumns": {"type": "array", "items": {"type": "string"}},
            "impactType": {"type": "string", "nullable": True}, #Making those field nullable
            "explanation": {"type": "string"},
            "sampleQuery": {"type": ["string", "null"]},
            "impact_status": {"type": "string", "enum": ["High", "Medium", "Low"]}
        },
        "required": ["storedProcedure", "impacted", "explanation", "impact_status"]
    }
}


def generate_response(prompt):
    """
    Sends a request to AWS Bedrock Anthropic Claude-3 Sonnet and retrieves a response.
    """
    payload = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4000,
        "temperature": 0,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": prompt}],
            }
        ],
    }
    try:
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(payload),
            accept="application/json",
            contentType="application/json"
        )
        response_body = json.loads(response["body"].read())
        # Extract response text
        raw_response = response_body["content"][0]["text"]
        return raw_response
    except (ClientError, Exception) as e:
        logging.error(f"ERROR: Can't invoke '{model_id}'. Reason: {e}")
        return None


def read_stored_procedures(folder):
    """
    Reads all stored procedure SQL files in the folder and returns a dictionary of {proc_name: sql_content}.
    """
    stored_procs = {}
    for filename in os.listdir(folder):
        if filename.endswith(".sql"):
            proc_name = filename[:-4]  # Remove .sql extension
            filepath = os.path.join(folder, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as file:
                    stored_procs[proc_name] = file.read()
            except FileNotFoundError:
                logging.warning(f"File not found: {proc_name}. Skipping.")
            except Exception as e:
                logging.error(f"Error reading file {filepath}: {e}. Skipping.")

    return stored_procs


def extract_valid_json(response_text):
    """
    Extracts the first valid JSON block from the Claude response.
    Returns None if no valid JSON is found.
    """
    # Remove ```json and ``` blocks
    response_text = re.sub(r"```json\s*|\s*```", "", response_text, flags=re.MULTILINE).strip()

    # Try to find a valid JSON array containing a single object
    json_match = re.search(r"^\[\s*\{.*\}\s*\]$", response_text, re.DOTALL)

    if json_match:
        json_str = json_match.group(0)
        try:
            data = json.loads(json_str)

            # Validate against schema
            jsonschema.validate(instance=data, schema=JSON_SCHEMA)
            return data
        except json.JSONDecodeError as e:
            logging.warning(f"Failed to parse extracted JSON: {e}")
            return None
        except jsonschema.exceptions.ValidationError as e:
            logging.warning(f"JSON validation failed: {e}")
            return None
    else:
        logging.warning("No JSON found in response.")
        return None


def analyze_stored_procedure_impact(json_file, stored_procedures):
    """
    Analyzes stored procedure impacts individually.
    """
    with open(json_file, "r", encoding="utf-8") as f:
        input_json = json.load(f)
    results = []
    for proc_name, proc_code in stored_procedures.items():
        logging.info(f"Analyzing stored procedure: {proc_name}")

        # Create the proc_batch dictionary containing only one stored procedure
        proc_batch = {proc_name: proc_code}

        prompt = f"""
    Your output *must* be a valid JSON array containing *one* JSON object for *each* stored procedure analyzed.  DO NOT include any other text outside of this JSON structure. If the structure is invalid, the response will be rejected.

    As a Database Master with extensive experience, I need your expert analysis on the impact of database schema changes on specific stored procedures.

    Here are the database schema changes:

    {json.dumps(input_json, indent=4)}

    I will provide a batch of stored procedures. Analyze each one **individually and in isolation**, considering *only* the provided schema changes. **Do not introduce information or dependencies beyond what is explicitly given.** Focus strictly on *direct* dependencies between the stored procedure code and the changed schema elements.

    Here are the stored procedures for analysis:

    {json.dumps(proc_batch, indent=4)}

    For *each* stored procedure in the batch, follow these rules:

    **Important: DO NOT HALLUCINATE DATA. Only provide information explicitly present within the provided stored procedure code and the provided schema changes. If there is NO direct impact, state that there is no direct impact. Do not invent or infer any other information.**

    1. **Direct Impact Only:** A stored procedure is *directly* impacted *only if* its *own SQL code (the specific SQL statements directly within the stored procedure definition)* directly references any of the **tables or columns mentioned in the schema changes**. A "direct reference" means that these table or column names appear explicitly in the stored procedure's SQL statements (e.g., in a `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `JOIN` clause). If the stored procedure accesses these elements *indirectly* through another table, it is *not* considered directly impacted and should be marked as "not impacted."

    2. **Column Deletion Impact:** If any column listed under `"deletion_changes"` in the schema changes is referenced in the stored procedure's SQL statements—including `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, or variable assignments—the procedure should be considered *impacted* with an **impactType** of `"Column Deletion"`. If the deleted column is used in conditions, calculations, or joins, specify the risk of query failure due to missing columns.

    3. **JSON Output Format:** Your output *must* be a valid JSON array containing *one* JSON object for *each* stored procedure analyzed. The JSON object *must* follow one of the three formats described below: DO NOT include any other text outside of this JSON structure. All keys and string values *must* be enclosed in double quotes (`"`). The example outputs are to be used as a guide:

    
    4. **Direct Reference Required:** 
    A stored procedure is considered *impacted* **only if** its own SQL code (not downstream, dynamic, or inferred logic) **explicitly references the changed tables/columns**. Look for direct mentions in `SELECT`, `JOIN`, `WHERE`, `GROUP BY`, `ORDER BY`, `INSERT`, `UPDATE`, `DELETE`, or assignments. 
    
    ➤ If the column does **not** appear in the code, **even if it exists in the table**, it is **not impacted**.

    5. **No Downstream Assumptions:** 
    Do NOT infer impact based on potential downstream usage, application-level logic, or indirect dependencies. If the column or table is **not directly used**, mark it as **not impacted**.

    6. **Hallucination is Forbidden:** 
    DO NOT assume usage of a column or table unless it appears in the code. Your analysis must be grounded only in the supplied stored procedure and schema change. No assumptions, no guesses.

 
      **Format 1: Not Impacted**
        ```json
        [
          {{
            "storedProcedure": "sp_name",
            "impacted": false,
            "explanation": "No direct impact detected from the provided schema changes. The stored procedure does not directly reference any of the affected tables or columns in its own SQL code.",
            "impact_status": "Low"
          }}
        ]
        ```

      **Format 2: Impacted (with Sample Query)**
        ```json
        [
          {{
            "storedProcedure": "sp_name",
            "impacted": true,
            "impactedTable": "affected_table_name",
            "impactedColumns": ["affected_column1", "affected_column2", ...],  // List the specific impacted columns
            "impactType": "Description of the impact (e.g., Data Type Change, Primary Key Change, Column Deletion)",
            "explanation": "Detailed explanation of how the schema change impacts the stored procedure's functionality.  The sampleQuery MUST be extracted or simplified from the stored procedure's code.",
            "sampleQuery": "SQL code snippet extracted from the stored procedure demonstrating the impact. This should be a minimal, executable snippet that includes the impacted table and columns (e.g., a WHERE clause, a SELECT statement, etc.). If you cannot find a directly relevant code snippet, provide a simplified or representative query demonstrating the impact.",
            "impact_status": "High"
          }}
        ]
        ```

      **Format 3: Impacted (No Directly Extractable Sample Query)**
        ```json
        [
          {{
            "storedProcedure": "sp_name",
            "impacted": true,
            "impactedTable": "affected_table_name",
            "impactedColumns": ["affected_column1", "affected_column2", ...],  // List the specific impacted columns
            "impactType": "Description of the impact (e.g., Data Type Change, Primary Key Change, Column Deletion)",
            "explanation": "Detailed explanation of how the schema change impacts the stored procedure's functionality. While the stored procedure is impacted, there is no directly extractable SQL code snippet that clearly demonstrates the impact. The impact is primarily on [explain the nature of the impact, e.g., variable declarations, data type conversions, etc. that are not directly visible in a query].",
            "sampleQuery": null,  // Explicitly set to null if no extractable sample query exists
            "impact_status": "High"
          }}
        ]
        ```

    4. **Determine 'impact_status':**

        *  If `impacted` is false, then `impact_status` is "Low"
        * If `impacted` is true:

            *  If the impact is a Column Deletion, and the column was used in a JOIN or WHERE clause, then `impact_status` is "High"
            *  If the impact is a Data Type Change that requires a code modification in the stored procedure, or may cause data loss, then `impact_status` is "High"
            *  If the impact is a Foreign Key Constraint Modification or Set NOT NULL Constraint that will likely require code review, then `impact_status` is "High".
            *  Otherwise, `impact_status` is "Medium".

    5. **Column Naming:** The `impactedColumns` field should list only columns from the schema changes under `column_changes`, `constraints_changes`, and `deletion_changes`. Extract relevant table and column names dynamically.

    6. **Example `impactType` Values:**
        * "Data Type Change"
        * "Primary Key Change Enforcement"
        * "Column Deletion"
        * "Foreign Key Constraint Modification"
        * "Set NOT NULL Constraint"

    7. **`sampleQuery` Guidelines:** The `sampleQuery` field should contain a *minimal*, executable SQL code snippet *extracted or simplified* from the stored procedure's code. If *no* suitable query can be constructed, set `"sampleQuery": null` and provide a detailed explanation in the "explanation" field. **If no suitable code can be found in the stored procedure, set "sampleQuery: null" and explain that the impact does not manifest as a query but a change of behavior.**

    Let's think step by step.

    Your output *must* be a valid JSON array containing *one* JSON object for *each* stored procedure analyzed.  DO NOT include any other text outside of this JSON structure. If the structure is invalid, the response will be rejected.
    """
        # Retry loop for Bedrock API

        retries = 3
        for attempt in range(retries):
            try:
                raw_response = generate_response(prompt)
                
                if raw_response is None:
                    raise ValueError(f"No response received from Bedrock API for {proc_name}.")
                
                logging.info(f"Raw Response from Bedrock for {proc_name}:\n{raw_response}")

                cleaned_response = extract_valid_json(raw_response)

                if cleaned_response and isinstance(cleaned_response, list) and len(cleaned_response) == 1:
                    results.append(cleaned_response[0])  # Append the single JSON object
                    break  # Exit retry loop if successful
                else:
                    raise ValueError(f"Failed to extract valid JSON or incorrect array length for {proc_name}.")

            except (json.JSONDecodeError, ValueError, jsonschema.exceptions.ValidationError) as e:
                logging.warning(f"JSON parsing failed (Attempt {attempt + 1}/{retries}) for {proc_name}. Retrying...\nError: {e}")
                time.sleep(2)
            except Exception as e:
                logging.error(f"Unexpected error during Bedrock API call for {proc_name}: {e}")
                time.sleep(2)
        else:
            logging.error(f"Maximum retries reached for {proc_name}. Skipping this procedure.")
            results.append({"storedProcedure": proc_name,
                            "impacted": False,
                            "explanation": "Analysis failed due to API errors.",
                            "impact_status": "High"})  # added impact_status

    return {"impacted_stored_procedures": results}


def save_to_excel(impact_result, output_filename="CustomerBilling_3.xlsx"):
    """
    Saves the impact analysis results to an Excel file.
    Handles cases where the `sampleQuery` is None or missing.
    """
    if not impact_result["impacted_stored_procedures"]:
        logging.info("No impacted stored procedures found. Skipping Excel generation.")
        return

    df = pd.DataFrame(impact_result["impacted_stored_procedures"])

    # Ensure all expected columns exist
    expected_columns = ["storedProcedure", "impacted", "impactedTable", "impactedColumns", "impactType", "explanation",
                        "sampleQuery", "impact_status"]
    for col in expected_columns:
        if col not in df.columns:
            df[col] = None  # Ensure column exists

    # Convert lists to strings for Excel compatibility, handle None values, and ensure strings
    if "impactedColumns" in df.columns:
        df["impactedColumns"] = df["impactedColumns"].apply(
            lambda x: ", ".join(x) if isinstance(x, list) else str(x) if x is not None else "")

    # Fill None values with empty strings for string columns
    for col in ["impactedTable", "impactType", "explanation", "sampleQuery"]:
        if col in df.columns:
            df[col] = df[col].fillna("")


    df.rename(columns={
        "storedProcedure": "Stored Procedure",
        "impacted": "Impacted",
        "impactedTable": "Impacted Table",
        "impactedColumns": "Impacted Columns",
        "impactType": "Impact Type",
        "explanation": "Explanation",
        "sampleQuery": "Sample Query",
        "impact_status": "Impact Status"
    }, inplace=True)

    with pd.ExcelWriter(output_filename, engine="xlsxwriter") as writer:
        df.to_excel(writer, index=False, sheet_name="Impact Analysis")

        # Get the xlsxwriter objects from the dataframe writer object.
        workbook  = writer.book
        worksheet = writer.sheets['Impact Analysis']

        # Add a header format.
        header_format = workbook.add_format({
            'bold': True,
            'text_wrap': True,
            'valign': 'top',
            'fg_color': '#D7E4BC',  # Light green, you can change this
            'border': 1})

        # Write the column headers with the defined format.
        for col_num, value in enumerate(df.columns.values):
            worksheet.write(0, col_num, value, header_format)

        # Auto-fit columns
        for i, col in enumerate(df.columns):
           max_len = df[col].astype(str).str.len().max()
           max_len = max(max_len, len(col)) + 2  # padding
           worksheet.set_column(i, i, max_len)


    logging.info(f"Impact analysis report saved to {output_filename}")


def run_impact_analysis(json_file_path, stored_proc_folder, output_folder):
    """
    Runs impact analysis and saves the result to an Excel file named after the table name from JSON.

    Parameters:
    json_file_path (str): Path to the JSON file containing reference data.
    stored_proc_folder (str): Path to the folder containing stored procedure SQL files.
    output_folder (str): Directory where the result Excel file will be saved.

    Returns:
    str: Path to the saved Excel file.
    """
    # Extract the table name (first key in JSON)
    table_name = os.path.splitext(os.path.basename(json_file_path))[0]

    # Read stored procedure SQL files
    stored_procedures = read_stored_procedures(stored_proc_folder)

    # Run impact analysis
    impact_result = analyze_stored_procedure_impact(json_file_path, stored_procedures)

    # Construct the output file path using the table name
    output_excel_path = os.path.join(output_folder, f"{table_name}.xlsx")

    # Save results to Excel
    save_to_excel(impact_result, output_excel_path)

    return output_excel_path  # Returning the file path for further use

# PREVENT THIS CODE FROM RUNNING ON IMPORT
if __name__ == "__main__":
    # Example usage:  (This code will only run when you execute the script directly)
    output_file = run_impact_analysis("input_json/CustomerXUsers.json", "stored_procedures_CustomerXUsers", "output")
    print(f"Impact analysis saved at: {output_file}")