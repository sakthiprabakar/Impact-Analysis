CREATE PROCEDURE [dbo].[sp_COR_Generator_Knowledge_Supplement]
(
	@form_id int,
	@revision_id int
)

AS

/* ******************************************************************

	Author		: Prabhu
	Updated On	: 16-Apr-2021
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_COR_Generator_Knowledge_Supplement]

	Description	: Procedure to Generator Knowledge Supplement

	Input		:  @form_id @revision_id

	Notes: Updated on 07/26/23 - Generator condition changes 
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_COR_Generator_Knowledge_Supplement]   569724,1

****************************************************************** */

BEGIN

	Select	
			
			wcr.form_id,
			wcr.revision_id,
			wcr.profile_id,				
			wcr.locked,
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
	        wcr.generator_name,
			wcr.state_id,
			wcr.signing_name,
			wcr.signing_title,
			wcr.signing_company,
			wcr.signing_date

	from FormGeneratorKnowledge FG
	join formwcr wcr on wcr.form_id = FG.form_id and wcr.revision_id = FG.revision_id
	---left join generator g on g.generator_id = wcr.generator_id
	where wcr.form_id =@form_id and wcr.revision_id = @revision_id and isnull(@revision_id, '') <> ''

END	

GO

	GRANT EXECUTE ON [dbo].[sp_COR_Generator_Knowledge_Supplement] TO COR_USER;

GO