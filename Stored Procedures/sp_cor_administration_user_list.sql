USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_cor_administration_user_list]
GO

CREATE PROCEDURE [dbo].[sp_cor_administration_user_list](
    @web_userid varchar(100),
    @role varchar(500) = null,    -- Changed from MAX to 500
    @search varchar(100) = null,
    @sort varchar(20) = '', -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status', 'Contact Company'
    @page bigint = 1,
    @perpage bigint = 20,
    @customer_id_list varchar(500) = '',  -- Changed from MAX to 500
    @generator_id_list varchar(500) = '',  -- Changed from MAX to 500
    @active_flag char(1) = 'A', -- 'A'ctive users, 'I'nactive users, 'X' all users.
    @search_type varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_id int = 0,
    @search_name varchar(200) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_email varchar(150) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_first_name varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_last_name varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_title varchar(150) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_phone varchar(20) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_fax varchar(20) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_country varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_zip_code varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_state varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_addr1 varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_city varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_company varchar(150) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_addr2 varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_addr3 varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_contact_addr4 varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_mobile varchar(100) = '',    -- Changed from NVARCHAR to VARCHAR
    @search_web_userid varchar(150) = ''    -- Changed from NVARCHAR to VARCHAR
)
AS
/* *****************************************************************
sp_cor_administration_user_list

List the users that the current @web_userid can admin.

--sp_cor_administration_user_list
EXEC dbo.sp_cor_administration_user_list_v2
	@web_userid = 'iceman'
	, @role = '' -- 'Administration'
	, @search = '' -- 'bram'
	, @sort = 'email'
	, @page = 1
	, @perpage = 99999
	, @active_flag = 'A'
	, @search_first_name = ''
	, @search_last_name = ''
	, @search_contact_zip_code = ''
	
SELECT  * FROM    contact WHERE contact_id in (219933, 219934)
SELECT  * FROM    contactxref WHERE contact_id in (219933, 219934)

SELECT  *  FROM    contact WHERE web_userid = 'jdirt'	
SELECT  *  FROM    contactxref where type = 'C' and contact_id in (211277)	
SELECT  *  FROM    contactxrole WHERE contact_id = 211277
SELECT  *  FROM    customer where customer_id in (6976, 15551, 15622, 18433, 18462, 602372)

select  CAST( RoleId AS nvarchar(1000)) RoleId ,RoleName,IsActive from cor_db.[dbo].[RolesRef]
WHERE roleid in ('177974A7-13D9-4123-8311-97A4C1FDC549', '2A57DB7C-E8A0-470C-8641-7469806A91D4', '42AD9B98-7A38-4607-B3B7-670DA552528E', '45892B8E-FAA5-451F-B2E6-B43DA7C14AEC', '6ED53B5D-5884-43E9-AC7F-A1F00EE6C2CA', '912B5F07-4553-488E-B9F3-C5F822A9DF6A', 'A3A7B60D-EF90-465A-8E10-8C954D003AA2', 'A8A04E15-5338-4B2C-BEDE-FB18EFF3F56E', 'AE18FA46-59AD-46CE-BFAD-420F1268315A', 'E525FE2D-F970-4E89-A5F4-68930C10B290')

delete FROM    contactxrole WHERE contact_id = 211277 and roleid = '6ED53B5D-5884-43E9-AC7F-A1F00EE6C2CA'
	
-- disable one: yhudspeth / 257568
select * from contact where web_userid = 'yhudspeth'
update contact set web_userid = isnull(web_userid, '') + '_' + convert(varchar(20), contact_id) where web_userid = 'yhudspeth' and contact_id <> 257568

sp_cor_administration_user_account_change
	@web_userid = 'nyswyn100'
	, @target_userid = 'yhudspeth'
	, @operation = 'add'
	, @account_type = 'X'

select * from	contactxref where	 contact_id = 257568

exec [dbo].[sp_contact_account_access_change] @user_code_or_id = 'nyswyn100'	, @target_contact_id	= 257568, @operation	= 'add' , @account_type	= 'C', @account_id	= 6976

sp_cor_administration_user_account_change
	@web_userid = 'nyswyn100'
	, @target_userid = 'yhudspeth'
	, @operation = 'add'
	, @account_type = 'C'
	, @account_id = 15551
	
History:
	04/28/2025 - Rally TA544844/TA556928 - Titian Modified to optimize the stored procedure as per the recommendations provided in the analysis document for Titan.

***************************************************************** */

-- Avoid query plan caching and handle nulls
DECLARE
    @i_web_userid varchar(100) = ISNULL(@web_userid, ''),
    @i_role varchar(500) = ISNULL(@role, ''),    -- Changed from MAX to 500
    @i_search varchar(100) = ISNULL(@search, ''),
    @i_sort varchar(20) = ISNULL(@sort, ''),
    @i_page bigint = ISNULL(@page, 1),
    @i_perpage bigint = ISNULL(@perpage, 20),
    @i_customer_id_list varchar(500) = ISNULL(@customer_id_list, ''),    -- Changed from MAX to 500
    @i_generator_id_list varchar(500) = ISNULL(@generator_id_list, ''),    -- Changed from MAX to 500
    @i_active_flag char(1) = ISNULL(@active_flag, 'A'),
    @i_am_I_internal int = 0,
    @i_contact_id int = 0;

-- Create a temp table for split role values
IF OBJECT_ID('tempdb..#troles') IS NOT NULL
    DROP TABLE #troles;

CREATE TABLE #troles (
    rolename varchar(150)
);

IF @i_role <> ''
    INSERT INTO #troles
    SELECT row
    FROM dbo.fn_SplitXsvText(',', 1, @i_role)
    WHERE row IS NOT NULL;

SELECT @i_contact_id = contact_id
FROM dbo.CORcontact
WHERE web_userid = @i_web_userid;

--The logic for @i_am_I_internal is hidden
/*SELECT @i_am_I_internal = 1
FROM dbo.ContactXRole x
JOIN cor_db.[dbo].[RolesRef] r ON x.RoleId = r.RoleID
JOIN dbo.Contact c ON x.contact_id = c.contact_id AND c.web_userid = @i_web_userid
WHERE r.RoleName LIKE '%internal%';  */

-- Create temp table for internal domains
IF OBJECT_ID('tempdb..#internal_domains') IS NOT NULL
    DROP TABLE #internal_domains;

CREATE TABLE #internal_domains (
    domain varchar(40)
);

INSERT INTO #internal_domains (domain)
VALUES
    ('@usecology.com'),
    ('@stablex.com'),
    ('@eqonline.com'),
    ('@nrcc.com'),
    ('@optisolbusiness.com');
    --.('@repsrv.com');

-- Create temp tables for customer and generator IDs
IF OBJECT_ID('tempdb..#customer_ids') IS NOT NULL
    DROP TABLE #customer_ids;

CREATE TABLE #customer_ids (
    customer_id int
);

IF @i_customer_id_list <> ''
BEGIN
    INSERT INTO #customer_ids (customer_id)
    SELECT CONVERT(int, row)
    FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
    WHERE row IS NOT NULL AND ISNUMERIC(row) = 1;
END

IF OBJECT_ID('tempdb..#generator_ids') IS NOT NULL
    DROP TABLE #generator_ids;

CREATE TABLE #generator_ids (
    generator_id int
);

IF @i_generator_id_list <> ''
BEGIN
    INSERT INTO #generator_ids (generator_id)
    SELECT CONVERT(int, row)
    FROM dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
    WHERE row IS NOT NULL AND ISNUMERIC(row) = 1;
END

-- Create a temp table for contact_ids with access
IF OBJECT_ID('tempdb..#contact_access') IS NOT NULL
    DROP TABLE #contact_access;

CREATE TABLE #contact_access (
    contact_id int,
    customer_id int,
    generator_id int
);

INSERT INTO #contact_access (contact_id, customer_id, generator_id)
SELECT x1.contact_id, x1.customer_id, x1.generator_id
FROM dbo.contactxref x1
WHERE x1.contact_id = @i_contact_id
AND x1.status = 'A'
AND x1.web_access = 'A';

-- Create a temp table instead of table variable for better statistics
IF OBJECT_ID('tempdb..#contactxref') IS NOT NULL
    DROP TABLE #contactxref;

CREATE TABLE #contactxref (
    contact_id bigint,
    type char(1),
    web_access char(1),
    type_count int
);

-- Add index to temp table
CREATE CLUSTERED INDEX IX_contactxref_contact_id ON #contactxref (contact_id);

INSERT INTO #contactxref
SELECT
    x.contact_id,
    MIN(x.type) AS type,
    MIN(x.web_access) AS web_access,
    COUNT(DISTINCT x.type) AS type_count
FROM dbo.contactxref x
JOIN dbo.contact c ON x.contact_id = c.contact_id
LEFT JOIN #internal_domains id ON c.email LIKE '%' + id.domain AND c.email <> 'itcommunications@usecology.com'
WHERE
    x.status = 'A'
    AND (
        EXISTS (
            SELECT 1
            FROM #contact_access ca
            WHERE (ca.customer_id = x.customer_id OR ca.generator_id = x.generator_id)
            AND (x.customer_id IS NOT NULL OR x.generator_id IS NOT NULL)
        )
    )
    AND (
        @i_customer_id_list = ''
        OR (
            @i_customer_id_list <> ''
            AND x.type = 'C'
            AND EXISTS (
                SELECT 1
                FROM #customer_ids ci
                WHERE ci.customer_id = x.customer_id
            )
        )
    )
    AND (
        @i_generator_id_list = ''
        OR (
            @i_generator_id_list <> ''
            AND x.type = 'G'
            AND EXISTS (
                SELECT 1
                FROM #generator_ids gi
                WHERE gi.generator_id = x.generator_id
            )
        )
    )
    -- Removed Internal User check as it's not useful according to requirements
    AND id.domain IS NULL
GROUP BY x.contact_id;

-- Using CTE for better performance with complex filtering
WITH FilteredContacts AS (
    SELECT DISTINCT
        CASE WHEN x.type_count = 2 THEN 'Both' ELSE CASE x.type WHEN 'C' THEN 'Customer' ELSE 'Generator' END END AS type,
        c.contact_id, c.name, c.email, c.first_name, c.last_name, c.title, c.phone, c.fax,
        c.contact_country, c.contact_zip_code, c.contact_state, c.contact_addr1, c.contact_city, c.contact_company,
        c.contact_addr2, c.contact_addr3, c.contact_addr4, c.mobile, c.web_userid,
        x.web_access AS status,
        CASE WHEN c.email LIKE '%usecology.com%' OR c.email LIKE '%republicservices.com%' THEN 1 ELSE 0 END AS IsInternalUser
    FROM dbo.contact c
    JOIN #contactxref x ON c.contact_id = x.contact_id
    JOIN dbo.contactxref xref ON c.contact_id = xref.contact_id
    WHERE x.type = 'C'
    AND x.web_access = CASE @i_active_flag WHEN 'X' THEN x.web_access ELSE @i_active_flag END
    AND c.contact_status = 'A'
    AND (c.web_userid IS NOT NULL AND c.web_userid <> '')
    AND (
        @i_role = ''
        OR (
            @i_role <> ''
            AND EXISTS (
                SELECT 1
                FROM cor_db.dbo.RolesRef rr WITH (NOLOCK)
                JOIN dbo.ContactXRole cxr WITH (NOLOCK) ON rr.roleid = cxr.RoleId
                JOIN #troles t ON rr.rolename = t.rolename
                WHERE cxr.contact_id = c.contact_id
                AND cxr.status = CASE @i_active_flag WHEN 'A' THEN 'A' ELSE cxr.status END
            )
        )
    )
    AND (
        @i_search = ''
        OR (
            @i_search <> ''
            AND ' ' + ISNULL(CONVERT(varchar(20), c.contact_id), '') +
                ' ' + ISNULL(c.name, '') +
                ' ' + ISNULL(c.email, '') +
                ' ' + ISNULL(c.first_name, '') +
                ' ' + ISNULL(c.last_name, '') +
                ' ' + ISNULL(c.title, '') +
                ' ' + ISNULL(c.phone, '') +
                ' ' + ISNULL(c.contact_city, '') +
                ' ' + ISNULL(c.contact_company, '') +
                ' ' + ISNULL(c.web_userid, '') + ' '
                LIKE '%' + @i_search + '%'
        )
    )
    AND (@search_type = '' OR
        CASE WHEN x.type_count = 2 THEN 'Both' ELSE CASE x.type WHEN 'C' THEN 'Customer' ELSE 'Generator' END END = @search_type)
    AND (@search_contact_id = 0 OR c.contact_id = @search_contact_id)
    AND (COALESCE(c.name, '') LIKE '%' + @search_name + '%')
    AND (COALESCE(c.email, '') LIKE '%' + @search_email + '%')
    AND (COALESCE(c.first_name, '') LIKE '%' + @search_first_name + '%')
    AND (COALESCE(c.last_name, '') LIKE '%' + @search_last_name + '%')
    AND (COALESCE(c.title, '') LIKE '%' + @search_title + '%')
    AND (COALESCE(c.phone, '') LIKE '%' + @search_phone + '%')
    AND (COALESCE(c.fax, '') LIKE '%' + @search_fax + '%')
    AND (COALESCE(c.contact_country, '') LIKE '%' + @search_contact_country + '%')
    AND (COALESCE(c.contact_zip_code, '') LIKE '%' + @search_contact_zip_code + '%')
    AND (COALESCE(c.contact_state, '') LIKE '%' + @search_contact_state + '%')
    AND (COALESCE(c.contact_addr1, '') LIKE '%' + @search_contact_addr1 + '%')
    AND (COALESCE(c.contact_city, '') LIKE '%' + @search_contact_city + '%')
    AND (COALESCE(c.contact_company, '') LIKE '%' + @search_contact_company + '%')
    AND (COALESCE(c.contact_addr2, '') LIKE '%' + @search_contact_addr2 + '%')
    AND (COALESCE(c.contact_addr3, '') LIKE '%' + @search_contact_addr3 + '%')
    AND (COALESCE(c.contact_addr4, '') LIKE '%' + @search_contact_addr4 + '%')
    AND (COALESCE(c.mobile, '') LIKE '%' + @search_mobile + '%')
    AND (COALESCE(c.web_userid, '') LIKE '%' + @search_web_userid + '%')
),
RankedContacts AS (
    SELECT
        type, contact_id, name, email, first_name, last_name, title, phone, fax,
        contact_country, contact_zip_code, contact_state, contact_addr1, contact_city,
        contact_company, contact_addr2, contact_addr3, contact_addr4, mobile, web_userid,
        status, IsInternalUser,
        ROW_NUMBER() OVER (ORDER BY
            CASE WHEN @i_sort IN ('', 'name') THEN name ELSE NULL END,
            CASE WHEN @i_sort = 'email' THEN email ELSE NULL END,
            CASE WHEN @i_sort = 'first_name' THEN first_name ELSE NULL END,
            CASE WHEN @i_sort = 'last_name' THEN last_name ELSE NULL END,
            CASE WHEN @i_sort = 'title' THEN title ELSE NULL END,
            CASE WHEN @i_sort = 'phone' THEN phone ELSE NULL END,
            CASE WHEN @i_sort = 'address' THEN contact_addr1 ELSE NULL END,
            CASE WHEN @i_sort = 'city' THEN contact_city ELSE NULL END,
            CASE WHEN @i_sort = 'state' THEN contact_state ELSE NULL END,
            CASE WHEN @i_sort = 'contact_company' THEN contact_company ELSE NULL END
        ) AS _row
    FROM FilteredContacts
)
SELECT
    type, contact_id, name, email, first_name, last_name, title, phone, fax,
    contact_country, contact_zip_code, contact_state, contact_addr1, contact_city,
    contact_company, contact_addr2, contact_addr3, contact_addr4, mobile, web_userid,
    status, IsInternalUser, _row
FROM RankedContacts
WHERE _row BETWEEN ((@i_page-1) * @i_perpage) + 1 AND (@i_page * @i_perpage)
ORDER BY _row;

-- Clean up temporary objects
IF OBJECT_ID('tempdb..#contactxref') IS NOT NULL
    DROP TABLE #contactxref;
IF OBJECT_ID('tempdb..#troles') IS NOT NULL
    DROP TABLE #troles;
IF OBJECT_ID('tempdb..#internal_domains') IS NOT NULL
    DROP TABLE #internal_domains;
IF OBJECT_ID('tempdb..#customer_ids') IS NOT NULL
    DROP TABLE #customer_ids;
IF OBJECT_ID('tempdb..#generator_ids') IS NOT NULL
    DROP TABLE #generator_ids;
IF OBJECT_ID('tempdb..#contact_access') IS NOT NULL
    DROP TABLE #contact_access;

RETURN 0;

go

grant execute on sp_cor_administration_user_list to eqweb, eqai, COR_USER

go
