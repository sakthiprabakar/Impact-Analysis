
CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_IllinoisDisposal](
	
			@profileId INT

)
AS

/***********************************************************************************

	Author		: Prabhu
	Updated On	: 5-Jan-2019
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_IllinoisDisposal]

	Description	: 
                  Procedure to get illinoisDisposal profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_IllinoisDisposal] 893442

*************************************************************************************/

BEGIN

	SELECT
			
			ISNULL( PID.none_apply_flag,'') AS none_apply_flag,
			ISNULL( PID.incecticides_flag,'') AS incecticides_flag,
			ISNULL( PID.pesticides_flag,'') AS pesticides_flag,
			ISNULL( PID.herbicides_flag,'') AS herbicides_flag,
			ISNULL( PID.household_waste_flag,'') AS household_waste_flag,
			ISNULL( PID.carcinogen_flag,'') AS carcinogen_flag,
			ISNULL( PID.other_flag,'') AS other_flag,
			ISNULL( PID.other_specify,'') AS other_specify,
			ISNULL( PID.sulfide_10_250_flag,'') AS sulfide_10_250_flag,
			ISNULL( PID.universal_waste_flag,'') AS universal_waste_flag,
			ISNULL( PID.characteristic_sludge_flag,'') AS characteristic_sludge_flag,
			ISNULL( PID.virgin_unused_product_flag,'') AS virgin_unused_product_flag,
			ISNULL( PID.spent_material_flag,'') AS spent_material_flag,
			ISNULL( PID.cyanide_plating_on_site_flag,'') AS cyanide_plating_on_site_flag,
			ISNULL( PID.substitute_commercial_product_flag,'') AS substitute_commercial_product_flag,
			ISNULL( PID.by_product_flag,'') AS by_product_flag,
			ISNULL( PID.rx_lime_flammable_gas_flag,'') AS rx_lime_flammable_gas_flag,
			ISNULL( PID.pollution_control_waste_IL_flag,'') AS pollution_control_waste_IL_flag,
			ISNULL( PID.industrial_process_waste_IL_flag,'') AS industrial_process_waste_IL_flag,
			ISNULL( PID.phenol_gt_1000_flag,'') AS phenol_gt_1000_flag,
			ISNULL( PID.generator_state_id,'') AS generator_state_id,
			ISNULL( PID.d004_above_PQL,'') AS d004_above_PQL,
			ISNULL( PID.d005_above_PQL,'') AS d005_above_PQL,
			ISNULL( PID.d006_above_PQL,'') AS d006_above_PQL,
			ISNULL( PID.d007_above_PQL,'') AS d007_above_PQL,
			ISNULL( PID.d008_above_PQL,'') AS d008_above_PQL,
			ISNULL( PID.d009_above_PQL,'') AS d009_above_PQL,
			ISNULL( PID.d010_above_PQL,'') AS d010_above_PQL,
			ISNULL( PID.d011_above_PQL,'') AS d011_above_PQL,
			ISNULL( PID.d012_above_PQL,'') AS d012_above_PQL,
			ISNULL( PID.d013_above_PQL,'') AS d013_above_PQL,
			ISNULL( PID.d014_above_PQL,'') AS d014_above_PQL,
			ISNULL( PID.d015_above_PQL,'') AS d015_above_PQL,
			ISNULL( PID.d016_above_PQL,'') AS d016_above_PQL,
			ISNULL( PID.d017_above_PQL,'') AS d017_above_PQL,
			ISNULL( PID.d018_above_PQL,'') AS d018_above_PQL,
			ISNULL( PID.d019_above_PQL,'') AS d019_above_PQL,
			ISNULL( PID.d020_above_PQL,'') AS d020_above_PQL,
			ISNULL( PID.d021_above_PQL,'') AS d021_above_PQL,
			ISNULL( PID.d022_above_PQL,'') AS d022_above_PQL,
			ISNULL( PID.d023_above_PQL,'') AS d023_above_PQL,
			ISNULL( PID.d024_above_PQL,'') AS d024_above_PQL,
			ISNULL( PID.d025_above_PQL,'') AS d025_above_PQL,
			ISNULL( PID.d026_above_PQL,'') AS d026_above_PQL,
			ISNULL( PID.d027_above_PQL,'') AS d027_above_PQL,
			ISNULL( PID.d028_above_PQL,'') AS d028_above_PQL,
			ISNULL( PID.d029_above_PQL,'') AS d029_above_PQL,
			ISNULL( PID.d030_above_PQL,'') AS d030_above_PQL,
			ISNULL( PID.d031_above_PQL,'') AS d031_above_PQL,
			ISNULL( PID.d032_above_PQL,'') AS d032_above_PQL,
			ISNULL( PID.d033_above_PQL,'') AS d033_above_PQL,
			ISNULL( PID.d034_above_PQL,'') AS d034_above_PQL,
			ISNULL( PID.d035_above_PQL,'') AS d035_above_PQL,
			ISNULL( PID.d036_above_PQL,'') AS d036_above_PQL,
			ISNULL( PID.d037_above_PQL,'') AS d037_above_PQL,
			ISNULL( PID.d038_above_PQL,'') AS d038_above_PQL,
			ISNULL( PID.d039_above_PQL,'') AS d039_above_PQL,
			ISNULL( PID.d040_above_PQL,'') AS d040_above_PQL,
			ISNULL( PID.d041_above_PQL,'') AS d041_above_PQL,
			ISNULL( PID.d042_above_PQL,'') AS d042_above_PQL,
			ISNULL( PID.d043_above_PQL,'') AS d043_above_PQL,
			--ISNULL( PID.created_by,'') AS created_by,
			--ISNULL( PID.date_created,'') AS date_created,
			ISNULL( PID.modified_by,'') AS date_modified,
			ISNULL( PID.date_modified,'') AS modified_by,
			ISNULL(PID.generator_certification_flag, '') as generator_certification_flag,
			ISNULL(PID.certify_flag, '') as certify_flag
			
			
			
	FROM  ProfileIllinoisDisposal AS PID 
	

	WHERE 

		profile_Id = @profileId 

	    FOR XML RAW ('IllinoisDisposal'), ROOT ('ProfileModel'), ELEMENTS
END

GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_IllinoisDisposal] TO COR_USER;

GO