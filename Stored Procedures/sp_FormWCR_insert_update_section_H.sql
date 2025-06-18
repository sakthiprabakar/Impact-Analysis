USE [PLT_AI]
GO
CREATE OR ALTER PROCEDURE dbo.sp_FormWCR_insert_update_section_H
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/************************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
**********************************************************************************/
BEGIN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id and revision_id = @revision_id)
			BEGIN
				UPDATE dbo.FormWCR
				   SET specific_technology_requested = p.v.value('specific_technology_requested[1]', 'CHAR(1)')
				     , requested_technology = p.v.value('requested_technology[1]', 'VARCHAR(255)')
					 , thermal_process_flag =  p.v.value('thermal_process_flag[1]', 'CHAR(1)')
					 , other_restrictions_requested = p.v.value('other_restrictions_requested[1]', 'VARCHAR(255)')
					 , signing_name = p.v.value('signing_name[1]', 'VARCHAR(40)')
					 , signing_title = p.v.value('signing_title[1]', 'VARCHAR(40)')
					 , signing_company = p.v.value('signing_company[1]', 'VARCHAR(40)')
					 , signed_on_behalf_of = p.v.value('signed_on_behalf_of[1]', 'CHAR(1)')
					 , signing_date = NULL
				  FROM @Data.nodes('SectionH')p(v)
				 WHERE form_id = @form_id
				   AND revision_id = @revision_id;

				IF EXISTS (SELECT form_id FROM dbo.FormXUSEFacility WHERE form_id = @form_id and revision_id = @revision_id)
					BEGIN
						DELETE FROM dbo.FormXUSEFacility WHERE form_id = @form_id and revision_id = @revision_id;
					END

				DECLARE @specific_technology_requested VARCHAR(10);
				SELECT @specific_technology_requested = p.v.value('specific_technology_requested[1]', 'CHAR(1)')
				  FROM @Data.nodes('SectionH')p(v);

				IF @specific_technology_requested = 'T'
					BEGIN
						INSERT INTO dbo.FormXUSEFacility (form_id, revision_id, company_id, profit_ctr_id
						     , date_created, date_modified, created_by, modified_by)
							SELECT @form_id as form_id
							     , @revision_id as revision_id
								 , p.v.value('company_id[1]', 'INT') as company_id
								 , p.v.value('profit_ctr_id[1]', 'INT') as profit_ctr_id
								 , GETDATE() as date_created
								 , GETDATE() as date_modified
								 , @web_userid as created_by
								 , @web_userid as modified_by
							  FROM @Data.nodes('SectionH/USEFacility/USEFacility')p(v);
					END	
				
				IF NOT EXISTS (SELECT form_id FROM dbo.FormSignature WHERE form_id = @form_id and revision_id = @revision_id)
					BEGIN
						INSERT INTO dbo.FormSignature (form_id, revision_id
						     , form_signature_type_id
							 , form_version_id
						     , sign_company
							 , sign_name
							 , sign_title
							 , sign_email
							 , sign_phone
							 , sign_fax
							 , sign_address
							 , sign_city
							 , sign_state
							 , sign_zip_code
							 , date_added
							 , sign_comment_internal
							 , logon
							 , contact_id
							 , e_signature_type_id
							 , e_signature_envelope_id
							 , e_signature_url
							 , e_signature_status, web_userid
							 , created_by, date_created
							 , modified_by, date_modified)
							SELECT @form_id as form_id, p.v.value('revision_id[1]', 'INT') as revision_id
							     , p.v.value('form_signature_type_id[1]', 'INT') as form_signature_type_id
								 , p.v.value('form_version_id[1]', 'INT') as form_version_id
								 , p.v.value('sign_company[1]', 'VARCHAR(40)') as sign_company
								 , p.v.value('sign_name[1]', 'VARCHAR(40)') as sign_name
								 , p.v.value('sign_title[1]', 'VARCHAR(20)') as sign_title
								 , p.v.value('sign_email[1]', 'VARCHAR(60)') as sign_email
								 , p.v.value('sign_phone[1]', 'VARCHAR(20)') as sign_phone
								 , p.v.value('sign_fax[1]', 'VARCHAR(20)') as sign_fax
								 , p.v.value('sign_address[1]', 'VARCHAR(255)') as sign_address
								 , p.v.value('sign_city[1]', 'VARCHAR(40)') as sign_city
								 , p.v.value('sign_state[1]', 'VARCHAR(2)') as sign_state
								 , p.v.value('sign_zip_code[1]', 'VARCHAR(15)') as sign_zip_code
								 , GETDATE() as date_added
								 , p.v.value('sign_comment_internal[1]', 'VARCHAR(500)') as sign_comment_internal
								 , p.v.value('logon[1]', 'VARCHAR(60)') as logon
								 , p.v.value('contact_id[1]', 'INT') as contact_id
								 , p.v.value('e_signature_type_id[1]', 'INT') as e_signature_type_id
								 , NULL as e_signature_envelope_id
								 , p.v.value('e_signature_url[1]', 'VARCHAR(255)') as e_signature_url
								 , NULL as e_signature_status, @web_userid as web_userid
								 , @web_userid as created_by, GETDATE() as date_created
								 , @web_userid as modified_by, GETDATE() as date_modified
							  FROM @Data.nodes('SectionH/Signature/Signature')p(v);
					END
				ELSE
					BEGIN
						UPDATE dbo.FormSignature
						   SET form_version_id = p.v.value('form_version_id[1]', 'int')
						     , sign_company = p.v.value('sign_company[1]', 'VARCHAR(40)')
							 , sign_name = p.v.value('sign_name[1]', 'VARCHAR(40)')
							 , sign_title = p.v.value('sign_title[1]', 'VARCHAR(20)')
							 , sign_email = p.v.value('sign_email[1]', 'VARCHAR(60)')
							 , sign_phone = p.v.value('sign_phone[1]', 'VARCHAR(20)')
							 , sign_fax = p.v.value('sign_fax[1]', 'VARCHAR(20)')
							 , sign_address = p.v.value('sign_address[1]', 'VARCHAR(255)')
							 , sign_city = p.v.value('sign_city[1]', 'VARCHAR(40)')
							 , sign_state = p.v.value('sign_state[1]', 'CHAR(2)')
							 , sign_zip_code = p.v.value('sign_zip_code[1]', 'VARCHAR(15)')
							 , date_added = p.v.value('date_added[1]', 'DATETIME')
							 , sign_comment_internal = p.v.value('sign_comment_internal[1]', 'VARCHAR(500)')
							 , logon = p.v.value('logon[1]', 'VARCHAR(60)')
							 , contact_id = p.v.value('contact_id[1]', 'int')
							 , e_signature_type_id = p.v.value('e_signature_type_id[1]', 'int')
							 , e_signature_url = p.v.value('e_signature_url[1]', 'VARCHAR(255)')
							 , modified_by = @web_userid
							 , date_modified = GETDATE()
						  FROM @Data.nodes('SectionH/Signature/Signature')p(v)
						 WHERE form_id = @form_id
						   and revision_id = @revision_id;
					END
				END
	END TRY

	BEGIN CATCH
		DECLARE @procedure VARCHAR(150) = ERROR_PROCEDURE()
			  , @error VARCHAR(2000) = ERROR_MESSAGE()

		DECLARE @error_description VARCHAR(4000) = 
				'Form ID: ' + convert(NVARCHAR(15), @form_id) 
				  + '-' +  convert(NVARCHAR(15), @revision_id) 
				  + CHAR(13) + CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
				  + CHAR(13) + CHAR(13) + 'Data: ' + CONVERT(NVARCHAR(4000), @Data)
		
		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = 'COR', @object = @procedure, @body = @error_description;
	END CATCH
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_H] TO COR_USER;
GO
/*****************************************************************************************/

