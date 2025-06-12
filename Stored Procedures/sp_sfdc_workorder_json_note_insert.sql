/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorder_json_note_insert]    Script Date: 11/14/2023 4:48:13 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[sp_sfdc_workorder_json_note_insert]
@next_workorder_id int,
@company_id int,
@profit_ctr_id int,
@JSON_DATA nvarchar(max),
@Notes_subject char(1),
@source_system varchar(100),
@user_code varchar(10)
/*  
Description: 

To Capture the NOTE entry for the RAW JSON data during the data integaration between SFDC & EQAI.

Devops#74012 10/26/2023  Nagaraj M   Created
Devops 77458 --01/31/2024 Venu - Modified for the erorr handling messgae text change
Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
*/

AS
BEGIN
  DECLARE 
  @key_value varchar(400),
  @note_id int,
  @sfs_workorderheader_uid int

  SELECT  @key_value = 'workorder_id;' + isnull(STR(@next_workorder_id),'') +
						' company_id;' + isnull(STR(@company_id),'') +
						' profit_ctr_id;' + isnull(STR(@profit_ctr_id),'') +   
						' JSON_DATA;' + isnull(@JSON_DATA,'') +
						' user_code;' + isnull(@user_code,'')
 
 BEGIN TRY
 BEGIN
   	  select @sfs_workorderheader_uid = max(sfs_workorderheader_uid)
	  from dbo.SFSWorkorderHeader
	  where workorder_id = @next_workorder_id
	  and company_id = @company_id
	  and profit_ctr_id = @profit_ctr_id

      EXECUTE @note_id = sp_sequence_next 'note.note_id'
	  INSERT INTO [dbo].SFSnote (sfs_workorderquoteheader_uid,
                              sfs_workorderheader_uid,
                              note_id,
							  note_source,
							  company_id,
							  profit_ctr_id,
                              note_date,
							  subject,
							  status,
							  note_type,
							  note,
							  customer_id,
							  contact_id,     
							  added_by,
							  date_added,
							  modified_by,
							  date_modified,
							  app_source,      
							  workorder_id,
							  salesforce_json_flag)
					SELECT
                              0,
                              @sfs_workorderheader_uid,
							  @note_id,
							  'Workorder',
							  @company_id,
							  @profit_ctr_id,
							  GETDATE(),
							  CASE @Notes_subject 
							 When 'H' Then 'Salesforce json-workorderheader'
							 When 'D' Then 'Salesforce json-workorderdetail'
							 END
							  'SALESFORCE JSON',
							  'C',
							  'JSON',
							  @JSON_Data,
							  '',
							  '',          
							  @user_code,
							  GETDATE(),
							  @user_code,
							  GETDATE(),
							  'SFDC',							 
							  @next_workorder_id,
							  'Y'
  END

  END TRY

  BEGIN CATCH
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,
										source_system_details,
										action,
										Error_description,
										log_date,
										Added_by)
								 SELECT
										@key_value,
										'sp_sfdc_quote_json_note_insert:: '+ @source_system,
										'Note Insert',
										ERROR_MESSAGE(),
										GETDATE(),
										@user_code
  Return -1 
  END CATCH

END
Return 0
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_json_note_insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_json_note_insert] TO svc_CORAppUser

GO 
