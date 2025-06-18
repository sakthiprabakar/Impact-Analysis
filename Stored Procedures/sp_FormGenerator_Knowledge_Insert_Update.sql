CREATE OR ALTER PROCEDURE dbo.sp_FormGenerator_Knowledge_Insert_Update
	  @form_id INTEGER
	, @revision_id INTEGER
	, @Data XML
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
  Updated By       : Dinesh
  Updated On date  : April 1st, 2021
  Decription       : Insert and Update Form Generator Knowledge details
  Type             : Stored Procedure
  Object Name      : [sp_FormGenerator_Knowledge_Insert_Update]
  Updated by Blair Christensen for Titan on 05/27/2025

  Inputs @Data,	@form_id, @revision_id
****************************************************************** */
BEGIN
	BEGIN TRY	
		IF NOT EXISTS (SELECT form_id FROM dbo.FormGeneratorKnowledge WHERE form_id = @form_id and revision_id =  @revision_id)
			BEGIN			
				INSERT INTO dbo.FormGeneratorKnowledge (form_id, revision_id
					 , profile_id, locked
					 , specific_gravity, ppe_code, rcra_reg_metals, rcra_reg_vo, rcra_reg_svo
					 , rcra_reg_herb_pest, rcra_reg_cyanide_sulfide, rcra_reg_ph, material_cause_flash
					 , material_meet_alc_exempt, analytical_comments, print_name
					 , created_by, date_created, modified_by, date_modified)
				SELECT TOP 1 @form_id as form_id, @revision_id as revision_id
					 , p.v.value('profile_id[1][not(@xsi:nil = "true")]', 'INT') as profile_id, 'U' as locked
					 , p.v.value('specific_gravity[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , p.v.value('ppe_code[1]', 'VARCHAR(10)')
					 , p.v.value('rcra_reg_metals[1]', 'CHAR(1)')
					 , p.v.value('rcra_reg_vo[1]', 'CHAR(1)')
					 , p.v.value('rcra_reg_svo[1]', 'CHAR(1)')
					 , p.v.value('rcra_reg_herb_pest[1]', 'CHAR(1)')
					 , p.v.value('rcra_reg_cyanide_sulfide[1]', 'CHAR(1)')
					 , p.v.value('rcra_reg_ph[1]', 'CHAR(1)')
					 , p.v.value('material_cause_flash[1]', 'CHAR(1)')
					 , p.v.value('material_meet_alc_exempt[1]', 'CHAR(1)')
					 , p.v.value('analytical_comments[1]', 'VARCHAR(125)')
					 , p.v.value('print_name[1]', 'VARCHAR(40)')
					 , @web_userid as created_by, GETDATE() as date_created, @web_userid as modified_by, GETDATE() as date_modified		  
				  FROM @Data.nodes('GeneratorKnowledge')p(v);
			END
		ELSE 
			BEGIN
				UPDATE dbo.FormGeneratorKnowledge
				   SET specific_gravity = p.v.value('specific_gravity[1]','float')
				     , ppe_code = p.v.value('ppe_code[1]','varchar(10)')
					 , rcra_reg_metals = p.v.value('rcra_reg_metals[1]','char(1)')
					 , rcra_reg_vo = p.v.value('rcra_reg_vo[1]','char(1)')
					 , rcra_reg_svo = p.v.value('rcra_reg_svo[1]','char(1)')
					 , rcra_reg_herb_pest = p.v.value('rcra_reg_herb_pest[1]','char(1)')
					 , rcra_reg_cyanide_sulfide = p.v.value('rcra_reg_cyanide_sulfide[1]','char(1)')
					 , rcra_reg_ph = p.v.value('rcra_reg_ph[1]','char(1)')
					 , material_cause_flash = p.v.value('material_cause_flash[1]','char(1)')
					 , material_meet_alc_exempt = p.v.value('material_meet_alc_exempt[1]','char(1)')
					 , analytical_comments = p.v.value('analytical_comments[1]','varchar(125)')
					 , print_name = p.v.value('print_name[1]','varchar(40)')
					 , created_by = @web_userid, date_created = GETDATE()
					 , modified_by = @web_userid, date_modified =	GETDATE()	
				  FROM @Data.nodes('GeneratorKnowledge')p(v)	  
				 WHERE form_id = @form_id
				   AND revision_id = @revision_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @procedure as VARCHAR(150)
			  , @mailTrack_userid as VARCHAR(60) = 'COR'
		SET @procedure = ERROR_PROCEDURE()
		DECLARE @error as VARCHAR(2047) = ERROR_MESSAGE()
		DECLARE @error_description VARCHAR(4000) = 'Form ID: ' + CONVERT(VARCHAR(15), @form_id)
			+ '-' +  CONVERT(VARCHAR(15), @revision_id)
			+ CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
			+ CHAR(13) + 'Data: ' + CONVERT(VARCHAR(4000), @Data)

		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = @mailTrack_userid, @object = @procedure, @body = @error_description;

	END CATCH
END;
GO

GRANT EXECUTE ON [dbo].[sp_FormGenerator_Knowledge_Insert_Update] TO COR_USER;
GO
