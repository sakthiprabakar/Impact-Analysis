USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_LookupProfitCenter]
GO


CREATE PROCEDURE [dbo].[sp_LookupProfitCenter]
    @profit_ctr_name NVARCHAR(MAX) = NULL,
    @web_userid NVARCHAR(100) = NULL
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
-- =============================================

EXEC sp_LookupProfitCenter @profit_ctr_name='',@web_userid='nyswyn100'

 */

BEGIN
    SET NOCOUNT ON;

   -- Set default value for profit center name if NULL
    IF (@profit_ctr_name IS NULL)
        SET @profit_ctr_name = '';

   DECLARE @IsPacificNRCCSRole BIT;
    -- Check if user has Pacific NRC CS Role
   SET @IsPacificNRCCSRole = COALESCE(
        (
            SELECT TOP 1 1 
            FROM Plt_ai..Contact ct
            INNER JOIN Plt_ai..ContactXRole cxr ON ct.Contact_ID = cxr.Contact_ID
            INNER JOIN [COR_DB].[dbo].[RolesRef] r ON cxr.RoleId = r.RoleId 
            WHERE r.RoleName = 'Pacific NRC CS'
              AND (web_userid = @web_userid OR email = @web_userid)
              AND web_access_flag = 'T'
              AND contact_status = 'A'
              AND cxr.status = 'A'
        ), 0
    );
 
 
    -- Main query to fetch facility information
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
        zc.longitude
    FROM USE_ProfitCenter upc 
    JOIN FormFacility f ON f.company_id = upc.company_id 
                       AND f.profit_ctr_id = upc.profit_ctr_id
    LEFT JOIN StateAbbreviation sa ON upc.state = sa.abbr 
                                  AND upc.country_code = sa.country_code
    LEFT JOIN dbo.Zipcodes zc ON zc.zipcode = upc.zip_code
    WHERE 
        f.version = 6
        AND (
            @profit_ctr_name = '' 
            OR (
                @profit_ctr_name <> '' 
                AND (
                    upc.name LIKE '%' + @profit_ctr_name + '%' 
                    OR upc.city LIKE '%' + @profit_ctr_name + '%' 
                    OR upc.state LIKE '%' + @profit_ctr_name + '%' 
                    OR sa.state_name LIKE '%' + @profit_ctr_name + '%'
                )
            )
        )
        AND (
            (@IsPacificNRCCSRole = 1)
            OR (
                @IsPacificNRCCSRole = 0 
                AND NOT (f.company_id IN (44, 45) AND f.profit_ctr_id = 0)
            )
        )
    ORDER BY upc.name;
END
GO


GRANT EXEC ON [dbo].[sp_LookupProfitCenter] TO COR_USER;

GO
