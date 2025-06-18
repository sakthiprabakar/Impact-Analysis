CREATE OR ALTER PROCEDURE dbo.sp_Validate_Thermal
	  @formid INT
	, @revision_ID INT
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Thermal]
	Procedure to validate Thermal Section required fields and Update the Status of section
	Updated by Blair Christensen for Titan 05/08/2025

inputs @formid, @revision_ID

Samples:
 EXEC [sp_Validate_Thermal] @form_id,@revision_ID
 EXEC [sp_Validate_Thermal] 600747, 1,'manand84'
****************************************************************** */
BEGIN
	DECLARE @ValidColumnNullCount INTEGER
		  , @TotalValidColumn INTEGER -- Based SELECT Column count
		  , @SectionType VARCHAR(3)
		  , @FormStatusFlag varchar(1) = 'Y'

	SET @SectionType = 'TL'
	SET @TotalValidColumn = 33

	SELECT @ValidColumnNullCount = (
		   CASE WHEN ftr.originating_generator_name IS NULL OR ftr.originating_generator_name = '' THEN 1
				ELSE 0
			END	
		 + CASE WHEN ftr.originating_generator_epa_id IS NULL OR ftr.originating_generator_epa_id  = ''  THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.oil_bearing_from_refining_flag IS NULL OR ftr.oil_bearing_from_refining_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.rcra_excluded_HSM_flag IS NULL OR ftr.rcra_excluded_HSM_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.oil_constituents_are_fuel_flag IS NULL OR ftr.oil_constituents_are_fuel_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.composition_water_percent IS NULL OR (CAST(ftr.composition_water_percent AS VARCHAR(15))) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.composition_solids_percent IS NULL OR (CAST(ftr.composition_solids_percent AS VARCHAR(15))) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.composition_organics_oil_TPH_percent IS NULL OR CAST(ftr.composition_organics_oil_TPH_percent AS VARCHAR(15)) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.heating_value_btu_lb IS NULL OR CAST(ftr.heating_value_btu_lb AS VARCHAR(15)) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.percent_of_ASH IS NULL  OR (CAST(ftr.percent_of_ASH AS VARCHAR(15))) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.self_heating_properties_flag IS NULL OR ftr.self_heating_properties_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.centrifuge_prior_to_shipment_flag IS NULL THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.fuel_oxygenates_flag IS NULL THEN 1
				ELSE 0
			END
		 + CASE WHEN ftr.surfactants_flag IS NULL THEN 1
				ELSE 0
			END
		 )
	  FROM dbo.FormWcr wcr
		   JOIN dbo.FormThermal ftr ON wcr.form_id = ftr.wcr_id
			    AND wcr.revision_id = ftr.wcr_rev_id
	 WHERE wcr.form_id = @formid
	   AND wcr.revision_id = @revision_ID;

	DECLARE @composition_water_percent FLOAT
		  , @composition_solids_percent FLOAT
		  , @composition_organics_oil_TPH_percent FLOAT

	SELECT @composition_water_percent = composition_water_percent
		 , @composition_solids_percent = composition_solids_percent
		 , @composition_organics_oil_TPH_percent = composition_organics_oil_TPH_percent
	  FROM dbo.FormThermal
	 WHERE wcr_id = @formid
	   AND wcr_rev_id = @revision_ID;

	IF ISNUMERIC(@composition_water_percent) = 0 or @composition_water_percent > 100
		BEGIN			 
			SET @FormStatusFlag = 'P'			   
		END

	IF ISNUMERIC(@composition_solids_percent) = 0 or @composition_solids_percent > 100
		BEGIN			 
			SET @FormStatusFlag = 'P'
			--PRINT 'solid percent'
		END

	IF ISNUMERIC(@composition_organics_oil_TPH_percent) = 0 or @composition_organics_oil_TPH_percent > 100
		BEGIN			 
			SET @FormStatusFlag = 'P'
			--PRINT 'organics_oil_TPH percent'
		END

	IF @ValidColumnNullCount != 0 
		BEGIN
			--PRINT '1'
			SET @FormStatusFlag = 'P'
		END

	DECLARE @petroleum_refining_F037_flag CHAR(1)
		  , @petroleum_refining_F038_flag CHAR(1)
		  , @petroleum_refining_K048_flag CHAR(1)
		  , @petroleum_refining_K049_flag CHAR(1)
		  , @petroleum_refining_K050_flag CHAR(1)
		  , @petroleum_refining_K051_flag CHAR(1)
		  , @petroleum_refining_K052_flag CHAR(1)
		  , @petroleum_refining_K169_flag CHAR(1)
		  , @petroleum_refining_K170_flag CHAR(1)
		  , @petroleum_refining_K171_flag CHAR(1)
		  , @petroleum_refining_K172_flag CHAR(1)
		  , @petroleum_refining_no_waste_code_flag CHAR(1)
		  , @gen_process VARCHAR(1000)
		  , @non_friable_debris_gt_2_inch_flag CHAR(1)
		  , @non_friable_debris_gt_2_inch_ppm FLOAT
		  , @bitumen_asphalt_tar_flag CHAR(1)
		  , @bitumen_asphalt_tar_ppm FLOAT
		  , @fuel_oxygenates_flag CHAR(1)
		  , @oxygenates_other_flag CHAR(1)
		  , @oxygenates_ppm FLOAT
		  , @thermalCount INT
			
	SELECT @bitumen_asphalt_tar_ppm = bitumen_asphalt_tar_ppm
	     , @bitumen_asphalt_tar_flag = bitumen_asphalt_tar_flag
		 , @oxygenates_ppm = oxygenates_ppm
		 , @oxygenates_other_flag = oxygenates_other_flag
		 , @fuel_oxygenates_flag = fuel_oxygenates_flag
		 , @non_friable_debris_gt_2_inch_ppm = non_friable_debris_gt_2_inch_ppm
		 , @non_friable_debris_gt_2_inch_flag = non_friable_debris_gt_2_inch_flag
		 , @petroleum_refining_no_waste_code_flag = petroleum_refining_no_waste_code_flag
		 , @gen_process=gen_process 
	  FROM dbo.FormThermal 
	 WHERE wcr_id = @formid
	   AND wcr_rev_id = @revision_ID;
			
			
	SELECT @thermalCount = (
		   CASE WHEN petroleum_refining_F037_flag IS NULL OR petroleum_refining_F037_flag = '' OR petroleum_refining_F037_flag = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_F038_flag IS NULL OR petroleum_refining_F038_flag = '' OR petroleum_refining_F038_flag = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K048_flag IS NULL OR petroleum_refining_K048_flag = '' OR petroleum_refining_K048_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K049_flag IS NULL OR petroleum_refining_K049_flag = '' OR petroleum_refining_K049_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K050_flag IS NULL OR petroleum_refining_K050_flag = '' OR petroleum_refining_K050_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K051_flag IS NULL OR petroleum_refining_K051_flag = '' OR petroleum_refining_K051_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K052_flag IS NULL OR petroleum_refining_K052_flag = '' OR petroleum_refining_K052_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K169_flag IS NULL OR petroleum_refining_K169_flag = '' OR petroleum_refining_K169_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K170_flag IS NULL OR petroleum_refining_K170_flag = '' OR petroleum_refining_K170_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K171_flag IS NULL OR petroleum_refining_K171_flag = '' OR petroleum_refining_K171_flag= 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K172_flag IS NULL OR petroleum_refining_K172_flag = '' OR petroleum_refining_K172_flag = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_no_waste_code_flag IS NULL OR petroleum_refining_no_waste_code_flag = '' OR petroleum_refining_no_waste_code_flag = 'F' THEN 0
				ELSE 1
			END
		 )
	  FROM dbo.FormThermal
	 WHERE wcr_id = @formid
	   AND wcr_rev_id = @revision_ID;

	IF @thermalCount = 0
		BEGIN
			--PRINT '2'
			SET @FormStatusFlag = 'P'
		END
	ELSE
		BEGIN 
			IF @petroleum_refining_no_waste_code_flag = 'T'
				BEGIN
					IF @gen_process = '' OR @gen_process IS NULL
						BEGIN
							--PRINT '3'
							SET @FormStatusFlag = 'P'
						END
                END
		END

	--- Physical State 
	DECLARE @physicalStateCount INT;
	SELECT @physicalStateCount = (
		   CASE WHEN consistency_solid IS NULL OR consistency_solid = '' OR consistency_solid = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_dust IS NULL OR consistency_dust = '' OR consistency_dust = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_debris IS NULL OR consistency_debris = '' OR consistency_debris = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_sludge IS NULL OR consistency_sludge = '' OR consistency_sludge = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_gas_aerosol IS NULL OR consistency_gas_aerosol = '' OR consistency_gas_aerosol = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_varies IS NULL OR consistency_varies = '' OR consistency_varies = 'F' THEN 0
				ELSE 1
			END
		 + CASE WHEN consistency_liquid IS NULL OR consistency_liquid = '' OR consistency_liquid = 'F' THEN 0
				ELSE 1
			END
	     )
	  FROM dbo.FormWcr
	 WHERE form_id =  @formid
	   AND revision_id = @revision_ID;
           
	IF @physicalStateCount = 0
		BEGIN
			--PRINT '4'
			SET @FormStatusFlag = 'P'
		END

	--- Contains Non-Friable Debris Material > 2-inch size
	IF @non_friable_debris_gt_2_inch_flag = 'T'
		BEGIN
			IF @non_friable_debris_gt_2_inch_ppm IS NULL OR CAST (@non_friable_debris_gt_2_inch_ppm AS varchar(15)) = '' 
				BEGIN 
					--PRINT '5'
					SET @FormStatusFlag = 'P'
				END
		END

	-- Contains Bitumen / Asphalt / Tar > 1% (wt.)
	IF @bitumen_asphalt_tar_flag IS NULL OR @bitumen_asphalt_tar_flag = ''
		BEGIN
			--PRINT '6'
		    SET @FormStatusFlag = 'P' 
		END
	ELSE
		IF @bitumen_asphalt_tar_flag = 'T'
			BEGIN
				IF @bitumen_asphalt_tar_ppm IS NULL OR CAST (@bitumen_asphalt_tar_ppm AS VARCHAR(15)) = ''
					BEGIN
						--PRINT '7'
						SET @FormStatusFlag = 'P' 
					END
			END


	-- Contains fuel oxygenates?
	IF @fuel_oxygenates_flag IS NULL OR @fuel_oxygenates_flag = ''
		BEGIN
			--PRINT '8'
			SET @FormStatusFlag = 'P' 
		END
	ELSE IF @fuel_oxygenates_flag='T' 
		BEGIN
			DECLARE @oxygenCount INT
			SELECT @oxygenCount = (  
				   CASE WHEN oxygenates_MTBE_flag IS NULL OR oxygenates_MTBE_flag = '' OR oxygenates_MTBE_flag = 'F' THEN 0
						ELSE 1
					END
				 + CASE WHEN oxygenates_ethanol_flag IS NULL OR oxygenates_ethanol_flag = '' OR oxygenates_ethanol_flag = 'F' THEN 0
						ELSE 1
					END
				 + CASE WHEN oxygenates_other_flag IS NULL OR oxygenates_other_flag = '' OR oxygenates_other_flag = 'F' THEN 0
						ELSE 1
					END
			     )
			  FROM dbo.FormThermal
			 WHERE wcr_id = @formid
			   AND wcr_rev_id = @revision_ID;

			IF @oxygenCount = 0 
				BEGIN
					--PRINT '9'
					SET @FormStatusFlag = 'P' 
				END
			ELSE
				BEGIN
					IF @oxygenates_other_flag = 'T'
						BEGIN
							IF CAST( @oxygenates_ppm AS varchar(15)) = ''
								BEGIN
									--PRINT '10'
									SET @FormStatusFlag = 'P' 
								END
						END
				END
		  
		END

	IF NOT EXISTS (SELECT 1 FROM FormSectionStatus WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION ='TL')
		BEGIN
			INSERT INTO dbo.FormSectionStatus (form_id, revision_id, section, section_status
			     , date_created, created_by, date_modified, modified_by, isActive)
				VALUES (@formid, @Revision_ID, 'TL', @FormStatusFlag, GETDATE(), @web_userid, GETDATE(), @web_userid, 1);
		END
	ELSE 
		BEGIN
			UPDATE dbo.FormSectionStatus 
			   SET section_status = @FormStatusFlag
			 WHERE FORM_ID = @formid
			  AND revision_id = @Revision_ID
			  AND SECTION = 'TL';
		END
END
GO

GRANT EXEC ON [dbo].[sp_Validate_Thermal] TO COR_USER;
GO