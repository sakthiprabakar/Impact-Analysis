USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_Validate_Profile_GeneratorKnowledge_Form]
GO
CREATE PROCEDURE [dbo].[sp_Validate_Profile_GeneratorKnowledge_Form]
	-- Add the parameters for the stored procedure here
	@profile_id int,
	@web_userid nvarchar(150)
AS

/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 13th April 2021
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_GeneratorKnowledge_Form]

	Procedure to validate Form Generator Knowledge required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid

Samples:
 EXEC [sp_Validate_Profile_GeneratorKnowledge_Form] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_GeneratorKnowledge_Form] 569059,'manand84'

****************************************************************** */

BEGIN
	
	declare @completed_status CHAR(1) = 'P'

	declare @specific_gravity float, 
			@ppe_code varchar(10), 
			@rcra_reg_metals char(1),
			@rcra_reg_vo char(1),
			@rcra_reg_svo char(1),
			@rcra_reg_herb_pest char(1),
			@rcra_reg_cyanide_sulfide char(1),
			@rcra_reg_ph char(1),
			@material_cause_flash char(1),
			@material_meet_alc_exempt char(1),
			@analytical_comments varchar(125),
			@print_name varchar(40),
			@title varchar(20), 
			@company varchar(40),
			@modified_by nvarchar(150)

		select @specific_gravity = specific_gravity,
			   @ppe_code = ppe_code,
			   @rcra_reg_metals = rcra_reg_metals,
			   @rcra_reg_vo = rcra_reg_vo,
			   @rcra_reg_svo = rcra_reg_svo,
			   @rcra_reg_herb_pest = rcra_reg_herb_pest,
			   @rcra_reg_cyanide_sulfide = rcra_reg_cyanide_sulfide,
			   @rcra_reg_ph = rcra_reg_ph,
			   @material_cause_flash = material_cause_flash,
			   @material_meet_alc_exempt = material_meet_alc_exempt,
			   @analytical_comments = analytical_comments,
			   @print_name = print_name 		
		from ProfileGeneratorKnowledge where profile_id =@profile_id

		-- select top 1 @modified_by = modified_by from formwcr where form_id = @form_id and revision_id = @revision_id

		--select @title = sign_title, @company = sign_company from FormSignature where form_id = @form_id and revision_id = @revision_id

	
		if(len(@specific_gravity) = 0 and isnull(@ppe_code, '') = '' and isnull(@rcra_reg_metals, '') = '' 
			and isnull(@rcra_reg_vo, '') = '' and isnull(@rcra_reg_svo, '') = '' and isnull(@rcra_reg_herb_pest, '') = '' 
			and isnull(@rcra_reg_cyanide_sulfide, '') = '' and isnull(@rcra_reg_ph, '') = '' and isnull(@material_cause_flash, '') = ''
			and isnull(@material_meet_alc_exempt, '') = '' and isnull(@analytical_comments, '') = '' 
			and isnull(@print_name, '') = '')
		begin
			set @completed_status = 'C'
		end
		else if(len(@specific_gravity) > 0 and @specific_gravity between 0.01 and 9.99 AND isnull(@ppe_code, '') <> ''  
				and (@rcra_reg_metals = 'T' OR @rcra_reg_metals = 'F')
				and (@rcra_reg_vo = 'T' or @rcra_reg_vo = 'F' )
				and (@rcra_reg_svo ='T' or @rcra_reg_svo = 'F')
				and (@rcra_reg_herb_pest ='T' or @rcra_reg_herb_pest ='F')
				and (@rcra_reg_cyanide_sulfide ='T' or @rcra_reg_cyanide_sulfide ='F')	
				and (@rcra_reg_ph ='T' or @rcra_reg_ph ='F')
				and (@material_cause_flash ='T' or @material_cause_flash ='F')
				and (@material_meet_alc_exempt ='T' or @material_meet_alc_exempt ='F'))
		begin
			set @completed_status = 'Y'
		end 
		else
		begin
			set @completed_status = 'P'
		end			

		-- completed status track
		IF(NOT EXISTS(SELECT 1 FROM ProfileSectionStatus WHERE profile_id = @profile_id AND section = 'GK'))
		BEGIN
		  INSERT INTO ProfileSectionStatus VALUES (@profile_id,'GK',@completed_status,getdate(),@web_userid,getdate(),@web_userid,1)
		END
		ELSE 
		BEGIN
		   UPDATE ProfileSectionStatus SET section_status = @completed_status,date_modified=getdate(),modified_by=@web_userid WHERE profile_id = @profile_id AND section = 'GK'
		END

END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_GeneratorKnowledge_Form] TO COR_USER;
GO

