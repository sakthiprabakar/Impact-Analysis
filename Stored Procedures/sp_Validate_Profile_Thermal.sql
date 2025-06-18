ALTER PROCEDURE dbo.sp_Validate_Profile_Thermal
	  @profile_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Thermal]
	--Updated by Blair Christensen for Titan 05/21/2025
	
	Procedure to validate Thermal Section required fields and Update the Status of section

inputs @profile_id, @web_userid

Samples:
 EXEC [sp_Validate_Profile_Thermal] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_Thermal] 902383, 'manand84'
****************************************************************** */
BEGIN
	DECLARE @ValidColumnNullCount INTEGER
		  , @TotalValidColumn INTEGER
		  , @SectionType VARCHAR(3)
		  , @ProfileStatusFlag VARCHAR(1) = 'Y'

	SET @SectionType = 'TL';
	SET @TotalValidColumn = 33;

	SELECT @ValidColumnNullCount = (
		   CASE WHEN originating_generator_name IS NULL OR originating_generator_name = '' THEN 1
				ELSE 0
			END	
		 + CASE WHEN originating_generator_epa_id IS NULL OR originating_generator_epa_id  = ''  THEN 1
				ELSE 0
			END
		 + CASE WHEN oil_bearing_from_refining_flag IS NULL OR oil_bearing_from_refining_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN rcra_excluded_HSM_flag IS NULL OR rcra_excluded_HSM_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN oil_constituents_are_fuel_flag IS NULL OR oil_constituents_are_fuel_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN composition_water_percent IS NULL OR CAST(composition_water_percent AS VARCHAR(15)) = '' THEN 1 
				ELSE 0
			END
		 + CASE WHEN composition_solids_percent IS NULL OR CAST(composition_solids_percent AS VARCHAR(15)) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN composition_organics_oil_TPH_percent IS NULL OR CAST(composition_organics_oil_TPH_percent AS VARCHAR(15)) = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN heating_value_btu_lb IS NULL OR CAST(heating_value_btu_lb AS VARCHAR(15)) = ''  THEN 1
				ELSE 0
			END
		 + CASE WHEN percent_of_ASH IS NULL OR CAST(percent_of_ASH AS VARCHAR(15)) = ''  THEN 1
				ELSE 0
			END
		 + CASE WHEN self_heating_properties_flag IS NULL OR self_heating_properties_flag = '' THEN 1
				ELSE 0
			END
		 + CASE WHEN centrifuge_prior_to_shipment_flag IS NULL THEN 1
				ELSE 0
			END
		 + CASE WHEN fuel_oxygenates_flag IS NULL THEN 1
				ELSE 0
			END
		 + CASE WHEN surfactants_flag IS NULL THEN 1
				ELSE 0
			END
		 )
	  FROM dbo.ProfileThermal
	 WHERE profile_id =  @profile_id;


	IF @ValidColumnNullCount != 0 
		BEGIN
			--PRINT '1'
			SET @ProfileStatusFlag = 'P'
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
	  FROM dbo.ProfileThermal
	 WHERE profile_id =  @profile_id;
			
	SELECT @thermalCount = (
		   CASE WHEN petroleum_refining_F037_flag IS NULL OR petroleum_refining_F037_flag = '' OR petroleum_refining_F037_flag = 'F' THEN 0
		        ELSE 1
			END
		 + CASE WHEN petroleum_refining_F038_flag IS NULL OR petroleum_refining_F038_flag = '' OR petroleum_refining_F038_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K048_flag IS NULL OR petroleum_refining_K048_flag = '' OR petroleum_refining_K048_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K049_flag IS NULL OR petroleum_refining_K049_flag = '' OR petroleum_refining_K049_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K050_flag IS NULL OR petroleum_refining_K050_flag = '' OR petroleum_refining_K050_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K051_flag IS NULL OR petroleum_refining_K051_flag = '' OR petroleum_refining_K051_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K052_flag IS NULL OR petroleum_refining_K052_flag = '' OR petroleum_refining_K052_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K169_flag IS NULL OR petroleum_refining_K169_flag = '' OR petroleum_refining_K169_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K170_flag IS NULL OR petroleum_refining_K170_flag = '' OR petroleum_refining_K170_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K171_flag IS NULL OR petroleum_refining_K171_flag = '' OR petroleum_refining_K171_flag='F' THEN 0
				ELSE 1
			END
		 + CASE WHEN petroleum_refining_K172_flag IS NULL OR petroleum_refining_K172_flag = '' OR petroleum_refining_K172_flag='F' THEN 0
				ELSE 1
			END		
		 + CASE WHEN petroleum_refining_no_waste_code_flag IS NULL OR petroleum_refining_no_waste_code_flag = '' OR petroleum_refining_no_waste_code_flag='F' THEN 0
				ELSE 1
			END)
	  FROM dbo.ProfileThermal
	 WHERE profile_id =  @profile_id;

	IF @thermalCount = 0
		BEGIN
			--PRINT '2'
			SET @ProfileStatusFlag = 'P'
		END
	ELSE
		BEGIN 
			IF @petroleum_refining_no_waste_code_flag = 'T'
				BEGIN
					IF @gen_process = '' OR @gen_process IS NULL
						BEGIN
							--PRINT '3'
							SET @ProfileStatusFlag = 'P'
						END
                END
		END


	--- Contains Non-Friable Debris Material > 2-inch size
	IF @non_friable_debris_gt_2_inch_flag = 'T'
		BEGIN
            IF @non_friable_debris_gt_2_inch_ppm IS NULL OR CAST (@non_friable_debris_gt_2_inch_ppm AS VARCHAR(15)) = '' 
				BEGIN 
					--PRINT '5'
					SET @ProfileStatusFlag = 'P'
				END
		END

	-- Contains Bitumen / Asphalt / Tar > 1% (wt.)
	IF @bitumen_asphalt_tar_flag IS NULL OR @bitumen_asphalt_tar_flag = ''
		BEGIN
			--PRINT '6'
			SET @ProfileStatusFlag = 'P' 
		END
	ELSE
		IF @bitumen_asphalt_tar_flag = 'T'
			BEGIN
				IF @bitumen_asphalt_tar_ppm IS NULL OR CAST (@bitumen_asphalt_tar_ppm AS VARCHAR(15)) = ''
					BEGIN
						--PRINT '7'
						SET @ProfileStatusFlag = 'P' 
					END
			END


	-- Contains fuel oxygenates?
	IF @fuel_oxygenates_flag IS NULL OR @fuel_oxygenates_flag = ''
		BEGIN
			--PRINT '8'
			SET @ProfileStatusFlag = 'P' 
		END
	ELSE IF @fuel_oxygenates_flag='T' 
		BEGIN
			DECLARE @oxygenCount INT
			SELECT @oxygenCount = (  
				   CASE WHEN oxygenates_MTBE_flag IS NULL OR oxygenates_MTBE_flag = '' OR oxygenates_MTBE_flag='F' THEN 0
						ELSE 1
					END
				 + CASE WHEN oxygenates_ethanol_flag IS NULL OR oxygenates_ethanol_flag = '' OR oxygenates_ethanol_flag='F' THEN 0
						ELSE 1
					END
				 + CASE WHEN oxygenates_other_flag IS NULL OR oxygenates_other_flag = '' OR oxygenates_other_flag='F' THEN 0
						ELSE 1
					END
			     )
			  FROM dbo.ProfileThermal
			 WHERE profile_id =  @profile_id;

			IF @oxygenCount = 0 
				BEGIN
					--PRINT '9'
					SET @ProfileStatusFlag = 'P' 
				END
			ELSE
				BEGIN
					IF @oxygenates_other_flag = 'T'
						BEGIN
							IF CAST( @oxygenates_ppm AS VARCHAR(15)) = ''
								BEGIN
									--PRINT '10'
									SET @ProfileStatusFlag = 'P' 
								END
						END
				END
		  
		END

	IF NOT EXISTS (SELECT 1 FROM dbo.ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='TL')
		BEGIN
			INSERT INTO dbo.ProfileSectionStatus ( profile_id, section, section_status
				 , date_created, created_by, date_modified, modified_by, isActive)
				VALUES (@profile_id, 'TL', @ProfileStatusFlag
					 , GETDATE(), @web_userid, GETDATE(), @web_userid, 1);
		END
	ELSE 
		BEGIN
			UPDATE dbo.ProfileSectionStatus
			   SET section_status = @ProfileStatusFlag
			 WHERE profile_id = @profile_id AND SECTION = 'TL';
		END

END
GO

GRANT EXEC ON [dbo].[sp_Validate_Profile_Thermal] TO COR_USER;
GO