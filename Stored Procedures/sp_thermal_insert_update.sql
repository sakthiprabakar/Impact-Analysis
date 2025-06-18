ALTER PROCEDURE dbo.sp_thermal_insert_update
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
INSERT / update Thermal form  (Part of form wcr INSERT / update)

	Updated By		: MONISH V
	Updated On		: 23RD Nov 2022
	Type			: Stored Procedure
	Object Name		: [sp_thermal_insert_update]

  Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
  --Updated by Blair Christensen for Titan 05/21/2025
  
inputs Data, Form ID, Revision ID
****************************************************************** */
BEGIN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id and revision_id =  @revision_id)
			BEGIN
				UPDATE dbo.FormWCR
				   SET consistency_solid = p.v.value('consistency_solid[1]', 'CHAR(1)')
				     , consistency_dust = p.v.value('consistency_dust[1]', 'CHAR(1)')
					 , consistency_debris = p.v.value('consistency_debris[1]', 'CHAR(1)')
					 , consistency_sludge = p.v.value('consistency_sludge[1]', 'CHAR(1)')
					 , consistency_liquid = p.v.value('consistency_liquid[1]', 'CHAR(1)')
					 , consistency_gas_aerosol = p.v.value('consistency_gas_aerosol[1]', 'CHAR(1)')
					 , consistency_varies = p.v.value('consistency_varies[1]', 'CHAR(1)')
					 , liquid_phase = p.v.value('liquid_phase[1]', 'CHAR(1)')
					 , signing_title = p.v.value('signing_title[1]', 'VARCHAR(40)')
					 , signing_name = p.v.value('signing_name[1]', 'VARCHAR(40)')
				  FROM @Data.nodes('Thermal')p(v)
				 WHERE form_id = @form_id and revision_id = @revision_id;
			END
		
		IF NOT EXISTS (SELECT 1 FROM dbo.FormThermal WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)
			BEGIN
				DECLARE @newForm_id INTEGER
					  , @newrev_id INTEGER = 1
					  , @FormWCR_uid INTEGER;

				EXEC @newForm_id = sp_sequence_next 'form.form_id'

				IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id AND revision_id = @revision_id)
					BEGIN
						SELECT @FormWCR_uid = formWCR_uid
						  FROM dbo.FormWCR
						 WHERE form_id = @form_id
						   AND revision_id = @revision_id;
					END
				ELSE
					BEGIN
						SET @FormWCR_uid = NULL;
					END

				INSERT INTO dbo.FormThermal(form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , originating_generator_name, originating_generator_epa_id, oil_bearing_from_refining_flag
					 , rcra_excluded_HSM_flag, oil_constituents_are_fuel_flag
					 , petroleum_refining_F037_flag, petroleum_refining_F038_flag
					 , petroleum_refining_K048_flag, petroleum_refining_K049_flag
					 , petroleum_refining_K050_flag, petroleum_refining_K051_flag, petroleum_refining_K052_flag
					 , petroleum_refining_K169_flag
					 , petroleum_refining_K170_flag, petroleum_refining_K171_flag, petroleum_refining_K172_flag
					 , petroleum_refining_no_waste_code_flag, gen_process
					 , composition_water_percent, composition_solids_percent, composition_organics_oil_TPH_percent
					 , heating_value_btu_lb, percent_of_ASH
					 , specific_halogens_ppm, specific_mercury_ppm, specific_SVM_ppm, specific_LVM_ppm
					 , specific_organic_chlorine_from_VOCs_ppm, specific_sulfides_ppm
					 , non_friable_debris_gt_2_inch_flag, non_friable_debris_gt_2_inch_ppm, self_heating_properties_flag
					 , bitumen_asphalt_tar_flag, bitumen_asphalt_tar_ppm, centrifuge_prior_to_shipment_flag, fuel_oxygenates_flag
					 , oxygenates_MTBE_flag, oxygenates_ethanol_flag, oxygenates_other_flag, oxygenates_ppm
					 , surfactants_flag, created_by, date_created, modified_by, date_modified, same_as_above
					 )
				SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
					 , p.v.value('originating_generator_name[1]', 'VARCHAR(75)') as originating_generator_name
					 , p.v.value('originating_generator_epa_id[1]', 'VARCHAR(12)') as originating_generator_epa_id
					 , p.v.value('oil_bearing_from_refining_flag[1]',' CHAR(1)') as oil_bearing_from_refining_flag
					 , p.v.value('rcra_excluded_HSM_flag[1]', 'CHAR(1)') as rcra_excluded_HSM_flag
					 , p.v.value('oil_constituents_are_fuel_flag[1]','CHAR(1)') as oil_constituents_are_fuel_flag
					 , p.v.value('petroleum_refining_F037_flag[1]', 'CHAR(1)') as petroleum_refining_F037_flag
					 , p.v.value('petroleum_refining_F038_flag[1]', 'CHAR(1)') as petroleum_refining_F038_flag
					 , p.v.value('petroleum_refining_K048_flag[1]', 'CHAR(1)') as petroleum_refining_K048_flag
					 , p.v.value('petroleum_refining_K049_flag[1]', 'CHAR(1)') as petroleum_refining_K049_flag
					 , p.v.value('petroleum_refining_K050_flag[1]', 'CHAR(1)') as petroleum_refining_K050_flag
					 , p.v.value('petroleum_refining_K051_flag[1]', 'CHAR(1)') as petroleum_refining_K051_flag
					 , p.v.value('petroleum_refining_K052_flag[1]', 'CHAR(1)') as petroleum_refining_K052_flag
					 , p.v.value('petroleum_refining_K169_flag[1]', 'CHAR(1)') as petroleum_refining_K169_flag
					 , p.v.value('petroleum_refining_K170_flag[1]', 'CHAR(1)') as petroleum_refining_K170_flag
					 , p.v.value('petroleum_refining_K171_flag[1]', 'CHAR(1)') as petroleum_refining_K171_flag
					 , p.v.value('petroleum_refining_K172_flag[1]', 'CHAR(1)') as petroleum_refining_K172_flag
					 , p.v.value('petroleum_refining_no_waste_code_flag[1]', 'CHAR(1)') as petroleum_refining_no_waste_code_flag
					 , p.v.value('gen_process[1]', 'VARCHAR(1000)') as gen_process
					 , p.v.value('composition_water_percent[1][not(@xsi:nil = "true")]', 'FLOAT') as composition_water_percent
					 , p.v.value('composition_solids_percent[1][not(@xsi:nil = "true")]', 'FLOAT') as composition_solids_percent
					 , p.v.value('composition_organics_oil_TPH_percent[1][not(@xsi:nil = "true")]', 'FLOAT') as composition_organics_oil_TPH_percent
					 , p.v.value('heating_value_btu_lb[1][not(@xsi:nil = "true")]', 'FLOAT') as heating_value_btu_lb
					 , p.v.value('percent_of_ASH[1][not(@xsi:nil = "true")]', 'FLOAT') as percent_of_ASH
					 , p.v.value('specific_halogens_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_halogens_ppm
					 , p.v.value('specific_mercury_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_mercury_ppm
					 , p.v.value('specific_SVM_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_SVM_ppm
					 , p.v.value('specific_LVM_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_LVM_ppm
					 , p.v.value('specific_organic_chlorine_from_VOCs_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_organic_chlorine_from_VOCs_ppm
					 , p.v.value('specific_sulfides_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as specific_sulfides_ppm
					 , p.v.value('non_friable_debris_gt_2_inch_flag[1]', 'CHAR(1)') as non_friable_debris_gt_2_inch_flag
					 , p.v.value('non_friable_debris_gt_2_inch_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as non_friable_debris_gt_2_inch_ppm
					 , p.v.value('self_heating_properties_flag[1]', 'CHAR(1)') as self_heating_properties_flag
					 , p.v.value('bitumen_asphalt_tar_flag[1]', 'CHAR(1)') as bitumen_asphalt_tar_flag
					 , p.v.value('bitumen_asphalt_tar_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as bitumen_asphalt_tar_ppm
					 , p.v.value('centrifuge_prior_to_shipment_flag[1]', 'CHAR(1)') as centrifuge_prior_to_shipment_flag
					 , p.v.value('fuel_oxygenates_flag[1]', 'CHAR(1)') as fuel_oxygenates_flag
					 , p.v.value('oxygenates_MTBE_flag[1]', 'CHAR(1)') as oxygenates_MTBE_flag
					 , p.v.value('oxygenates_ethanol_flag[1]', 'CHAR(1)') as oxygenates_ethanol_flag
					 , p.v.value('oxygenates_other_flag[1]', 'CHAR(1)') as oxygenates_other_flag
					 , p.v.value('oxygenates_ppm[1][not(@xsi:nil = "true")]', 'FLOAT') as oxygenates_ppm
					 , p.v.value('surfactants_flag[1]', 'CHAR(1)') as surfactants_flag
					 , @web_userid as created_by
					 , GETDATE() as date_created
					 , @web_userid as modified_by
					 , GETDATE() as date_modified
					 , p.v.value('same_as_above[1]', 'CHAR(1)') as same_as_above
				  FROM @Data.nodes('Thermal')p(v);
			END
		ELSE
			BEGIN
				UPDATE dbo.FormThermal
				   SET locked = 'U'
				     , originating_generator_name = p.v.value('originating_generator_name[1]', 'VARCHAR(40)')
					 , originating_generator_epa_id = p.v.value('originating_generator_epa_id[1]', 'VARCHAR(12)')
					 , oil_bearing_from_refining_flag = p.v.value('oil_bearing_from_refining_flag[1]', 'CHAR(1)')
					 , rcra_excluded_HSM_flag = p.v.value('rcra_excluded_HSM_flag[1]', 'CHAR(1)')
					 , oil_constituents_are_fuel_flag = p.v.value('oil_constituents_are_fuel_flag[1]', 'CHAR(1)')
					 , petroleum_refining_F037_flag = p.v.value('petroleum_refining_F037_flag[1]', 'CHAR(1)')
					 , petroleum_refining_F038_flag = p.v.value('petroleum_refining_F038_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K048_flag = p.v.value('petroleum_refining_K048_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K049_flag = p.v.value('petroleum_refining_K049_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K050_flag = p.v.value('petroleum_refining_K050_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K051_flag = p.v.value('petroleum_refining_K051_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K052_flag = p.v.value('petroleum_refining_K052_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K169_flag = p.v.value('petroleum_refining_K169_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K170_flag = p.v.value('petroleum_refining_K170_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K171_flag = p.v.value('petroleum_refining_K171_flag[1]', 'CHAR(1)')
					 , petroleum_refining_K172_flag = p.v.value('petroleum_refining_K172_flag[1]', 'CHAR(1)')
					 , petroleum_refining_no_waste_code_flag = p.v.value('petroleum_refining_no_waste_code_flag[1]', 'CHAR(1)')
					 , gen_process = p.v.value('gen_process[1]', 'VARCHAR(1000)')
					 , composition_water_percent = p.v.value('composition_water_percent[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , composition_solids_percent = p.v.value('composition_solids_percent[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , composition_organics_oil_TPH_percent = p.v.value('composition_organics_oil_TPH_percent[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , heating_value_btu_lb = p.v.value('heating_value_btu_lb[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , percent_of_ASH = p.v.value('percent_of_ASH[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_halogens_ppm = p.v.value('specific_halogens_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_mercury_ppm = p.v.value('specific_mercury_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_SVM_ppm = p.v.value('specific_SVM_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_LVM_ppm = p.v.value('specific_LVM_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_organic_chlorine_from_VOCs_ppm = p.v.value('specific_organic_chlorine_from_VOCs_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , specific_sulfides_ppm = p.v.value('specific_sulfides_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , non_friable_debris_gt_2_inch_flag = p.v.value('non_friable_debris_gt_2_inch_flag[1]', 'CHAR(1)')
					 , non_friable_debris_gt_2_inch_ppm = p.v.value('non_friable_debris_gt_2_inch_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , self_heating_properties_flag = p.v.value('self_heating_properties_flag[1]', 'CHAR(1)')
					 , bitumen_asphalt_tar_flag = p.v.value('bitumen_asphalt_tar_flag[1]', 'CHAR(1)')
					 , bitumen_asphalt_tar_ppm = p.v.value('bitumen_asphalt_tar_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , centrifuge_prior_to_shipment_flag = p.v.value('centrifuge_prior_to_shipment_flag[1]', 'CHAR(1)')
					 , fuel_oxygenates_flag = p.v.value('fuel_oxygenates_flag[1]', 'CHAR(1)')
					 , oxygenates_MTBE_flag = p.v.value('oxygenates_MTBE_flag[1]', 'CHAR(1)')
					 , oxygenates_ethanol_flag = p.v.value('oxygenates_ethanol_flag[1]', 'CHAR(1)')
					 , oxygenates_other_flag = p.v.value('oxygenates_other_flag[1]', 'CHAR(1)')
					 , oxygenates_ppm = p.v.value('oxygenates_ppm[1][not(@xsi:nil = "true")]', 'FLOAT')
					 , surfactants_flag = p.v.value('surfactants_flag[1]', 'CHAR(1)')
					 , modified_by = @web_userid
					 , date_modified = GETDATE()
					 , same_as_above = p.v.value('same_as_above[1]', 'CHAR(1)')
				  FROM @Data.nodes('Thermal')p(v)
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @procedure VARCHAR(150)
			  , @mailTrack_userid VARCHAR(60) = 'COR'
		SET @procedure = ERROR_PROCEDURE()

		DECLARE @error VARCHAR(2047) = ERROR_MESSAGE()
		DECLARE @error_description VARCHAR(4000) = 'Form ID: ' + CONVERT(VARCHAR(15), @form_id)
				+ '-' + CONVERT(VARCHAR(15), @revision_id)
				+ CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
				+ CHAR(13) + 'Data: ' + CONVERT(VARCHAR(4000), @Data);

		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = @mailTrack_userid, @object = @procedure, @body = @error_description
	END CATCH
END
GO
GRANT EXECUTE ON [dbo].[sp_thermal_insert_update] TO COR_USER;
GO
