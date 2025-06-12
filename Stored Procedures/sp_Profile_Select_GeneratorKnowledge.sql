CREATE PROCEDURE [dbo].[sp_Profile_Select_GeneratorKnowledge]		
		@profile_id int
AS

	
/* ******************************************************************

	Author		: Dinesh
	Updated On	: 23-Apr-2021
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_GeneratorKnowledge]

	Description	: Procedure to Generator Knowledge Supplement

	Input		: @profile_id
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_GeneratorKnowledge]   684922

****************************************************************** */

BEGIN	
	Select				
			p.profile_id,				
			PG.locked,
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
			'' as signing_name,		
			isnull(g.generator_name,'') as generator_name,		
	        isnull(g.state_id,'') as state_id,	
			'' as signing_title,
			'' as signing_company,			
			null as signing_date,
			'' AS IsCompleted

	from ProfileGeneratorKnowledge PG
	join Profile p on p.profile_id = PG.profile_id
	left join generator g on g.generator_id = p.generator_id
	where p.profile_id = @profile_id

	FOR XML RAW ('GeneratorKnowledge'), ROOT ('ProfileModel'), ELEMENTS

END	

GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_GeneratorKnowledge] TO COR_USER;

GO