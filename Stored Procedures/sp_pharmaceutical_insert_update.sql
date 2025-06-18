ALTER PROCEDURE dbo.sp_pharmaceutical_insert_update
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
Insert / update Pharmaceutical form  (Part of form wcr insert / update)
--Updated by Blair Christensen for Titan 05/21/2025

inputs Data, Form ID, Revision ID
	--EXEC sp_FormWCR_insert_update_pharmaceutical '<Pharmaceutical>
--<wcr_id>427534</wcr_id>
--<wcr_rev_id>1</wcr_rev_id>
--<locked>U</locked>
--<pharm_certification_flag>F</pharm_certification_flag>			
--<modified_by>TESTed</modified_by>
--<created_by>TESTd</created_by>
--<signing_date> </signing_date>
--<signing_name>test</signing_name>
--</Pharmaceutical>',427534 , 1
****************************************************************** */
 BEGIN
	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.FormPharmaceutical WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)
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

				INSERT INTO dbo.FormPharmaceutical (form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , pharm_certification_flag
					 , created_by, date_created, date_modified, modified_by
					 )
				SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
					 , p.v.value('pharm_certification_flag[1]', 'CHAR(1)') as pharm_certification_flag
					 , @web_userid as created_by, GETDATE() as date_created, GETDATE() as date_modified, @web_userid as modified_by
				  FROM @Data.nodes('Pharmaceutical')p(v);
			END
		ELSE
			BEGIN
				UPDATE dbo.FormPharmaceutical
			       SET locked = 'U'
				     , pharm_certification_flag = p.v.value('pharm_certification_flag[1]', 'CHAR(1)')
					 , date_modified = GETDATE()
					 , modified_by = @web_userid
				  FROM @Data.nodes('Pharmaceutical')p(v)
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @mailTrack_userid VARCHAR(60) = 'COR'
			  , @error_description VARCHAR(4000)

		SET @error_description = CONVERT(VARCHAR(20), @form_id)
			+ ' - ' + CONVERT(VARCHAR(10), @revision_id) 
			+ ' ErrorMessage: ' + Error_Message() + '\n XML: ' + CONVERT(VARCHAR(4000), @Data)

		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
		VALUES(@error_description, ERROR_PROCEDURE(), @mailTrack_userid, GETDATE());
	END CATCH
END
GO

GRANT EXECUTE ON [dbo].[sp_pharmaceutical_insert_update] TO COR_USER;
GO
