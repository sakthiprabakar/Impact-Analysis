
CREATE  PROCEDURE [dbo].[sp_Profile_Select_Section_certification](
	
		  @profileId INT

)
AS
-- 

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_certification]

	Description	: 
                  Procedure to get Section certification profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_certification] 893442

*************************************************************************************/
BEGIN
SELECT
			  ISNULL( Certificate.vsqg_cesqg_accept_flag,'') AS vsqg_cesqg_accept_flag,
			  ISNULL(GETDATE(),'') AS signing_date
			

	FROM  Profile AS Certificate 
	

	WHERE 

		profile_Id = @profileId 

	   FOR XML RAW ('certification'), ROOT ('ProfileModel'), ELEMENTS
		    
END	
			

		
	  GO

GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_certification] TO COR_USER;

GO
