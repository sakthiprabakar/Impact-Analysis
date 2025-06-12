GO
DROP PROCEDURE IF EXISTS [sp_Validate_Section_E]
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Section_E]
		-- Add the parameters for the stored procedure here
		@formid INT,
		@Revision_ID INT
	AS
/* ******************************************************************

		Updated By		: Monish
		Updated On		: 30th NOV 2022
		Type			: Stored Procedure
		Object Name		: [sp_Validate_Section_E]


		Procedure to validate Section E required fields and Update the Status of section

	inputs 
	
		@formid
		@revision_ID



	Samples:
	 EXEC [sp_Validate_Section_E] @form_id,@revision_ID
	 EXEC [sp_Validate_Section_E] 460236, 1
	 EXEC [sp_Validate_Section_E] 579573, 1
	 EXEC [sp_Validate_Section_E] 710450, 1

****************************************************************** */
	BEGIN
		DECLARE @ValidColumnNullCount INTEGER;
		DECLARE @TotalValidColumn INTEGER; -- Based SELECT Column count
		DECLARE @SectionType VARCHAR;
		--DECLARE @Revision_ID INTEGER;
		DECLARE @FormStatusFlag varchar(1) = 'Y'


		SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
		SELECT * INTO #tempFormXWasteCode FROM FormXWasteCode  WHERE form_id=@formid and revision_id=@Revision_ID 


		--Check the Pennsylvania Residual Waste is checked 'T' and the state code is avaialble
		DECLARE @PA_residual_waste_flag_count INT 
		SELECT  @PA_residual_waste_flag_count = COUNT(PA_residual_waste_flag) 
			FROM #tempFormWCR 
			WHERE PA_residual_waste_flag = 'T'
		
		IF (@PA_residual_waste_flag_count > 0)
		BEGIN
			DECLARE @PA_Waste_code_count INT 
			SELECT @PA_Waste_code_count=COUNT(*) 
			FROM #tempFormXWasteCode WHERE specifier='PA'
			
			IF (@PA_Waste_code_count < 1)
			BEGIN
				SET @FormStatusFlag = 'P'
			END

		END

		-- 1. Texas State Waste Code:
		DECLARE @Isnotamendrenewal CHAR(1);
		DECLARE @Texascodecount INT;

		SET @Texascodecount = (SELECT COUNT(waste_code) FROM #tempFormXWasteCode WHERE  specifier = 'TX')
		SET @Isnotamendrenewal = (SELECT
		CASE WHEN (EXISTS(SELECT * FROM #tempFormWCR WHERE copy_source not in ('amendment','renewal')))THEN 'T' else 'F' END Isnotamendrenewal)		
		

			IF((EXISTS(SELECT * FROM #tempFormWCR WHERE  texas_waste_material_type in ('I','N','U')) 
			  AND (@Isnotamendrenewal='T' AND @Texascodecount <= 0))
				OR
				(@Texascodecount > 0 AND NOT EXISTS(SELECT * FROM #tempFormWCR WHERE  texas_waste_material_type in ('I','N','U'))))		
			BEGIN
				SET @FormStatusFlag = 'P'
			END

		
			--Rcra Exempt flag
			DECLARE @RCRA_waste_code_flag char(1), @PA_residual_waste_flag char(1);
			DECLARE	@rcra_exempt_flag CHAR(1);
			DECLARE @rcra_exempt_reason VARCHAR;

			SELECT @RCRA_waste_code_flag =  RCRA_waste_code_flag, 
		       @rcra_exempt_flag = rcra_exempt_flag, 
			   @rcra_exempt_reason = rcra_exempt_reason,
			   @PA_residual_waste_flag = PA_residual_waste_flag FROM #tempFormWCR

			IF(ISNULL(@RCRA_waste_code_flag,'') = 'T')
			BEGIN 
				IF(ISNULL(@rcra_exempt_flag,'') = '')
				BEGIN
					SET @FormStatusFlag = 'P'
				END
				IF(@rcra_exempt_flag='T' and ISNULL(@rcra_exempt_reason,'')='')
				BEGIN
				SET @FormStatusFlag = 'P'
				END
			END								

		
		 -- Pennsylvania Residual Waste Flag:
		 IF(ISNULL(@PA_residual_waste_flag,'')= '')
		 BEGIN
		    SET @FormStatusFlag = 'P'
		 END

		-- 2. State Waste Codes:
		IF(EXISTS(SELECT * 
					FROM #tempFormWCR 
					WHERE  ISNULL(state_waste_code_flag,'')<>'T') 
					AND NOT EXISTS(SELECT * 
									FROM #tempFormXWasteCode 
									WHERE specifier = 'state'))
		BEGIN
			SET @FormStatusFlag = 'P'
		END

		-- 3. RCRA Waste Codes:
		IF(EXISTS(SELECT * 
					FROM #tempFormWCR 
					WHERE  ISNULL(RCRA_waste_code_flag,'')<>'T') AND 
					NOT EXISTS(SELECT * 
								FROM #tempFormXWasteCode 
								WHERE (specifier = 'rcra_characteristic' or specifier = 'rcra_listed')))
		BEGIN
			SET @FormStatusFlag = 'P'
		END

		-- Check for 4. If F006-F009, F012, or F019, are Cyanides used in the process
		IF(EXISTS(SELECT * 
					FROM #tempFormXWasteCode 
					WHERE  waste_code_uid 
					IN(SELECT waste_code_uid 
						FROM WasteCode 
						WHERE waste_code IN('F006','F007','F008','F009','F012','F019')) 
						AND (specifier = 'rcra_characteristic' OR specifier='rcra_listed')))
		BEGIN
		  IF(EXISTS(SELECT * FROM #tempFormWCR WHERE cyanide_plating IS NULL or cyanide_plating=''))
		  BEGIN
			SET @FormStatusFlag = 'P'
		  END
		END

		-- 5. Knowledge is from
		IF(EXISTS(SELECT * FROM #tempFormWCR WHERE 
		(ISNULL(info_basis_knowledge, '') = '' OR  info_basis_knowledge <>'T') AND 
		(ISNULL(info_basis_analysis, '') = '' OR info_basis_analysis <>'T') AND 
		(ISNULL(info_basis_msds, '') = '' OR info_basis_msds <>'T')))
		BEGIN
			SET @FormStatusFlag = 'P'
		END


		-- 6. Chemical Composition		
	

		IF (EXISTS( SELECT * FROM FormXConstituent WHERE form_id=@formid AND revision_id=@Revision_ID  AND 
		(cor_lock_flag IS NULL OR cor_lock_flag='' or cor_lock_flag!='T')
		AND  ((TCLP_or_totals IS NULL OR TCLP_or_totals='')
							OR (unit IS NULL OR unit='')
							OR ((min_concentration IS NULL OR max_concentration IS NULL) AND typical_concentration IS NULL)
							OR (max_concentration = 0 AND typical_concentration = 0)
							OR (min_concentration > max_concentration))))
		BEGIN	
		
			PRINT 'Chemical compostion failed'
			SET @FormStatusFlag = 'P'			
		END

		-- Update the form status in FormSectionStatus table
		IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND SECTION ='SE'))
		BEGIN
			INSERT INTO FormSectionStatus 
			VALUES (@formid,@Revision_ID,'SE',@FormStatusFlag,getdate(),1,getdate(),1,1)
		END
		ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag 
			WHERE FORM_ID = @formid AND SECTION = 'SE'
		END

		DROP TABLE #tempFormWCR 
		DROP TABLE #tempFormXWasteCode 
	
END
GO

GRANT EXEC ON [dbo].[sp_Validate_Section_E] TO COR_USER;
GO