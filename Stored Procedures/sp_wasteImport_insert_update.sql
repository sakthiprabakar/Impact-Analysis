ALTER PROCEDURE dbo.sp_wasteImport_insert_update
     @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
Insert / update Waste Import form  (Part of form wcr insert / update)
--Updated by Blair Christensen for Titan 05/21/2025
inputs Data, Form ID, Revision ID
****************************************************************** */
BEGIN
	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.FormWasteImport WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)
			BEGIN	
				DECLARE @newForm_id INTEGER
					  , @newrev_id INTEGER = 1
					  , @FormWCR_uid INTEGER;

				EXEC @newForm_id = sp_sequence_next 'form.form_id';

				IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id AND revision_id = @revision_id)
					BEGIN
						SELECT @FormWCR_uid = formWCR_uid
						  FROM dbo.FormWCR
						 WHERE form_id = @form_id
						   AND revision_id = @revision_id;
					END
				ELSE
					BEGIN
						SET @FormWCR_uid = NULL;
					END

				INSERT INTO dbo.FormWasteImport (form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , foreign_exporter_name
					 , foreign_exporter_address
					 , foreign_exporter_contact_name
					 , foreign_exporter_phone
					 , foreign_exporter_fax
					 , foreign_exporter_email
					 , epa_notice_id
					 , epa_consent_number
					 , effective_date
					 , expiration_date
					 , approved_volume
					 , approved_volume_unit
					 , importing_generator_id
					 , importing_generator_name
					 , importing_generator_address
					 , importing_generator_city
					 , importing_generator_province_territory
					 , importing_generator_mail_code
					 , importing_generator_epa_id
					 , tech_contact_id
					 , tech_contact_name
					 , tech_contact_phone
					 , tech_cont_email
					 , tech_contact_fax
					 , created_by, date_created, date_modified, modified_by
					 , foreign_exporter_sameas_generator
					 , foreign_exporter_city
					 , foreign_exporter_province_territory
					 , foreign_exporter_mail_code
					 , foreign_exporter_country
					 )
				SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
					 , p.v.value('foreign_exporter_name[1]', 'VARCHAR(200)') as foreign_exporter_name
					 , p.v.value('foreign_exporter_address[1]', 'VARCHAR(100)') as foreign_exporter_address
					 , p.v.value('foreign_exporter_contact_name[1]', 'VARCHAR(40)') as foreign_exporter_contact_name
					 , p.v.value('foreign_exporter_phone[1]', 'VARCHAR(20)') as foreign_exporter_phone
					 , p.v.value('foreign_exporter_fax[1]', 'VARCHAR(20)') as foreign_exporter_fax
					 , p.v.value('foreign_exporter_email[1]', 'VARCHAR(50)') as foreign_exporter_email
					 , p.v.value('epa_notice_id[1]', 'VARCHAR(100)') as epa_notice_id
					 , p.v.value('epa_consent_number[1]', 'VARCHAR(150)') as epa_consent_number
					 , p.v.value('effective_date[1][not(@xsi:nil = "true")]', 'DATETIME') as effective_date
					 , p.v.value('expiration_date[1][not(@xsi:nil = "true")]', 'DATETIME') as expiration_date
					 , p.v.value('approved_volume[1]', 'NVARCHAR(100)') as approved_volume
					 , p.v.value('approved_volume_unit[1]', 'VARCHAR(4)') as approved_volume_unit
					 , p.v.value('importing_generator_id[1]','INTEGER') as importing_generator_id
					 , p.v.value('importing_generator_name[1]', 'VARCHAR(200)') as importing_generator_name
					 , p.v.value('importing_generator_address[1]', 'VARCHAR(100)') as importing_generator_address
					 , p.v.value('importing_generator_city[1]', 'VARCHAR(100)') as importing_generator_city
					 , p.v.value('importing_generator_province_territory[1]', 'VARCHAR(100)') as importing_generator_province_territory
					 , p.v.value('importing_generator_mail_code[1]', 'VARCHAR(15)') as importing_generator_mail_code
					 , p.v.value('importing_generator_epa_id[1]', 'VARCHAR(60)') as importing_generator_epa_id
					 , p.v.value('tech_contact_id[1]', 'INTEGER') as tech_contact_id
					 , p.v.value('tech_contact_name[1]', 'VARCHAR(40)') as tech_contact_name
					 , p.v.value('tech_contact_phone[1]', 'VARCHAR(20)') as tech_contact_phone
					 , p.v.value('tech_cont_email[1]', 'VARCHAR(50)') as tech_cont_email
					 , p.v.value('tech_contact_fax[1]', 'VARCHAR(10)') as tech_contact_fax
					 , @web_userid as created_by, GETDATE() as date_created, GETDATE() as date_modified, @web_userid as modified_by
					 , p.v.value('foreign_exporter_sameas_generator[1]','CHAR(1)') as foreign_exporter_sameas_generator
					 , p.v.value('foreign_exporter_city[1]', 'VARCHAR(100)') as foreign_exporter_city
					 , p.v.value('foreign_exporter_province_territory[1]', 'VARCHAR(100)') as foreign_exporter_province_territory
					 , p.v.value('foreign_exporter_mail_code[1]', 'VARCHAR(20)') as foreign_exporter_mail_code
					 , p.v.value('foreign_exporter_country[1]', 'VARCHAR(100)') as foreign_exporter_country
				  FROM @Data.nodes('WasteImport')p(v);
			END
		ELSE
			BEGIN
				UPDATE dbo.FormWasteImport
				   SET locked = 'U'
				     , foreign_exporter_name = p.v.value('foreign_exporter_name[1]', 'VARCHAR(200)')
					 , foreign_exporter_address = p.v.value('foreign_exporter_address[1]', 'VARCHAR(100)')
					 , foreign_exporter_contact_name = p.v.value('foreign_exporter_contact_name[1]', 'VARCHAR(40)')
					 , foreign_exporter_phone = p.v.value('foreign_exporter_phone[1]', 'VARCHAR(20)')
					 , foreign_exporter_fax = p.v.value('foreign_exporter_fax[1]', 'VARCHAR(20)')
					 , foreign_exporter_email = p.v.value('foreign_exporter_email[1]', 'VARCHAR(50)')
					 , epa_notice_id = p.v.value('epa_notice_id[1]', 'VARCHAR(100)')
					 , epa_consent_number = p.v.value('epa_consent_number[1]', 'VARCHAR(150)')
					 , effective_date = p.v.value('effective_date[1][not(@xsi:nil = "true")]', 'DATETIME')
					 , expiration_date = p.v.value('expiration_date[1][not(@xsi:nil = "true")]', 'DATETIME')
					 , approved_volume = p.v.value('approved_volume[1]', 'NVARCHAR(100)')
					 , approved_volume_unit = p.v.value('approved_volume_unit[1]', 'VARCHAR(4)')
					 , importing_generator_id = p.v.value('importing_generator_id[1]', 'INTEGER')
					 , importing_generator_name = p.v.value('importing_generator_name[1]', 'VARCHAR(200)')
					 , importing_generator_address = p.v.value('importing_generator_address[1]', 'VARCHAR(100)')
					 , importing_generator_city = p.v.value('importing_generator_city[1]', 'VARCHAR(100)')
					 , importing_generator_province_territory = p.v.value('importing_generator_province_territory[1]', 'VARCHAR(100)')
					 , importing_generator_mail_code = p.v.value('importing_generator_mail_code[1]', 'VARCHAR(15)')
					 , importing_generator_epa_id = p.v.value('importing_generator_epa_id[1]', 'VARCHAR(60)')
					 , tech_contact_id = p.v.value('tech_contact_id[1]', 'INTEGER')
					 , tech_contact_name = p.v.value('tech_contact_name[1]', 'VARCHAR(40)')
					 , tech_contact_phone = p.v.value('tech_contact_phone[1]', 'VARCHAR(20)')
					 , tech_cont_email = p.v.value('tech_cont_email[1]', 'VARCHAR(50)')
					 , tech_contact_fax = p.v.value('tech_contact_fax[1]', 'VARCHAR(10)')
					 , date_modified = GETDATE(), modified_by = @web_userid
					 , foreign_exporter_sameas_generator = p.v.value('foreign_exporter_sameas_generator[1]','CHAR(1)')
					 , foreign_exporter_city = p.v.value('foreign_exporter_city[1]', 'VARCHAR(100)')
					 , foreign_exporter_province_territory = p.v.value('foreign_exporter_province_territory[1]', 'VARCHAR(100)')
					 , foreign_exporter_mail_code = p.v.value('foreign_exporter_mail_code[1]', 'VARCHAR(20)')
					 , foreign_exporter_country = p.v.value('foreign_exporter_country[1]', 'CHAR(3)')
				  FROM @Data.nodes('WasteImport')p(v)
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @procedure NVARCHAR(150)
			  , @mailTrack_userid NVARCHAR(60) = 'COR'

		SET @procedure = ERROR_PROCEDURE()
		DECLARE @error NVARCHAR(2047) = ERROR_MESSAGE()
		DECLARE @error_description NVARCHAR(4000) = 'Form ID: ' + CONVERT(NVARCHAR(15), @form_id)
				+ '-' +  CONVERT(NVARCHAR(15), @revision_id) 
				+ CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
				+ CHAR(13) + 'Data: ' + CONVERT(NVARCHAR(2000), @Data)

		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = @mailTrack_userid, @object = @procedure, @body = @error_description;
	END CATCH
END
GO

GRANT EXECUTE ON sp_wasteImport_insert_update TO COR_USER
GO
