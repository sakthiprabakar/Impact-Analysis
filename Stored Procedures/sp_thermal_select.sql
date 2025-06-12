
GO
DROP PROC IF EXISTS sp_thermal_select
GO

CREATE   PROCEDURE [dbo].[sp_thermal_select](
		 @form_id INT,
		 @revision_id	INT
)
AS

/* ******************************************************************

	Updated By		: MONISH V
	Updated On		: 23RD Nov 2022
	Type			: Stored Procedure
	Object Name		: [sp_thermal_Select]


	Procedure used for getting thermal details for given form id and revision id

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [dbo].[sp_thermal_Select] @form_id,@revision_ID
 EXEC [dbo].[sp_thermal_Select] '428898','1'

****************************************************************** */
BEGIN
	DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='TR'

		SELECT
			WT.form_id,
			WT.revision_id,
			COALESCE(WT.wcr_id,@form_id) AS wcr_id,
			COALESCE(WT.wcr_rev_id,@revision_id) AS wcr_rev_id,
			(SELECT gen_process FROM formwcr WHERE form_id= @form_id and revision_id = @revision_id) AS generating_process,
			WT.locked,
			WT.originating_generator_name,
			ISNULL(WT.originating_generator_epa_id,'') AS originating_generator_epa_id,
			WT.same_as_above,
			WT.oil_bearing_from_refining_flag,
			WT.rcra_excluded_HSM_flag,
			WT.oil_constituents_are_fuel_flag,
			WT.petroleum_refining_F037_flag,
			WT.petroleum_refining_F038_flag,
			WT.petroleum_refining_K048_flag,
			WT.petroleum_refining_K049_flag,
			WT.petroleum_refining_K050_flag,
			WT.petroleum_refining_K051_flag,
			WT.petroleum_refining_K052_flag,
			WT.petroleum_refining_K169_flag,
			WT.petroleum_refining_K170_flag,
			WT.petroleum_refining_K171_flag,
			WT.petroleum_refining_K172_flag,
			WT.petroleum_refining_no_waste_code_flag,
			WT.gen_process,
			@section_status AS IsCompleted
			,CAST(WT.composition_water_percent  AS CHAR) AS composition_water_percent,
			--WT.composition_water_percent,
			CAST(WT.composition_solids_percent  AS CHAR) AS composition_solids_percent,
			--WT.composition_solids_percent,
			CAST(WT.composition_organics_oil_TPH_percent  AS CHAR) AS composition_organics_oil_TPH_percent,
			--WT.composition_organics_oil_TPH_percent,
			CAST(WT.heating_value_btu_lb  AS CHAR) AS heating_value_btu_lb,
			--WT.heating_value_btu_lb,
			CAST(WT.percent_of_ASH  AS CHAR) AS percent_of_ASH,
			--WT.percent_of_ASH,
			CAST(WT.specific_halogens_ppm  AS CHAR) AS specific_halogens_ppm,
			--WT.specific_halogens_ppm,
			--WT.specific_mercury_ppm,
			CAST(WT.specific_mercury_ppm  AS CHAR) AS specific_mercury_ppm,
			--WT.specific_SVM_ppm,
			CAST(WT.specific_SVM_ppm  AS CHAR) AS specific_SVM_ppm,
			--WT.specific_LVM_ppm,
			CAST(WT.specific_LVM_ppm  AS CHAR) AS specific_LVM_ppm,
			--WT.specific_organic_chlorine_from_VOCs_ppm,
			CAST(WT.specific_organic_chlorine_from_VOCs_ppm  AS CHAR) AS specific_organic_chlorine_from_VOCs_ppm,
			--WT.specific_sulfides_ppm,
			CAST(WT.specific_sulfides_ppm  AS CHAR) AS specific_sulfides_ppm,
			WT.non_friable_debris_gt_2_inch_flag,
			CAST(WT.non_friable_debris_gt_2_inch_ppm  AS CHAR) AS non_friable_debris_gt_2_inch_ppm,
			--WT.non_friable_debris_gt_2_inch_ppm,
			WT.self_heating_properties_flag,
			WT.bitumen_asphalt_tar_flag,
			CAST(WT.bitumen_asphalt_tar_ppm  AS CHAR) AS bitumen_asphalt_tar_ppm,
			--WT.bitumen_asphalt_tar_ppm,
			WT.centrifuge_prior_to_shipment_flag,
			WT.fuel_oxygenates_flag,
			WT.oxygenates_MTBE_flag,
			WT.oxygenates_ethanol_flag,
			WT.oxygenates_other_flag,
			CAST(WT.oxygenates_ppm  AS CHAR) AS oxygenates_ppm,
			--WT.oxygenates_ppm,
			WT.surfactants_flag,
			WT.created_by,
			WT.date_created,
			WT.date_modified,
			WT.modified_by,
			WCR.generator_name,
			WCR.epa_id AS generator_epa_id,
			WCR.waste_common_name,
			WCR.consistency_solid,
			WCR.consistency_dust,
			WCR.consistency_debris,
			WCR.consistency_sludge ,
			WCR.consistency_liquid,
			WCR.consistency_gas_aerosol ,
			WCR.consistency_varies ,
			WCR.liquid_phase,
			WCR.signing_title,
			WCR.signing_name ,
			WCR.signing_date 

	FROM  FormThermal AS WT 
	
	JOIN  FormWCR AS WCR ON WT.wcr_id = WCR.form_id AND WT.wcr_rev_id = WCR.revision_id
	
	WHERE 

		WCR.form_id = @form_id and  WCR.revision_id = @revision_id 

		--FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS) AS FormWCRSelectSection;

		FOR XML RAW ('thermal'), ROOT ('ProfileModel'), ELEMENTS
END

GO

GRANT EXECUTE ON [dbo].[sp_thermal_select] TO COR_USER;
GO
