--drop proc if exists sp_flash_report_trip_status
go

CREATE PROCEDURE sp_flash_report_trip_status
	@StartDate		          datetime = NULL,
	@EndDate		          datetime = NULL,
    @copc_list                varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@customer_id_list         varchar(500) = NULL,
    @generator_id_list        varchar(500) = NULL,
    @site_code_list           varchar(500) = NULL,
    @trip_id_list             varchar(500) = NULL,
    @workorder_id_list        varchar(500) = NULL,
    @user_code                varchar(100) = NULL, -- for associates
    @contact_id               int = NULL, -- for customers
    @permission_id            int = NULL,
    @debug_flag               int = 0
		
AS
/*****************************************************************************************************
This SP reports status information about trips - no revenue work (which was sp_flash_report_trip_revenue_forecast).

Blatantly stolen, modified, upgraded from sp_flash_report_forecast

------------------------------------------------------------------------------------

8/2/2016	JPB Added null check before fn_convert_manifest_line call to speed it up.
				Addded #shortcut table for speed.
8/3/2016	JPB	Renamed sp_flash_report_trip_status.  Yoinked the revenue work out.
02/08/2021 JPB  DO:17714 - add TSDF Columns to output
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
------------------------------------------------------------------------------------


SAMPLE:
sp_flash_report_trip_status 
	@StartDate		          = '7/25/2016', -- datetime = NULL,
	@EndDate		          = '7/30/2016', -- datetime = NULL,
    @copc_list                = '14|4', -- varchar(500) = NULL, -- ex: 21|1,14|0,14|1
	@customer_id_list         = null, -- varchar(500) = NULL,
    @generator_id_list        = '', -- varchar(500) = NULL,
    @site_code_list           = '', -- varchar(500) = NULL,
    @trip_id_list             = '', -- varchar(500) = NULL,
    @workorder_id_list        = '', -- varchar(500) = NULL,
    @user_code                = 'JONATHAN', -- varchar(100) = NULL, -- for associates
    @contact_id               = -1, --int = NULL, -- for customers
    @permission_id            = 168, --int = NULL,
    @debug_flag               = 0 -- int = 0


sp_flash_report_trip_status 
	@StartDate		          = null, -- datetime = NULL,
	@EndDate		          = null, -- datetime = NULL,
    @copc_list                = '14|14', -- varchar(500) = NULL, -- ex: 21|1,14|0,14|1
	@customer_id_list         = null, -- varchar(500) = NULL,
    @generator_id_list        = '', -- varchar(500) = NULL,
    @site_code_list           = '', -- varchar(500) = NULL,
    @trip_id_list             = '85654', -- varchar(500) = NULL,
    @workorder_id_list        = '', -- varchar(500) = NULL,
    @user_code                = 'JONATHAN', -- varchar(100) = NULL, -- for associates
    @contact_id               = -1, --int = NULL, -- for customers
    @permission_id            = 340, --int = NULL,
    @debug_flag               = 0 -- int = 0


*****************************************************************************************************/
-- Abort if there were no specific parameters given:

/*
-- DEBUG:
-- select top 20 trip_id, company_id, profit_ctr_id from tripheader order by date_added desc
DECLARE
	@StartDate		          datetime = null,
	@EndDate		          datetime = null,
    @copc_list                varchar(500) = '14|6', -- ex: 21|1,14|0,14|1
	@customer_id_list         varchar(500) = null,
    @generator_id_list        varchar(500) = NULL,
    @site_code_list           varchar(500) = NULL,
    @trip_id_list             varchar(500) = '85652',
    @workorder_id_list        varchar(500) = NULL,
    @user_code                varchar(100) = 'JONATHAN', -- for associates
    @contact_id               int = -1, -- for customers
    @permission_id            int = 340,
    @debug_flag               int = 0

*/

drop table if exists #tbl_profit_center_filter
drop table if exists #tbl_generator 
drop table if exists #tbl_SiteCode 
drop table if exists #tbl_trip 
drop table if exists #tbl_workorder 
drop table if exists #SecuredCustomer
drop table if exists #tbl_customer
drop table if exists #tmp_line 
drop table if exists #shortcut 
	
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


IF @debug_flag = 1 BEGIN
	SELECT 
		CASE WHEN @StartDate IS NULL OR @StartDate = '1900-01-01 00:00:00.000' THEN
			0
		ELSE
			len(ltrim(isnull(@StartDate, '')))
		END +
		CASE WHEN @EndDate IS NULL OR @EndDate = '1900-01-01 00:00:00.000' THEN
			0
		ELSE
			len(ltrim(isnull(@EndDate, '')))
		END +
/*		len(ltrim(isnull(@copc_list, ''))) + */
		len(ltrim(isnull(@customer_id_list, ''))) +
		len(ltrim(isnull(@generator_id_list, ''))) +
		len(ltrim(isnull(@site_code_list, ''))) +
		len(ltrim(isnull(@trip_id_list, ''))) +
		len(ltrim(isnull(@workorder_id_list, ''))) AS parameter_length
END

	IF 
		CASE WHEN @StartDate IS NULL OR @StartDate = '1900-01-01 00:00:00.000' THEN
			0
		ELSE
			len(ltrim(isnull(@StartDate, '')))
		END +
		CASE WHEN @EndDate IS NULL OR @EndDate = '1900-01-01 00:00:00.000' THEN
			0
		ELSE
			len(ltrim(isnull(@EndDate, '')))
		END +
/*		len(ltrim(isnull(@copc_list, ''))) + */
		len(ltrim(isnull(@customer_id_list, ''))) +
		len(ltrim(isnull(@generator_id_list, ''))) +
		len(ltrim(isnull(@site_code_list, ''))) +
		len(ltrim(isnull(@trip_id_list, ''))) +
		len(ltrim(isnull(@workorder_id_list, ''))) = 0
		RETURN
	
DECLARE 
	@company_id	int,
	@profit_ctr_id int,
	@wo_id			int,
	@base_rate_quote_id	int,
	@resource_type   	char(1),
	@sequence_id 		int,
	@wo_count			int,
	@project_quote_id	int,
	@customer_quote_id	int,
	@project_code		varchar(15), 
	@customer_id		int,
	@detail_count		int,
	@fixed_price_total	money,
	@fixed_price_amount	money, 
	@fixed_price_count	int,
	@fixed_price_flag	char(1),
	@rowcount			int,
	@cust_discount		decimal(7,2),
	@sql_stmt        	varchar(max),
	@ensr_amt        	money,
	@insr_amt        	money,
	@insr_flag			char(1),
	@billing_project_id int,
	@ensr_flag       	char(1),
	@count_disposal		int,
	@disposal_seq_id	int,
	@max_disposal_seq_id int,
	@receipt_id       	int,
	@receipt_line_id 	int,
	@line_id         	int,
	@max_line_id		int,
	@trans_type			char(1),
	@appr_ensr_exempt	char(1),
	@product_id			int,
	@prod_reg_fee		char(1),
	@apply_surcharge	tinyint,
	@appr_insr_exempt	char(1)
	
-- Fix/Set EndDate's time.
	if isnull(@EndDate,'') <> ''
		if datepart(hh, @EndDate) = 0 set @EndDate = @EndDate + 0.99999

-- Create tables to contain input lists --

   -- Facility:
		create table #tbl_profit_center_filter (
			[company_id] int, 
			profit_ctr_id int,
			base_rate_quote_id int
		)
 
		INSERT #tbl_profit_center_filter 
		SELECT secured_copc.company_id, secured_copc.profit_ctr_id, Profitcenter.base_rate_quote_id
		    FROM SecuredProfitCenter secured_copc (nolock)
		    INNER JOIN (
		        SELECT 
		            RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
		            RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		        from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		        where isnull(row, '') <> '') selected_copc ON 
		            secured_copc.company_id = selected_copc.company_id 
		            AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
		            AND secured_copc.permission_id = @permission_id
		            AND secured_copc.user_code = @user_code
		    INNER JOIN Profitcenter (nolock) on 
		        Profitcenter.company_id = selected_copc.company_id 
		        AND Profitcenter.profit_ctr_id = selected_copc.profit_ctr_id

   -- Customer:
		create table #tbl_customer (customer_id int)
		INSERT #tbl_customer SELECT convert(int, row) FROM dbo.fn_SplitXsvText(',', 0, @customer_id_list) WHERE isnull(row, '') <> ''

   -- Generator:
        create table #tbl_generator (generator_id int)
        INSERT #tbl_generator SELECT convert(int, row) FROM dbo.fn_SplitXsvText(',', 0, @generator_id_list) WHERE isnull(row, '') <> ''

   -- Site Code:
		create table #tbl_SiteCode (site_code varchar(16))
		INSERT #tbl_SiteCode SELECT row FROM dbo.fn_SplitXsvText(',', 0, @site_code_list)  WHERE isnull(row, '') <> ''

   -- Trip ID:
        create table #tbl_trip (trip_id int)
        INSERT #tbl_trip SELECT convert(int, row) FROM dbo.fn_SplitXsvText(',', 0, @trip_id_list) WHERE isnull(row, '') <> ''
        
   -- Workorder ID:
        create table #tbl_workorder (workorder_id int)
        INSERT #tbl_workorder SELECT convert(int, row) FROM dbo.fn_SplitXsvText(',', 0, @workorder_id_list) WHERE isnull(row, '') <> ''


-- Customer security enforcement:
	select distinct customer_id
	into #SecuredCustomer
	from SecuredCustomer sc (nolock)
	where sc.user_code = @user_code
	and sc.permission_id = @permission_id

	create index cui_secured_customer_tmp on #SecuredCustomer(customer_id)

 	if (select count(*) from #tbl_customer) > 0 
 	 delete from #SecuredCustomer 
 	 where customer_id not in (select customer_id from #tbl_customer)


-- create temp tables for data being worked on:
CREATE TABLE #tmp_line (
    company_id  		int NULL,
    profit_ctr_id 		int NULL,
    profit_ctr_name   	varchar(60),
    source_table		varchar(60),	-- Receipt/Workorder...Query type
    trip_id				int,
    trip_sequence_id	int,
    trip_company_id		int,
    trip_profit_ctr_id	int,
    receipt_id 			int,	-- or workorder_id
    resource_type		char(2), -- null for receipts
    line_id 			int,	-- or sequence_id
    workorder_type_id	int,
	project_code 		varchar(15),
	customer_id 		int,
	cust_discount		float,
	generator_id 		int,
	manifest 			varchar(20),
	manifest_line 		int,
    description 		varchar(300),
    processing_note		varchar(100),
    quantity 			float,
	bill_unit_code 		varchar(4),
	account_desc    	varchar(40) NULL,
	pricing_method  	char(1) NULL,
	fixed_price 		char(1) NULL,
    insr_amt    		money,
    ensr_amt    		money,
    revenue     		money,
    tsdf_code			varchar(15),
    progress_flag 		int
)

CREATE TABLE #shortcut (
	workorder_id		int,
	company_id			int,
	profit_ctr_id		int
)

   SET @sql_stmt = '
INSERT #shortcut
select woh.workorder_id, woh.company_id, woh.profit_ctr_id
FROM WorkOrderHeader woh (nolock)  
INNER JOIN #tbl_profit_center_filter tpcf (nolock) on woh.company_id = tpcf.company_id AND woh.profit_ctr_id = tpcf.profit_ctr_id  
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id   and wos.company_id = woh.company_id   and wos.profit_ctr_id = woh.profit_ctr_id   and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */  
WHERE 1=1
'

 	IF isnull(@StartDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) >= ''' + convert(varchar(40), @StartDate, 121) + '''
'

    IF isnull(@EndDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) <= ''' + convert(varchar(40), @EndDate, 121) + '''
'

 	IF exists (select 1 from #tbl_generator) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from #tbl_generator)
'
 	
    IF exists (select 1 from #tbl_SiteCode) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from generator where site_code in (select site_code from #tbl_SiteCode))
'

    IF exists (select 1 from #tbl_trip) set @sql_stmt = @sql_stmt + '
    AND woh.trip_id in (select trip_id from #tbl_trip)
'

    IF exists (select 1 from #tbl_workorder) set @sql_stmt = @sql_stmt + '
    AND woh.workorder_id in (select workorder_id from #tbl_workorder)
'

IF @debug_flag = 1 SELECT @sql_stmt AS sql_stmt

EXEC (@sql_stmt)


-- Compose the SQL Statement that will select header records for the work in process.
-- Workorder Info:
   SET @sql_stmt = '
INSERT #tmp_line
SELECT
    wod.company_id,
	wod.profit_ctr_id,
	pc.profit_ctr_name,
	''Workorder, NON fixed price (Q1)'',
	woh.trip_id,
	woh.trip_sequence_id,
	woh.company_id,
	woh.profit_ctr_id,
	wod.workorder_id,
	wod.resource_type,
	wod.sequence_id,
	woh.workorder_type_id,
	woh.project_code,
	woh.customer_id,
	null as cust_discount,
	woh.generator_id,
	wod.manifest,
	CASE WHEN isnull(wod.manifest_line, '''') <> '''' THEN
	    CASE WHEN IsNumeric(wod.manifest_line) <> 1 THEN
	        CASE WHEN (wod.manifest_line is null OR wod.manifest_page_num is null) then 0 else dbo.fn_convert_manifest_line(wod.manifest_line, wod.manifest_page_num) end
	    ELSE
	        wod.manifest_line
	    END
	ELSE
	    NULL
	END AS manifest_line,
	wod.description,
	null as processing_note,
	COALESCE(wodu.quantity, wod.quantity_used, wod.quantity, 0) as quantity,
	COALESCE(wodu.bill_unit_code, wod.bill_unit_code) as bill_unit_code,
	null as account_desc,
    null as pricing_method,
    ''F'' as fixed_price,
    null as insr_amt,
    null as ensr_amt,
    null as revenue,
    wod.tsdf_code,
    0 as progress_flag
FROM #shortcut cut
INNER JOIN WorkOrderHeader woh (nolock) on cut.workorder_id = woh.workorder_id and cut.company_id = woh.company_id and cut.profit_ctr_id = woh.profit_ctr_id
INNER JOIN WorkOrderDetail wod (nolock) on woh.workorder_id = wod.workorder_id
      AND woh.company_id = wod.company_id
      AND woh.profit_ctr_id = wod.profit_ctr_id
      AND isnull(woh.fixed_price_flag, ''F'') = ''F''
      and wod.bill_rate > -2
      AND NOT EXISTS (
		SELECT 1
		FROM WorkorderQuoteHeader (nolock)
		WHERE project_code = woh.project_code
		AND quote_type = ''P''
		AND company_id = woh.company_id
		AND fixed_price_flag = ''T''
      )
INNER JOIN ProfitCenter pc (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
LEFT JOIN WorkorderDetailUnit wodu (nolock)
	on wod.workorder_id = wodu.workorder_id
	and wod.company_id = wodu.company_id
	and wod.profit_ctr_id = wodu.profit_ctr_id
	and wod.sequence_id = wodu.sequence_id
	and wodu.quantity > 0
	and wodu.billing_flag = ''T''
	and wod.resource_type = ''D''
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      AND woh.trip_id is not null
'

 	IF isnull(@StartDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) >= ''' + convert(varchar(40), @StartDate, 121) + '''
'

    IF isnull(@EndDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) <= ''' + convert(varchar(40), @EndDate, 121) + '''
'

 	IF exists (select 1 from #tbl_generator) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from #tbl_generator)
'
 	
    IF exists (select 1 from #tbl_SiteCode) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from generator where site_code in (select site_code from #tbl_SiteCode))
'

    IF exists (select 1 from #tbl_trip) set @sql_stmt = @sql_stmt + '
    AND woh.trip_id in (select trip_id from #tbl_trip)
'

    IF exists (select 1 from #tbl_workorder) set @sql_stmt = @sql_stmt + '
    AND woh.workorder_id in (select workorder_id from #tbl_workorder)
'

-- Linked Receipt Info:
set @sql_stmt = @sql_stmt + ' UNION
SELECT
    r.company_id,
	r.profit_ctr_id,
	pc.profit_ctr_name,
	''Receipt linked from workorder (Q2)'',
	woh.trip_id,
	woh.trip_sequence_id,
	woh.company_id,
	woh.profit_ctr_id,
	r.receipt_id,
	null,
	r.line_id,
	woh.workorder_type_id,
	woh.project_code,
	woh.customer_id,
	null as cust_discount,
	r.generator_id,
	r.manifest,
	r.manifest_line,
	isnull(p.approval_desc, pr.description),
	CASE WHEN th.trip_status <> ''C'' THEN
		''Receipt info shown is invalid - Trip is not Complete''
	ELSE
		null
	END as processing_note,
	rp.bill_quantity,
	rp.bill_unit_code,
	null as account_desc,
    null as pricing_method,
    ''F'' as fixed_price,
    null as insr_amt,
    null as ensr_amt,
	null total_extended_amt,
	(
		select top 1 tsdf_code 
		from tsdf 
		WHERE eq_company = r.company_id and eq_profit_ctr = r.profit_ctr_id and eq_flag = ''T'' and tsdf_status = ''A''
	) tsdf_code,
    0 as progress_flag
FROM #shortcut cut
INNER JOIN WorkOrderHeader woh (nolock) on cut.workorder_id = woh.workorder_id and cut.company_id = woh.company_id and cut.profit_ctr_id = woh.profit_ctr_id
INNER JOIN TripHeader th  (nolock) on woh.trip_id = th.trip_id
	AND woh.company_id = th.company_id
	AND woh.profit_ctr_id = th.profit_ctr_id
INNER JOIN ProfitCenter pc  (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
INNER JOIN BillingLinkLookup bll (nolock) 
	ON woh.workorder_id = bll.source_id
	AND woh.company_id = bll.source_company_id
	AND woh.profit_ctr_id = bll.source_profit_ctr_id
INNER JOIN Receipt r (nolock) 
	ON bll.receipt_id = r.receipt_id
	AND bll.company_id = r.company_id
	AND bll.profit_ctr_id = r.profit_ctr_id
	AND r.receipt_status <> ''V''
	AND r.fingerpr_status <> ''V''
INNER JOIN ReceiptPrice rp (nolock) 
	ON r.receipt_id = rp.receipt_id
	AND r.company_id = rp.company_id
	AND r.profit_ctr_id = rp.profit_ctr_id
	AND r.line_id = rp.line_id
LEFT OUTER JOIN Profile p  (nolock) on r.profile_id = p.profile_id
LEFT OUTER JOIN Product pr  (nolock) on r.product_id = pr.product_id and r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      AND woh.trip_id is not null
      AND isnull(woh.fixed_price_flag, ''F'') = ''F''
      AND NOT EXISTS (
		SELECT 1
		FROM WorkorderQuoteHeader (nolock)
		WHERE project_code = woh.project_code
		AND quote_type = ''P''
		AND company_id = woh.company_id
		AND fixed_price_flag = ''T''
      )
'

 	IF isnull(@StartDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) >= ''' + convert(varchar(40), @StartDate, 121) + '''
'

    IF isnull(@EndDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) <= ''' + convert(varchar(40), @EndDate, 121) + '''
'

 	IF exists (select 1 from #tbl_generator) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from #tbl_generator)
'
 	
    IF exists (select 1 from #tbl_SiteCode) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from generator where site_code in (select site_code from #tbl_SiteCode))
'

    IF exists (select 1 from #tbl_trip) set @sql_stmt = @sql_stmt + '
    AND woh.trip_id in (select trip_id from #tbl_trip)
'

    IF exists (select 1 from #tbl_workorder) set @sql_stmt = @sql_stmt + '
    AND woh.workorder_id in (select workorder_id from #tbl_workorder)
'

-- Fixed Price WO info:
set @sql_stmt = @sql_stmt + ' UNION
SELECT
    woh.company_id,
    woh.profit_ctr_id,
    pc.profit_ctr_name,
    ''Workorders with FIXED PRICE (Q3)'',
    woh.trip_id,
    woh.trip_sequence_id,
    woh.company_id,
    woh.profit_ctr_id,
    woh.workorder_id,
    ''X'' as resource_type,
    1 as sequence_id,
    woh.workorder_type_id,
    woh.project_code,
    woh.customer_id,
	null as cust_discount,
    woh.generator_id,
    NULL as manifest,
    NULL AS manifest_line,
    ''Fixed Price Item'' as description,
    NULL as processing_note,
    1 AS quantity,
    NULL as bill_unit_code,
    null as account_desc,
    null as pricing_method,
    ''T'' as fixed_price,
    null as insr_amt,
    null as ensr_amt,
    null as revenue,
    null as tsdf_code,
    0 as progress_flag
FROM #shortcut cut
INNER JOIN WorkOrderHeader woh (nolock) on cut.workorder_id = woh.workorder_id and cut.company_id = woh.company_id and cut.profit_ctr_id = woh.profit_ctr_id
INNER JOIN ProfitCenter pc  (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      AND woh.trip_id is not null
      AND (
		  isnull(woh.fixed_price_flag, ''F'') = ''T''
		  OR EXISTS (
			SELECT 1
			FROM WorkorderQuoteHeader (nolock) 
			WHERE project_code = woh.project_code
			AND quote_type = ''P''
			AND company_id = woh.company_id
			AND fixed_price_flag = ''T''
		  )
	  )
'

 	IF isnull(@StartDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) >= ''' + convert(varchar(40), @StartDate, 121) + '''
'

    IF isnull(@EndDate, '') <> '' set @sql_stmt = @sql_stmt + '
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, woh.end_date) <= ''' + convert(varchar(40), @EndDate, 121) + '''
'

    IF exists (select 1 from #tbl_generator) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from #tbl_generator)
'
    
    IF exists (select 1 from #tbl_SiteCode) set @sql_stmt = @sql_stmt + '
    AND woh.generator_id in (select generator_id from generator  (nolock) where site_code in (select site_code from #tbl_SiteCode))
'

    IF exists (select 1 from #tbl_trip) set @sql_stmt = @sql_stmt + '
    AND woh.trip_id in (select trip_id from #tbl_trip)
'

    IF exists (select 1 from #tbl_workorder) set @sql_stmt = @sql_stmt + '
    AND woh.workorder_id in (select workorder_id from #tbl_workorder)
'

IF @debug_flag = 1 SELECT @sql_stmt AS sql_stmt

EXEC (@sql_stmt)


-- How many Work orders did we get?
SELECT @wo_count = count(*) from #tmp_line

IF @debug_flag = 1 PRINT 'Selecting from #tmp_line: Work order line count ' + CONVERT(varchar(40), @wo_count)
IF @debug_flag = 1 SELECT * FROM #tmp_line




if @debug_flag = 1 BEGIN
	PRINT 'before setting nulls to 0'
	SELECT * from #tmp_line
END

update #tmp_line SET
       revenue = isnull(revenue, 0),
       insr_amt = isnull(insr_amt, 0),
       ensr_amt = isnull(ensr_amt, 0)
       

if @debug_flag = 1 BEGIN
	PRINT 'after setting nulls to 0'
	SELECT * from #tmp_line
END

-- Output the #tmp_line record
SELECT 
	th.trip_id,
	th.company_id as trip_company_id,
	th.profit_ctr_id as trip_profit_ctr_id,
	th.trip_desc,
	th.driver_name,
	CASE th.trip_status
		WHEN 'N' then 'New'
		WHEN 'D' then 'Dispatched'
		WHEN 'H' then 'Hold'
		WHEN 'V' then 'Void'
		WHEN 'C' then 'Complete'
		WHEN 'A' then 'Arrived'
		WHEN 'U' then 'Unloading'
		ELSE 'Unknown'
	END as trip_status,
	th.trip_start_date,
	th.trip_end_date,
	t.company_id,
	t.profit_ctr_id,
	t.trip_sequence_id,
	t.source_table,
	t.receipt_id,
	t.resource_type,
	t.line_id,
	t.customer_id,
	cust.cust_name,
	cust.cust_city,
	cust.cust_state,
	cust.cust_zip_code,
	t.generator_id,
	gen.generator_name,
	gen.epa_id,
	gen.generator_city,
	gen.generator_state,
	gen.generator_zip_code,
	gen.site_code,
	gen.site_type,
	gst.generator_site_type,
	woth.account_desc,
	t.project_code,
	CASE WHEN source_table like 'W%' THEN
		CASE isnull(woh.workorder_status, r.receipt_status)
			WHEN 'A' THEN 'Accepted'
			WHEN 'C' THEN 'Completed'
			WHEN 'D' THEN 'Dispatched'
			WHEN 'N' THEN 'New'
			WHEN 'P' THEN 'Priced'
			WHEN 'T' THEN 'Template'
			WHEN 'V' THEN 'Void'
			WHEN 'X' THEN 'Trip'
			ELSE 'New'
		END
	ELSE
		CASE isnull(woh.workorder_status, r.receipt_status)
			WHEN 'A' THEN 'Accepted'
			WHEN 'I' THEN 'Unknown'
			WHEN 'L' THEN 'In the Lab'
			WHEN 'M' THEN 'Manual'
			WHEN 'N' THEN 'New'
			WHEN 'R' THEN 'Rejected'
			WHEN 'T' THEN 'In-Transit'
			WHEN 'U' THEN 'Unloading'
			WHEN 'V' THEN 'Void'		
			ELSE 'New'
		END
	END as status,
	t.manifest,
	t.manifest_line,
	CASE WHEN t.receipt_id is null THEN
		'Incomplete/Missing Workorder or Receipt information'
	ELSE
		CASE WHEN t.processing_note IS NULL THEN
			t.description
		ELSE
			t.description + ' NOTE: ' + t.processing_note
		END
	END as description,
	t.quantity,
	t.bill_unit_code,
	wos.date_act_arrive,
	wos.date_act_depart,
	t.account_desc,
	isnull(woh.purchase_order, r.purchase_order) as purchase_order,
	tsdf.TSDF_code,
	tsdf.TSDF_name ,
	tsdf.TSDF_addr1 ,
	tsdf.TSDF_addr2 ,
	tsdf.TSDF_addr3 ,
	tsdf.TSDF_EPA_ID ,
	tsdf.TSDF_phone ,
	tsdf.TSDF_contact_phone ,
	tsdf.TSDF_city ,
	tsdf.TSDF_state ,
	tsdf.TSDF_zip_code,
	tsdf.TSDF_country_code
FROM #tmp_line t
INNER JOIN WorkOrderTypeHeader woth (nolock)
	ON woth.workorder_type_id = t.workorder_type_id
	inner join TripHeader th (nolock) 
		ON th.trip_id = t.trip_id
		AND th.company_id = t.trip_company_id
		AND th.profit_ctr_id = t.trip_profit_ctr_id
	LEFT outer join WorkOrderHeader woh (nolock) 
		on t.receipt_id = woh.workorder_id
		and t.company_id = woh.company_id
		and t.profit_ctr_id = woh.profit_ctr_id
		AND t.source_table like 'workorder%'
	LEFT outer join Receipt r (nolock) 
		on t.receipt_id = r.receipt_id
		and t.line_id = r.line_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		AND t.source_table like 'receipt%'
	LEFT OUTER JOIN WorkOrderHeader woh2 (nolock) 
		ON th.trip_id = woh2.trip_id
		AND th.company_id = woh2.company_id
		AND th.profit_ctr_id = woh2.profit_ctr_id
		AND woh2.trip_sequence_id = t.trip_sequence_id
	LEFT OUTER JOIN Customer cust (nolock) 
		ON t.customer_id = cust.customer_id
	LEFT OUTER JOIN Generator gen (nolock) 
		ON t.generator_id = gen.generator_id
	LEFT OUTER JOIN GeneratorSiteType gst (nolock) 
		ON gen.site_type = gst.generator_site_type_abbr
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh2.workorder_id
		and wos.company_id = woh2.company_id
		and wos.profit_ctr_id = woh2.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	LEFT JOIN TSDF (nolock)
		on t.tsdf_code = tsdf.tsdf_code
WHERE 1=1
ORDER BY 
	t.trip_id, 
	t.trip_sequence_id, 
	t.receipt_id, 
	t.line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_status] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_status] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_status] TO [EQAI]
    AS [dbo];

