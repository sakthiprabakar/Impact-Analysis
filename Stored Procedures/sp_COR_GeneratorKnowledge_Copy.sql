CREATE OR ALTER PROCEDURE dbo.sp_COR_GeneratorKnowledge_Copy
	  @source_form_id INTEGER
	, @source_revision_id INTEGER
	, @new_form_id INTEGER
	, @new_revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/*
	Modified by Blair Christensen for Titan 05/27/2025
*/
BEGIN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormGeneratorKnowledge WHERE form_id = @source_form_id AND revision_id = @source_revision_id)
			BEGIN
				INSERT INTO dbo.FormGeneratorKnowledge (form_id, revision_id, profile_id, locked
					 , specific_gravity, ppe_code, rcra_reg_metals, rcra_reg_vo, rcra_reg_svo, rcra_reg_herb_pest
					 , rcra_reg_cyanide_sulfide, rcra_reg_ph, material_cause_flash, material_meet_alc_exempt
					 , analytical_comments, print_name, created_by, date_created
					 , modified_by, date_modified)
				SELECT @new_form_id as form_id,	@new_revision_id as revision_id, NULL as profile_id, 'U' as locked
					 , specific_gravity, ppe_code, rcra_reg_metals, rcra_reg_vo, rcra_reg_svo, rcra_reg_herb_pest
					 , rcra_reg_cyanide_sulfide, rcra_reg_ph, material_cause_flash, material_meet_alc_exempt
					 , analytical_comments, print_name, @web_userid as created_by, GETDATE() as date_created
					 , @web_userid as modified_by, GETDATE() as date_modified
				  FROM dbo.FormGeneratorKnowledge
				 WHERE form_id = @source_form_id
				   AND revision_id = @source_revision_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @procedure VARCHAR(150) 
		SET @procedure = ERROR_PROCEDURE()				
		DECLARE @error VARCHAR(2400) = 'Form ID: ' + CONVERT(VARCHAR(15), @source_form_id)
			+ '-' +  CONVERT(VARCHAR(15), @source_revision_id)
			+ CHAR(13) + 'Error Message: ' + ISNULL(ERROR_MESSAGE(), '');

		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = @web_userid, @object = @procedure, @body = @error;

		DECLARE @error_description VARCHAR(2047)
		SET @error_description = @error;
		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
		VALUES(@error_description, ERROR_PROCEDURE(), @web_userid, GETDATE());

	END CATCH
END;
GO

GRANT EXEC ON [dbo].[sp_COR_GeneratorKnowledge_Copy] TO COR_USER;

GO
