CREATE PROCEDURE [dbo].[sp_COR_Profile_Generator_Knowledge_Supplement]
(
	@profile_id int
	
)

AS

/* ******************************************************************

	Author		: Prabhu
	Updated On	: 24-May-2021
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_COR_Profile_Generator_Knowledge_Supplement]

	Description	: Procedure to Profile Generator Knowledge Supplement

	Input		:  @profile_id
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_COR_Profile_Generator_Knowledge_Supplement] 684922

****************************************************************** */

BEGIN

	Select	
			
			
            PG.profile_id,    
            PG.locked,
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
            g.generator_name,
			g.state_id,
			
			p.[wcr_sign_company] signing_company,

            p.[wcr_sign_name] signing_name,

            p.[wcr_sign_title] signing_title,

            p.[wcr_sign_date] signing_date

	from ProfileGeneratorKnowledge PG
	join profile p on p.profile_id = PG.profile_id
    left join generator g on g.generator_id = p.generator_id
    where p.profile_id =@profile_id

END	

GO

	GRANT EXECUTE ON [dbo].[sp_COR_Profile_Generator_Knowledge_Supplement] TO COR_USER;

    GO