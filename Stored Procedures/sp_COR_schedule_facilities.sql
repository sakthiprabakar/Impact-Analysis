USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_COR_schedule_facilities]
GO

-- Create the procedure
CREATE PROCEDURE [dbo].[sp_COR_schedule_facilities]
    @profit_ctr_name NVARCHAR(255) = NULL,
    @web_userid NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    /*
    -- =============================================
    -- Created By:  Sathiyamoorthi M
    -- Create date: 18th Nov, 2024
    -- Description: Retrieving the Facility List for schedule
    -- =============================================
	-- exec sp_COR_schedule_facilities '','manand84'
    */

    -- Set default value for profit center name if NULL
    SET @profit_ctr_name = ISNULL(@profit_ctr_name, '');

    -- Create a temporary table to store results from sp_LookupProfitCenter
    CREATE TABLE #TempFacilityInfo (
        company_id INT,
        profit_ctr_id INT,
        profit_ctr_name NVARCHAR(255),
        city NVARCHAR(255),
        state NVARCHAR(50),
        state_name NVARCHAR(255),
        address_1 NVARCHAR(255),
        address_2 NVARCHAR(255),
        phone NVARCHAR(50),
        epa_id NVARCHAR(50),
        zip_code NVARCHAR(50),
        latitude FLOAT,
        longitude FLOAT
    );

    -- Insert results from sp_LookupProfitCenter into the temporary table
    INSERT INTO #TempFacilityInfo
    EXEC sp_LookupProfitCenter @profit_ctr_name, @web_userid;

    -- Select data excluding Beatty and Grandview facilities
    SELECT 
        company_id,
        profit_ctr_id,
        profit_ctr_name,
        city,
        state,
        state_name,
        address_1,
        address_2,
        phone,
        epa_id,
        zip_code,
        latitude,
        longitude
    FROM #TempFacilityInfo
    WHERE NOT EXISTS (
        SELECT 1
        FROM (VALUES (44, 0), (45, 0)) AS ExcludeFacs(company_id, profit_ctr_id)
        WHERE ExcludeFacs.company_id = #TempFacilityInfo.company_id 
          AND ExcludeFacs.profit_ctr_id = #TempFacilityInfo.profit_ctr_id
    )
    ORDER BY profit_ctr_name;

    -- Drop the temporary table
    DROP TABLE #TempFacilityInfo;

END;
GO

GRANT EXEC ON [dbo].[sp_COR_schedule_facilities] TO COR_USER;

GO