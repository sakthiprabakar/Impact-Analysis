USE plt_ai;
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_Validate_Section_E];
GO

CREATE PROCEDURE [dbo].[sp_Validate_Section_E]
    @formid INT,
    @Revision_ID INT
AS
BEGIN 

/* ******************************************************************
        Updated By       : Monish
        Updated On       : 30th NOV 2022
        Type            : Stored Procedure
        Object Name     : [sp_Validate_Section_E]
        Updated By      : Senthilkumar I
        Updated On      : 28th Feb 2025
        Ticket          : DE38160
        Change          : texas_waste_material_type condition U to A changed
        Procedure to validate Section E required fields and update the status of the section.

        Inputs:    
            @formid
            @revision_ID

        Sample Execution:
            EXEC [sp_Validate_Section_E] @form_id, @revision_ID;
            EXEC [sp_Validate_Section_E] 460236, 1;
            EXEC [sp_Validate_Section_E] 579573, 1;
            EXEC [sp_Validate_Section_E] 710450, 1;
    ****************************************************************** */
    DECLARE @FormStatusFlag CHAR(1) = 'Y';

    -- Temporary Tables
    SELECT 
        form_id, revision_id, PA_residual_waste_flag, copy_source, 
        texas_waste_material_type, RCRA_waste_code_flag, rcra_exempt_flag, 
        rcra_exempt_reason, state_waste_code_flag, cyanide_plating, 
        info_basis_knowledge, info_basis_analysis, info_basis_msds
    INTO #tempFormWCR
    FROM FormWCR 
    WHERE form_id = @formid AND revision_id = @Revision_ID;

    SELECT 
        form_id, revision_id, specifier, waste_code_uid, waste_code
    INTO #tempFormXWasteCode
    FROM FormXWasteCode  
    WHERE form_id = @formid AND revision_id = @Revision_ID;

    -- Check Pennsylvania Residual Waste
    DECLARE @PA_residual_waste_flag_count INT, @PA_Waste_code_count INT;
    SELECT @PA_residual_waste_flag_count = COUNT(PA_residual_waste_flag) 
    FROM #tempFormWCR WHERE PA_residual_waste_flag = 'T';

    IF (@PA_residual_waste_flag_count > 0)
    BEGIN
        SELECT @PA_Waste_code_count = COUNT(waste_code_uid) 
        FROM #tempFormXWasteCode WHERE specifier = 'PA';

        IF (@PA_Waste_code_count < 1)
        BEGIN
            SET @FormStatusFlag = 'P';
        END
    END

    -- Texas State Waste Code Validation
    DECLARE @Isnotamendrenewal CHAR(1), @Texascodecount INT;
    
    SELECT @Texascodecount = COUNT(waste_code_uid) 
    FROM #tempFormXWasteCode WHERE specifier = 'TX';

    SELECT @Isnotamendrenewal = 
        CASE 
            WHEN EXISTS(SELECT 1 FROM #tempFormWCR WHERE copy_source NOT IN ('amendment', 'renewal')) 
            THEN 'T' 
            ELSE 'F' 
        END;

    IF (
        (EXISTS (SELECT 1 FROM #tempFormWCR WHERE texas_waste_material_type IN ('I', 'N', 'A')) 
        AND @Isnotamendrenewal = 'T' AND @Texascodecount <= 0) 
        OR 
        (@Texascodecount > 0 AND NOT EXISTS (SELECT 1 FROM #tempFormWCR WHERE texas_waste_material_type IN ('I', 'N', 'A')))
    )
    BEGIN
        SET @FormStatusFlag = 'P';
    END

    -- RCRA Exempt Flag Validation
    DECLARE @RCRA_waste_code_flag CHAR(1), @rcra_exempt_flag CHAR(1), @rcra_exempt_reason VARCHAR(255),@PA_residual_waste_flag char(1);
    
    SELECT 
        @RCRA_waste_code_flag = RCRA_waste_code_flag,
        @rcra_exempt_flag = rcra_exempt_flag,
        @rcra_exempt_reason = rcra_exempt_reason,
		@PA_residual_waste_flag = PA_residual_waste_flag 
    FROM #tempFormWCR;

    IF (@RCRA_waste_code_flag = 'T')
    BEGIN 
        IF (@rcra_exempt_flag IS NULL OR @rcra_exempt_flag = '')
        BEGIN
            SET @FormStatusFlag = 'P';
        END
        IF (@rcra_exempt_flag = 'T' AND (@rcra_exempt_reason IS NULL OR @rcra_exempt_reason = ''))
        BEGIN
            SET @FormStatusFlag = 'P';
        END
    END

    -- Pennsylvania Residual Waste Flag Check
    IF(@PA_residual_waste_flag IS NULL OR @PA_residual_waste_flag = '')
    BEGIN
        SET @FormStatusFlag = 'P';
    END

    -- State Waste Codes Validation
    IF (EXISTS (SELECT 1 FROM #tempFormWCR WHERE state_waste_code_flag <> 'T') 
        AND NOT EXISTS (SELECT 1 FROM #tempFormXWasteCode WHERE specifier = 'state'))
    BEGIN
        SET @FormStatusFlag = 'P';
    END

    -- RCRA Waste Codes Validation
    IF (EXISTS (SELECT 1 FROM #tempFormWCR WHERE RCRA_waste_code_flag <> 'T') 
        AND NOT EXISTS (SELECT 1 FROM #tempFormXWasteCode WHERE specifier IN ('rcra_characteristic', 'rcra_listed')))
    BEGIN
        SET @FormStatusFlag = 'P';
    END

    -- Cyanide Plating Validation
    IF (EXISTS (SELECT 1 FROM #tempFormXWasteCode WHERE waste_code_uid IN 
                (SELECT waste_code_uid FROM WasteCode WHERE waste_code IN ('F006', 'F007', 'F008', 'F009', 'F012', 'F019'))
                AND specifier IN ('rcra_characteristic', 'rcra_listed')))
    BEGIN
        IF (EXISTS (SELECT 1 FROM #tempFormWCR WHERE cyanide_plating IS NULL OR cyanide_plating = ''))
        BEGIN
            SET @FormStatusFlag = 'P';
        END
    END

    -- Knowledge Source Validation
    IF (EXISTS (SELECT 1 FROM #tempFormWCR WHERE 
                (info_basis_knowledge IS NULL OR info_basis_knowledge <> 'T') 
                AND (info_basis_analysis IS NULL OR info_basis_analysis <> 'T') 
                AND (info_basis_msds IS NULL OR info_basis_msds <> 'T')))
    BEGIN
        SET @FormStatusFlag = 'P';
    END

    -- Chemical Composition Validation
     IF (EXISTS (SELECT 1 
            FROM FormXConstituent 
            WHERE form_id = @formid 
              AND revision_id = @Revision_ID  
              AND (cor_lock_flag IS NULL OR cor_lock_flag = '' OR cor_lock_flag <> 'T')
              AND ((TCLP_or_totals IS NULL OR TCLP_or_totals = '')
                   OR (unit IS NULL OR unit = '')
                   OR ((min_concentration IS NULL OR max_concentration IS NULL) AND typical_concentration IS NULL)
                   OR (max_concentration = 0 AND typical_concentration = 0)
                   OR (min_concentration > 0 AND max_concentration IS NULL)  -- Ensure max_concentration is not NULL when min_concentration > 0
                   OR (min_concentration > max_concentration))))
    BEGIN   
        SET @FormStatusFlag = 'P';
    END

    -- Update FormSectionStatus Table
    IF NOT EXISTS (SELECT COUNT(section) FROM FormSectionStatus WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SE')
    BEGIN
        INSERT INTO FormSectionStatus (form_id, revision_id, section, section_status, date_created, created_by, date_modified, modified_by, isActive) 
        VALUES (@formid, @Revision_ID, 'SE', @FormStatusFlag, GETDATE(), 1, GETDATE(), 1, 1);
    END
    ELSE 
    BEGIN
         UPDATE FormSectionStatus SET section_status = @FormStatusFlag, date_modified=GETDATE()
        WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'SE';
    END

    DROP TABLE #tempFormWCR;
    DROP TABLE #tempFormXWasteCode;
END;
GO

GRANT EXEC ON [dbo].[sp_Validate_Section_E] TO COR_USER;
GO
