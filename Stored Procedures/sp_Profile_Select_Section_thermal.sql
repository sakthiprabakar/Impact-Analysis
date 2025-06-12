GO
DROP PROC IF EXISTS sp_Profile_Select_Section_thermal
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_thermal](
@profileId INT
)
AS


/***********************************************************************************
 
    Updated By    : MONISH V
    Updated ON    : 23RD NOV 2022
    Type          : Store Procedure 
    Object Name   : [sp_Profile_Select_Section_thermal]
 
  
     Procedure to get thermal profile details
                   
 
    Input       
	
	@profileid
                                                                
    Execution Statement    
	
	EXEC  [dbo].[sp_Profile_Select_Section_thermal] 893442
 
*************************************************************************************/

BEGIN
		SELECT
			
				  ISNULL( Thermal.originating_generator_name,'') AS originating_generator_name,
				  ISNULL( Thermal.originating_generator_epa_id,'') AS originating_generator_epa_id,
				  ISNULL( Thermal.same_as_above,'') AS same_as_above,
				  ISNULL( Thermal.oil_bearing_from_refining_flag,'') AS oil_bearing_from_refining_flag,
				  ISNULL( Thermal.rcra_excluded_HSM_flag,'') AS rcra_excluded_HSM_flag,
				  ISNULL( Thermal.oil_constituents_are_fuel_flag,'') AS oil_constituents_are_fuel_flag,
				  --ISNULL( Thermal.waste_code_uid,'') AS waste_code_uid,
				  ISNULL( Thermal.gen_process,'') AS gen_process,
				  ISNULL( Thermal.composition_water_percent,'') AS composition_water_percent,
				  ISNULL( Thermal.composition_solids_percent,'') AS composition_solids_percent,
				  ISNULL( Thermal.composition_organics_oil_TPH_percent,'') AS composition_organics_oil_TPH_percent,
				  ISNULL( Thermal.heating_value_btu_lb,'') AS heating_value_btu_lb,
				  ISNULL( Thermal.percent_of_ASH,'') AS percent_of_ASH,
				  ISNULL( Thermal.specific_halogens_ppm,'') AS specific_halogens_ppm,
				  ISNULL( Thermal.specific_mercury_ppm,'') AS specific_mercury_ppm,
				  ISNULL( Thermal.specific_SVM_ppm,'') AS specific_SVM_ppm,
				  ISNULL( Thermal.specific_LVM_ppm,'') AS specific_LVM_ppm,
				  ISNULL( Thermal.specific_organic_chlorine_from_VOCs_ppm,'') AS specific_organic_chlorine_from_VOCs_ppm,
				  ISNULL( Thermal.specific_sulfides_ppm,'') AS specific_sulfides_ppm,
				  ISNULL( Thermal.non_friable_debris_gt_2_inch_flag,'') AS non_friable_debris_gt_2_inch_flag,
				  ISNULL( Thermal.non_friable_debris_gt_2_inch_ppm,'') AS non_friable_debris_gt_2_inch_ppm,
				  ISNULL( Thermal.self_heating_properties_flag,'') AS self_heating_properties_flag,
				  ISNULL( Thermal.bitumen_asphalt_tar_flag,'') AS bitumen_asphalt_tar_flag,
				  ISNULL( Thermal.bitumen_asphalt_tar_ppm,'') AS bitumen_asphalt_tar_ppm,
				  ISNULL( Thermal.centrifuge_prior_to_shipment_flag,'') AS centrifuge_prior_to_shipment_flag,
				  ISNULL( Thermal.fuel_oxygenates_flag,'') AS fuel_oxygenates_flag,
				  ISNULL( Thermal.oxygenates_MTBE_flag,'') AS oxygenates_MTBE_flag,
				  ISNULL( Thermal.oxygenates_ethanol_flag,'') AS oxygenates_ethanol_flag,
				  ISNULL( Thermal.oxygenates_other_flag,'') AS oxygenates_other_flag,
				  ISNULL( Thermal.oxygenates_ppm,'') AS oxygenates_ppm,
				  ISNULL( Thermal.surfactants_flag,'') AS surfactants_flag,
				  ISNULL(GETDATE(),'') AS signing_date
				 
			

	FROM  ProfileThermal AS Thermal 
	WHERE profile_Id = @profileId 
	FOR XML RAW ('thermal'), ROOT ('ProfileModel'), ELEMENTS


END

GO

GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_thermal] TO COR_USER;
GO
