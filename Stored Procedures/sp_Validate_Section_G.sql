USE [PLT_AI]
GO

DROP PROC IF EXISTS sp_Validate_Section_G

GO

CREATE PROCEDURE  [dbo].[sp_Validate_Section_G]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID INT
AS


/* ******************************************************************

	Updated By		: Sathiyamoorthi
	Updated On		: 21th Sep 2022
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_G]


	Procedure to validate Section G required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_G] @form_id,@revision_ID
 EXEC [sp_Validate_Section_G] 600702, 1

****************************************************************** */

BEGIN
	DECLARE @FormStatusFlag varchar(1) = 'Y'
	
	DECLARE 
		@ccvocgr500 char(1),
		@waste_treated_after_generation CHAR(1),
		@waste_treated_after_generation_desc VARCHAR(255),
		@more_than_50_pct_debris char(1),
		@debris_separated char(1), 
		@debris_not_mixed_or_diluted varchar(1),
		@subject_to_mact_neshap char(1),
		@neshap_standards_part INT,		
		@neshap_subpart VARCHAR(255),
		@origin_refinery char(1),
		@generator_type_ID INT,
		@waste_water_flag char(1),
		@meets_alt_soil_treatment_stds char(1),
		@waste_meets_ldr_standards char(1),
		@rcracode_Count INT,
		@exceedsLDR_Count INT,
		@modified_by VARCHAR(60)

		SELECT 
		@ccvocgr500 = ccvocgr500,
		@waste_treated_after_generation=waste_treated_after_generation,
		@waste_treated_after_generation_desc=waste_treated_after_generation_desc,
		@more_than_50_pct_debris = more_than_50_pct_debris,
		@debris_separated=debris_separated, 
		@debris_not_mixed_or_diluted=debris_not_mixed_or_diluted,
		@subject_to_mact_neshap = subject_to_mact_neshap,
		@neshap_standards_part = neshap_standards_part,
		@neshap_subpart = neshap_subpart,
		@origin_refinery = origin_refinery,
		@generator_type_ID=generator_type_ID,
		@waste_water_flag=waste_water_flag,
		@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
		@waste_meets_ldr_standards=waste_meets_ldr_standards,
		@modified_by = modified_by 
		FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	--SELECT * INTO #tempFormXWasteCode FROM FormXWasteCode  WHERE form_id=@formid and revision_id=@Revision_ID 

	--1. Volatile Organic Concentration:
	IF(ISNULL(@ccvocgr500,'')='' )
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 2. Has the material been treated after the initial point of generation?	
	--IF(EXISTS(SELECT * FROM #tempFormWCR WHERE ISNULL(waste_treated_after_generation,'')='' OR waste_treated_after_generation='T' ))
	--BEGIN		
		--If 'T' THEN user must enter the Describe
		IF(@waste_treated_after_generation='T' AND ISNULL(@waste_treated_after_generation_desc,'')='')
		BEGIN
			SET @FormStatusFlag = 'P'
		END
	--END

	-- 3. If RCRA Hazardous AND exceeds LDR

	SET @rcracode_Count = (SELECT count(form_id) 
							FROM FormXWasteCode 
							WHERE form_id = @formid AND revision_id=@Revision_ID 
							AND (specifier = 'rcra_characteristic' OR specifier = 'rcra_listed'));
	SET @exceedsLDR_Count =(SELECT count(form_id) 
							FROM FormXConstituent AS ChemicalComposition 
							WHERE form_id = @formid and revision_id = @Revision_ID and exceeds_LDR='T')

	IF(((@generator_type_ID in (1,3) AND (@rcracode_Count>0)) OR @exceedsLDR_Count>0)
		AND
		(@waste_water_flag<>'N' AND @waste_water_flag<>'W' 
		AND @meets_alt_soil_treatment_stds<>'T'
		AND @more_than_50_pct_debris<>'T'
		AND @waste_meets_ldr_standards<>'T'))
	BEGIN
	 SET @FormStatusFlag = 'P'
	END

	-- 3. Alternative Treatment Standards for debris 40 CFR Part 268.2(g) & (h); >50% of waste is > 2.5 inch size (G3)

	IF(@more_than_50_pct_debris = 'T')
	BEGIN
		

		IF(@debris_separated<>'T' or @debris_not_mixed_or_diluted<>'T')
		BEGIN
			SET @FormStatusFlag = 'P'			
		END

	END

	-- 5. Is the site or waste/material, subject to NESHAP/MACT standard(s)?
	IF(@subject_to_mact_neshap='T')
	BEGIN				
		--If yes, please choose the applicable Part & NESHAP Subpart is Required
		IF(@neshap_standards_part NOT IN(61,62,63,0) OR @neshap_standards_part is NULL)
		BEGIN
			SET @FormStatusFlag = 'P'
		END

		IF  (@neshap_standards_part IN(61,62,63) AND ISNULL(@neshap_subpart,'')='')
		BEGIN
			SET @FormStatusFlag = 'P'
		END
	END

	/*6. Is the waste/material RCRA Hazardous containing Benzene and originating at a petroleum 
	refinery (SIC 2911), chemical manufacturing Plant (SIC 2800 through 2899) or Coke by-product recovery plant (SIC 3312)*/
	IF(ISNULL(@origin_refinery,'')='' )
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND SECTION ='SG'))
	BEGIN
		INSERT INTO FormSectionStatus 
		VALUES (@formid,@Revision_ID,'SG',@FormStatusFlag,getdate(),@modified_by,getdate(),@modified_by,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag 
		WHERE FORM_ID = @formid AND revision_id=@Revision_ID  AND SECTION = 'SG'
	END
	--DROP TABLE #tempFormXWasteCode 
END
GO

GRANT EXEC ON [dbo].[sp_Validate_Section_G] TO COR_USER;
GO