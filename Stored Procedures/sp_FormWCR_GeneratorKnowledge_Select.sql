CREATE  PROCEDURE [dbo].[sp_FormWCR_GeneratorKnowledge_Select]
		@form_id INT,
		@revision_id INT
AS

	
/* ******************************************************************

	Author		: Dinesh
	Updated On	: 23-Apr-2021
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_FormWCR_GeneratorKnowledge_Select]

	Description	: Procedure to Generator Knowledge Supplement

	Input		:  @form_id @revision_id
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_FormWCR_GeneratorKnowledge_Select]   581573,1

	select * from FormGeneratorKnowledge  where form_id=581573

****************************************************************** */

BEGIN
DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='GK'
	Select	
			
			wcr.form_id,
			wcr.revision_id,
			wcr.profile_id,				
			wcr.locked,
			CONVERT(decimal(18,2), CAST(specific_gravity AS FLOAT)) as specific_gravity,			
			isnull(ppe_code,'') as ppe_code,
			isnull(rcra_reg_metals,'') as rcra_reg_metals,
			isnull(rcra_reg_vo,'') as rcra_reg_vo,
			isnull(rcra_reg_svo,'') as rcra_reg_svo,
			isnull(rcra_reg_herb_pest,'') as rcra_reg_herb_pest,
			isnull(rcra_reg_cyanide_sulfide,'') as rcra_reg_cyanide_sulfide,
			isnull(rcra_reg_ph,'') as rcra_reg_ph,
			isnull(material_cause_flash,'') as material_cause_flash,
			isnull(material_meet_alc_exempt,'') as material_meet_alc_exempt,
			isnull(analytical_comments,'') as analytical_comments,
			isnull(signing_name,'') as signing_name,		
			isnull(g.generator_name,'') as generator_name,		
	        isnull(g.state_id,'') as state_id,	
			isnull(wcr.signing_title,'') as signing_title,
			isnull(wcr.signing_company,'') as signing_company,			
			wcr.signing_date,
			@section_status AS IsCompleted

	from FormGeneratorKnowledge FG
	join formwcr wcr on wcr.form_id = FG.form_id and wcr.revision_id = FG.revision_id
	left join generator g on g.generator_id = wcr.generator_id
	where wcr.form_id = @form_id and wcr.revision_id = @revision_id

	FOR XML RAW ('GeneratorKnowledge'), ROOT ('ProfileModel'), ELEMENTS

END	

GO

	GRANT EXECUTE ON [dbo].[sp_FormWCR_GeneratorKnowledge_Select] TO COR_USER;

GO