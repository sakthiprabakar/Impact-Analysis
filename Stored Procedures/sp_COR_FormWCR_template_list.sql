
DROP PROCEDURE IF EXISTS [dbo].[sp_COR_FormWCR_template_list] 
GO 

CREATE PROCEDURE [dbo].[sp_COR_FormWCR_template_list]
    @page INT,
    @perpage INT,
    @Search VARCHAR(100) = '',
    @Sort VARCHAR(50)
AS
/* ******************************************************************
    Created By       : Ashothaman P
    Created On       : 26th Jun 2024
    Type             : Stored Procedure
    Ticket           : 89274
    Object Name      : [sp_COR_FormWCR_template_list]

	-- EXEC sp_COR_FormWCR_template_list @page = 1, @perpage = 10, @Search = '', @Sort = 'TemplateName'; 
    ***********************************************************************/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT;
	DECLARE @TotalRows INT;
    SET @Offset = (@page - 1) * @perpage;

    -- Create a temporary table to store the results
    CREATE TABLE #Templates (
        RowNum INT,
        form_id INT,
        revision_id INT,
        generator_id INT,
        generator_name VARCHAR(255),
        epa_id VARCHAR(12),
        customer_id INT,
        cust_name VARCHAR(255),
        display_status_uid INT,
        waste_common_name VARCHAR(255),
        date_created DATETIME,
        date_modified DATETIME,
        created_by VARCHAR(100),
        modified_by VARCHAR(100)
    );

    -- Insert the results with row numbers
    INSERT INTO #Templates
    SELECT 
   ROW_NUMBER() OVER (ORDER BY 
                CASE WHEN @Sort = 'Modified Date' THEN wcr.date_modified END DESC,
                CASE WHEN @Sort = 'Created Date' THEN wcr.date_created END DESC,
                CASE WHEN @Sort = 'Template Name' THEN wcr.waste_common_name END ASC) AS RowNum,
        wcr.form_id AS form_id, 
        wcr.revision_id AS revision_id, 
        g.generator_id AS generator_id, 
        g.generator_name AS generator_name, 
        wcr.epa_id,
        c.customer_id AS customer_id,
        c.cust_name AS cust_name,
        wcr.display_status_uid AS display_status_uid,
        wcr.waste_common_name AS waste_common_name,
        wcr.date_created AS date_created,
        wcr.date_modified,
        wcr.created_by,
        wcr.modified_by
    FROM FormWCRTemplate t
    INNER JOIN FormWCR wcr ON wcr.form_id = t.template_form_id
    INNER JOIN Generator g ON wcr.generator_id = g.generator_id
    INNER JOIN Customer c ON wcr.customer_id = c.customer_id
    WHERE 
        (@Search = '' OR 
        wcr.form_id LIKE '%' + @Search + '%' OR
        g.generator_id LIKE '%' + @Search + '%' OR
        g.generator_name LIKE '%' + @Search + '%' OR
		wcr.waste_common_name LIKE '%' + @Search + '%')AND t.status = 'A';

   
    SELECT @TotalRows = COUNT(*) FROM #Templates;

    -- Select the paginated results
    SELECT 
        @TotalRows AS TotalRows,
        RowNum,
        form_id,
        revision_id,
        generator_id,
        generator_name,
        epa_id,
        customer_id,
        cust_name,
        display_status_uid,
        waste_common_name,
        date_created,
        date_modified,
        created_by,
        modified_by
    FROM #Templates
    WHERE RowNum > @Offset AND RowNum <= @Offset + @perpage;

    -- Drop the temporary table
    DROP TABLE #Templates;
END;
GO 

GRANT EXEC ON [dbo].[sp_COR_FormWCR_template_list] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_template_list] TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_template_list] TO EQAI 
GO 