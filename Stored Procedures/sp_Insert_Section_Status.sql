CREATE	PROCEDURE [dbo].[sp_Insert_Section_Status] 
	-- Add the parameters for the stored procedure here
	@form_id int,
	@revision_id int,
	@web_userid nvarchar(200)
AS


/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Insert_Section_Status]
	Description	: Form Section status update


	Description	: 
				Insert form each secion status (Section A- H) as Clean (i.e: C)  when adding a new form  

	Input		:
				@form_id
				@revision_id
				@web_userid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Insert_Section_Status] 466012,1, 'manand84'

*************************************************************************************/

BEGIN
    IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SA'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SA','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END
	
	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SB'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SB','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SC'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SC','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SD'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SD','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SE'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SE','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SF'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SF','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SG'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SG','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END

	 IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SH'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SH','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id and section = 'SL'))
	BEGIN
	INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SL','C',getdate(),@web_userid,getdate(),@web_userid,1)
	END
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SB','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SC','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SD','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SE','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SF','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SG','C',getdate(),1,getdate(),1,1)
	--INSERT INTO FormSectionStatus (form_id,revision_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive) VALUES (@form_id,@revision_id,'SH','C',getdate(),1,getdate(),1,1)

	--EXEC sp_COR_Insert_Supplement_Section_Status @form_id, @revision_id, @web_userid

END

GO

	GRANT EXEC ON [dbo].[sp_Insert_Section_Status] TO COR_USER;

GO


--select * from FormSectionStatus