CREATE PROCEDURE sp_flash_report_trip_forecast
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
This SP summarizes the revenue from all stages of work orders that relate to Trips.  
Work Orders that have not yet been priced are calculated as if they have been priced

Blatantly stolen, modified, upgraded from sp_flash_report_forecast

------------------------------------------------------------------------------------

Notes related to it's design:
	GEM:15088 Flash report for workorders related to trips that aren't necessarily complete yet...
	 
	Create a report that shows the prices per stop for trips.
	 
	Once the trip is complete, the (disposal) data is only valid when it comes from:
		EQ Facilities - receipts 
		3rd Party TSDF: TSDFApproval (price * quanity_used, for the wod bill unit)
	 
	Before the trip is complete, it must be dispatched, and the field
	    WorkorderHeader.trip_act_departure must be set.
        The report data comes from workorderdetail combined with the quotes 
        Which quote?  See the money bag (EQAI: Apply Prices - which Jason said 
              is also done in sp_flash_report_forecast).
	 
	Consider writing a function that does what the Apply Prices button does, so 
	      it can be used in EQAI or the report.
	 
	Try to make as many select criteria fields available as possible:
        Workorder ID, Trip ID, Date Range, Customer, Generator, Site Code, Facility etc
	 
	When returning data, show as many fields as possible:
        Workorder Status,  
        trip, 
        workorder, 
        actual arrive, 
        actual depart, 
        site code, 
        city, 
        state, 
        zip, 
        gen name,
        PO etc) 
        "*" next to calculated totals, etc.  
        Total per workorder (stop) etc... Also include line descriptions.
        insr_surcharge, - note whether they're exempt based on the billing project that's assigned.
        ensr_surcharge - note whether they're exempt based on the billing project that's assigned.

	Secure this report by workorder... apply the filtering to the workorder, 
	    you can see whatever info you need from the receipt in any company, 
	    if have access to workorder its related to.

	-- Changes:12/20/2010 11:05:53 AM

	12/20/2010 - JPB - Modified so that it will Calculate prices on trips not just in Dispatched status,
		but in Dispatched, Arrived or Unloading.
		
01/12/2012 SK	Changed to use the new WorkOrderTypeHeader.workorder_type_id (GL standardization project)
1/19/2012 - JPB Modified the output of date_act_arrive and date_act_depature so they don't get aliases.		
07/14/2014 - JPB	Add Driver Name to output
01/05/2015  AM  Added billing_project_id parameter to fn_get_ensr_percent function.
------------------------------------------------------------------------------------

    sp_flash_report_trip_forecast history:
        09/28/2010 JPB  Created
        10/19/2010 JPB  Added calculation of pre-completed trips' manifest-only lines
        10/20/2010 JPB  Fix: Don't calculate pre-completed manifest-only prices on already-completed trips
        10/21/2010 JPB  Fix: Date comparison changed from woh.end_date to
        	COALESCE(woh.trip_act_departure, woh.date_est_departure, woh.end_date)

	    sp_flash_report_forecast history:
			11/27/2000 SCC	Created
			06/15/2001 LJT	Added a dummy record to the #tmp_revenue just in case 
			  		there were no detail lines to be priced. 
					The workorder wouldshow up with a total of 0.
			06/03/2003 JDB	Added profit_ctr_id to TSDFApproval.
			04/14/2005 JDB	Added bill_unit_code for TSDFApproval
			07/17/2006 RG	revised for quoteheader qoutedetail
			07/24/2006 RG   fixed issues wt tsdf approval view changes
			03/27/2007 JDB	Fixed join between WorkOrderDetail and TSDFApproval 
			  		for disposal calculations.
					Added "AND d.bill_rate > 0" to the WHERE clause for Disposal 
					(formerly it was retrieving MAN Only, which is bill_rate = -1)
					Added support for Work Orders that use Profiles.
					Modified calculation to first get pricing from the work order 
					line, then calculate from either the resource class, TSDF 
					Approval, or Profile.  See "CASE resource_type"	and 
					"COALESCE(d.price, pqd.price)".
			04/16/2007 SCC	Changed to use workorderheader.submitted_flag and 
			  		CustomerBilling.territory_code
			04/06/2010 RJG	Changed WorkOrderQuoteDetail references to join 
			  		against the "WorkOrderQuoteDetail" and have it use company_id 
			  		as well as profit_ctr_id
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
		sp_flash_report_trip_forecast '3-04-2007 00:00:00','3-6-2007 23:59:59', 10673, 10673, 0 , '99', 1
		sp_flash_report_trip_forecast '11-01-2014 00:00:00','3-21-2014 23:59:59', 10000, 10673, 0 , '99', 1

SAMPLE:
sp_flash_report_trip_forecast 
	@StartDate		          = '6/4/2014', -- datetime = NULL,
	@EndDate		          = '7/1/2014', -- datetime = NULL,
    @copc_list                = '14|4', -- varchar(500) = NULL, -- ex: 21|1,14|0,14|1
	@customer_id_list         = '10673', -- varchar(500) = NULL,
    @generator_id_list        = '', -- varchar(500) = NULL,
    @site_code_list           = '', -- varchar(500) = NULL,
    @trip_id_list             = '', -- varchar(500) = NULL,
    @workorder_id_list        = '', -- varchar(500) = NULL,
    @user_code                = 'JONATHAN', -- varchar(100) = NULL, -- for associates
    @contact_id               = -1, --int = NULL, -- for customers
    @permission_id            = 168, --int = NULL,
    @debug_flag               = 0 -- int = 0

sp_flash_report_trip_forecast 
	@StartDate		          = null, -- datetime = NULL,
	@EndDate		          = null, -- datetime = NULL,
    @copc_list                = '15|4', -- varchar(500) = NULL, -- ex: 21|1,14|0,14|1
	@customer_id_list         = null, -- varchar(500) = NULL,
    @generator_id_list        = '', -- varchar(500) = NULL,
    @site_code_list           = '', -- varchar(500) = NULL,
    @trip_id_list             = '25003', -- varchar(500) = NULL,
    @workorder_id_list        = '', -- varchar(500) = NULL,
    @user_code                = 'JONATHAN', -- varchar(100) = NULL, -- for associates
    @contact_id               = -1, --int = NULL, -- for customers
    @permission_id            = 168, --int = NULL,
    @debug_flag               = 0 -- int = 0


*****************************************************************************************************/
-- Abort if there were no specific parameters given:

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
		INSERT #tbl_customer SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_id_list) WHERE isnull(row, '') <> ''

   -- Generator:
        create table #tbl_generator (generator_id int)
        INSERT #tbl_generator SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 0, @generator_id_list) WHERE isnull(row, '') <> ''

   -- Site Code:
		create table #tbl_SiteCode (site_code varchar(16))
		INSERT #tbl_SiteCode SELECT row from dbo.fn_SplitXsvText(',', 0, @site_code_list)  WHERE isnull(row, '') <> ''

   -- Trip ID:
        create table #tbl_trip (trip_id int)
        INSERT #tbl_trip SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 0, @trip_id_list) WHERE isnull(row, '') <> ''
        
   -- Workorder ID:
        create table #tbl_workorder (workorder_id int)
        INSERT #tbl_workorder SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 0, @workorder_id_list) WHERE isnull(row, '') <> ''


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
CREATE TABLE #tmp_price (
    company_id          int         NULL,
    profit_ctr_id       int         NULL,
    workorder_id        int,
    resource_type       char(1),
    sequence_id         int,
    bill_rate           float       NULL,
    quantity            float       NULL,
    resource_to_price   varchar(10) NULL,
    group_code          varchar(10) NULL,
    group_instance_id   int         NULL,
    price               money       NULL,
    priced_flag         int         NULL
)

CREATE TABLE #tmp_revenue (
    revenue     money NULL,
    account_desc    varchar(40) NULL,
    company_id  int NULL,
    profit_ctr_id int NULL,
    workorder_id    int NULL,
    resource_type   char(1),
    sequence_id int,
    pricing_method  char(1) NULL,
    fixed_price char(1) NULL,
    ensr_amt	money,
    insr_amt	money,
    bill_rate	float
)

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
    progress_flag 		int
)

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
	cb.cust_discount,
	woh.generator_id,
	wod.manifest,
	CASE WHEN isnull(wod.manifest_line, '''') <> '''' THEN
	    CASE WHEN IsNumeric(wod.manifest_line) <> 1 THEN
	        dbo.fn_convert_manifest_line(wod.manifest_line, wod.manifest_page_num)
	    ELSE
	        wod.manifest_line
	    END
	ELSE
	    NULL
	END AS manifest_line,
	wod.description,
	null as processing_note,
	ISNULL( 
	    CASE
	            WHEN wod.quantity_used IS NULL
	            THEN IsNull(wod.quantity,0)
	            ELSE wod.quantity_used
	    END
	, 0) AS quantity,
	wod.bill_unit_code,
	null as account_desc,
    null as pricing_method,
    ''F'' as fixed_price,
    null as insr_amt,
    null as ensr_amt,
    null as revenue,
    0 as progress_flag
FROM WorkOrderHeader woh (nolock)
INNER JOIN #tbl_profit_center_filter tpcf (nolock) on woh.company_id = tpcf.company_id
      AND woh.profit_ctr_id = tpcf.profit_ctr_id
INNER JOIN #SecuredCustomer sc on woh.customer_id = sc.customer_id
INNER JOIN CustomerBilling cb (nolock) ON woh.customer_id = cb.customer_id
      AND ISNULL(woh.billing_project_id, 0) = cb.billing_project_id
INNER JOIN WorkOrderDetail wod (nolock) on woh.workorder_id = wod.workorder_id
      AND woh.company_id = wod.company_id
      AND woh.profit_ctr_id = wod.profit_ctr_id
      AND isnull(woh.fixed_price_flag, ''F'') = ''F''
      AND NOT EXISTS (
		SELECT 1
		FROM WorkorderQuoteHeader (nolock)
		WHERE project_code = woh.project_code
		AND quote_type = ''P''
		AND company_id = woh.company_id
		AND fixed_price_flag = ''T''
      )
INNER JOIN TripHeader th (nolock)
	on woh.trip_id = th.trip_id
	and woh.company_id = th.company_id
	and woh.profit_ctr_id = th.profit_ctr_id
INNER JOIN ProfitCenter pc (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      /* AND woh.workorder_status IN (''N'', ''C'', ''D'') */
      AND woh.trip_id is not null
/*      
      AND isnull(woh.trip_act_departure, ''1/1/1900'') > ''1/1/1901''
      AND not exists (select 1 from BillingLinkLookup (nolock) where
      	source_id = woh.workorder_id
      	and source_company_id = woh.company_id
      	and source_profit_ctr_id = woh.profit_ctr_id
      )
*/      
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
	cb.cust_discount,
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
	rp.total_extended_amt,
    0 as progress_flag
FROM WorkOrderHeader woh (nolock)
INNER JOIN #tbl_profit_center_filter tpcf (nolock) on woh.company_id = tpcf.company_id
      AND woh.profit_ctr_id = tpcf.profit_ctr_id
INNER JOIN #SecuredCustomer sc on woh.customer_id = sc.customer_id
INNER JOIN CustomerBilling cb  (nolock) ON woh.customer_id = cb.customer_id
      AND ISNULL(woh.billing_project_id, 0) = cb.billing_project_id
INNER JOIN TripHeader th  (nolock) on woh.trip_id = th.trip_id
	AND woh.company_id = th.company_id
	AND woh.profit_ctr_id = th.profit_ctr_id
INNER JOIN ProfitCenter pc  (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
INNER JOIN BillingLinkLookup bll (nolock) 
	ON woh.workorder_id = bll.source_id
	AND woh.company_id = bll.source_company_id
	AND woh.profit_ctr_id = bll.source_profit_ctr_id
	/* AND th.trip_status = ''C'' */
INNER JOIN Receipt r (nolock) 
	ON bll.receipt_id = r.receipt_id
	AND bll.company_id = r.company_id
	AND bll.profit_ctr_id = r.profit_ctr_id
	/* AND wod.profile_id = r.profile_id */
	/* AND th.trip_status = ''C'' */
	AND r.receipt_status <> ''V''
	AND r.fingerpr_status <> ''V''
INNER JOIN ReceiptPrice rp (nolock) 
	ON r.receipt_id = rp.receipt_id
	AND r.company_id = rp.company_id
	AND r.profit_ctr_id = rp.profit_ctr_id
	AND r.line_id = rp.line_id
	/* AND th.trip_status = ''C'' */
LEFT OUTER JOIN Profile p  (nolock) on r.profile_id = p.profile_id
LEFT OUTER JOIN Product pr  (nolock) on r.product_id = pr.product_id and r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN Generator gen  (nolock) on r.generator_id = gen.generator_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      /* AND woh.workorder_status IN (''N'', ''C'', ''D'')  */
      AND woh.trip_id is not null
/*      AND isnull(woh.trip_act_departure, ''1/1/1900'') > ''1/1/1901'' */
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
	cb.cust_discount,
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
    0 as progress_flag
FROM WorkOrderHeader woh (nolock) 
INNER JOIN #tbl_profit_center_filter tpcf  (nolock) on woh.company_id = tpcf.company_id
      AND woh.profit_ctr_id = tpcf.profit_ctr_id
INNER JOIN #SecuredCustomer sc on woh.customer_id = sc.customer_id
INNER JOIN CustomerBilling cb  (nolock) ON woh.customer_id = cb.customer_id
      AND ISNULL(woh.billing_project_id, 0) = cb.billing_project_id
INNER JOIN TripHeader th  (nolock) on woh.trip_id = th.trip_id
	AND woh.company_id = th.company_id
	AND woh.profit_ctr_id = th.profit_ctr_id
INNER JOIN ProfitCenter pc  (nolock) on woh.company_id = pc.company_id and woh.profit_ctr_id = pc.profit_ctr_id
LEFT OUTER JOIN Generator gen  (nolock) on woh.generator_id = gen.generator_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
	and wos.company_id = woh.company_id
	and wos.profit_ctr_id = woh.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
      /* AND woh.workorder_status IN (''N'', ''C'', ''D'') */
      AND woh.trip_id is not null
/*      AND isnull(woh.trip_act_departure, ''1/1/1900'') > ''1/1/1901'' */
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


-- Try to apply prices from billing for the records we got.
IF @debug_flag = 1 PRINT 'Attempting to update prices from Billing for Receipts:'
	-- first those with receipts:
	update #tmp_line set 
		revenue = total_extended_amt,
		insr_amt = insr_extended_amt,
		ensr_amt = ensr_extended_amt,
		progress_flag = 3
	from #tmp_line t
	inner join billing b (nolock) 
		on b.receipt_id = t.receipt_id
		and b.line_id = t.line_id
		and b.company_id = t.company_id
		and b.profit_ctr_id = t.profit_ctr_id
		and b.bill_unit_code = t.bill_unit_code
		and b.trans_source = 'R'
	where t.source_table like 'R%'
		and t.progress_flag = 0
IF @debug_flag = 1 select * from #tmp_line where progress_flag = 1 and source_table like 'R%'

IF @debug_flag = 1 PRINT 'Attempting to update prices from Billing for Workorders:'
	update #tmp_line set 
		revenue = total_extended_amt,
		insr_amt = insr_extended_amt,
		ensr_amt = ensr_extended_amt,
		progress_flag = 3
	from #tmp_line t
	inner join billing b (nolock) 
		on b.receipt_id = t.receipt_id
		and b.workorder_resource_type = t.resource_type
		and b.company_id = t.company_id
		and b.profit_ctr_id = t.profit_ctr_id
		and b.workorder_sequence_id = t.line_id
		and b.trans_source = 'W'
	where t.source_table like 'W%'
		and t.progress_flag = 0
IF @debug_flag = 1 select * from #tmp_line where progress_flag = 1 and source_table like 'W%'

-- Calculate prices for each work order
WHILE EXISTS (select 1 from #tmp_line where source_table like 'workorder%' and progress_flag = 0)
BEGIN

    delete from #tmp_revenue

    -- Get info on a work order
    SELECT TOP 1
        @company_id = company_id,
        @profit_ctr_id = profit_ctr_id,
        @wo_id = receipt_id,
        @project_code = project_code, 
        @customer_id = customer_id,
        @cust_discount = ROUND(cust_discount, 2),
        @fixed_price_flag = fixed_price
    FROM #tmp_line 
    WHERE source_table like 'workorder%' and progress_flag = 0

IF @debug_flag = 1 BEGIN
   PRINT 'Company ID ' + CONVERT(varchar(40), @company_id)
   PRINT 'Profit Center ID ' + CONVERT(varchar(40), @profit_ctr_id)
   PRINT 'Work order ID ' + CONVERT(varchar(40), @wo_id)
   PRINT 'Customer ID: ' + CONVERT(varchar(40), @customer_id) + ' and discount: ' + CONVERT(varchar(30), @cust_discount)
END

	-- SELECT the base rate quote
	SELECT @base_rate_quote_id = base_rate_quote_id
	FROM profitcenter  (nolock) 
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id

	-- Get the quote ID for project_code
	IF @project_code IS NULL
	BEGIN
		SET @project_quote_id = 0
	END
	ELSE
		SELECT @project_quote_id = quote_id
		FROM WorkorderQuoteHeader (nolock) 
		WHERE project_code = @project_code
		AND quote_type = 'P'
		AND company_id = @company_id
		-- WOQH selects should *not* use profit_ctr_id.

IF @debug_flag = 1 PRINT 'Project Quote: ' + CONVERT(varchar(40), @project_quote_id)

	---------------------------
	-- Fixed Price Workorder --
	---------------------------
	IF @fixed_price_flag = 'T'
	BEGIN
		-- Get the amounts already priced
		SELECT @fixed_price_total = SUM(woh.total_price), 
			@fixed_price_count = COUNT(woh.total_price)
		FROM WorkOrderHeader woh (nolock) 
		WHERE woh.quote_id = @project_quote_id
		AND woh.company_id = @company_id
		AND woh.workorder_status IN ('A', 'P')

		IF @fixed_price_count = 0
			SELECT @fixed_price_amount = 0
		ELSE
			SELECT @fixed_price_amount = @fixed_price_total / @fixed_price_count

		-- If no Workorders have yet billed from the fixed price quote,
		-- get the entire fixed price amount from the quote
		IF @fixed_price_count = 0
		BEGIN
			SELECT @fixed_price_total = fixed_price
				FROM WorkorderQuoteHeader  (nolock) 
				WHERE quote_id = @project_quote_id
		        AND company_id = @company_id
        
			-- How many workorders are we processing under this project quote?
			SELECT @fixed_price_count = COUNT(distinct workorder_id)
				FROM #tmp_line 
				WHERE project_code = @project_code
		        AND company_id = @company_id
				
			-- Divvy total amount between workorders to be processed here
			IF @fixed_price_count = 0
				SELECT @fixed_price_amount = @fixed_price_total
			ELSE
				SELECT @fixed_price_amount = @fixed_price_total / @fixed_price_count
		END
		
		IF @debug_flag = 1 PRINT 'fixed price total: ' + CONVERT(varchar(40), @fixed_price_total )
			+ ' fixed price count: ' + CONVERT(varchar(40), @fixed_price_count )
			+ ' fixed price amount: ' + CONVERT(varchar(40), @fixed_price_amount )

		-- Insert a record for the forecasted amount
		INSERT #tmp_revenue (
			revenue,
			account_desc, 
			company_id,
			profit_ctr_id,
			workorder_id,
			resource_type,
			sequence_id,
			pricing_method,
			fixed_price,
			ensr_amt,
			insr_amt,
			bill_rate	)
		SELECT @fixed_price_amount, 
			WOTH.account_desc, 
			t.company_id,
			t.profit_ctr_id,
			t.receipt_id,
			t.resource_type,
			t.line_id,
			'C', 
			'T',
			null,
			null,
			null
		FROM #tmp_line t 
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = t.workorder_type_id
		--inner join glaccount g (nolock) 
		--	ON t.workorder_type = g.account_type
		--	AND g.account_class = 'O'
		--	AND g.profit_ctr_id = t.profit_ctr_id
		--	AND g.company_id = t.company_id
		WHERE
            t.receipt_id = @wo_id
			AND t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
	END

	------------------------------
	-- Regular Priced Workorder --
	------------------------------
	IF @fixed_price_flag = 'F'
	BEGIN

		-- Get the quote ID for customer
		SELECT @customer_quote_id = ISNULL(quote_id, 0)
		FROM WorkorderQuoteHeader  (nolock) 
		WHERE quote_id = @customer_id
		AND company_id = @company_id
		AND quote_type = 'C'
		-- WOQH selects should NOT use profit_ctr_id

		IF @@ROWCOUNT = 0 SELECT @customer_quote_id = 0
	
		IF @debug_flag = 1 PRINT 'Customer Quote: ' + CONVERT(varchar(40), @customer_quote_id)

		-- Delete any previously priced lines
		DELETE FROM #tmp_price

		-- Get Detail lines to forecast pricing.  Price based on resource class.
		-- The price is retrieved to pick any 'Other' detail line pricing
		
		INSERT #tmp_price 
		SELECT 
		 	company_id,
		 	profit_ctr_id,
		 	workorder_id,
		 	resource_type,
		 	sequence_id,
		 	ISNULL(bill_rate, 0),
			ISNULL(quantity_used, 0), 
			resource_class_code,
			group_code,
			isnull(group_instance_id, 0) ,
			CASE resource_type 
				WHEN 'E' THEN ISNULL(price, 0)
				WHEN 'L' THEN ISNULL(price, 0)
				WHEN 'O' THEN ISNULL(price, 0)
				ELSE 0
				END AS price,
			0 AS priced_flag
			FROM WorkOrderDetail  (nolock) 
			WHERE workorder_id = @wo_id
			AND company_id = @company_id
			AND profit_ctr_id = @profit_ctr_id
			AND isnull(group_instance_id, 0) = 0
			AND ISNULL(bill_rate, 0) > -2
		UNION ALL
		-- Include groups
		SELECT DISTINCT 
		 	company_id,
		 	profit_ctr_id,
		 	workorder_id,
		 	resource_type,
		 	sequence_id,
		 	ISNULL(bill_rate, 0),
			ISNULL(quantity_used, 0), 
			resource_class_code,
			group_code,
			isnull(group_instance_id, 0) ,
			0 AS price,
			0 AS priced_flag
			FROM WorkOrderDetail  (nolock) 
			WHERE workorder_id = @wo_id
			AND company_id = @company_id
			AND profit_ctr_id = @profit_ctr_id
			AND resource_type = 'G'
			AND ISNULL(bill_rate, 0) > -2


		-- Price any manifest only (bill_rate = -1) items as if they're receipt lines already
		-- But only for trips that aren't complete.
		UPDATE #tmp_price SET price = (tp.quantity * pqd.price), priced_flag = 1
			FROM #tmp_price tp
			INNER JOIN workorderdetail wod  (nolock) ON wod.workorder_id = tp.workorder_id
			and wod.resource_type = tp.resource_type
			and wod.sequence_id = tp.sequence_id
			and wod.company_id = tp.company_id
			and wod.profit_ctr_id = tp.profit_ctr_id
			INNER JOIN Workorderheader woh  (nolock) ON woh.workorder_id = wod.workorder_id
			and woh.company_id = wod.company_id
			and woh.profit_ctr_id = wod.profit_ctr_id
			INNER JOIN tripheader th  (nolock) ON woh.trip_id = th.trip_id
			INNER JOIN ProfileQuoteDetail pqd  (nolock) ON wod.profile_id = pqd.profile_id
			and wod.profile_company_id = pqd.company_id
			and wod.profile_profit_ctr_id = pqd.profit_ctr_id
			AND wod.bill_unit_code = pqd.bill_unit_code
			AND pqd.status = 'A'
			WHERE tp.bill_rate = -1
			and tp.price = 0
			and th.trip_status IN ('D', 'A', 'U')
		
		UPDATE #tmp_line SET description = description + ' - NOTE: Receipt info shown is not valid until Trip is Complete'
		FROM #tmp_line tl
		INNER JOIN #tmp_price tp on tl.receipt_id = tp.workorder_id
			AND tl.company_id = tp.company_id
			AND tl.profit_ctr_id = tp.profit_ctr_id
		 	AND tl.resource_type = tp.resource_type
		 	AND tl.line_id = tp.sequence_id
		WHERE tp.bill_rate = -1
		AND tp.price <> 0


		-- Price any groups at the highest bill rate of its group members
		UPDATE #tmp_price SET bill_rate = (SELECT MAX(ISNULL(bill_rate,0)) 
			FROM WorkOrderDetail  (nolock) 
			WHERE workorder_id = #tmp_price.workorder_id
            AND company_id = #tmp_price.company_id
			AND profit_ctr_id = @profit_ctr_id
			AND WorkOrderDetail.group_code = #tmp_price.group_code
			AND WorkOrderDetail.group_instance_id = #tmp_price.group_instance_id
			AND ISNULL(bill_rate, 0) > 0
			)
		WHERE #tmp_price.group_instance_id > 0

IF @debug_flag = 1 SELECT * FROM #tmp_price
			
		-- Identify number of detail lines that need pricing
		SELECT @detail_count = COUNT(*) FROM #tmp_price WHERE price = 0
		IF @detail_count > 0
		BEGIN
			/* Try to price assigned resource from project - Doubletime */
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @project_quote_id 
			AND qd.company_id = #tmp_price.company_id
			AND qd.profit_ctr_id = #tmp_price.profit_ctr_id
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND qd.group_code = #tmp_price.group_code
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows (doubletime)'

			/* Try to price assigned resource from project - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @project_quote_id 
            AND qd.company_id = #tmp_price.company_id
            AND qd.profit_ctr_id = #tmp_price.profit_ctr_id
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from project - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @project_quote_id 
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
            AND qd.profit_ctr_id = #tmp_price.profit_ctr_id

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Project priced ' + CONVERT(varchar(40), @rowcount) + ' rows'

			/* Try to price assigned resource from customer - Doubletime*/
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code					
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
            AND qd.profit_ctr_id = #tmp_price.profit_ctr_id

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (doubletime)'

			/* Try to price assigned resource from customer - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
            AND qd.profit_ctr_id = #tmp_price.profit_ctr_id

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from customer - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @customer_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
			AND qd.profit_ctr_id = #tmp_price.profit_ctr_id

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Customer priced ' + CONVERT(varchar(40), @rowcount) + ' rows (standard)'

			/* Try to price assigned resource from base - Doubletime */
			UPDATE #tmp_price SET price = qd.price_dt, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 2
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
			AND qd.profit_ctr_id = #tmp_price.profit_ctr_id

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (Doubletime)'

			/* Try to price assigned resource from base - Overtime */
			UPDATE #tmp_price SET price = qd.price_ot, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1.5
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
			AND qd.profit_ctr_id = #tmp_price.profit_ctr_id
			

SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 PRINT 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (time and a half)'

			/* Try to price assigned resource from base - Standard */
			UPDATE #tmp_price SET price = qd.price, priced_flag = 1
			FROM WorkorderQuoteDetail qd (nolock) 
			WHERE qd.quote_id = @base_rate_quote_id 
			AND qd.group_code = #tmp_price.group_code						
			AND qd.resource_item_code = #tmp_price.resource_to_price
			AND #tmp_price.bill_rate = 1
			AND #tmp_price.price = 0
            AND qd.company_id = #tmp_price.company_id
			AND qd.profit_ctr_id = #tmp_price.profit_ctr_id


SELECT @rowcount = @@ROWCOUNT
IF @debug_flag = 1 AND @rowcount > 0 print 'Base rate priced ' + CONVERT(varchar(40), @rowcount) + ' rows (Standard)'

		END
IF @debug_flag = 1 print 'selecting priced detail lines'
IF @debug_flag = 1 SELECT * FROM #tmp_price WHERE priced_flag = 1
IF @debug_flag = 1 print 'selecting detail lines that were not priced'
IF @debug_flag = 1 SELECT * FROM #tmp_price WHERE priced_flag = 0


		------------------------------------------------------------------------------
		-- Store detail results in revenue table
		------------------------------------------------------------------------------
		
IF @debug_flag = 1 print 'selecting lines to add to #tmp_revenue:'
IF @debug_flag = 1
		SELECT SUM((t.quantity * t.price) * ((100 - w.cust_discount)/100)),
			WOTH.account_desc,
			t.company_id,
			t.profit_ctr_id,
			t.workorder_id,
			t.resource_type,
			t.sequence_id,
			'C',
			'F',
			null,
			null,
			null
		FROM #tmp_price t
		inner join #tmp_line w
			ON t.workorder_id = w.receipt_id
			and t.company_id = w.company_id
			and t.profit_ctr_id = w.profit_ctr_id
			and t.resource_type = w.resource_type
			and t.sequence_id = w.line_id
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--inner join GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND t.company_id = g.company_id
		--	AND t.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE 
	 	 	t.workorder_id = @wo_id
	 	 	and t.company_id = @company_id
	 	 	and t.profit_ctr_id = @profit_ctr_id
	 	 	and isnull(w.revenue, 0) = 0
 		GROUP BY 
			woth.account_desc,
			t.company_id,
			t.profit_ctr_id,
			t.workorder_id,
			t.resource_type,
			t.sequence_id
		
		
		INSERT #tmp_revenue (
			revenue,
			account_desc, 
			company_id,
			profit_ctr_id,
			workorder_id,
			resource_type,
			sequence_id,
			pricing_method,
			fixed_price,
			ensr_amt,
			insr_amt,
			bill_rate	)
		SELECT SUM((t.quantity * t.price) * ((100 - w.cust_discount)/100)),
			woth.account_desc,
			t.company_id,
			t.profit_ctr_id,
			t.workorder_id,
			t.resource_type,
			t.sequence_id,
			'C',
			'F',
			null,
			null,
			null
		FROM #tmp_price t
		inner join #tmp_line w
			ON t.workorder_id = w.receipt_id
			and t.company_id = w.company_id
			and t.profit_ctr_id = w.profit_ctr_id
			and t.resource_type = w.resource_type
			and t.sequence_id = w.line_id
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--inner join GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND w.company_id = g.company_id
		--	AND w.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE 
	 	 	t.workorder_id = @wo_id
	 	 	and w.company_id = @company_id
	 	 	and w.profit_ctr_id = @profit_ctr_id
	 	 	and isnull(w.revenue, 0) = 0
 		GROUP BY 
			woth.account_desc,
			t.company_id,
			t.profit_ctr_id,
			t.workorder_id,
			t.resource_type,
			t.sequence_id
			
		------------------------------------------------------------------------------
		-- Get the disposal prices (from TSDF approvals and Profiles)
		------------------------------------------------------------------------------
IF @debug_flag = 1 print 'selecting disposal lines to add to #tmp_revenue:'
IF @debug_flag = 1
		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, tp.price)) * ((100 - w.cust_discount)/100)),
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id,
			'C',
			'F',
			null,
			null,
			null
		FROM WorkOrderDetail d (nolock) 
		INNER JOIN TSDFApprovalPrice tp  (nolock) ON (d.tsdf_approval_id = tp.tsdf_approval_id
			AND d.profit_ctr_id = tp.profit_ctr_id
			AND d.company_id = tp.company_id
			AND d.bill_unit_code = tp.bill_unit_code)
		INNER JOIN TSDFApproval t  (nolock) ON (tp.tsdf_approval_id = t.tsdf_approval_id
            AND tp.company_id = t.company_id
            AND tp.profit_ctr_id = t.profit_ctr_id)
			AND t.tsdf_approval_status = 'A'
		INNER JOIN TSDF  (nolock) ON (d.TSDF_code = TSDF.TSDF_code)
			AND ISNULL(TSDF.eq_flag, 'F') = 'F'		-- Get Work Orders using TSDF Approvals
		INNER JOIN #tmp_line w
			ON d.workorder_id = w.receipt_id
	        AND d.company_id = w.company_id
			AND d.profit_ctr_id = w.profit_ctr_id
			AND d.resource_type = w.resource_type
			and d.sequence_id= w.line_id
			AND d.resource_type = 'D'
			AND d.bill_rate > 0
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--INNER JOIN GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND w.company_id = g.company_id
		--	AND w.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE d.workorder_id = @wo_id
			AND d.profit_ctr_id = @profit_ctr_id
            AND d.company_id = @company_id
		GROUP BY
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id
		UNION

		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, pqd.price)) * ((100 - w.cust_discount)/100)),
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id,
			'C',
			'F',
			null,
			null,
			null
		FROM WorkOrderDetail d (nolock) 
		INNER JOIN ProfileQuoteDetail pqd  (nolock) ON (d.profile_id = pqd.profile_id
			AND d.profit_ctr_id = pqd.profit_ctr_id
			AND d.company_id = pqd.company_id
			AND d.bill_unit_code = pqd.bill_unit_code)
		INNER JOIN TSDF  (nolock) ON (d.TSDF_code = TSDF.TSDF_code)
			AND ISNULL(TSDF.eq_flag, 'F') = 'T'		-- Get Work Orders using Profiles
		INNER JOIN #tmp_line w
			ON d.workorder_id = w.receipt_id
	        AND d.company_id = w.company_id
			AND d.profit_ctr_id = w.profit_ctr_id
			AND d.resource_type = w.resource_type
			and d.sequence_id= w.line_id
			AND d.resource_type = 'D'
			AND d.bill_rate > 0
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--INNER JOIN GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND w.company_id = g.company_id
		--	AND w.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE d.workorder_id = @wo_id
			AND d.profit_ctr_id = @profit_ctr_id
            AND d.company_id = @company_id
		GROUP BY 
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id
		
		INSERT #tmp_revenue (
			revenue,
			account_desc, 
			company_id,
			profit_ctr_id,
			workorder_id,
			resource_type,
			sequence_id,
			pricing_method,
			fixed_price,
			ensr_amt,
			insr_amt,
			bill_rate	)
		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, tp.price)) * ((100 - w.cust_discount)/100)),
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id,
			'C',
			'F',
			null,
			null,
			null
		FROM WorkOrderDetail d (nolock) 
		INNER JOIN TSDFApprovalPrice tp  (nolock) ON (d.tsdf_approval_id = tp.tsdf_approval_id
			AND d.profit_ctr_id = tp.profit_ctr_id
			AND d.company_id = tp.company_id
			AND d.bill_unit_code = tp.bill_unit_code)
		INNER JOIN TSDFApproval t  (nolock) ON (tp.tsdf_approval_id = t.tsdf_approval_id
            AND tp.company_id = t.company_id
            AND tp.profit_ctr_id = t.profit_ctr_id)
			AND t.tsdf_approval_status = 'A'
		INNER JOIN TSDF  (nolock) ON (d.TSDF_code = TSDF.TSDF_code)
			AND ISNULL(TSDF.eq_flag, 'F') = 'F'		-- Get Work Orders using TSDF Approvals
		INNER JOIN #tmp_line w
			ON d.workorder_id = w.receipt_id
	        AND d.company_id = w.company_id
			AND d.profit_ctr_id = w.profit_ctr_id
			AND d.resource_type = w.resource_type
			and d.sequence_id= w.line_id
			AND d.resource_type = 'D'
			AND d.bill_rate > 0
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--INNER JOIN GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND w.company_id = g.company_id
		--	AND w.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE d.workorder_id = @wo_id
			AND d.profit_ctr_id = @profit_ctr_id
            AND d.company_id = @company_id
	 	 	and isnull(w.revenue, 0) = 0
		GROUP BY
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id
		UNION

		SELECT SUM((d.bill_rate * ISNULL(d.quantity_used, 0) * COALESCE(d.price, pqd.price)) * ((100 - w.cust_discount)/100)),
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id,
			'C',
			'F',
			null,
			null,
			null
		FROM WorkOrderDetail d (nolock) 
		INNER JOIN ProfileQuoteDetail pqd  (nolock) ON (d.profile_id = pqd.profile_id
			AND d.profit_ctr_id = pqd.profit_ctr_id
			AND d.company_id = pqd.company_id
			AND d.bill_unit_code = pqd.bill_unit_code)
		INNER JOIN TSDF  (nolock) ON (d.TSDF_code = TSDF.TSDF_code)
			AND ISNULL(TSDF.eq_flag, 'F') = 'T'		-- Get Work Orders using Profiles
		INNER JOIN #tmp_line w
			ON d.workorder_id = w.receipt_id
	        AND d.company_id = w.company_id
			AND d.profit_ctr_id = w.profit_ctr_id
			AND d.resource_type = w.resource_type
			and d.sequence_id= w.line_id
			AND d.resource_type = 'D'
			AND d.bill_rate > 0
		INNER JOIN WorkOrderTypeHeader WOTH (NOLOCK)
			ON WOTH.workorder_type_id = w.workorder_type_id
		--INNER JOIN GLAccount g (nolock) 
		--	ON w.workorder_type = g.account_type
		--	AND w.company_id = g.company_id
		--	AND w.profit_ctr_id = g.profit_ctr_id
		--	AND g.account_class = 'O'
		WHERE d.workorder_id = @wo_id
			AND d.profit_ctr_id = @profit_ctr_id
            AND d.company_id = @company_id
	 	 	and isnull(w.revenue, 0) = 0
		GROUP BY 
			woth.account_desc,
			w.company_id,
			w.profit_ctr_id,
			w.receipt_id,
			w.resource_type,
			w.line_id
			
IF @debug_flag = 1 PRINT 'These are the revenue records for workorder: ' + CONVERT(varchar(30),@wo_id)
IF @debug_flag = 1 SELECT * FROM #tmp_revenue WHERE workorder_id = @wo_id AND company_id = @company_id AND profit_ctr_id = @profit_ctr_id

	END

    -- Apply surcharges
    
	    -- INSR
			SELECT	@billing_project_id  = ISNULL(billing_project_id, 0)
				FROM WorkorderHeader (nolock) 
				WHERE WorkOrderHeader.workorder_ID = @wo_id
				AND WorkOrderHeader.profit_ctr_ID = @Profit_ctr_ID
				AND WorkorderHeader.company_id = @Company_id

			SELECT	@insr_flag = insurance_surcharge_flag
				FROM CustomerBilling (nolock) 
				WHERE customer_id = @customer_id
				AND billing_project_id = @billing_project_id

			IF @insr_flag = 'T' OR @insr_flag = 'P'
			BEGIN
				IF @fixed_price_flag = 'T'
				BEGIN
					/*
						SELECT @insr_amt = ROUND((ISNULL(woh.total_price, 0)) * (ISNULL(c.insurance_surcharge_percent, 0) / 100), 2)
						FROM WorkorderHeader woh
						INNER JOIN Company c ON woh.company_id = c.company_id
						WHERE woh.workorder_ID = @wo_id
						AND woh.profit_ctr_ID = @Profit_ctr_ID
						AND woh.company_id = @Company_id
					*/
					update #tmp_revenue set insr_amt = ROUND((ISNULL(r.revenue, 0)) * (ISNULL(c.insurance_surcharge_percent, 0) / 100), 2)
					FROM #tmp_revenue r
					INNER JOIN Company c  (nolock) ON r.company_id = c.company_id
					WHERE r.workorder_ID = @wo_id
					AND r.profit_ctr_ID = @Profit_ctr_ID
					AND r.company_id = @Company_id
				END
				ELSE
			    BEGIN
				
					update #tmp_revenue set insr_amt = ROUND((r.revenue) * (ISNULL(c.insurance_surcharge_percent, 0) / 100), 2)
					FROM #tmp_revenue r
					INNER JOIN WorkOrderDetail wod (nolock) 
						ON r.workorder_id = wod.workorder_id
						AND r.company_id = wod.company_id
						AND r.profit_ctr_id = wod.profit_ctr_id
						AND r.resource_type = wod.resource_type
						AND r.sequence_id = wod.sequence_id
					INNER JOIN WorkorderHeader woh  (nolock) ON woh.workorder_id = wod.workorder_id
						AND woh.profit_ctr_ID = wod.profit_ctr_ID
					  AND woh.company_ID = wod.company_id
					INNER JOIN ResourceClass rc  (nolock) ON wod.company_id = rc.company_id
						AND wod.profit_ctr_id = rc.profit_ctr_id
						AND wod.resource_type = rc.resource_type
						AND wod.resource_class_code = rc.resource_class_code
						AND wod.bill_unit_code = rc.bill_unit_code
					INNER JOIN Company c  (nolock) ON wod.company_id = c.company_id
					WHERE r.workorder_ID = @wo_id
					AND r.profit_ctr_ID = @Profit_ctr_ID
					AND r.company_ID = @company_ID
					AND ISNULL(rc.regulated_fee, 'F') = 'F'
					AND wod.bill_rate > 0
					AND wod.resource_type NOT IN ('G', 'D')
					
					update #tmp_revenue set 
						insr_amt = 0 
					where
						ISNULL(insr_amt, 0) = 0
						and workorder_id = @wo_id
						and company_id = @company_id
						and profit_ctr_id = @profit_ctr_id

					-- Add in the insurance surcharge from the disposal lines; they have no resource_class_code, so remove the join to resourceclass
					update #tmp_revenue set insr_amt = ISNULL(ROUND(r.revenue * (ISNULL(c.insurance_surcharge_percent, 0) / 100), 2), 0)
					FROM #tmp_revenue r
					INNER JOIN WorkOrderDetail wod (nolock) 
						ON r.workorder_id = wod.workorder_id
						AND r.company_id = wod.company_id
						AND r.profit_ctr_id = wod.profit_ctr_id
						AND r.resource_type = wod.resource_type
						AND r.sequence_id = wod.sequence_id
					INNER JOIN WorkorderHeader woh  (nolock) ON woh.workorder_id = wod.workorder_id
						AND woh.profit_ctr_ID = wod.profit_ctr_ID
						AND woh.company_id = wod.company_id
					INNER JOIN Company c  (nolock) ON wod.company_id = c.company_id
					WHERE r.workorder_ID = @wo_id
					AND r.profit_ctr_ID = @Profit_ctr_ID
					AND r.company_id = @company_id
					AND wod.bill_rate > 0
					AND wod.resource_type = 'D'
				END
			END
			ELSE
			    update #tmp_revenue set insr_amt = 0
				WHERE workorder_ID = @wo_id
				AND profit_ctr_ID = @Profit_ctr_ID
				AND company_id = @Company_id

	    
	    
	    -- ENSR
			SELECT @billing_project_id  = ISNULL(billing_project_id, 0)
			FROM WorkorderHeader  (nolock) 
			WHERE WorkOrderHeader.workorder_id = @wo_id
			AND WorkOrderHeader.profit_ctr_id = @profit_ctr_id
			AND Workorderheader.company_id = @company_id

			SELECT	@ensr_flag = ensr_flag
			FROM CustomerBilling (nolock) 
			WHERE customer_id = @customer_id
			AND billing_project_id = @billing_project_id

			IF @ensr_flag = 'T' OR @ensr_flag = 'P'
			    BEGIN
				SET @max_disposal_seq_id = 0
				SET @disposal_seq_id = 0

				SELECT @max_disposal_seq_id = MAX(wod.sequence_ID)
				FROM #tmp_revenue r
				INNER JOIN WorkOrderDetail wod (nolock) 
					ON r.workorder_id = wod.workorder_id
					AND r.company_id = wod.company_id
					AND r.profit_ctr_id = wod.profit_ctr_id
					AND r.resource_type = wod.resource_type
					AND r.sequence_id = wod.sequence_id
				INNER JOIN TSDF  (nolock) ON wod.TSDF_code = TSDF.TSDF_code
				WHERE r.workorder_id = @wo_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.company_id = @company_id
				AND wod.resource_type = 'D'
				AND wod.bill_rate > 0
				AND wod.profile_id > 0
				AND TSDF.eq_flag = 'T'

			    IF ISNULL(@max_disposal_seq_id, 0) = 0 SET @max_disposal_seq_id = 0

				update #tmp_revenue set ensr_amt = 0
				WHERE workorder_id = @wo_id
				AND profit_ctr_id = @profit_ctr_id
				AND company_id = @company_id

				--------------------------------------------------------
				-- Loop through disposal lines to EQ facilities
				--------------------------------------------------------
				DisposalLoop:

				SELECT @disposal_seq_id = MIN(wod.sequence_ID)
				FROM #tmp_revenue r
				INNER JOIN WorkOrderDetail wod (nolock) 
					ON r.workorder_id = wod.workorder_id
					AND r.company_id = wod.company_id
					AND r.profit_ctr_id = wod.profit_ctr_id
					AND r.resource_type = wod.resource_type
					AND r.sequence_id = wod.sequence_id
				INNER JOIN TSDF  (nolock) ON wod.TSDF_code = TSDF.TSDF_code
				WHERE r.workorder_id = @wo_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.company_id = @company_id
				AND wod.resource_type = 'D'
				AND wod.bill_rate > 0
				AND wod.profile_id > 0
				AND TSDF.eq_flag = 'T'
				AND wod.sequence_ID > @disposal_seq_id

				-- Add in the energy surcharge from the disposal lines; they have no resource_class_code, so remove the join to resourceclass
				-- ?? What if there's not a wom.date_delivered yet?
				update #tmp_revenue set ensr_amt = ROUND((r.revenue) * (ISNULL(dbo.fn_get_ensr_percent(wom.date_delivered, woh.customer_id, ISNULL(woh.billing_project_id, 0)), 0) / 100), 2)
				FROM #tmp_revenue r
				INNER JOIN WorkOrderDetail wod (nolock) 
					ON r.workorder_id = wod.workorder_id
					AND r.company_id = wod.company_id
					AND r.profit_ctr_id = wod.profit_ctr_id
					AND r.resource_type = wod.resource_type
					AND r.sequence_id = wod.sequence_id
				INNER JOIN WorkorderHeader woh  (nolock) ON woh.workorder_id = wod.workorder_id
					AND woh.profit_ctr_ID = wod.profit_ctr_ID
					AND woh.company_id = wod.company_id
				INNER JOIN WorkOrderManifest wom  (nolock) ON wom.profit_ctr_id = wod.profit_ctr_id
					AND wom.workorder_id = wod.workorder_id
					AND wom.company_id = wod.company_id
					AND wom.manifest = wod.manifest
				WHERE r.workorder_id = @wo_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.company_id = @company_id
				AND wod.sequence_ID = @disposal_seq_id
				AND wod.resource_type = 'D'

				update #tmp_revenue set 
					ensr_amt = 0 
				where
					ISNULL(ensr_amt, 0) = 0
					and workorder_id = @wo_id
					and company_id = @company_id
					and profit_ctr_id = @profit_ctr_id
			    
				IF @disposal_seq_id < @max_disposal_seq_id GOTO DisposalLoop
			    END
			ELSE
				update #tmp_revenue set 
					ensr_amt = 0 
				WHERE 1=1
					and workorder_id = @wo_id
					and company_id = @company_id
					and profit_ctr_id = @profit_ctr_id


IF @debug_flag = 1 PRINT 'Testing the update of #tmp_line : ' + CONVERT(varchar(30),@wo_id)
IF @debug_flag = 1 
	select distinct
	    w.company_id,
	    w.profit_ctr_id,
	    w.receipt_id,
	    w.resource_type,
	    w.line_id,
		1 as progress_flag,
		t.account_desc,
		t.pricing_method,
		t.fixed_price,
		t.insr_amt,
		t.ensr_amt,
		t.revenue
	FROM #tmp_line w
	inner join #tmp_revenue t
	on w.receipt_id = t.workorder_id
	and w.company_id = t.company_id
	and w.profit_ctr_id = t.profit_ctr_id
	and w.resource_type = t.resource_type
	and w.line_id = t.sequence_id


    -- update #tmp_line records with #tmp Revenue data.		
    UPDATE #tmp_line SET 
		progress_flag = 1,
		account_desc = t.account_desc,
		-- invoice_id = t.invoice_id,
		-- invoice_code = t.invoice_code,
		pricing_method = t.pricing_method,
		fixed_price = t.fixed_price,
		insr_amt = t.insr_amt,
		ensr_amt = t.ensr_amt,
		revenue = t.revenue
	FROM #tmp_line w
	inner join #tmp_revenue t
		on w.receipt_id = t.workorder_id
		and w.company_id = t.company_id
		and w.profit_ctr_id = t.profit_ctr_id
		and w.resource_type = t.resource_type
		and w.line_id = t.sequence_id
		and w.source_table like 'workorder%'

    UPDATE #tmp_line SET
        progress_flag = 1
    WHERE 1=1
        AND @company_id = company_id
        AND @profit_ctr_id = profit_ctr_id
        AND @wo_id = receipt_id
        and source_table like 'workorder%'
		
IF @debug_flag = 1 PRINT 'These are the updated #tmp_line records for workorder: ' + CONVERT(varchar(30),@wo_id)
IF @debug_flag = 1 SELECT * FROM #tmp_line WHERE receipt_id = @wo_id AND company_id = @company_id AND profit_ctr_id = @profit_ctr_id
    
END

-- Done with Workorder Pricing & Surcharges.
DONE:

-- Calc prices on Receipts...
if @debug_flag = 1 begin
	PRINT 'Calculate Receipt Prices... (Before):'
	SELECT * from #tmp_line WHERE source_table like 'receipt%'
END

update #tmp_line set 
	revenue = (
		select sum(rp.total_extended_amt)
		from receiptprice rp  (nolock) 
		where rp.receipt_id = #tmp_line.receipt_id
			and rp.company_id = #tmp_line.company_id
			and rp.profit_ctr_id = #tmp_line.profit_ctr_id
			and rp.line_id = #tmp_line.line_id
	),
	progress_flag = 1
where
	source_table like 'receipt%'
	and progress_flag = 0
	and revenue is null

update #tmp_line set pricing_method = CASE processing_note
	WHEN 'Receipt info shown is invalid - Trip is not Complete' THEN 'C'
	ELSE 'A'
END
where
	source_table like 'receipt%'


if @debug_flag = 1 begin
	PRINT 'Calculate Receipt Prices... (After):'
	SELECT * from #tmp_line WHERE source_table like 'receipt%' and progress_flag = 1
END


-- Need to calculate insr, ensr on receipt-records.
UPDATE #tmp_line set ensr_amt = null, insr_amt = null where source_table like 'receipt%' and progress_flag = 1

-- ENSR
IF @debug_flag=1 PRINT 'Looping over ENSR_AMT charge calculation (Receipt)'
While exists (select 1 from #tmp_line where ensr_amt is NULL and source_table like 'receipt%' and progress_flag = 1)
BEGIN

	select top 1 @receipt_id = receipt_id,
	@company_id = company_id,
	@profit_ctr_id = profit_ctr_id,
	@receipt_line_id = line_id
	from #tmp_line
	where ensr_amt is NULL and source_table like 'receipt%'
	order by company_id, profit_ctr_id, receipt_id, line_id

	IF @debug_flag=1 SELECT 'Loop Values (1):', @receipt_id AS Receipt_id, @company_id AS Company_ID, @profit_ctr_id AS Profit_Ctr_id, @Receipt_Line_ID AS Line_ID

	SELECT
		@trans_type = r.trans_type,
		@ensr_flag = cb.ensr_flag
	FROM Receipt r (nolock) 
	LEFT OUTER JOIN CustomerBilling cb (nolock) 
		ON cb.customer_id = r.customer_id
		AND cb.billing_project_id = ISNULL(r.billing_project_id, 0)
	WHERE r.receipt_id = @receipt_id
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.line_id = @receipt_line_id
	AND r.receipt_status <> 'V'
	AND r.fingerpr_status <> 'V'

	IF @debug_flag=1 SELECT 'Loop Values (2):', @trans_type AS Trans_Type, @ensr_flag AS Ensr_Flag

	-- No energy surcharge calculated for exempt customers.
	IF @ensr_flag = 'F'
	BEGIN
		update #tmp_line set ensr_amt = 0.00, progress_flag = 2
		where ensr_amt is null
		and receipt_id = @receipt_id
		and company_id = @company_id
		and profit_ctr_id = @profit_ctr_id
		-- No line match, because the whole receipt is for the same exempt customer.
		continue -- get the next receipt to process.
	END

	IF @ensr_flag IN ('T', 'P')
	BEGIN

		-- Disposal Line
		IF @trans_type = 'D'
		BEGIN
			SELECT	@appr_ensr_exempt = a.ensr_exempt
			FROM Receipt r (nolock) 
			LEFT OUTER JOIN ProfileQuoteApproval a  (nolock) ON (r.profile_id = a.profile_id 
				AND r.company_id = a.company_id
				AND r.profit_ctr_id = a.profit_ctr_id)
			LEFT OUTER JOIN Profile p  (nolock) on a.profile_id = p.profile_id
			WHERE r.receipt_id = @receipt_id
			AND r.line_id = @receipt_line_id
			AND r.company_id = @company_id
			AND r.profit_ctr_id = @profit_ctr_id
			AND p.curr_status_code = 'A'
			
			IF @ensr_flag = 'P' AND @appr_ensr_exempt = 'T'
			BEGIN
				-- Skip energy surcharge; this is an exempt approval.
				update #tmp_line set ensr_amt = 0.00, progress_flag = 2
				where ensr_amt is null
				and receipt_id = @receipt_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and line_id = @receipt_line_id
				continue -- get the next receipt/line
			END
			ELSE
			BEGIN
				update #tmp_line SET 
					ensr_amt = ROUND(((w.revenue * ISNULL(dbo.fn_get_ensr_percent(r.receipt_date, r.customer_id, ISNULL(r.billing_project_id, 0)), 0)) / 100), 2), progress_flag = 2
				FROM #tmp_line w
				INNER JOIN Receipt r (nolock) 
					ON w.receipt_id = r.receipt_id
					AND w.company_id = r.company_id
					AND w.profit_ctr_id = r.profit_ctr_id
					AND w.line_id = r.line_id
				INNER JOIN ReceiptPrice rp (nolock) 
					ON r.receipt_id = rp.receipt_id
					AND r.company_id = rp.company_id
					AND r.profit_ctr_id = rp.profit_ctr_id
					AND r.line_id = rp.line_id
				INNER JOIN Company c (nolock) 
					ON r.company_id = c.company_id
				WHERE r.receipt_id = @receipt_id
				AND r.line_id = @receipt_line_id
				AND r.company_id = @company_id
				AND r.profit_ctr_id = @profit_ctr_id
			END
		END
		ELSE
		BEGIN
			update #tmp_line set ensr_amt = 0.00, progress_flag = 2
			where ensr_amt is null
			and receipt_id = @receipt_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and line_id = @receipt_line_id
			continue -- get the next receipt/line
		END
	END
END

-- INSR
IF @debug_flag=1 PRINT 'Looping over INSR_AMT charge calculation (Receipt)'
While exists (select 1 from #tmp_line where insr_amt is NULL and source_table like 'receipt%' and progress_flag <= 2)
BEGIN

	select top 1 @receipt_id = receipt_id,
	@company_id = company_id,
	@profit_ctr_id = profit_ctr_id,
	@receipt_line_id = line_id
	from #tmp_line
	where insr_amt is NULL and source_table like 'receipt%'
	order by company_id, profit_ctr_id, receipt_id, line_id

	SELECT	
		@apply_surcharge = 0,
		@trans_type = r.trans_type,
		@insr_flag = cb.insurance_surcharge_flag
	FROM Receipt r (nolock) 
	LEFT OUTER JOIN CustomerBilling cb (nolock) 
		ON cb.customer_id = r.customer_id
		AND cb.billing_project_id = ISNULL(r.billing_project_id, 0)
	WHERE r.receipt_id = @receipt_id
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.line_id = @receipt_line_id

	-- No insurance surcharge calculated for exempt customers.
	IF @insr_flag = 'F'
	BEGIN
		update #tmp_line set insr_amt = 0.00, progress_flag = 3
		where insr_amt is null
		and receipt_id = @receipt_id
		and company_id = @company_id
		and profit_ctr_id = @profit_ctr_id
		-- No line match, because the whole receipt is for the same exempt customer.
		continue -- get the next receipt to process.
	END
	
	IF @insr_flag in ('T', 'P')
	BEGIN
	
		-- Disposal Line
		IF @trans_type = 'D'
		BEGIN
			SELECT @appr_insr_exempt = a.insurance_exempt
			FROM Receipt r (nolock) 
			LEFT OUTER JOIN ProfileQuoteApproval a  (nolock) ON (r.profile_id = a.profile_id
				AND r.company_id = a.company_id
				AND r.profit_ctr_id = a.profit_ctr_id)
			LEFT OUTER JOIN Profile p  (nolock) on a.profile_id = p.profile_id
			WHERE r.receipt_id = @receipt_id
			AND r.line_id = @receipt_line_id
			AND r.profit_ctr_id = @profit_ctr_id
			AND r.company_id = @company_id
			AND p.curr_status_code = 'A'
			
			IF @insr_flag = 'P' AND @appr_insr_exempt = 'T'
			BEGIN
				-- Skip insurance surcharge; this is an exempt approval.
				update #tmp_line set insr_amt = 0.00, progress_flag = 3
				where insr_amt is null
				and receipt_id = @receipt_id
				and line_id = @receipt_line_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				continue -- get the next receipt/line
			END
			ELSE
				SET @apply_surcharge = 1
		END

		-- Service Line
		IF @trans_type = 'S'
		BEGIN
			SELECT	
				@product_id = r.product_id,
				@prod_reg_fee = p.regulated_fee
			FROM Receipt r (nolock) 
			LEFT OUTER JOIN Product p  (nolock) ON (r.product_id = p.product_id
				AND r.company_id = p.company_id 
				AND r.profit_ctr_id = p.profit_ctr_id)
			WHERE r.receipt_id = @receipt_id
			AND r.line_id = @receipt_line_id
			AND r.profit_ctr_id = @profit_ctr_id
			AND r.company_id = @company_id
			
			IF @prod_reg_fee = 'T'
			BEGIN
				-- Skip insurance surcharge; this is a regulated fee.
				update #tmp_line set insr_amt = 0.00, progress_flag = 3
				where insr_amt is null
				and receipt_id = @receipt_id
				and line_id = @receipt_line_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				continue -- get the next receipt/line
			END
			ELSE
				SET @apply_surcharge = 1
		END

		IF @apply_surcharge = 1
		BEGIN
			update #tmp_line set 
			insr_amt = ROUND((w.revenue * ISNULL(c.insurance_surcharge_percent, 0) / 100), 2), progress_flag = 3
			FROM #tmp_line w
			inner join company c (nolock) 
				ON w.company_id = c.company_id
			where w.insr_amt is null
			and w.receipt_id = @receipt_id
			and w.line_id = @receipt_line_id
			and w.company_id = @company_id
			and w.profit_ctr_id = @profit_ctr_id
			and w.source_table like 'receipt%'
		END
		ELSE
		BEGIN
			update #tmp_line set insr_amt = 0.00, progress_flag = 3
			where insr_amt is null
			and receipt_id = @receipt_id
			and line_id = @receipt_line_id
			and company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			continue -- get the next receipt/line
		END
	END
END

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
	--CASE t.workorder_type
	--	WHEN 'A' THEN 'Retail Product Offering'
	--	WHEN 'B' THEN 'Brokered Disposal/Trans. Services'
	--	WHEN 'D' THEN 'Underground Cleaning Services'
	--	WHEN 'E' THEN 'Emergency Response'
	--	WHEN 'H' THEN 'Marine Services'
	--	WHEN 'K' THEN 'Other Services'
	--	WHEN 'L' THEN 'Lab Packs'
	--	WHEN 'M' THEN 'Managed Service Contracts'
	--	WHEN 'N' THEN 'North Carolina Revenue'
	--	WHEN 'O' THEN 'Equipment Rental'
	--	WHEN 'P' THEN 'Remediation Project Management'
	--	WHEN 'R' THEN 'Rail'
	--	WHEN 'S' THEN 'Industrial Cleaning Services'
	--	WHEN 'T' THEN 'Self Waste Transportation and Disposal'
	--	WHEN 'V' THEN 'Recovery Services'
	--END as workorder_type,
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
	CASE t.pricing_method
		WHEN 'C' THEN 'Calculated'
		ELSE 'Actual'
	END AS pricing_method,
	CASE t.fixed_price
		WHEN 'F' Then 'No'
		ELSE 'Yes'
	END as fixed_price,
	t.insr_amt,
	t.ensr_amt,
	t.revenue
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
WHERE
	t.revenue + t.insr_amt + t.ensr_amt > 0
ORDER BY 
	t.trip_id, 
	t.trip_sequence_id, 
	t.receipt_id, 
	t.line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_forecast] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_forecast] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_trip_forecast] TO [EQAI]
    AS [dbo];

