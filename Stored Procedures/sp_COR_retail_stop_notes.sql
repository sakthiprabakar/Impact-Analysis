--	drop proc sp_COR_retail_stop_notes

go

CREATE OR ALTER PROCEDURE dbo.sp_COR_retail_stop_notes
    @web_userid         varchar(100) = '',
    @service_date_from  datetime = '1/1/1900',    -- Beginning Start Date
    @service_date_to    datetime = '1/1/1900',    -- Ending Start Date
    @store_number       varchar(1000) = '',       -- Optimized: Changed to varchar(1000) from varchar(max) 28/04/2025
    @generator_name     varchar(1000) = '',
    @generator_city     varchar(1000) = '',
    @generator_state    varchar(1000) = '',
    @generator_region   varchar(1000) = '',
    @generator_district varchar(1000) = '',
    @customer_id_list   varchar(1000) = '',  /* Added 2019-07-17 by AA */
    @generator_id_list  varchar(1000) = ''   /* Added 2019-07-17 by AA */
AS
/* ***************************************************************************************************
sp_COR_retail_stop_notes:

Info:
    Returns the data for Trip Question Notes. Copied & Modified from sp_eqip_retail_stop_notes.
    LOAD TO PLT_AI

Examples:
    sp_COR_retail_stop_notes
    @web_userid         = 'jeff.scott@usecology.com',
    @service_date_from  = '1/1/2021',
    @service_date_to    = '5/1/2021',
    @store_number       = '',
    @generator_name     = '',
    @generator_city     = '',
    @generator_state    = '',
    @generator_region   = '',
    @generator_district = '',
    @customer_id_list   = '18462',
    @generator_id_list  = ''

History:
    08/14/2015 JPB  Created
    09/03/2015 JPB  Added Generator columns
    12/18/2018 JPB  Modified from sp_eqip_retail_stop_notes for COR2 dev
    10/14/2019 DevOps:11600 - AM - Added customer_id and generator_id temp tables and added receipt join.
    04/28/2025 Rally TA544849/TA556933 Titan Added performance optimizations (parameterized queries, better indexing, NOCOUNT, etc.)
	
*************************************************************************************************** */
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE
        @status_criteria       varchar(200) = 'Invoiced,Declined,Complete,No Waste Picked Up,Complete - Waste Removed,In Process,Scheduled/Confirmed,Scheduled,Unavailable',
        @i_contact_id         int,
        @i_customer_id_list   varchar(1000) = ISNULL(@customer_id_list, ''),     -- Optimized: Changed to varchar(1000) from varchar(4000) 28/04/2025
        @i_generator_id_list  varchar(1000) = ISNULL(@generator_id_list, ''),
        @i_service_date_from  datetime = CONVERT(datetime, @service_date_from),
        @i_service_date_to    datetime = CONVERT(datetime, @service_date_to);

    -- Clean up any existing temp tables that might have been left from a previous execution 28/04/2025
    IF OBJECT_ID('tempdb..#customer') IS NOT NULL DROP TABLE #customer;
    IF OBJECT_ID('tempdb..#generator_list') IS NOT NULL DROP TABLE #generator_list;
    IF OBJECT_ID('tempdb..#status_filter') IS NOT NULL DROP TABLE #status_filter;
    IF OBJECT_ID('tempdb..#store_number') IS NOT NULL DROP TABLE #store_number;
    IF OBJECT_ID('tempdb..#city') IS NOT NULL DROP TABLE #city;
    IF OBJECT_ID('tempdb..#state') IS NOT NULL DROP TABLE #state;
    IF OBJECT_ID('tempdb..#region') IS NOT NULL DROP TABLE #region;
    IF OBJECT_ID('tempdb..#district') IS NOT NULL DROP TABLE #district;
    IF OBJECT_ID('tempdb..#access_filter') IS NOT NULL DROP TABLE #access_filter;

    -- Get contact ID once with optimized query plan
    SELECT @i_contact_id = contact_id
    FROM dbo.CORcontact WITH (NOLOCK)
    WHERE web_userid = @web_userid;

    IF @i_service_date_to > '1/1/1900'
       SET @i_service_date_to = @i_service_date_to + 0.99999

    -- Create filtered customer IDs table with appropriate index 28/04/2025
    CREATE TABLE #customer (customer_id bigint PRIMARY KEY CLUSTERED);

    IF @i_customer_id_list <> ''
    BEGIN
        INSERT INTO #customer
        SELECT CONVERT(bigint, row)
        FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
        WHERE row IS NOT NULL;
    END

    -- Create filtered generator IDs table with appropriate index  28/04/2025
    CREATE TABLE #generator_list (generator_id bigint PRIMARY KEY CLUSTERED);

    IF @i_generator_id_list <> ''
    BEGIN
        INSERT INTO #generator_list
        SELECT CONVERT(bigint, row)
        FROM dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
        WHERE row IS NOT NULL;
    END

    -- Status Criteria Filter with temporary table for better compatibility  28/04/2025
    CREATE TABLE #status_filter (status_filter varchar(50) PRIMARY KEY);

    IF DATALENGTH(@status_criteria) > 0
    BEGIN
        INSERT INTO #status_filter
        SELECT RTRIM(LEFT(row, 50))
        FROM dbo.fn_SplitXsvText(',', 1, @status_criteria)
        WHERE ISNULL(row, '') <> '';
    END

    -- Filter tables for various criteria with appropriate indexes 28/04/2025
    CREATE TABLE #store_number (generator_id int PRIMARY KEY CLUSTERED);
    CREATE TABLE #city (generator_id int PRIMARY KEY CLUSTERED);
    CREATE TABLE #state (generator_state char(2), country char(3), PRIMARY KEY CLUSTERED(generator_state, country));
    CREATE TABLE #region (generator_id int PRIMARY KEY CLUSTERED);
    CREATE TABLE #district (generator_id int PRIMARY KEY CLUSTERED);

    -- Populate filter tables with optimized queries
    IF ISNULL(@store_number, '') <> ''
    BEGIN
        INSERT INTO #store_number
        SELECT generator_id
        FROM dbo.generator WITH (NOLOCK)
        WHERE site_code IN (
            SELECT row
            FROM dbo.fn_SplitXsvText(',', 1, @store_number)
            WHERE row IS NOT NULL
        );
    END

    IF ISNULL(@generator_name, '') <> ''
    BEGIN
        INSERT INTO #city
        SELECT generator_id
        FROM dbo.generator WITH (NOLOCK)
        WHERE EXISTS (
            SELECT 1
            FROM dbo.fn_SplitXsvText(',', 1, @generator_name) c
            WHERE generator.generator_name LIKE '%' + REPLACE(c.row, ' ', '%') + '%'
            AND c.row IS NOT NULL
        );
    END

    IF ISNULL(@generator_city, '') <> ''
    BEGIN
        INSERT INTO #city
        SELECT generator_id
        FROM dbo.generator WITH (NOLOCK)
        WHERE EXISTS (
            SELECT 1
            FROM dbo.fn_SplitXsvText(',', 1, @generator_city) c
            WHERE generator.generator_city LIKE '%' + REPLACE(c.row, ' ', '%') + '%'
            AND c.row IS NOT NULL
        );
    END

    -- Simplified logic for Generate State
	IF ISNULL(@generator_state, '') <> ''
	BEGIN
		 INSERT INTO #state (generator_state, country)
		 SELECT sa.abbr, sa.country_code
		 FROM dbo.fn_SplitXsvText(',', 1, @generator_state) x
		 JOIN dbo.stateabbreviation sa WITH (NOLOCK)
			ON (
				 ( (sa.state_name = x.row OR sa.abbr = x.row) AND x.row NOT LIKE '%-%' )
				 OR
				 ( (sa.abbr + '-' + sa.country_code = x.row OR sa.country_code + '-' + sa.abbr = x.row) AND x.row LIKE '%-%' )
			   )
		WHERE x.row IS NOT NULL;
	END


    IF ISNULL(@generator_region, '') <> ''
    BEGIN
        INSERT INTO #region
        SELECT generator_id
        FROM dbo.generator WITH (NOLOCK)
        WHERE generator_region_code IN (
            SELECT row
            FROM dbo.fn_SplitXsvText(',', 1, @generator_region)
            WHERE row IS NOT NULL
        );
    END

    IF ISNULL(@generator_district, '') <> ''
    BEGIN
        INSERT INTO #district
        SELECT generator_id
        FROM dbo.generator WITH (NOLOCK)
        WHERE generator_district IN (
            SELECT row
            FROM dbo.fn_SplitXsvText(',', 1, @generator_district)
            WHERE row IS NOT NULL
        );
    END

    -- Create access filter table with proper indexing
    CREATE TABLE #access_filter (
        company_id int,
        profit_ctr_id int,
        workorder_id int,
        billing_status_info varchar(40),
        PRIMARY KEY CLUSTERED (company_id, profit_ctr_id, workorder_id)
    );

    -- Build parameterized WHERE conditions for filtering   28/04/2025
    DECLARE @where nvarchar(2000) = '
        WHERE w2.workorder_status NOT IN (''V'', ''X'', ''T'')';

    IF @i_service_date_from > '1/1/1900'
        SET @where = @where + '
        AND COALESCE(wos.date_act_arrive, wos.date_act_depart, w2.start_date) >= @dt_from';

    IF @i_service_date_to > '1/1/1900'
        SET @where = @where + '
        AND COALESCE(wos.date_act_arrive, wos.date_act_depart, w2.start_date) <= @dt_to';

    -- Create optimized dynamic SQL with parameterized query 28/04/2025
	-- 5/15/2025 - TA556933 Checked LEN of @sql and get 1480 so updated the size to 2000 (Joanthon Carey)
    DECLARE @sql nvarchar(2000) = '
    INSERT INTO #access_filter (company_id, profit_ctr_id, workorder_id)
    SELECT w2.company_id, w2.profit_ctr_id, w2.workorder_id
    FROM dbo.workorderheader w2 WITH (NOLOCK)
    JOIN dbo.ContactCORWorkorderHeaderBucket sc WITH (NOLOCK)
        ON w2.workorder_id = sc.workorder_id
        AND w2.company_id = sc.company_id
        AND w2.profit_ctr_id = sc.profit_ctr_id
        AND sc.contact_id = @contact_id
    LEFT JOIN dbo.WorkOrderStop wos WITH (NOLOCK)
        ON w2.workorder_id = wos.workorder_id
        AND w2.company_id = wos.company_id
        AND w2.profit_ctr_id = wos.profit_ctr_id
        AND wos.stop_sequence_id = 1' + @where;

    -- Add conditional filters based on populated tables 28/04/2025
    IF EXISTS (SELECT 1 FROM #store_number)
        SET @sql = @sql + '
        AND EXISTS (
            SELECT 1 FROM #store_number
            WHERE generator_id = w2.generator_id
        )';

    IF EXISTS (SELECT 1 FROM #city)
        SET @sql = @sql + '
        AND EXISTS (
            SELECT 1 FROM #city
            WHERE generator_id = w2.generator_id
        )';

    IF EXISTS (SELECT 1 FROM #state)
        SET @sql = @sql + '
        AND EXISTS (
            SELECT 1
            FROM dbo.generator gs WITH (NOLOCK)
            JOIN #state s
                ON ISNULL(NULLIF(gs.generator_country, ''''), ''USA'') = s.country
                AND gs.generator_state = s.generator_state
            WHERE gs.generator_id = w2.generator_id
        )';

    IF EXISTS (SELECT 1 FROM #region)
        SET @sql = @sql + '
        AND EXISTS (
            SELECT 1 FROM #region
            WHERE generator_id = w2.generator_id
        )';

    IF EXISTS (SELECT 1 FROM #district)
        SET @sql = @sql + '
        AND EXISTS (
            SELECT 1 FROM #district
            WHERE generator_id = w2.generator_id
        )';

    -- Add query optimization hints
    SET @sql = @sql + '
    OPTION (RECOMPILE)';

    -- Execute the parameterized query with all parameters
    EXEC sp_executesql @sql,
        N'@contact_id int, @dt_from datetime, @dt_to datetime',
        @contact_id = @i_contact_id,
        @dt_from = @i_service_date_from,
        @dt_to = @i_service_date_to;

    -- Update billing status info in one batch operation with optimized case statement
    UPDATE f
    SET f.billing_status_info =
        CASE
            WHEN b.status_code = 'I' THEN 'Invoiced'
            WHEN wos.decline_id IN (2, 3) THEN 'Declined'
            WHEN wos.decline_id = 4 THEN 'No Waste Picked Up'
            WHEN (GETDATE() > wos.date_act_arrive) OR (GETDATE() > h.end_date)
                THEN 'Complete' + CASE WHEN wos.waste_flag = 'T' THEN ' - Waste Removed' ELSE '' END
            WHEN GETDATE() BETWEEN h.start_date AND h.end_date THEN 'In Process'
            WHEN GETDATE() < h.start_date AND wos.confirmation_date IS NOT NULL THEN 'Scheduled/Confirmed'
            WHEN GETDATE() < h.start_date THEN 'Scheduled'
            ELSE 'Unavailable'
        END
    FROM #access_filter f
    INNER JOIN dbo.workorderheader h WITH (NOLOCK)
        ON h.workorder_id = f.workorder_id
        AND h.company_id = f.company_id
        AND h.profit_ctr_id = f.profit_ctr_id
    INNER JOIN dbo.WorkOrderStop wos WITH (NOLOCK)
        ON h.company_id = wos.company_id
        AND h.profit_ctr_id = wos.profit_ctr_id
        AND h.workorder_id = wos.workorder_id
    LEFT OUTER JOIN dbo.billing b WITH (NOLOCK)
        ON b.receipt_id = h.workorder_id
        AND b.company_id = h.company_id
        AND b.profit_ctr_id = h.profit_ctr_id
        AND b.trans_source = 'W';

    -- Populate status filter if empty
    IF NOT EXISTS (SELECT 1 FROM #status_filter)
    BEGIN
        INSERT INTO #status_filter
        SELECT DISTINCT billing_status_info
        FROM #access_filter
        WHERE billing_status_info IS NOT NULL;
    END

    -- Create index to speed up the final join
    CREATE NONCLUSTERED INDEX IX_access_filter_status ON #access_filter (billing_status_info);

    -- Final result set with optimized joins and filtering
    SELECT DISTINCT
        h.company_id,
        h.profit_ctr_id,
        h.workorder_id,
        af.billing_status_info AS status,
        dbo.fn_web_profitctr_display_name(h.company_id, h.profit_ctr_id) AS profit_ctr_name,
        h.trip_id,
        h.customer_id,
        c.cust_name,
        g.generator_name,
        g.epa_id,
        g.site_code,
        g.generator_state,
        g.generator_city,
        g.generator_pickup_schedule_type,
        g.generator_facility_size,
        g.generator_facility_date_opened,
        g.generator_facility_date_closed,
        g.generator_market_code,
        g.generator_region_code,
        g.generator_annual_sales,
        g.generator_business_unit,
        g.generator_division,
        gs.code,
        th.driver_name,
        h.release_code,
        h.purchase_order,
        wos.pickup_contact,
        wos.pickup_contact_title,
        CASE
            WHEN wos.date_act_arrive IS NULL AND af.billing_status_info IN ('Complete', 'Invoiced') THEN h.end_date
            ELSE wos.date_act_arrive
        END AS trip_act_arrive,
        CASE
            WHEN qc.category_desc IS NULL THEN 'Uncategorized'
            ELSE qc.category_desc
        END AS category_name,
        tq.question_text,
        tq.answer_text
    FROM #access_filter af
    INNER JOIN #status_filter sf
        ON af.billing_status_info = sf.status_filter
    INNER JOIN dbo.workorderheader h WITH (NOLOCK)
        ON h.workorder_id = af.workorder_id
        AND h.company_id = af.company_id
        AND h.profit_ctr_id = af.profit_ctr_id
    INNER JOIN dbo.WorkOrderStop wos WITH (NOLOCK)
        ON h.workorder_ID = wos.workorder_id
        AND h.company_id = wos.company_id
        AND h.profit_ctr_ID = wos.profit_ctr_id
    INNER JOIN dbo.TripHeader th WITH (NOLOCK)
        ON th.trip_id = h.trip_id
        AND h.company_id = th.company_id
        AND h.profit_ctr_id = th.profit_ctr_id
    INNER JOIN dbo.TripQuestion tq WITH (NOLOCK)
        ON tq.workorder_id = h.workorder_ID
        AND tq.company_id = h.company_id
        AND tq.profit_ctr_id = h.profit_ctr_id
        AND tq.view_on_web_flag = 'T'
    LEFT OUTER JOIN dbo.QuestionCategory qc WITH (NOLOCK)
        ON tq.question_category_id = qc.question_category_id
    INNER JOIN dbo.customer c WITH (NOLOCK)
        ON h.customer_id = c.customer_id
    LEFT OUTER JOIN dbo.generator g WITH (NOLOCK)
        ON h.generator_id = g.generator_id
    LEFT JOIN dbo.GeneratorSubLocation gs WITH (NOLOCK)
        ON h.generator_sublocation_id = gs.generator_sublocation_id
    WHERE h.workorder_status NOT IN ('V', 'X', 'T')
        AND (@i_customer_id_list = ''
            OR EXISTS (SELECT 1 FROM #customer WHERE customer_id = h.customer_id))
        AND (@i_generator_id_list = ''
            OR EXISTS (SELECT 1 FROM #generator_list WHERE generator_id = h.generator_id))
    ORDER BY h.company_id, h.profit_ctr_id, h.customer_id, h.workorder_id DESC
    OPTION (RECOMPILE, MAXDOP 4);

    -- Clean up temporary tables
    IF OBJECT_ID('tempdb..#customer') IS NOT NULL DROP TABLE #customer;
    IF OBJECT_ID('tempdb..#generator_list') IS NOT NULL DROP TABLE #generator_list;
    IF OBJECT_ID('tempdb..#status_filter') IS NOT NULL DROP TABLE #status_filter;
    IF OBJECT_ID('tempdb..#store_number') IS NOT NULL DROP TABLE #store_number;
    IF OBJECT_ID('tempdb..#city') IS NOT NULL DROP TABLE #city;
    IF OBJECT_ID('tempdb..#state') IS NOT NULL DROP TABLE #state;
    IF OBJECT_ID('tempdb..#region') IS NOT NULL DROP TABLE #region;
    IF OBJECT_ID('tempdb..#district') IS NOT NULL DROP TABLE #district;
    IF OBJECT_ID('tempdb..#access_filter') IS NOT NULL DROP TABLE #access_filter;
END

GO

GRANT EXECUTE ON sp_COR_retail_stop_notes TO EQWEB, COR_USER, EQAI
GO

   