DROP PROCEDURE IF EXISTS [sp_ProfileEcoflo_select]
GO

CREATE PROCEDURE [dbo].[sp_ProfileEcoflo_select](
	
		 @profileId INT

)
AS
/***********************************************************************************
 
    Updated By    : Nallaperumal C
    Updated On    : 14-october-2023
    Type          : Store Procedure 
    Object Name   : [sp_ProfileEcoflo_select]
    Ticket        : 73641
                                                    
    Execution Statement    
	
	EXEC  [dbo].[sp_ProfileEcoflo_select] @profileId
 
*************************************************************************************/

BEGIN

	SELECT 
	PRE.viscosity_value AS viscosity_value,
	PRE.total_solids_low AS total_solids_low,
	PRE.total_solids_high AS total_solids_high,
	PRE.total_solids_description AS total_solids_description,
	PRE.fluorine_low AS fluorine_low,
	PRE.fluorine_high AS fluorine_high,
	PRE.chlorine_low AS chlorine_low,
	PRE.chlorine_high AS chlorine_high,
	PRE.bromine_low AS bromine_low,
	PRE.bromine_high AS bromine_high,
	PRE.iodine_low AS iodine_low,
	PRE.iodine_high AS iodine_high,
	PRE.added_by AS added_by,
	PRE.modified_by AS modified_by,
	GETDATE() AS date_added,
	GETDATE() AS date_modified,
	PRE.total_solids_flag,
	PRE.organic_halogens_flag,
	PRE.fluorine_low_flag,
	PRE.fluorine_high_flag,
	PRE.chlorine_low_flag,
	PRE.chlorine_high_flag,
	PRE.bromine_low_flag,
	PRE.bromine_high_flag,
	PRE.iodine_low_flag,
	PRE.iodine_high_flag
	FROM  ProfileEcoflo AS PRE 
	WHERE 
		profile_Id = @profileId

	     FOR XML RAW ('FuelsBlending'), ROOT ('ProfileModel'), ELEMENTS XSINIL

END


GO
GRANT EXEC ON [dbo].[sp_ProfileEcoflo_select] TO COR_USER;
GO