USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_Validate_Profile_Section_D]
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_D]
	@profile_id int

AS



/* ******************************************************************

	
	Updated By		: Sathiyamoorthi 
	Updated On		: 25th Sep 2024
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_D]
	Ticket			: 94413


	Requirement 94413: Express Renewal > Access to 'Express Renewal' Icon

inputs 
	
	@profile_id
	


Samples:
 EXEC [sp_Validate_Profile_Section_D] @profile_id
 EXEC [sp_Validate_Profile_Section_D] 569276
 --exec sp_Validate_Profile_Section_D 699442
****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	
	DECLARE @odor Char(1);
	DECLARE @odor_type_ammonia char(1);
	DECLARE @odor_type_amines char(1);
	DECLARE @odor_type_mercaptans char(1);
	DECLARE @odor_type_sulfur char(1);
	DECLARE @odor_type_organic_acid char(1);
	DECLARE @odor_type_other NVARCHAR;
	DECLARE @odor_other_desc NVARCHAR;
	DECLARE @paint_filter_solid_flag CHAR (1);
	DECLARE @ph_lte_2 CHAR (1);
	DECLARE @ph_gt_2_lt_5 CHAR (1);
	DECLARE @ph_gte_5_lte_10 CHAR (1);
	DECLARE @ph_gt_10_lt_12_5 CHAR (1);
	DECLARE @ph_gte_12_5 CHAR (1);
	DECLARE @ignitability_lt_90 CHAR(1);
	DECLARE @ignitability_90_139 CHAR (1);
	DECLARE @ignitability_140_199 CHAR(1);
	DECLARE @ignitability_gte_200 CHAR (1);
	DECLARE @ignitability_does_not_flash CHAR (1);
	DECLARE @ignitability_flammable_solid CHAR (1);
	DECLARE @incidental_liquid_flag CHAR (1);
	DECLARE @color CHAR (1);
	DECLARE @handling_issue NVARCHAR;
	DECLARE @handling_issue_desc NVARCHAR;
	DECLARE @SectionDStatus char(1);

	SET @SectionType = 'SD'
	SET @SectionDStatus = 'Y'

	SET @TotalValidColumn = 6

	-- Validate the Physical Description, PCT, Min and Max value
	IF (SELECT COUNT(*) FROM ProfileComposition where profile_id=@profile_id) < 1
	BEGIN
	
		SET @SectionDStatus = 'P'
	END
	ELSE
	BEGIN
		IF(select count(*) from  ProfileComposition where profile_id=@profile_id 
			and (comp_from_pct is null or comp_to_pct is null) AND comp_typical_pct  is null) > 0
	    BEGIN
		
		  SET @SectionDStatus = 'P'
		END
	END


			SELECT @odor=odor_strength,@odor_type_ammonia = odor_type_ammonia,@odor_type_amines = odor_type_amines,@odor_type_mercaptans = odor_type_mercaptans,@odor_type_sulfur = odor_type_sulfur
			,@odor_type_organic_acid = odor_type_organic_acid,@odor_type_other=odor_type_other,@color =color
			,@odor_type_other=odor_type_other,@odor_other_desc=odor_other_desc,@handling_issue=handling_issue,
			@handling_issue_desc=handling_issue_desc ,@ph_gt_10_lt_12_5 =ph_gt_10_lt_12_5,@incidental_liquid_flag =incidental_liquid_flag,
			@ph_lte_2 = ph_lte_2,@ph_gt_2_lt_5 = ph_gt_2_lt_5, @ph_gte_5_lte_10 =ph_gte_5_lte_10,@ph_gte_12_5 =ph_gte_12_5,
			@ignitability_lt_90 = ignitability_lt_90,@ignitability_90_139 = ignitability_90_139,@ignitability_140_199 =ignitability_140_199,
			@ignitability_gte_200 = ignitability_gte_200,@ignitability_does_not_flash = ignitability_does_not_flash,
			@ignitability_flammable_solid = ignitability_flammable_solid,@paint_filter_solid_flag = paint_filter_solid_flag
			FROM ProfileLab Where profile_id=@profile_id and type = 'A'		


			--Validate other fields in section D
	
			-- + (CASE WHEN odor_other_desc IS NULL THEN 1 ELSE 0 END)
				SET  @ValidColumnNullCount = (CASE WHEN (@odor IS NULL or @odor='') THEN 1 ELSE 0 END)
				+ (CASE WHEN (@color IS NULL or @color='') THEN 1 ELSE 0 END)
			    --+ (CASE WHEN ((@consistency_liquid='T' OR @consistency_sludge = 'T' ) AND (@liquid_phase IS NULL OR @liquid_phase='')) THEN 1 ELSE 0 END)				
			    + (CASE WHEN (@paint_filter_solid_flag IS NULL OR @paint_filter_solid_flag='') THEN 1 ELSE 0 END)		
				+ (CASE WHEN (@paint_filter_solid_flag='T' AND (@incidental_liquid_flag IS NULL OR @incidental_liquid_flag='')) THEN 1 ELSE 0 END)				
				--+ (CASE WHEN (ignitability_compare_symbol IS NULL OR ignitability_compare_symbol='') THEN 1 ELSE 0 END)


		IF (@ValidColumnNullCount > 0)
		BEGIN
		
			SET @SectionDStatus = 'P'
		END
			

			DECLARE @oderCount INT

			SET @oderCount = (CASE WHEN @odor_type_ammonia IS NULL OR @odor_type_ammonia ='F' OR @odor_type_ammonia ='' THEN 0 ELSE 1 END)
				+ (CASE WHEN @odor_type_amines IS NULL OR @odor_type_amines ='F' OR @odor_type_amines='' THEN 0 ELSE 1 END)
				+ (CASE WHEN @odor_type_mercaptans IS NULL OR @odor_type_mercaptans = 'F' OR @odor_type_mercaptans='' THEN 0 ELSE 1 END)
				+ (CASE WHEN @odor_type_sulfur IS NULL OR @odor_type_sulfur = 'F' OR @odor_type_sulfur='' THEN 0 ELSE 1 END)
				+ (CASE WHEN @odor_type_organic_acid IS NULL OR @odor_type_organic_acid = 'F' OR @odor_type_organic_acid='' THEN 0 ELSE 1 END)
				+ (CASE WHEN @odor_type_other IS NULL OR @odor_type_other = 'F' OR @odor_type_other='' THEN 0 ELSE 1 END)

			

			IF (@odor='S' OR @odor='R')
			 BEGIN
			   IF @oderCount = 0
				 BEGIN
				  SET @SectionDStatus = 'P'		
				 END
			    
			 END
			--print 'Odor Type ' + @SectionDStatus
			IF @odor_type_other = 'T' AND (@odor_other_desc = '' OR @odor_other_desc IS NULL)
				BEGIN
				SET @SectionDStatus = 'P'		
				END
		

		  --- PH COUNT
		  DECLARE @phCount int
		  SET @phCount = (CASE WHEN isnull(@ph_lte_2, '')  = '' OR @ph_lte_2 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ph_gt_2_lt_5, '')  = '' OR @ph_gt_2_lt_5 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ph_gte_5_lte_10, '')  = '' OR @ph_gte_5_lte_10 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ph_gt_10_lt_12_5, '')  = '' OR @ph_gt_10_lt_12_5 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ph_gte_12_5, '')  = '' OR @ph_gte_12_5 ='F' THEN 1 ELSE 0 END)	 
			
			IF @phCount = 5
			BEGIN
			
				SET @SectionDStatus = 'P'
			END

			--Odor strength type

			Declare @OdorStrengthType int
			set @OdorStrengthType = (case when @odor_type_ammonia = 'T' THEN 1 ELSE 0 END)
					 +	(case when @odor_type_amines = 'T' THEN 1 ELSE 0 END)
					 +	(case when @odor_type_mercaptans = 'T' THEN 1 ELSE 0 END)
					 +	(case when @odor_type_sulfur = 'T' THEN 1 ELSE 0 END)
					 +	(case when @odor_type_organic_acid = 'T' THEN 1 ELSE 0 END)
					 +	(case when @odor_type_other = 'T' THEN 1 ELSE 0 END)
					
					if @OdorStrengthType > 0
					Begin
					if @odor = 'N' or @odor = ''
					Begin
					SET @SectionDStatus = 'P'		
				 END
			    
			 END
			
          --- FLASH POINT
		  DECLARE @fpCount int
		  SET @fpCount = (CASE WHEN isnull(@ignitability_lt_90, '')  = '' OR @ignitability_lt_90 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ignitability_90_139, '')  = '' OR @ignitability_90_139 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ignitability_140_199, '')  = '' OR @ignitability_140_199 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ignitability_gte_200, '')  = '' OR @ignitability_gte_200 ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ignitability_does_not_flash, '')  = '' OR @ignitability_does_not_flash ='F' THEN 1 ELSE 0 END)
						+ (CASE WHEN isnull(@ignitability_flammable_solid, '')  = '' OR @ignitability_flammable_solid ='F' THEN 1 ELSE 0 END)	 

			IF @fpCount = 6 
			  BEGIN

				DECLARE @gnitability_compare_temperature int
				SELECT @gnitability_compare_temperature = ignitability_compare_temperature from ProfileLab 
							Where profile_id =  @profile_id 
				IF @gnitability_compare_temperature is NULL or @gnitability_compare_temperature=''
				BEGIN
				     SET @SectionDStatus = 'P'
				END
			  END
			  --print 'Flash Point' + @SectionDStatus
		  IF(@handling_issue <> 'T' AND @handling_issue <> 'F')
		  BEGIN
			SET @SectionDStatus = 'P'
		  END

          IF @handling_issue = 'T'
		  BEGIN
			IF @handling_issue_desc = '' AND @handling_issue_desc IS NULL
			BEGIN
			
				SET @SectionDStatus = 'P'
			END		  
		  END
			
			--print 'Handling ' + @SectionDStatus


DECLARE @Checking INTEGER;

SET @Checking = (SELECT COUNT(*) FROM ProfileSectionStatus WHERE PROFILE_ID = @profile_id AND SECTION = 'SD')

IF @Checking < 1 
		BEGIN
		  INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SD',@SectionDStatus,getdate(),1,getdate(),1,1)
		END
	ELSE 
	   BEGIN
	     UPDATE ProfileSectionStatus SET section_status = @SectionDStatus WHERE PROFILE_ID = @profile_id AND SECTION = 'SD'
	   END

END


GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_D] TO COR_USER;
GO