USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_LookupProfitCenter]
GO
CREATE PROCEDURE [dbo].[sp_LookupProfitCenter]
    @profit_ctr_name VARCHAR(55) = NULL,
    @web_userid VARCHAR(100) = NULL
AS

/* 

-- =============================================
-- Updated By:  Sathiyamoorthi
-- Create date: 10th Jan, 2024
-- Description: for Retreiving the Facility List

-- Updated By:  Samson Mychael
-- Create date: 16th October, 2024
-- Description: for Retreiving the Facility List along with ZipCode,Latitude and Longitude

-- Updated By:  Samson Mychael
-- Create date: 30th October, 2024
-- Description: Modified filtering criteria to include facility name, city, state, and state 

-- Updated By:  Praveen Kumar
-- Ticket: US152562
-- Create date: 5th May, 2025
-- Description: Modified filtering criteria to include facility name, city, state, and state 

-- Updated By:  Praveen Kumar
-- Create date: 19th May, 2025
-- Description: Refactored sp_LookupProfitCenter to optimize input types, replace COALESCE, remove unnecessary TOP
-- =============================================

EXEC sp_LookupProfitCenter @profit_ctr_name='',@web_userid='nyswyn100'

 */

BEGIN
    SET NOCOUNT ON;

    IF (@profit_ctr_name IS NULL)
        SET @profit_ctr_name = '';

    DECLARE @IsPacificNRCCSRole BIT;

    SET @IsPacificNRCCSRole = ISNULL(
        (
            SELECT 1
            FROM [COR_DB].[dbo].[RolesRef] AS Roles
            WHERE Roles.RoleName = 'Pacific NRC CS'
                AND Roles.IsActive = 1
                AND Roles.RoleId IN (
                    SELECT CXR.RoleId
                    FROM [Plt_ai].[DBO].ContactXRole CXR
                    WHERE CXR.Contact_ID = (
                            SELECT TOP 1 Contact_ID
                            FROM [Plt_ai].[DBO].Contact AS [User]
                            WHERE (web_userid = @web_userid OR email = @web_userid)
                                AND web_access_flag = 'T'
                                AND contact_status = 'A'
                        )
                        AND CXR.status = 'A'
                )
        ), 0);

    SELECT DISTINCT
        upc.company_id,
        upc.profit_ctr_id,
        upc.name AS profit_ctr_name,	
        upc.city,
        upc.state,
        sa.state_name,
        upc.address_1,
        upc.address_2,
        upc.phone,
        upc.epa_id,
        upc.zip_code,
		zc.latitude,
		zc.longitude,
         -- Retrieve related data as JSON formatted string
        (
            SELECT 
                JSON_QUERY((
                    SELECT 
                        -- Fetch disposal services
                        (SELECT STRING_AGG(disposal_service_code, ',') 
                         FROM ProfitCenterXDisposalService 
                         WHERE company_id = upc.company_id AND profit_ctr_id = upc.profit_ctr_id) AS disposal_services,

                        -- Fetch waste types
                        (SELECT STRING_AGG(waste_type_code, ',') 
                         FROM ProfitCenterXWasteType 
                         WHERE company_id = upc.company_id AND profit_ctr_id = upc.profit_ctr_id) AS waste_types,

                        -- Fetch treatment services
                        (SELECT STRING_AGG(treatment_process_code, ',') 
                         FROM ProfitCenterXTreatmentProcess 
                         WHERE company_id = upc.company_id AND profit_ctr_id = upc.profit_ctr_id) AS treatment_process

                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) 
        ) AS filterCategories
    FROM USE_ProfitCenter upc 
    JOIN FormFacility f ON f.company_id = upc.company_id AND f.profit_ctr_id = upc.profit_ctr_id
    LEFT JOIN StateAbbreviation sa ON upc.state = sa.abbr AND upc.country_code = sa.country_code
    LEFT JOIN dbo.Zipcodes zc ON zc.zipcode = upc.zip_code
    WHERE 
        f.version = 6
        AND (
            ((@profit_ctr_name IS NOT NULL AND @profit_ctr_name ='') AND (upc.name LIKE '%' + @profit_ctr_name + '%' 
                OR upc.city LIKE '%' + @profit_ctr_name + '%' 
                OR upc.state LIKE '%' + @profit_ctr_name + '%' 
                OR sa.state_name LIKE '%' + @profit_ctr_name + '%'))
            OR (@IsPacificNRCCSRole = 1)
        )
        AND (
            (@IsPacificNRCCSRole = 1)
            OR (@IsPacificNRCCSRole = 0 AND NOT (f.company_id IN (45) AND f.profit_ctr_id = 0))
        ) 
    ORDER BY upc.name;
END

GO


GRANT EXEC ON [dbo].[sp_LookupProfitCenter] TO COR_USER;

GO
