import os
import json
import time
import re
import dotenv
import boto3
import logging
import pandas as pd
import jsonschema

# Load environment variables
dotenv.load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# AWS Bedrock Configuration
BEDROCK_REGION = os.environ.get("BEDROCK_REGION")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID")  # e.g., "anthropic.claude-v2"
BEDROCK_ROLE_ARN = os.environ.get("BEDROCK_ROLE_ARN")

try:
    session = boto3.Session()  # You might need to configure your AWS credentials
    bedrock = session.client("bedrock-runtime", region_name=BEDROCK_REGION)
except Exception as e:
    logging.error(f"Error configuring AWS Bedrock: {e}")
    exit()


# JSON Schema for validation (adjust as needed)
JSON_SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "storedProcedure": {"type": "string"},
            "impacted": {"type": "boolean"},
            "impactedTable": {"type": "string", "nullable": True},
            "impactedColumns": {"type": "array", "items": {"type": "string"}},
            "impactType": {"type": "string", "nullable": True},
            "explanation": {"type": "string"},
            "sampleQuery": {"type": ["string", "null"]},
            "impact_status": {"type": "string", "enum": ["High", "Medium", "Low"]}
        },
        "required": ["storedProcedure", "impacted", "explanation", "impact_status"]
    }
}


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
    Extracts the first valid JSON block from the Bedrock response.
    """
    # Remove any text before the JSON array
    response_text = response_text.strip()
    json_start_index = response_text.find('[')
    if json_start_index > 0:
        response_text = response_text[json_start_index:]

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
    Analyzes stored procedure impacts individually using AWS Bedrock.
    """
    with open(json_file, "r", encoding="utf-8") as f:
        input_json = json.load(f)
    results = []
    for proc_name, proc_code in stored_procedures.items():
        logging.info(f"Analyzing stored procedure: {proc_name}")

        # Create the proc_batch dictionary containing only one stored procedure
        proc_batch = {proc_name: proc_code}

        prompt = f"""
    You are a database expert analyzing the impact of schema changes on stored procedures. You will receive a JSON document describing database schema changes and a single stored procedure. Your task is to analyze the stored procedure for potential impacts based on the schema changes and respond with a JSON array containing a single JSON object with the impact analysis

    Here's the JSON schema for the database schema changes:
    {json.dumps(input_json, indent=4)}

    Here's the stored procedure:
    {json.dumps(proc_batch, indent=4)}

    Analyze the stored procedure and determine:

    1.  **storedProcedure**: Name of procedure being processed

    2.  **impacted**:  Determine whether the stored procedure is impacted by the schema changes.
        A stored procedure is considered impacted if it *directly* references any of the tables or columns that have been changed or removed in the schema changes.

    3.  **impactedTable**:  The name of the table that causes an impact on the stored procedure

    4.  **impactedColumns**: the list of columns that causes impact on stored procedure

    5.  **impactType**: A short description of the reason of impact

    6.  **explanation**: Provide a detailed explanation of how the schema changes might affect the stored procedure. Consider changes in data types, primary keys, constraints, column removals, and new columns.

    7.  **sampleQuery**: If the stored procedure is impacted, provide a sample SQL query (extracted or simplified from the stored procedure's code) that demonstrates the impact. If there is no impacted query , set the value to null

    8.  **impact_status**: provide a rating out of HIGH, MEDUIM, LOW. Base on those consideration

        *   If `impacted` is false, then `impact_status` is "Low"
        *   If `impacted` is true:

            *   If the impact is a Column Deletion, and the column was used in a JOIN or WHERE clause, then `impact_status` is "High"
            *   If the impact is a Data Type Change that requires a code modification in the stored procedure, or may cause data loss, then `impact_status` is "High"
            *   If the impact is a Foreign Key Constraint Modification or Set NOT NULL Constraint that will likely require code review, then `impact_status` is "High".
            *   Otherwise, `impact_status` is "Medium".

    The JSON schema you must follow is:

    \`\`\`json
    [
      {{
        "storedProcedure": "procedure_name",
        "impacted": true or false,
        "impactedTable": "table_name" or null,
        "impactedColumns": ["column1", "column2", ...] or [],
        "impactType": "description of impact" or null,
        "explanation": "detailed explanation of the impact",
        "sampleQuery": "SQL query demonstrating the impact" or null,
        "impact_status": "High" | "Medium" | "Low"
      }}
    ]
    \`\`\`

    **IMPORTANT**: Your ENTIRE response *must* be a valid JSON array containing only one JSON object that conforms to the JSON schema above. If the stored procedure is not impacted, then set impacted to false.

    Let's think step by step.
    """
        # Retry loop for AWS Bedrock
        retries = 3
        for attempt in range(retries):
            try:
                # Prepare the request body for Bedrock
                body = json.dumps({
                    "prompt": prompt,
                    "max_tokens_to_sample": 4096,  # Adjust as needed
                    "temperature": 0.0,  # Adjust as needed,
                    "top_p": 0.9
                })

                response = bedrock.invoke_model(
                    modelId=BEDROCK_MODEL_ID,
                    contentType="application/json",
                    accept="application/json",
                    body=body
                )

                response_body = json.loads(response['body'].read().decode('utf-8'))

                # Extract the generated text
                raw_response = response_body['completion']  # Varies with model
                logging.info(f"Raw Response from Bedrock for {proc_name}:\n{raw_response}")

                cleaned_response = extract_valid_json(raw_response)

                if cleaned_response and isinstance(cleaned_response, list) and len(cleaned_response) == 1:
                    cleaned_response[0]["storedProcedure"] = proc_name
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
                            "impactedTable": "null",
                            "impactedColumns": [],
                            "impactType": "null",
                            "explanation": "Analysis failed due to API errors.",
                            "sampleQuery": "null",
                            "impact_status": "Unknown"})  # added impact_status

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


    # Install xlsxwriter if it's not installed
    try:
        import xlsxwriter
    except ImportError:
        print("xlsxwriter not found. Installing...")
        try:
            import subprocess
            subprocess.check_call(["pip", "install", "xlsxwriter"])
            import xlsxwriter  # Try importing again after installation
        except Exception as e:
            print(f"Failed to install xlsxwriter: {e}")
            return


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
    # Load JSON data
    #with open(json_file_path, "r", encoding="utf-8") as f:
    #    parsed_data = json.load(f)

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
    # Example usage:  (This code will only run when you execute gemini_v2.py directly)
    output_file = run_impact_analysis("input_json\CustomerXUsers.json", "stored_procedures_CustomerXUsers", "output")
    print(f"Impact analysis saved at: {output_file}")