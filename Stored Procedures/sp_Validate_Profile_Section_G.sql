USE [PLT_AI]
GO

DROP PROC IF EXISTS sp_Validate_Profile_Section_G
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_G]
	@profile_id INT
/* ******************************************************************

	Updated By		: Sathiyamoorthi
	Updated On		: 21th Sep 2022
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_G]


	Procedure to validate Section G required fields and Update the Status of section

inputs 
	
	@profile_id

Samples:
 EXEC [sp_Validate_Profile_Section_G] @profile_id=600702
 EXEC [sp_Validate_Profile_Section_G] 600702

****************************************************************** */
AS
BEGIN
	DECLARE @ProfileStatusFlag VARCHAR(1) = 'Y';

	DECLARE 
		@ccvocgr500 CHAR(1),
		@waste_treated_after_generation CHAR(1),
		@waste_treated_after_generation_desc VARCHAR(255),
		@more_than_50_pct_debris CHAR(1),
		@debris_separated CHAR(1), 
		@debris_not_mixed_or_diluted VARCHAR(1),
		@subject_to_mact_neshap CHAR(1),
		@neshap_standards_part INT,		
		@neshap_subpart VARCHAR(255),
		@origin_refinery CHAR(1),
		@generator_type_ID INT,
		@waste_water_flag CHAR(1),
		@meets_alt_soil_treatment_stds CHAR(1),
		@waste_meets_ldr_standards CHAR(1),
		@rcracode_Count INT,
		@exceedsLDR_Count INT,
		@modified_by VARCHAR(60)


		SELECT
		@ccvocgr500 = pl.ccvocgr500,
		@waste_treated_after_generation = p.waste_treated_after_generation,
		@waste_treated_after_generation_desc = p.waste_treated_after_generation_desc,
		@more_than_50_pct_debris = pl.more_than_50_pct_debris,
		@debris_separated = p.debris_separated,
		@debris_not_mixed_or_diluted = p.debris_not_mixed_or_diluted,
		@subject_to_mact_neshap = pl.subject_to_mact_neshap,
		@neshap_standards_part = pl.neshap_standards_part,
		@neshap_subpart = pl.neshap_subpart,
		@origin_refinery = p.origin_refinery,
		@generator_type_ID = g.generator_type_ID,
		@waste_water_flag = p.waste_water_flag,
		@meets_alt_soil_treatment_stds = pl.meets_alt_soil_treatment_stds,
		@waste_meets_ldr_standards = p.waste_meets_ldr_standards,
		@modified_by = p.modified_by
		FROM Profile p
		JOIN ProfileLab AS pl ON pl.profile_id=p.profile_id and [type] = 'A'
		JOIN Generator AS g ON   p.generator_id =  g.generator_id  
		WHERE p.profile_id=@profile_id

		--1. Volatile Organic Concentration:
		IF(ISNULL(@ccvocgr500,'')='' )
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END

		-- 2. Has the material been treated after the initial point of generation?	
		--If 'T' THEN user must enter the Describe
		IF(@waste_treated_after_generation='T' AND ISNULL(@waste_treated_after_generation_desc,'')='')
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END

		-- 3. If RCRA Hazardous AND exceeds LDR	
		SET @rcracode_Count = (SELECT COUNT(pw.waste_code_uid)
								FROM profilewastecode pw
								JOIN WasteCode wc ON pw.waste_code_uid = wc.waste_code_uid
								WHERE pw.profile_id = @profile_id AND pw.waste_code <> 'NONE'
								AND wc.[status] = 'A' AND wc.waste_code_origin = 'F' 
								AND wc.haz_flag = 'T' AND wc.waste_type_code IN ('L', 'C'))
		SET @exceedsLDR_Count = (SELECT COUNT(1) FROM ProfileConstituent WHERE profile_id=@profile_id  and (exceeds_LDR = 'T'))

		IF(((@generator_type_ID in (1,3) AND (@rcracode_Count>0)) OR @exceedsLDR_Count>0)
		AND
		(@waste_water_flag<>'N' AND @waste_water_flag<>'W' 
		AND @meets_alt_soil_treatment_stds<>'T'
		AND @more_than_50_pct_debris<>'T'
		AND @waste_meets_ldr_standards<>'T'))
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END

		-- 3. Alternative Treatment Standards for debris 40 CFR Part 268.2(g) & (h); >50% of waste is > 2.5 inch size (G3)

		IF(@more_than_50_pct_debris = 'T')
		BEGIN
			IF(@debris_separated<>'T' or @debris_not_mixed_or_diluted<>'T')
			BEGIN
				SET @ProfileStatusFlag = 'P'			
			END
		END

		-- 5. Is the site or waste/material, subject to NESHAP/MACT standard(s)?
		IF(@subject_to_mact_neshap='T')
		BEGIN				
		--If yes, please choose the applicable Part & NESHAP Subpart is Required
			IF(@neshap_standards_part NOT IN(61,62,63,0) OR @neshap_standards_part is NULL)
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END
			IF  (@neshap_standards_part IN(61,62,63) AND ISNULL(@neshap_subpart,'')='')
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END
		END

		/*6. Is the waste/material RCRA Hazardous containing Benzene and originating at a petroleum 
		refinery (SIC 2911), chemical manufacturing Plant (SIC 2800 through 2899) or Coke by-product recovery plant (SIC 3312)*/
		IF(ISNULL(@origin_refinery,'')='' )
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END


		-- Update the form status in FormSectionStatus table
		IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE PROFILE_ID =@profile_id AND SECTION ='SG'))
		BEGIN
			INSERT INTO ProfileSectionStatus 
			VALUES (@profile_id,'SG',@ProfileStatusFlag,GETDATE(),@modified_by,GETDATE(),@modified_by,1)
		END
		ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag 
			WHERE PROFILE_ID =@profile_id AND SECTION = 'SG'
		END

END


GO
GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_G] TO COR_USER;
GO

