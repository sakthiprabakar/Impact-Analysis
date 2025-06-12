USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Thermal]    Script Date: 26-11-2021 13:14:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE  [dbo].[sp_Validate_Profile_Thermal]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Thermal]


	Procedure to validate Thermal Section required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid


Samples:
 EXEC [sp_Validate_Profile_Thermal] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_Thermal] 902383, 'manand84'

****************************************************************** */

BEGIN

	DECLARE @ValidColumnNullCount INTEGER;

	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);

	SET @SectionType = 'TL'
	SET @TotalValidColumn = 33

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'
	
	SET  @ValidColumnNullCount = (SELECT  (
				   -- (CASE WHEN wcr.generator_name IS NULL OR wcr.generator_name = '' THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.epa_id IS NULL OR wcr.epa_id = '' THEN 1 ELSE 0 END)
				  --+	
				  (CASE WHEN pt.originating_generator_name IS NULL OR pt.originating_generator_name = '' THEN 1 ELSE 0 END)	
				  +	(CASE WHEN pt.originating_generator_epa_id IS NULL OR pt.originating_generator_epa_id  = ''  THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.waste_common_name IS NULL OR wcr.waste_common_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.oil_bearing_from_refining_flag IS NULL OR pt.oil_bearing_from_refining_flag = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.rcra_excluded_HSM_flag IS NULL OR pt.rcra_excluded_HSM_flag = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.oil_constituents_are_fuel_flag IS NULL OR pt.oil_constituents_are_fuel_flag = '' THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.signing_name IS NULL OR wcr.signing_name = '' THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.signing_title IS NULL OR wcr.signing_title = '' THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.signing_date IS NULL OR wcr.signing_date = '' THEN 1 ELSE 0 END)	 
				  --+	(CASE WHEN wcr.liquid_phase IS NULL OR wcr.liquid_phase = '' THEN 1 ELSE 0 END)				
				  +	(CASE WHEN pt.composition_water_percent IS NULL OR (CAST(pt.composition_water_percent AS VARCHAR(15))) = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.composition_solids_percent IS NULL OR (CAST(pt.composition_solids_percent AS VARCHAR(15))) = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.composition_organics_oil_TPH_percent IS NULL OR (CAST(pt.composition_organics_oil_TPH_percent AS VARCHAR(15))) = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.heating_value_btu_lb IS NULL   OR (CAST(pt.heating_value_btu_lb AS VARCHAR(15))) = ''  THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.percent_of_ASH IS NULL  OR (CAST(pt.percent_of_ASH AS VARCHAR(15))) = ''  THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.self_heating_properties_flag IS NULL OR pt.self_heating_properties_flag = '' THEN 1 ELSE 0 END)

				  --+	(CASE WHEN ftr.bitumen_asphalt_tar_flag IS NULL THEN 1 ELSE 0 END)
				 -- +	(CASE WHEN ftr.bitumen_asphalt_tar_ppm IS NULL THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.centrifuge_prior_to_shipment_flag IS NULL THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.fuel_oxygenates_flag IS NULL THEN 1 ELSE 0 END)
				  +	(CASE WHEN pt.surfactants_flag IS NULL THEN 1 ELSE 0 END)


		    ) AS sum_of_nulls
			From ProfileThermal AS pt
			Where 
			pt.profile_id =  @profile_id)


			IF @ValidColumnNullCount != 0 
			 BEGIN
			 print '1'
			   SET @ProfileStatusFlag = 'P'
			 END

			--SELECT petroleum_refining_F037_flag=odor_type_other,@odor_other_desc=odor_other_desc,@handling_issue=handling_issue,@handling_issue_desc=handling_issue_desc FROM FormWCR WHERE form_id = @formid

			DECLARE @petroleum_refining_F037_flag CHAR(1)
			DECLARE @petroleum_refining_F038_flag CHAR(1)
			DECLARE @petroleum_refining_K048_flag CHAR(1)
			DECLARE @petroleum_refining_K049_flag CHAR(1)
			DECLARE @petroleum_refining_K050_flag CHAR(1)
			DECLARE @petroleum_refining_K051_flag CHAR(1)
			DECLARE @petroleum_refining_K052_flag CHAR(1)
			DECLARE @petroleum_refining_K169_flag CHAR(1)
			DECLARE @petroleum_refining_K170_flag CHAR(1)
			DECLARE @petroleum_refining_K171_flag CHAR(1)
			DECLARE @petroleum_refining_K172_flag CHAR(1)
			DECLARE @petroleum_refining_no_waste_code_flag CHAR(1)
			DECLARE @gen_process VARCHAR(MAX)
			DECLARE @non_friable_debris_gt_2_inch_flag CHAR(1)
			DECLARE @non_friable_debris_gt_2_inch_ppm FLOAT
			DECLARE @bitumen_asphalt_tar_flag CHAR(1)
			DECLARE @bitumen_asphalt_tar_ppm FLOAT
			DECLARE @fuel_oxygenates_flag CHAR(1)

			DECLARE @oxygenates_other_flag CHAR(1)
			DECLARE @oxygenates_ppm FLOAT

			DECLARE @thermalCount INT
			
		--	SELECT @petroleum_refining_F037_flag=petroleum_refining_F037_flag,@petroleum_refining_F038_flag=petroleum_refining_F038_flag,@petroleum_refining_K048_flag=petroleum_refining_K048_flag,@petroleum_refining_K049_flag=petroleum_refining_K049_flag,@petroleum_refining_K050_flag=petroleum_refining_K050_flag,@petroleum_refining_K051_flag=petroleum_refining_K051_flag,@petroleum_refining_K052_flag=petroleum_refining_K052_flag,@petroleum_refining_K169_flag=petroleum_refining_K169_flag,@petroleum_refining_K170_flag=petroleum_refining_K170_flag,@petroleum_refining_K171_flag=petroleum_refining_K171_flag,@petroleum_refining_K172_flag=petroleum_refining_K172_flag,@gen_process=gen_process From FormThermal Where form_id =  @formid and revision_id = @revision_ID
			SELECT @bitumen_asphalt_tar_ppm=bitumen_asphalt_tar_ppm,  @bitumen_asphalt_tar_flag= bitumen_asphalt_tar_flag, @oxygenates_ppm=oxygenates_ppm,@oxygenates_other_flag=oxygenates_other_flag,@fuel_oxygenates_flag=fuel_oxygenates_flag,@non_friable_debris_gt_2_inch_ppm = non_friable_debris_gt_2_inch_ppm, @non_friable_debris_gt_2_inch_flag =non_friable_debris_gt_2_inch_flag , @petroleum_refining_no_waste_code_flag=petroleum_refining_no_waste_code_flag,@gen_process=gen_process From ProfileThermal Where profile_id =  @profile_id
			
			
			SET @thermalCount = (SELECT  (
			    	(CASE WHEN  petroleum_refining_F037_flag IS NULL OR petroleum_refining_F037_flag = '' OR petroleum_refining_F037_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_F038_flag IS NULL OR petroleum_refining_F038_flag = '' OR petroleum_refining_F038_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K048_flag IS NULL OR petroleum_refining_K048_flag = '' OR petroleum_refining_K048_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K049_flag IS NULL OR petroleum_refining_K049_flag = '' OR petroleum_refining_K049_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K050_flag IS NULL OR petroleum_refining_K050_flag = '' OR petroleum_refining_K050_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K051_flag IS NULL OR petroleum_refining_K051_flag = '' OR petroleum_refining_K051_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K052_flag IS NULL OR petroleum_refining_K052_flag = '' OR petroleum_refining_K052_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K169_flag IS NULL OR petroleum_refining_K169_flag = '' OR petroleum_refining_K169_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K170_flag IS NULL OR petroleum_refining_K170_flag = '' OR petroleum_refining_K170_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K171_flag IS NULL OR petroleum_refining_K171_flag = '' OR petroleum_refining_K171_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  petroleum_refining_K172_flag IS NULL OR petroleum_refining_K172_flag = '' OR petroleum_refining_K172_flag='F' THEN 0 ELSE 1 END)		
				  +	(CASE WHEN  petroleum_refining_no_waste_code_flag IS NULL OR petroleum_refining_no_waste_code_flag = '' OR petroleum_refining_no_waste_code_flag='F' THEN 0 ELSE 1 END)		 
		    ) AS sum_of_thermalnulls
			From ProfileThermal
			Where 
			profile_id =  @profile_id)	

			IF @thermalCount = 0
			   BEGIN
			   print '2'
			      SET @ProfileStatusFlag = 'P'
			   END
			ELSE
			 BEGIN 
			   IF @petroleum_refining_no_waste_code_flag = 'T'
				BEGIN
				  IF @gen_process = '' OR @gen_process IS NULL
				   BEGIN
				   print '3'
						SET @ProfileStatusFlag = 'P'
				   END
                END
			 END

          --- Physical State 
		 --  DECLARE @physicalStateCount INT ;
		 --  SET @physicalStateCount =  (SELECT  (
		 --           (CASE WHEN consistency_solid IS NULL OR consistency_solid = '' OR consistency_solid = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_dust IS NULL OR consistency_dust = '' OR consistency_dust = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_debris IS NULL OR consistency_debris = '' OR consistency_debris = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_sludge IS NULL OR consistency_sludge = '' OR consistency_sludge = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_gas_aerosol IS NULL OR consistency_gas_aerosol = '' OR consistency_gas_aerosol = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_varies IS NULL OR consistency_varies = '' OR consistency_varies = 'F' THEN 0 ELSE 1 END)
			--	  +	(CASE WHEN consistency_liquid IS NULL OR consistency_liquid = '' OR consistency_liquid = 'F' THEN 0 ELSE 1 END)
   --         ) AS sum_of_phyStsnulls
			--From ProfileLab
			--Where 
			--profile_id =  @profile_id)	
           
		 --  IF @physicalStateCount = 0
			--   BEGIN
			--   print '4'
			--      SET @ProfileStatusFlag = 'P'
			--   END

		 --- Contains Non-Friable Debris Material > 2-inch size
		  IF @non_friable_debris_gt_2_inch_flag = 'T'
		   BEGIN
            IF @non_friable_debris_gt_2_inch_ppm IS NULL OR CAST (@non_friable_debris_gt_2_inch_ppm AS varchar(15)) = '' 
             BEGIN 
			 print '5'
			  SET @ProfileStatusFlag = 'P'
			 END
		   END

		-- Contains Bitumen / Asphalt / Tar > 1% (wt.)
		  IF   @bitumen_asphalt_tar_flag IS NULL OR @bitumen_asphalt_tar_flag = ''
		   BEGIN
		   print '6'
		    SET @ProfileStatusFlag = 'P' 
		   END
		  ELSE
		    IF @bitumen_asphalt_tar_flag = 'T'
		     BEGIN
			  IF @bitumen_asphalt_tar_ppm IS NULL OR CAST (@bitumen_asphalt_tar_ppm AS VARCHAR(15)) = ''
			    BEGIN
				print '7'
				     SET @ProfileStatusFlag = 'P' 
				END
			 END


         -- Contains fuel oxygenates?

		 IF @fuel_oxygenates_flag IS NULL OR @fuel_oxygenates_flag = ''
		   BEGIN
		   print '8'
		      SET @ProfileStatusFlag = 'P' 
		   END
		ELSE IF @fuel_oxygenates_flag='T' 
		  BEGIN
		   DECLARE @oxygenCount INT
		   SET @oxygenCount = (SELECT  
		        (
			    	(CASE WHEN  oxygenates_MTBE_flag IS NULL OR oxygenates_MTBE_flag = '' OR oxygenates_MTBE_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  oxygenates_ethanol_flag IS NULL OR oxygenates_ethanol_flag = '' OR oxygenates_ethanol_flag='F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN  oxygenates_other_flag IS NULL OR oxygenates_other_flag = '' OR oxygenates_other_flag='F' THEN 0 ELSE 1 END)
			    ) AS sum_of_thermalnulls
			From ProfileThermal
			Where 
			profile_id =  @profile_id)

			IF @oxygenCount = 0 
			 BEGIN
			 print '9'
			   SET @ProfileStatusFlag = 'P' 
			 END
			ELSE
			  BEGIN
			   IF @oxygenates_other_flag = 'T'
			    BEGIN
			     IF CAST( @oxygenates_ppm AS varchar(15)) = ''
				  BEGIN
				  print '10'
				    SET @ProfileStatusFlag = 'P' 
				  END
				END
			  END
		  
		  END

	  IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='TL'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'TL',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'TL'
		END

       
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Thermal] TO COR_USER;
GO