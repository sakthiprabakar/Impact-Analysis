

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_B]
	@profileid int

AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_B]

	Description	: 
                  Procedure to get SECTION B profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_B] 893442

*************************************************************************************/

	SELECT ISNULL(approval_desc,'') as waste_common_name,ISNULL(gen_process,'') as gen_process,ISNULL(EPA_source_code,'') as EPA_source_code ,ISNULL(EPA_form_code,'') AS EPA_form_code  from Profile  
	where profile_id = @profileid
	FOR XML RAW ('SectionB'), ROOT ('ProfileModel'), ELEMENTS










--	select  top 1
--approval_desc,
--gen_process,
--EPA_source_code,
--EPA_form_code 
--from profile






  GO

GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_B] TO COR_USER;

GO
