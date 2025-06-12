USE [PLT_AI]
GO

/****************************************************************************************************************/
DROP PROC IF EXISTS sp_thermal_insert_update
GO

CREATE PROCEDURE [dbo].[sp_thermal_insert_update]
       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
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
  
inputs 
	
	Data -- XML data having values for the FormThermal table
	Form ID
	Revision ID
****************************************************************** */
BEGIN
	begin try	
	  IF(EXISTS(SELECT form_id FROM FormWCR  WITH(NOLOCK)  WHERE form_id = @form_id and revision_id =  @revision_id))
	  BEGIN
			UPDATE  FormWCR
			SET 
				consistency_solid = p.v.value('consistency_solid[1]','CHAR(1)'),
				consistency_dust = p.v.value('consistency_dust[1]','CHAR(1)'),
				consistency_debris = p.v.value('consistency_debris[1]','CHAR(1)'),
				consistency_sludge = p.v.value('consistency_sludge[1]','CHAR(1)'),
				consistency_liquid = p.v.value('consistency_liquid[1]','CHAR(1)'),
				consistency_gas_aerosol = p.v.value('consistency_gas_aerosol[1]','CHAR(1)'),
				consistency_varies = p.v.value('consistency_varies[1]','CHAR(1)'),
				liquid_phase = p.v.value('liquid_phase[1]','CHAR(1)'),
				signing_title = p.v.value('signing_title[1]','varchar(40)'), 
				signing_name = p.v.value('signing_name[1]','varchar(40)')
			FROM 
			@Data.nodes('Thermal')p(v) WHERE form_id = @form_id and revision_id =  @revision_id
	  END
	  IF(NOT EXISTS(SELECT 1 FROM FormThermal  WITH(NOLOCK) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id))
	BEGIN
		DECLARE @newForm_id INT 
		DECLARE @newrev_id INT  = 1  
		EXEC @newForm_id = sp_sequence_next 'form.form_id'
		INSERT INTO FormThermal(
			form_id,
			revision_id,
			wcr_id,
			wcr_rev_id,
			locked,
			originating_generator_name,
			originating_generator_epa_id,
			same_as_above,
			oil_bearing_from_refining_flag,
			rcra_excluded_HSM_flag,
			oil_constituents_are_fuel_flag,
			petroleum_refining_F037_flag,
			petroleum_refining_F038_flag,
			petroleum_refining_K048_flag,
			petroleum_refining_K049_flag,
			petroleum_refining_K050_flag,
			petroleum_refining_K051_flag,
			petroleum_refining_K052_flag,
			petroleum_refining_K169_flag,
			petroleum_refining_K170_flag,
			petroleum_refining_K171_flag,
			petroleum_refining_K172_flag,
			petroleum_refining_no_waste_code_flag,
			gen_process,
			composition_water_percent,
			composition_solids_percent,
			composition_organics_oil_TPH_percent,
			heating_value_btu_lb,
			percent_of_ASH,
			specific_halogens_ppm,
			specific_mercury_ppm,
			specific_SVM_ppm,
			specific_LVM_ppm,
			specific_organic_chlorine_from_VOCs_ppm,
			specific_sulfides_ppm,
			non_friable_debris_gt_2_inch_flag,
			non_friable_debris_gt_2_inch_ppm,
			self_heating_properties_flag,
			bitumen_asphalt_tar_flag,
			bitumen_asphalt_tar_ppm,
			centrifuge_prior_to_shipment_flag,
			fuel_oxygenates_flag,
			oxygenates_MTBE_flag,
			oxygenates_ethanol_flag,
			oxygenates_other_flag,
			oxygenates_ppm,
			surfactants_flag,
			created_by,
			date_created,
			date_modified,
			modified_by
			)
        SELECT
			 
		    form_id = @newForm_id,
			revision_id = @newrev_id,
		    wcr_id = @form_id,
			wcr_rev_id = @revision_id,
			--locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			originating_generator_name = p.v.value('originating_generator_name[1]','varchar(40)'),
			originating_generator_epa_id = p.v.value('originating_generator_epa_id[1]','varchar(12)'),
			same_as_above = p.v.value('same_as_above[1]','char(1)'),
			oil_bearing_from_refining_flag = p.v.value('oil_bearing_from_refining_flag[1]','char(1)'),
			rcra_excluded_HSM_flag = p.v.value('rcra_excluded_HSM_flag[1]','char(1)'),
			oil_constituents_are_fuel_flag = p.v.value('oil_constituents_are_fuel_flag[1]','char(1)'),
			petroleum_refining_F037_flag = p.v.value('petroleum_refining_F037_flag[1]','char(1)'),
			petroleum_refining_F038_flag = p.v.value('petroleum_refining_F038_flag[1]','char(1)'), 
			petroleum_refining_K048_flag = p.v.value('petroleum_refining_K048_flag[1]','char(1)'),
			petroleum_refining_K049_flag = p.v.value('petroleum_refining_K049_flag[1]','char(1)'),
			petroleum_refining_K050_flag = p.v.value('petroleum_refining_K050_flag[1]','char(1)'),
			petroleum_refining_K051_flag = p.v.value('petroleum_refining_K051_flag[1]','char(1)'),
			petroleum_refining_K052_flag = p.v.value('petroleum_refining_K052_flag[1]','char(1)'),
			petroleum_refining_K169_flag = p.v.value('petroleum_refining_K169_flag[1]','char(1)'),
			petroleum_refining_K170_flag = p.v.value('petroleum_refining_K170_flag[1]','char(1)'),
			petroleum_refining_K171_flag = p.v.value('petroleum_refining_K171_flag[1]','char(1)'),
			petroleum_refining_K172_flag = p.v.value('petroleum_refining_K172_flag[1]','char(1)'),
			petroleum_refining_no_waste_code_flag = p.v.value('petroleum_refining_no_waste_code_flag[1]','char(1)'),
			gen_process = p.v.value('gen_process[1]','varchar(4000)'),
			composition_water_percent = p.v.value('composition_water_percent[1][not(@xsi:nil = "true")]','float'),
			composition_solids_percent = p.v.value('composition_solids_percent[1][not(@xsi:nil = "true")]','float'),
			composition_organics_oil_TPH_percent = p.v.value('composition_organics_oil_TPH_percent[1][not(@xsi:nil = "true")]','float'),
			heating_value_btu_lb = p.v.value('heating_value_btu_lb[1][not(@xsi:nil = "true")]','float'),
			percent_of_ASH = p.v.value('percent_of_ASH[1][not(@xsi:nil = "true")]','float'),
			specific_halogens_ppm = p.v.value('specific_halogens_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_mercury_ppm = p.v.value('specific_mercury_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_SVM_ppm = p.v.value('specific_SVM_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_LVM_ppm = p.v.value('specific_LVM_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_organic_chlorine_from_VOCs_ppm = p.v.value('specific_organic_chlorine_from_VOCs_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_sulfides_ppm = p.v.value('specific_sulfides_ppm[1][not(@xsi:nil = "true")]','float'),
			non_friable_debris_gt_2_inch_flag = p.v.value('non_friable_debris_gt_2_inch_flag[1]','char(1)'),
			non_friable_debris_gt_2_inch_ppm = p.v.value('non_friable_debris_gt_2_inch_ppm[1][not(@xsi:nil = "true")]','float'),
			self_heating_properties_flag = p.v.value('self_heating_properties_flag[1]','char(1)'),
			bitumen_asphalt_tar_flag = p.v.value('bitumen_asphalt_tar_flag[1]','char(1)'),
			bitumen_asphalt_tar_ppm = p.v.value('bitumen_asphalt_tar_ppm[1][not(@xsi:nil = "true")]','float'),
			centrifuge_prior_to_shipment_flag = p.v.value('centrifuge_prior_to_shipment_flag[1]','char(1)'),
			fuel_oxygenates_flag = p.v.value('fuel_oxygenates_flag[1]','char(1)'),
			oxygenates_MTBE_flag = p.v.value('oxygenates_MTBE_flag[1]','char(1)'),
			oxygenates_ethanol_flag = p.v.value('oxygenates_ethanol_flag[1]','char(1)'),
			oxygenates_other_flag = p.v.value('oxygenates_other_flag[1]','char(1)'),
			oxygenates_ppm = p.v.value('oxygenates_ppm[1][not(@xsi:nil = "true")]','float'),
			surfactants_flag = p.v.value('surfactants_flag[1]','char(1)'),
		    created_by = @web_userid,
		    date_created = GETDATE(),
		    date_modified = GETDATE(),
			modified_by = @web_userid
        FROM
            @Data.nodes('Thermal')p(v)
   END
  ELSE
   BEGIN
        UPDATE  FormThermal
        SET                 
			--locked = p.v.value('locked[1]','char(1)'),
			locked = 'U',
			originating_generator_name = p.v.value('originating_generator_name[1]','varchar(40)'),
			originating_generator_epa_id = p.v.value('originating_generator_epa_id[1]','varchar(12)'),
			same_as_above = p.v.value('same_as_above[1]','char(1)'),
			oil_bearing_from_refining_flag = p.v.value('oil_bearing_from_refining_flag[1]','char(1)'),
			rcra_excluded_HSM_flag = p.v.value('rcra_excluded_HSM_flag[1]','char(1)'),
			oil_constituents_are_fuel_flag = p.v.value('oil_constituents_are_fuel_flag[1]','char(1)'),
			petroleum_refining_F037_flag = p.v.value('petroleum_refining_F037_flag[1]','char(1)'),
			petroleum_refining_F038_flag = p.v.value('petroleum_refining_F038_flag[1]','char(1)'), 
			petroleum_refining_K048_flag = p.v.value('petroleum_refining_K048_flag[1]','char(1)'),
			petroleum_refining_K049_flag = p.v.value('petroleum_refining_K049_flag[1]','char(1)'),
			petroleum_refining_K050_flag = p.v.value('petroleum_refining_K050_flag[1]','char(1)'),
			petroleum_refining_K051_flag = p.v.value('petroleum_refining_K051_flag[1]','char(1)'),
			petroleum_refining_K052_flag = p.v.value('petroleum_refining_K052_flag[1]','char(1)'),
			petroleum_refining_K169_flag = p.v.value('petroleum_refining_K169_flag[1]','char(1)'),
			petroleum_refining_K170_flag = p.v.value('petroleum_refining_K170_flag[1]','char(1)'),
			petroleum_refining_K171_flag = p.v.value('petroleum_refining_K171_flag[1]','char(1)'),
			petroleum_refining_K172_flag = p.v.value('petroleum_refining_K172_flag[1]','char(1)'),
			petroleum_refining_no_waste_code_flag = p.v.value('petroleum_refining_no_waste_code_flag[1]','char(1)'),
			gen_process = p.v.value('gen_process[1]','varchar(4000)'),
			composition_water_percent = p.v.value('composition_water_percent[1][not(@xsi:nil = "true")]','float'),
			composition_solids_percent = p.v.value('composition_solids_percent[1][not(@xsi:nil = "true")]','float'),
			composition_organics_oil_TPH_percent = p.v.value('composition_organics_oil_TPH_percent[1][not(@xsi:nil = "true")]','float'),
			heating_value_btu_lb = p.v.value('heating_value_btu_lb[1][not(@xsi:nil = "true")]','float'),
			percent_of_ASH = p.v.value('percent_of_ASH[1][not(@xsi:nil = "true")]','float'),
			specific_halogens_ppm = p.v.value('specific_halogens_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_mercury_ppm = p.v.value('specific_mercury_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_SVM_ppm = p.v.value('specific_SVM_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_LVM_ppm = p.v.value('specific_LVM_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_organic_chlorine_from_VOCs_ppm = p.v.value('specific_organic_chlorine_from_VOCs_ppm[1][not(@xsi:nil = "true")]','float'),
			specific_sulfides_ppm = p.v.value('specific_sulfides_ppm[1][not(@xsi:nil = "true")]','float'),
			non_friable_debris_gt_2_inch_flag = p.v.value('non_friable_debris_gt_2_inch_flag[1]','char(1)'),
			non_friable_debris_gt_2_inch_ppm = p.v.value('non_friable_debris_gt_2_inch_ppm[1][not(@xsi:nil = "true")]','float'),
			self_heating_properties_flag = p.v.value('self_heating_properties_flag[1]','char(1)'),
			bitumen_asphalt_tar_flag = p.v.value('bitumen_asphalt_tar_flag[1]','char(1)'),
			bitumen_asphalt_tar_ppm = p.v.value('bitumen_asphalt_tar_ppm[1][not(@xsi:nil = "true")]','float'),
			centrifuge_prior_to_shipment_flag = p.v.value('centrifuge_prior_to_shipment_flag[1]','char(1)'),
			fuel_oxygenates_flag = p.v.value('fuel_oxygenates_flag[1]','char(1)'),
			oxygenates_MTBE_flag = p.v.value('oxygenates_MTBE_flag[1]','char(1)'),
			oxygenates_ethanol_flag = p.v.value('oxygenates_ethanol_flag[1]','char(1)'),
			oxygenates_other_flag = p.v.value('oxygenates_other_flag[1]','char(1)'),
			oxygenates_ppm = p.v.value('oxygenates_ppm[1][not(@xsi:nil = "true")]','float'),
			surfactants_flag = p.v.value('surfactants_flag[1]','char(1)'),	
		    date_modified = GETDATE(),
		    modified_by = @web_userid
		 FROM
         @Data.nodes('Thermal')p(v) WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id
   END
   end try
   begin catch
		DECLARE @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				DECLARE @error nvarchar(4000) = ERROR_MESSAGE()
				DECLARE @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' 
															+  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + ISNULL(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
   end catch
END
GO
	GRANT EXECUTE ON [dbo].[sp_thermal_insert_update] TO COR_USER;
GO
/***************************************************************************************************************/