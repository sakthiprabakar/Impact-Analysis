USE [PLT_AI]
GO
/**************************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_wasteImport_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_wasteImport_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************
Insert / update Waste Import form  (Part of form wcr insert / update)
inputs 	
	Data -- XML data having values for the FormWasteImport table
	Form ID
	Revision ID

****************************************************************** */
 BEGIN
	begin try
	  IF(NOT EXISTS(SELECT 1 FROM FormWasteImport  WITH(NOLOCK) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id))
		BEGIN	
		DECLARE @newForm_id INT   
		EXEC @newForm_id = sp_sequence_next 'form.form_id'
		DECLARE @newrev_id INT  = 1
		select  @form_id, @newrev_id
			INSERT INTO FormWasteImport(
				form_id,
				revision_id,
				wcr_id,
				wcr_rev_id,
				locked,
				foreign_exporter_name,
				foreign_exporter_address,
				foreign_exporter_city,
				foreign_exporter_province_territory,
				foreign_exporter_mail_code,
				foreign_exporter_country,
				foreign_exporter_contact_name,
				foreign_exporter_phone,
				foreign_exporter_fax,
				foreign_exporter_email,
				epa_notice_id,
				epa_consent_number,
				effective_date,
				expiration_date,
				approved_volume,
				approved_volume_unit,
				importing_generator_id,
				importing_generator_name,
				importing_generator_address,
				importing_generator_city,
				importing_generator_province_territory,
				importing_generator_mail_code,
				importing_generator_epa_id,
				tech_contact_id,
				tech_contact_name,
				tech_contact_phone,
				tech_cont_email,
				tech_contact_fax,
				created_by,
				date_created,
				date_modified,
				modified_by,
				foreign_exporter_sameas_generator
				)
			SELECT			 
				form_id = @newForm_id,
				revision_id = @newrev_id,
				wcr_id = @form_id, --p.v.value('wcr_id[1]','int'),
				wcr_rev_id = @revision_id, --  p.v.value('wcr_rev_id[1]','int'),
				--locked = p.v.value('locked[1]','char(1)'),
				locked = 'U',
				foreign_exporter_name = p.v.value('foreign_exporter_name[1]','varchar(200)'),
				foreign_exporter_address = p.v.value('foreign_exporter_address[1]','varchar(100)'),
				foreign_exporter_city = p.v.value('foreign_exporter_city[1]','varchar(100)'),
				foreign_exporter_province_territory = p.v.value('foreign_exporter_province_territory[1]','varchar(100)'),
				foreign_exporter_mail_code = p.v.value('foreign_exporter_mail_code[1]','varchar(20)'),
				foreign_exporter_country = p.v.value('foreign_exporter_country[1]','varchar(100)'),
				foreign_exporter_contact_name = p.v.value('foreign_exporter_contact_name[1]','varchar(40)'),
				foreign_exporter_phone = p.v.value('foreign_exporter_phone[1]','varchar(20)'),
				foreign_exporter_fax = p.v.value('foreign_exporter_fax[1]','varchar(20)'),
				foreign_exporter_email = p.v.value('foreign_exporter_email[1]','varchar(50)'),
				epa_notice_id = p.v.value('epa_notice_id[1]','varchar(100)'),
				epa_consent_number = p.v.value('epa_consent_number[1]','varchar(150)'),
				effective_date = p.v.value('effective_date[1][not(@xsi:nil = "true")]','datetime'),
				expiration_date = p.v.value('expiration_date[1][not(@xsi:nil = "true")]','datetime'),
				--approved_volume = p.v.value('approved_volume[1][not(@xsi:nil = "true")]','float'),
				approved_volume = p.v.value('approved_volume[1]','nvarchar(100)'),
				approved_volume_unit = p.v.value('approved_volume_unit[1]','varchar(4)'),
				importing_generator_id = p.v.value('importing_generator_id[1]','int'),
				importing_generator_name = p.v.value('importing_generator_name[1]','varchar(200)'),
				importing_generator_address = p.v.value('importing_generator_address[1]','varchar(100)'),
				importing_generator_city = p.v.value('importing_generator_city[1]','varchar(100)'),
				importing_generator_province_territory = p.v.value('importing_generator_province_territory[1]','varchar(100)'),
				importing_generator_mail_code = p.v.value('importing_generator_mail_code[1]','varchar(15)'),
				importing_generator_epa_id = p.v.value('importing_generator_epa_id[1]','varchar(60)'),
				tech_contact_id = p.v.value('tech_contact_id[1]','int'),
				tech_contact_name = p.v.value('tech_contact_name[1]','varchar(40)'),
				tech_contact_phone = p.v.value('tech_contact_phone[1]','varchar(20)'),
				tech_cont_email = p.v.value('tech_cont_email[1]','varchar(50)'),
				tech_contact_fax = p.v.value('tech_contact_fax[1]','varchar(10)'),	
				created_by = @web_userid,
				date_created = GETDATE(),
				date_modified = GETDATE(),
				modified_by = @web_userid,
				foreign_exporter_sameas_generator = p.v.value('foreign_exporter_sameas_generator[1]','CHAR(1)')
			FROM
				@Data.nodes('WasteImport')p(v)
	   END
	  ELSE
	   BEGIN
			UPDATE  FormWasteImport
			SET                 
				--locked = p.v.value('locked[1]','char(1)'),
				locked = 'U',
				foreign_exporter_name = p.v.value('foreign_exporter_name[1]','varchar(200)'),
				foreign_exporter_address = p.v.value('foreign_exporter_address[1]','varchar(100)'),
				foreign_exporter_city = p.v.value('foreign_exporter_city[1]','varchar(100)'),
				foreign_exporter_province_territory = p.v.value('foreign_exporter_province_territory[1]','varchar(100)'),
				foreign_exporter_mail_code = p.v.value('foreign_exporter_mail_code[1]','varchar(20)'),
				foreign_exporter_country = p.v.value('foreign_exporter_country[1]','varchar(100)'),
				foreign_exporter_contact_name = p.v.value('foreign_exporter_contact_name[1]','varchar(40)'),
				foreign_exporter_phone = p.v.value('foreign_exporter_phone[1]','varchar(20)'),
				foreign_exporter_fax = p.v.value('foreign_exporter_fax[1]','varchar(20)'),
				foreign_exporter_email = p.v.value('foreign_exporter_email[1]','varchar(50)'),
				epa_notice_id = p.v.value('epa_notice_id[1]','varchar(100)'),
				epa_consent_number = p.v.value('epa_consent_number[1]','varchar(150)'),
				effective_date = p.v.value('effective_date[1][not(@xsi:nil = "true")]','datetime'),
				expiration_date = p.v.value('expiration_date[1][not(@xsi:nil = "true")]','datetime'),
				--approved_volume = p.v.value('approved_volume[1]','float'),
				approved_volume = p.v.value('approved_volume[1]','nvarchar(100)'),
				approved_volume_unit = p.v.value('approved_volume_unit[1]','varchar(4)'),
				importing_generator_id = p.v.value('importing_generator_id[1]','int'),
				importing_generator_name = p.v.value('importing_generator_name[1]','varchar(200)'),
				importing_generator_address = p.v.value('importing_generator_address[1]','varchar(100)'),
				importing_generator_city = p.v.value('importing_generator_city[1]','varchar(100)'),
				importing_generator_province_territory = p.v.value('importing_generator_province_territory[1]','varchar(100)'),
				importing_generator_mail_code = p.v.value('importing_generator_mail_code[1]','varchar(15)'),
				importing_generator_epa_id = p.v.value('importing_generator_epa_id[1]','varchar(60)'),
				tech_contact_id = p.v.value('tech_contact_id[1]','int'),
				tech_contact_name = p.v.value('tech_contact_name[1]','varchar(40)'),
				tech_contact_phone = p.v.value('tech_contact_phone[1]','varchar(20)'),
				tech_cont_email = p.v.value('tech_cont_email[1]','varchar(50)'),
				tech_contact_fax = p.v.value('tech_contact_fax[1]','varchar(10)'),	
				date_modified = GETDATE(),
				modified_by = @web_userid,
				foreign_exporter_sameas_generator = p.v.value('foreign_exporter_sameas_generator[1]','CHAR(1)')
			 FROM
			 @Data.nodes('WasteImport')p(v) WHERE  wcr_id= @form_id and wcr_rev_id =  @revision_id
	   END
	end try
	begin catch
		declare @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'

				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)

														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
	end catch
END
GO
	GRANT EXECUTE ON sp_wasteImport_insert_update TO COR_USER
GO
/*************************************************************************************************/
