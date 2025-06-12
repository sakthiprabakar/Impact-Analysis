USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Validate_Section_D]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Section_D]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID int
AS



/* ******************************************************************

	Updated By		: Vinoth D
	Updated On		: 22nd may 2024
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_D]
	Ticket			: Task 87583: [Change Request] Section D3 & D6 Validation Updates

	Procedure to validate Section D required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_D] @form_id,@revision_ID
 EXEC [sp_Validate_Section_D] 460064, 1
 EXEC [sp_Validate_Section_D] -1129654, 1
****************************************************************** */

--declare 	@formid INT=459957,
--	@Revision_ID int=1

BEGIN
	DECLARE @ValidColumnNullCount INTEGER,@TotalValidColumn INTEGER,@Checking INTEGER;

	DECLARE @SectionType VARCHAR(50),@comp_description VARCHAR(50),@odor_other_desc VARCHAR(50),@handling_issue_desc VARCHAR (MAX);
--	DECLARE @Revision_ID INTEGER;

	DECLARE @comp_typical_pct FLOAT,@comp_from_pct FLOAT,@comp_to_pct FLOAT,@total_typical_pct FLOAT,@total_to_pct FLOAT;

	DECLARE @odor CHAR(1),@odor_type_ammonia CHAR(1),@odor_type_amines CHAR(1),@odor_type_mercaptans CHAR(1),
	@odor_type_sulfur CHAR(1),@odor_type_organic_acid CHAR(1),@odor_type_other CHAR (1),@consistency_solid CHAR (1),
	@consistency_dust CHAR (1),@consistency_debris CHAR (1),@consistency_sludge CHAR (1),@consistency_liquid CHAR (1),
	@consistency_gas_aerosol CHAR (1),@consistency_varies CHAR (1),@paint_filter_solid_flag CHAR (1),@ph_lte_2 CHAR (1),
	@ph_gt_2_lt_5 CHAR (1),@ph_gte_5_lte_10 CHAR (1),@ph_gt_10_lt_12_5 CHAR (1),@ph_gte_12_5 CHAR (1),@ignitability_lt_90 CHAR(1),
	@ignitability_90_139 CHAR (1),@ignitability_140_199 CHAR(1),@ignitability_gte_200 CHAR (1),@ignitability_does_not_flash CHAR (1),
	@ignitability_flammable_solid CHAR (1),@color CHAR (1),@liquid_phase CHAR (1),@incidental_liquid_flag CHAR (1),
	@handling_issue CHAR (1),@SectionDStatus char(1);
	
	DECLARE @gnitability_compare_temperature INT, @oderCount INT, @phyCount INT, @filterCount INT, @phCount INT,
	@OdorStrengthType INT, @fpCount INT;

	SET @SectionType = 'SD'
	SET @SectionDStatus = 'Y'
	SET @TotalValidColumn = 6

	-- Validate the Physical Description, PCT, Min and Max value
	SELECT @total_typical_pct=SUM(ISNULL(comp_typical_pct,0)),@total_to_pct=SUM(ISNULL(comp_to_pct,0)) FROM  FormXWCRComposition 
					WHERE form_id=@formid and revision_id=@Revision_ID;
	IF NOT EXISTS (SELECT form_id FROM FormXWCRComposition where form_id = @formid AND revision_id = @Revision_ID) 
	BEGIN
		SET @SectionDStatus = 'P'
	END
	ELSE
	BEGIN
		IF(EXISTS
		    (SELECT form_id
					FROM  FormXWCRComposition 
					WHERE form_id=@formid and revision_id=@Revision_ID
					AND
					(
						(
							 ISNULL(comp_description,'')='' AND ISNULL(comp_from_pct,0)=0 
							 AND ISNULL(comp_to_pct,0)=0 AND ISNULL(comp_typical_pct,0)=0
							 --'Check all value should not be empty'
						) 
						OR
						(
							 isnull(comp_description,'')=''
							 --'Physical Description should not be empty'
						)
						OR
						(
							  ISNULL(comp_from_pct,0)>0 AND  ISNULL(comp_to_pct,0)=0 
							  --'max value should not be empty'
						)
						OR
						(
							   ISNUMERIC(comp_from_pct)=0 and (ISNULL(comp_to_pct,0)>0)
							   --'min value should not be empty'
						)
						OR
						(
							   ISNULL(comp_from_pct,0) > ISNULL(comp_to_pct,0)
							   --'min value should not be greater than maximum value'
						)
						OR
						(
							   ISNULL(comp_description,'')<>'' AND ISNULL(comp_from_pct,0)=0 
							   AND ISNULL(comp_to_pct,0)=0 AND isnull(comp_typical_pct,0)=0
							   --'Typical,Min,Max should not be empty'
						)
						--OR
						--(
						--	   SUM(comp_typical_pct) < 100 AND SUM(comp_to_pct) < 100
						--	   --'Typical,Max total not 100'
						--)
					)
		   )
		)
		BEGIN
		    SET @SectionDStatus = 'P'
		END
		ELSE IF  (( @total_typical_pct < 100) AND (@total_to_pct < 100))
			BEGIN
				SET @SectionDStatus = 'P'
				--PRINT 'Typical,Max total not 100'
			END
	END

	SELECT @odor=odor_strength,@odor_type_ammonia = odor_type_ammonia,@odor_type_amines = odor_type_amines,
		@consistency_liquid = consistency_liquid,@gnitability_compare_temperature = ignitability_compare_temperature,
		@odor_type_mercaptans = odor_type_mercaptans,@consistency_solid = consistency_solid,@consistency_dust = consistency_dust,
		@odor_type_sulfur = odor_type_sulfur,@odor_type_organic_acid = odor_type_organic_acid,@consistency_debris = consistency_debris,
		@odor_type_other=odor_type_other,@odor_other_desc=odor_other_desc,@paint_filter_solid_flag = paint_filter_solid_flag,
		@handling_issue=handling_issue,@handling_issue_desc=handling_issue_desc ,@ph_gt_10_lt_12_5 =ph_gt_10_lt_12_5,
		@consistency_varies = consistency_varies,@ph_lte_2 = ph_lte_2,@ph_gt_2_lt_5 = ph_gt_2_lt_5,
		@ph_gte_5_lte_10 =ph_gte_5_lte_10,@ph_gte_12_5 =ph_gte_12_5,@consistency_gas_aerosol = consistency_gas_aerosol,
		@ignitability_lt_90 = ignitability_lt_90,@ignitability_90_139 = ignitability_90_139,
		@ignitability_140_199 =ignitability_140_199,@ignitability_gte_200 = ignitability_gte_200,
		@ignitability_does_not_flash = ignitability_does_not_flash,@consistency_sludge = consistency_sludge,
		@ignitability_flammable_solid = ignitability_flammable_solid,@color =color, @liquid_phase = liquid_phase,
		@incidental_liquid_flag =incidental_liquid_flag
		FROM FormWCR 
		WHERE form_id = @formid and revision_id = @Revision_ID


		SET @ValidColumnNullCount = (CASE WHEN (ISNULL(@odor,'')='') THEN 1 ELSE 0 END)
			+ (CASE WHEN (ISNULL(@color,'')='') THEN 1 ELSE 0 END)
			+ (CASE WHEN ((@consistency_liquid='T' OR @consistency_sludge = 'T' or @consistency_varies = 'T' ) AND (ISNULL(@liquid_phase,'')='' or @liquid_phase = 'F')) THEN 1 ELSE 0 END)				
			+ (CASE WHEN (ISNULL(@paint_filter_solid_flag,'')='') THEN 1 ELSE 0 END)		
			+ (CASE WHEN (@paint_filter_solid_flag='T' AND (ISNULL(@incidental_liquid_flag,'')='')) THEN 1 ELSE 0 END)				
			--+ (CASE WHEN (ignitability_compare_symbol IS NULL OR ignitability_compare_symbol='') THEN 1 ELSE 0 END)

		IF (@ValidColumnNullCount > 0)
			BEGIN
				SET @SectionDStatus = 'P'
			END

		SET @oderCount = (CASE WHEN isnull(@odor_type_ammonia, '')  = '' OR @odor_type_ammonia ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@odor_type_amines, '') = '' OR @odor_type_amines ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@odor_type_mercaptans, '') = '' OR @odor_type_mercaptans ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@odor_type_sulfur, '') = '' OR @odor_type_sulfur ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@odor_type_organic_acid, '') = '' OR @odor_type_organic_acid ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@odor_type_other, '') = '' OR @odor_type_other ='F' THEN 0 ELSE 1 END)
			

		IF ((@odor in ('S','R') AND @oderCount = 0) OR (@odor_type_other = 'T' AND (ISNULL(@odor_other_desc,'') = '')))
			BEGIN
				SET @SectionDStatus = 'P'	
			END
		

		SET @phyCount = (CASE WHEN isnull(@consistency_solid, '')  = '' OR @consistency_solid ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_dust, '')  = '' OR @consistency_dust ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_debris, '')  = '' OR @consistency_debris ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_sludge, '')  = '' OR @consistency_sludge ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_liquid, '')  = '' OR @consistency_liquid ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_gas_aerosol, '')  = '' OR @consistency_gas_aerosol ='F' THEN 0 ELSE 1 END)
			+ (CASE WHEN isnull(@consistency_varies, '')  = '' OR @consistency_varies ='F' THEN 0 ELSE 1 END)
			
		IF (@phyCount = 0)
			BEGIN
				SET @SectionDStatus = 'P'
			END	 

			--Paint filter
			
		SET @filterCount = (CASE WHEN @consistency_solid = 'T' AND (@consistency_liquid = '' OR @consistency_liquid = 'F') AND @paint_filter_solid_flag = 'F' THEN 1 ELSE 0 END)
			+(CASE WHEN @consistency_liquid = 'T' AND (@consistency_solid = '' OR @consistency_solid = 'F') AND @paint_filter_solid_flag = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @consistency_solid = 'T' AND @paint_filter_solid_flag = '' THEN 1 ELSE 0 END)
			+(CASE WHEN @consistency_liquid = 'T' AND @paint_filter_solid_flag = '' THEN 1 ELSE 0 END)
			+(CASE WHEN @consistency_liquid = 'T' AND @consistency_solid = 'T' AND @paint_filter_solid_flag = '' THEN 1 ELSE 0 END)
				
		IF (@filterCount > 0)
			BEGIN
				SET @SectionDStatus = 'P'
			END

		SET @phCount = (CASE WHEN ISNULL(@ph_lte_2, '')  = '' OR @ph_lte_2 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN ISNULL(@ph_gt_2_lt_5, '')  = '' OR @ph_gt_2_lt_5 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN ISNULL(@ph_gte_5_lte_10, '')  = '' OR @ph_gte_5_lte_10 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN ISNULL(@ph_gt_10_lt_12_5, '')  = '' OR @ph_gt_10_lt_12_5 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN ISNULL(@ph_gte_12_5, '')  = '' OR @ph_gte_12_5 ='F' THEN 1 ELSE 0 END)
				
		IF (@phCount = 5)
			BEGIN
				SET @SectionDStatus = 'P'
			END

		--Odor strength type
		SET @OdorStrengthType = (CASE WHEN @odor_type_ammonia = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @odor_type_amines = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @odor_type_mercaptans = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @odor_type_sulfur = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @odor_type_organic_acid = 'T' THEN 1 ELSE 0 END)
			+(CASE WHEN @odor_type_other = 'T' THEN 1 ELSE 0 END)

		IF ((@OdorStrengthType > 0) AND (@odor = 'N' OR @odor = ''))
			BEGIN
				SET @SectionDStatus = 'P'	    
			END
			
			
          --- FLASH POINT
		SET @fpCount =(CASE WHEN isnull(@ignitability_lt_90, '')  = '' OR @ignitability_lt_90 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN isnull(@ignitability_90_139, '')  = '' OR @ignitability_90_139 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN isnull(@ignitability_140_199, '')  = '' OR @ignitability_140_199 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN isnull(@ignitability_gte_200, '')  = '' OR @ignitability_gte_200 ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN isnull(@ignitability_does_not_flash, '')  = '' OR @ignitability_does_not_flash ='F' THEN 1 ELSE 0 END)
			+(CASE WHEN isnull(@ignitability_flammable_solid, '')  = '' OR @ignitability_flammable_solid ='F' THEN 1 ELSE 0 END)

		IF ((@fpCount = 6) AND (ISNULL(@gnitability_compare_temperature,'')='' ))
			BEGIN	
				SET @SectionDStatus = 'P'		
			END
			  --print 'Flash Point' + @SectionDStatus
		ELSE IF(@handling_issue <> 'T' AND @handling_issue <> 'F')
			BEGIN
				SET @SectionDStatus = 'P'
			END
        ELSE IF (@handling_issue = 'T' AND ISNULL(@handling_issue_desc,'') = '')
			BEGIN
				SET @SectionDStatus = 'P'
			END
			
		SET @Checking = (SELECT COUNT(FORM_ID) 
							FROM FormSectionStatus 
							WHERE FORM_ID = @formid AND revision_id=@Revision_ID AND SECTION = 'SD')

		IF @Checking < 1 
			BEGIN
				INSERT INTO FormSectionStatus 
				VALUES (@formid,@Revision_ID,'SD',@SectionDStatus,GETDATE(),1,GETDATE(),1,1)
			END
		ELSE 
			BEGIN
				UPDATE FormSectionStatus SET section_status = @SectionDStatus 
					WHERE FORM_ID = @formid and revision_id = @Revision_ID AND SECTION = 'SD'
			END



END


GO
GRANT EXECUTE ON [dbo].[sp_Validate_Section_D] TO COR_USER;
GO