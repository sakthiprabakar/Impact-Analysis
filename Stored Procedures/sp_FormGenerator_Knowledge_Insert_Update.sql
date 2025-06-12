USE [PLT_AI]
GO
/************************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormGenerator_Knowledge_Insert_Update]
GO
CREATE PROCEDURE [dbo].[sp_FormGenerator_Knowledge_Insert_Update]
	@form_id int,
	@revision_id int,
	@Data xml,
	@web_userid varchar(100)
AS
/* ******************************************************************
  Updated By       : Dinesh
  Updated On date  : April 1st, 2021
  Decription       : Insert and Update Form Generator Knowledge details
  Type             : Stored Procedure
  Object Name      : [sp_FormGenerator_Knowledge_Insert_Update]

  Inputs 
	   @Data,	--> XML data	
	   @form_id,
	   @revision_id
 
  Samples:
	 EXEC [dbo].[sp_FormGenerator_Knowledge_Insert_Update]  @form_id, @revision_id, @Data 
****************************************************************** */
BEGIN
	BEGIN TRY	
		IF(NOT EXISTS(SELECT form_id FROM FormGeneratorKnowledge  WITH(NOLOCK)  WHERE form_id = @form_id and revision_id =  @revision_id))
		BEGIN			
			INSERT INTO FormGeneratorKnowledge 
			(
				form_id, 
				revision_id, 
				profile_id, 
				locked, 
				specific_gravity,
				ppe_code,
				rcra_reg_metals,
				rcra_reg_vo,
				rcra_reg_svo,
				rcra_reg_herb_pest,
				rcra_reg_cyanide_sulfide,
				rcra_reg_ph,
				material_cause_flash,
				material_meet_alc_exempt,
				analytical_comments,
				print_name,			
				date_added,
				created_by,
				date_created,
				modified_by,
				date_modified
			)
			  SELECT TOP 1		 
					@form_id,
					@revision_id,
					p.v.value('profile_id[1][not(@xsi:nil = "true")]','int'),
					'U',
					p.v.value('specific_gravity[1][not(@xsi:nil = "true")]','float'),
					p.v.value('ppe_code[1]','varchar(10)'),
					p.v.value('rcra_reg_metals[1]','char(1)'),
					p.v.value('rcra_reg_vo[1]','char(1)'),
					p.v.value('rcra_reg_svo[1]','char(1)'),
					p.v.value('rcra_reg_herb_pest[1]','char(1)'),
					p.v.value('rcra_reg_cyanide_sulfide[1]','char(1)'),
					p.v.value('rcra_reg_ph[1]','char(1)'),
					p.v.value('material_cause_flash[1]','char(1)'),
					p.v.value('material_meet_alc_exempt[1]','char(1)'),
					p.v.value('analytical_comments[1]','varchar(125)'),
					p.v.value('print_name[1]','varchar(40)'),				
					GETDATE(),
					@web_userid,
					GETDATE(),
					@web_userid,
					GETDATE()		  
			  FROM
				  @Data.nodes('GeneratorKnowledge')p(v)
		END
		ELSE 
		BEGIN
			UPDATE FormGeneratorKnowledge
			SET
				specific_gravity = p.v.value('specific_gravity[1]','float'),
				ppe_code = p.v.value('ppe_code[1]','varchar(10)'),
				rcra_reg_metals = p.v.value('rcra_reg_metals[1]','char(1)'),
				rcra_reg_vo = p.v.value('rcra_reg_vo[1]','char(1)'),
				rcra_reg_svo = p.v.value('rcra_reg_svo[1]','char(1)'),
				rcra_reg_herb_pest = p.v.value('rcra_reg_herb_pest[1]','char(1)'),
				rcra_reg_cyanide_sulfide = p.v.value('rcra_reg_cyanide_sulfide[1]','char(1)'),
				rcra_reg_ph = p.v.value('rcra_reg_ph[1]','char(1)'),
				material_cause_flash = p.v.value('material_cause_flash[1]','char(1)'),
				material_meet_alc_exempt = p.v.value('material_meet_alc_exempt[1]','char(1)'),
				analytical_comments = p.v.value('analytical_comments[1]','varchar(125)'),
				print_name = p.v.value('print_name[1]','varchar(40)'),			
				date_added = GETDATE(),
				created_by = @web_userid,
				date_created = GETDATE(),
				modified_by = @web_userid,
				date_modified =	GETDATE()	
			FROM @Data.nodes('GeneratorKnowledge')p(v)	  
			WHERE form_id = @form_id AND revision_id = @revision_id
		END
	END TRY
	BEGIN CATCH
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

	END CATCH

END
GO
	GRANT EXECUTE ON [dbo].[sp_FormGenerator_Knowledge_Insert_Update] TO COR_USER;
GO
/***********************************************************************************************/
