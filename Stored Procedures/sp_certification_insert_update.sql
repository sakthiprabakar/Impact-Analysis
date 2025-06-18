ALTER PROCEDURE dbo.sp_certification_insert_update
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_certification_insert_update]
	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
	Procedure to insert update Cerification supplementry forms

	--Updated by Blair Christensen for Titan 05/21/2025
inputs 	
	@Data
	@form_id
	@revision_id
Samples:
 EXEC [sp_certification_insert_update] @Data,@formId,@revisionId
 EXEC [sp_certification_insert_update]  '<Certification>
<wcr_id>123</wcr_id>
<wcr_rev_id>1</wcr_rev_id>
<locked>U</locked>
<vsqg_cesqg_accept_flag>F</vsqg_cesqg_accept_flag>
<created_by>test</created_by>
<modified_by>local test</modified_by>
<generator_name>PITT</generator_name>
<generator_address1>STREET generator_address1</generator_address1>
<generator_address2>WEST MORRIS STREET generator_address2</generator_address2>
<generator_address3>MORRIS generator_address3</generator_address3>
<generator_address4>generator_address4</generator_address4>
<generator_city>INDIANA</generator_city>
<generator_state>IN</generator_state>
<gen_mail_zip>461</gen_mail_zip>
<signing_date>2018-12-12 00:00:00</signing_date>
<signing_name>local signing_name</signing_name>
<signing_title>local signing_title</signing_title>
</Certification>',427568,1
***********************************************************************/  
BEGIN
	BEGIN TRY	
		IF NOT EXISTS (SELECT 1 FROM dbo.FormVSQGCESQG WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)
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

				INSERT INTO dbo.FormVSQGCESQG(form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , vsqg_cesqg_accept_flag
					 , created_by, date_created, modified_by, date_modified
					 --, printname, company, title
					 )
				SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
					 , p.v.value('vsqg_cesqg_accept_flag[1]', 'CHAR(1)') as vsqg_cesqg_accept_flag
					 , created_by = @web_userid, date_created = GETDATE()
					 , modified_by = @web_userid, date_modified = GETDATE()
				  FROM @Data.nodes('Certification')p(v);
			END
		ELSE
			BEGIN
				UPDATE dbo.FormVSQGCESQG
				   SET locked = 'U'
				     , vsqg_cesqg_accept_flag = p.v.value('vsqg_cesqg_accept_flag[1]', 'CHAR(1)')
					 , date_modified = GETDATE()
					 , modified_by = @web_userid
				  FROM @Data.nodes('Certification')p(v)
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY

	BEGIN CATCH 			
		DECLARE @error_description VARCHAR(2047)
			  , @mailTrack_userid VARCHAR(60) = 'COR'

		SET @error_description = ' ErrorMessage: ' + Error_Message()

		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
		VALUES(@error_description, ERROR_PROCEDURE(), @mailTrack_userid, GETDATE());
	END CATCH
END
GO

GRANT EXEC ON [dbo].[sp_certification_insert_update] TO COR_USER;
GO
