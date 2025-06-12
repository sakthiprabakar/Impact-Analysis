
CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_usedOil](
	 
	 @profileId INT
)
AS


/***********************************************************************************
 
    Updated By    : Prabhu
    Updated On    : 24-Dec-2018
    Type          : Store Procedure 
    Object Name   : [sp_Profile_Select_Section_usedOil]
 
  
     Procedure to get usedOil profile details
                   
 
    Input       
	
	@profileid
                                                                
    Execution Statement    
	
	EXEC  [dbo].[sp_Profile_Select_Section_usedOil] 651846
 
*************************************************************************************/
BEGIN
  SELECT 
		ISNULL(UsedOil.wwa_halogen_gt_1000,'') AS wwa_halogen_gt_1000, 
		ISNULL(UsedOil.halogen_source,'') AS wwa_halogen_source, 
		ISNULL(UsedOil.halogen_source_desc,'') AS wwa_halogen_source_desc1,
		ISNULL(UsedOil.halogen_source_other,'') AS wwa_other_desc_1

	FROM ProfileLab as UsedOil

	WHERE UsedOil.profile_Id = @profileId AND UsedOil.Type = 'A'

	FOR XML RAW ('usedOil'), ROOT ('ProfileModel'), ELEMENTS

END

GO

	GRANT EXEC ON [dbo].[sp_Profile_Select_Section_usedOil] TO COR_USER;

GO


		
		
	 