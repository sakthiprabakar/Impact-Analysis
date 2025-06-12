CREATE PROCEDURE sp_COR_GeneratorKnowledge_Copy
	-- Add the parameters for the stored procedure here
	@source_form_id int,
	@source_revision_id int,
	@new_form_id int,
	@new_revision_id int,
	@web_userid nvarchar(150)
AS
BEGIN

	begin try
	
	if(exists(select top 1 1 from FormGeneratorKnowledge where form_id = @source_form_id and revision_id = @source_revision_id))
	begin
		insert into FormGeneratorKnowledge
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
	
		select
		@new_form_id,
		@new_revision_id,
		null,
		'U',
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
		getdate(),
		@web_userid,
		getdate(),
		@web_userid,
		getdate()
		from FormGeneratorKnowledge
		where form_id = @source_form_id and revision_id = @source_revision_id
		end
	end try
	begin catch
		declare @procedure nvarchar(150) 
		set @procedure = ERROR_PROCEDURE()				
		declare @error nvarchar(max) = 'Form ID: ' + convert(nvarchar(15), @source_form_id) + '-' +  convert(nvarchar(15), @source_revision_id) 
													+ CHAR(13) + 
													+ CHAR(13) + 
													'Error Message: ' + isnull(Error_Message(), '')

														   
		EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
				@web_userid = @web_userid, 
				@object = @procedure,
				@body = @error

		DECLARE @error_description VARCHAR(MAX)
		set @error_description = @error;
		INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                        VALUES(@error_description,ERROR_PROCEDURE(),@web_userid,GETDATE())

	end catch

END

GO

GRANT EXEC ON [dbo].[sp_COR_GeneratorKnowledge_Copy] TO COR_USER;

GO
