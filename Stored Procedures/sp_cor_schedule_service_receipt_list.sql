drop procedure if exists sp_cor_schedule_service_receipt_list
go

create procedure sp_cor_schedule_service_receipt_list (
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(10) = null	-- 'Requested', 'Scheduled', 'Service' (default = service)
	-- Receipts don't use a specifier, so this field does not apply to Receipts

	, @customer_search	varchar(max) = null
	, @manifest			varchar(max) = null

	, @schedule_type	varchar(max) = null	-- Ignored for Receipts
	, @service_type		varchar(max) = null	-- Ignored for Receipts

	--    , @generator_search	varchar(max) = null
	, @generator_name	varchar(max) = null
	, @epa_id			varchar(max) = null -- can take CSV list
	, @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
	, @generator_division varchar(max) = null -- can take CSV list
	, @generator_state	varchar(max) = null -- can take CSV list
	, @generator_region	varchar(max) = null -- can take CSV list
	, @approval_code	varchar(max) = null	-- Approval Code List
	, @transaction_id	varchar(max) = null
	, @transaction_type	varchar(20) = 'all' -- 'all', 'receipt' or 'workorder'
	, @facility			varchar(max) = null

	, @project_code       varchar(max) = null           -- Project Code Ignored for Receipts

	, @release_code       varchar(50) = null    -- Release code (NOT a list)
	, @purchase_order     varchar(20) = null    -- Purchase Order
	, @search			varchar(max) = null -- Common search
	, @adv_search		varchar(max) = null
    , @status			varchar(max) = null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @combine_transactions bit = 0 -- optional flag for removing receipts linked to listed work orders.
	, @dashboard_service_status varchar(20) = '' -- optional: force selection logic to match sp_cor_dashboard_service_status count logic.
		-- options: '' (none), 'service_date', 'service_scheduled', or 'service_pending'. Descriptions later...
	, @dashboard_service_status_period varchar(2) = null -- for use with @dashboard_service_status
		/* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
) as

/* *******************************************************************
sp_cor_schedule_service_receipt_list

 10/15/2019  AM		DevOps:11604 - Added customer_id and generator_id temp tables and added receipt join.
 06/10/2021  JPB	DO:15510 - add logic to merge related transactions
 2/22/2022	 MPM	DevOps 19126 - Added "fuzzy logic" for emergency response workorder_type_ids.
 3/18/2022	 MPM	DevOps 19126 - Added "fuzzy logic" for Emergency_Response_Type_Reason.

COMBINATION OF sp_cor_schedule_service_list
AND				sp_cor_receipt_list

@dashboard_service_status Description:
--------------------------------------
sp_cor_dashboard_service_status is used on the COR2 dashboard to count work orders
but uses logic not found previously in sp_cor_schedule_service_receipt_list.
sp_cor_dashboard_service_status outputs 3 counts:

	service_date:
		The count of “Service Request” is a count of all work orders 
		that are not voided and not a template for the customer’s access where 
		the work order start date is within the period of time for the metric.
		
	service_scheduled:
		The count of “Service Scheduled” is a count of all work orders 
		that are not voided and not a template for the customer’s access where 
		the work order has a scheduled service date entered that is within the 
		date range of the metric. To qualify, the work order should not have a 
		status of completed and it should also not be submitted.

	service_pending:
		The count of “Service Pending” is a count of all work orders that 
		are not voided and not a template for the customer’s access where the 
		work order start date is within the period of time for the metric and 
		the work order does not have a scheduled service date entered.

The @dashboard_service_status input allows this sp (sp_cor_schedule_service_receipt_list)
to alter its normal behavior to match the logic in sp_cor_dashboard_service_status.

-- Testing:

		sp_cor_dashboard_service_status
			@web_userid = 'court_c'
			, @start_date = '10/1/2020'
			, @end_date = '12/31/2020'
			, @customer_id_list = '18433'
		-- service_date: 18133
		-- service_scheduled: 0
		-- service_pending: 18133

		exec sp_cor_schedule_service_receipt_list
		-- exec sp_cor_schedule_service_receipt_count
			@web_userid = 'court_c'
			, @date_start = '10/1/2020'
			, @date_end = '12/31/2020'
			, @customer_id_list = '18433'
			, @search = ''
			--, @manifest = '006168865JJK'
		--	, @page = 1
			, @perpage = 20
			-- , @excel_output = 1
			-- , @transaction_type = 'workorder'
			, @combine_transactions = 1
			-- , @dashboard_service_status = 'service_date'
				-- options: '' (none), 'service_date', 'service_scheduled', or 'service_pending'. Descriptions later...
			, @dashboard_service_status_period  = null -- for use with @dashboard_service_status
		/* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */

		-- service_date: 18133   4s
		-- service_scheduled: 0
		-- service_pending: 18133  6s



--#region Finding workorders with all resource types to test with...
		drop table #d
		drop table #e
		drop table #f
		drop table #g
		drop table #h

		-- Finding a victim
		select distinct top 3000 c.email, x.workorder_id, x.company_id, x.profit_ctr_id, x.start_date
		into #d
		from contact c
		join ContactCORWorkorderHeaderBucket x on c.contact_id = x.contact_id
		join workorderdetail d on x.workorder_id = d.workorder_id and x.company_id = d.company_id and x.profit_ctr_id = d.profit_ctr_id
			and d.resource_type = 'D' and d.bill_rate > 0
		join billing b on x.workorder_id = b.receipt_id and x.company_id = b.company_id and x.profit_ctr_id = b.profit_ctr_id
			and b.status_code = 'I' and b.trans_source = 'W'
		where 1=1
			and c.web_access_flag in ('T', 'A')
		and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'E')
		-- and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'L')
		-- and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'S')
		-- and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'O')
		order by x.start_date desc

		SELECT  *  
		into #e
		FROM    #d d
		where 1=1
		and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id	and z.bill_rate > 0 and z.resource_type = 'E')

		SELECT  *  
		into #f
		FROM    #e d
		where 1=1
		and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id	and z.bill_rate > 0 and z.resource_type = 'L')

		SELECT  *  
		into #g
		FROM    #f d
		where 1=1
		and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id	and z.bill_rate > 0 and z.resource_type = 'S')

		SELECT  *  
		into #h
		FROM    #g d
		where 1=1
		and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id	and z.bill_rate > 0 and z.resource_type = 'O')

		SELECT  *  FROM    #h

	SELECT  * FROM    ContactCORCustomerBucket where contact_id = 10913
	SELECT  * FROM    contact WHERE  contact_id = 10913

--#endregion	

Samples:


exec sp_cor_schedule_service_receipt_list
	@web_userid = 'dcrozier@riteaid.com'
	, @date_start = '11/1/2015'
	, @date_end = '12/31/2015'

exec sp_cor_schedule_service_receipt_list
	@web_userid = 'nyswyn100'
	, @date_start = '11/1/2019'
	, @date_end = '12/31/2021'
	-- , @customer_id_list = '583'
	, @search = ''
	--, @manifest = '006168865JJK'
--	, @excel_output = 1
	, @perpage = 2000
	, @page = 1
	, @transaction_type = 'all'
	, @combine_transactions = 1
-- demo, 81 rows

select * from billinglinklookup WHERE receipt_id in (757041, 757042, 757043, 757044, 757045, 757046, 757047, 757048, 757049, 757050, 757051, 757052, 757053) and company_id = 21

SELECT  * FROM    billing WHERE  receipt_id = 164765 and company_id = 27

-- 2054.42
SELECT  * FROM    billingdetail WHERE billing_uid in (
SELECT  billing_uid FROM    billing WHERE  receipt_id = 164765 and company_id = 27
)
-- 2314.16
SELECT  * FROM    invoicedetail WHERE  receipt_id = 164765 and company_id = 27
SELECT  * FROM    invoiceheader WHERE invoice_id = 1577998 -- 2975.87
SELECT  * FROM    invoicedetail WHERE invoice_id = 1577998 -- 2716.13
select 0.00	+ 259.74	+ 661.71	+ 2054.42	+ 0.00	+ 0.00 -- 2975.87
SELECT  sum(total_extended_amt) FROM    billing WHERE  invoice_code = '610444' -- 2716.13
SELECT  sum(extended_amt) FROM    billingdetail WHERE billing_uid in (
SELECT  billing_uid FROM    billing WHERE  invoice_code = '610444'
)


exec sp_cor_schedule_service_receipt_list
	@web_userid = 'zachery.wright'
	, @transaction_id = 24520500

	exec sp_cor_service_disposal
	@web_userid = 'zachery.wright'
	, @workorder_id = 24520500
	, @company_id = 14
	, @profit_ctr_id = 6
	, @manifest = '24520500'


	
exec sp_cor_schedule_service_receipt_list
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2018'
	, @date_end = '5/31/2038'
	, @date_specifier	= null	-- 'Requested', 'Scheduled', 'Service' (default = service)
    , @customer_search	= null
    , @manifest			= null
	, @schedule_type	= null
	, @service_type		= null -- 'Distribution Center'
    , @generator_name	= null
    , @epa_id			= null -- can take CSV list
    , @store_number		= null -- can take CSV list
	-- , @generator_district = null -- can take CSV list
    , @generator_region	= null -- can take CSV list
    , @transaction_id	= null
    , @approval_code = 'HFHW02L'
    , @facility			= null
    , @status			= null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
    , @adv_search		= null
	, @sort				= '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				= 1
	, @perpage			= 20
	, @excel_output		= 1
	, @customer_id_list =  '15551'
	, @generator_id_list = '122955,132101'

SELECT  *  FROM    receipt where receipt_id = 2009774 and company_id = 21 and approval_code = 'HFUW13'
SELECT  *  FROM    workorderdetail where workorder_id =22656300 and profit_ctr_id =6
-- SERVICE_TYPE testing:
-- No filter: 2390
-- Store: 12
-- Dist: 0
SELECT  *  FROM    workorderheader where customer_id = 15551 and generator_sublocation_id is not null and start_date <= '12/31/2015'
-- 12.  All store.  Seems legit.

SELECT  *  FROM    contact where web_userid = 'nyswyn100'
SELECT  *  FROM    contactxref WHERE contact_id = 185547
SELECT  *  FROM    generatorsublocation WHERE customer_id = 15551
-- Store: id = 28
-- Distribution Center: id = 37

-- SCHEDULE_TYPE testing:

SELECT  *  FROM    contact where web_userid = 'zachery.wright'
SELECT  *  FROM    contactxref WHERE contact_id = 184522
SELECT  *  FROM    generatorsublocation WHERE customer_id = 15622


SELECT  *  FROM    workorderheader where customer_id = 15622 and workorderscheduletype_uid is not null and start_date <= '12/31/2015'
-- none to test.

		
SELECT  *  FROM    workorderdetail WHERE workorder_id = 22445900 and company_id = 14 and profit_ctr_id = 0
	
******************************************************************* */


--#region Debugging
/*
declare
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(10) = null	-- 'Requested', 'Scheduled', 'Service' (default = service)
	-- Receipts don't use a specifier, so this field does not apply to Receipts

	, @customer_search	varchar(max) = null
	, @manifest			varchar(max) = null

	, @schedule_type	varchar(max) = null	-- Ignored for Receipts
	, @service_type		varchar(max) = null	-- Ignored for Receipts

	--    , @generator_search	varchar(max) = null
	, @generator_name	varchar(max) = null
	, @epa_id			varchar(max) = null -- can take CSV list
	, @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
	, @generator_division varchar(max) = null -- can take CSV list
	, @generator_state	varchar(max) = null -- can take CSV list
	, @generator_region	varchar(max) = null -- can take CSV list
	, @approval_code	varchar(max) = null	-- Approval Code List
	, @transaction_id	varchar(max) = null
	, @transaction_type	varchar(20) = 'all' -- always receipt in this proc
	, @facility			varchar(max) = null

	, @project_code       varchar(max) = null           -- Project Code Ignored for Receipts

	, @release_code       varchar(50) = null    -- Release code (NOT a list)
	, @purchase_order     varchar(20) = null    -- Purchase Order
	, @search			varchar(max) = null -- Common search
	, @adv_search		varchar(max) = null
    , @status			varchar(max) = null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @combine_transactions bit = 1

	select
	@web_userid = 'nyswyn100'
	, @date_start = '11/1/2019'
	, @date_end = '12/31/2021'
	, @date_specifier = null -- 'Requested', 'Scheduled', 'Service' (default = service)
	, @customer_search = null
	, @manifest = null
	, @schedule_type = null
	, @service_type = null -- 'Distribution Center'
	, @generator_name = null
	, @epa_id = null -- can take CSV list
	, @store_number = null -- can take CSV list
	-- , @generator_district = null -- can take CSV list
	, @generator_region = null -- can take CSV list
	, @transaction_id = null
	, @transaction_type = 'all'
	, @generator_state = ''
	, @generator_division = ''
	, @approval_code = ''
	, @facility = null
	, @status = null -- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
	, @adv_search = null
	, @sort = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page = 1
	, @perpage = 20000
	, @excel_output = 0
	, @customer_id_list =  ''
	, @generator_id_list = ''
	, @combine_transactions = 1

-- SELECT  *  FROM    generator where generator_id = 75040

*/

--#endregion

-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_date_start			datetime = convert(date, isnull(@date_start, '1/1/1999'))
	, @i_date_end			datetime = convert(date, isnull(@date_end, '1/1/1999'))
	, @i_date_specifier		varchar(10) = isnull(@date_specifier, 'service')
    , @i_customer_search	varchar(max) = isnull(@customer_search, '')
    , @i_manifest			varchar(max) = replace(isnull(@manifest, ''), ' ', ',')
	, @i_schedule_type		varchar(max) = @schedule_type
	, @i_service_type		varchar(max) = @service_type
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
	, @i_generator_division varchar(max) = isnull(@generator_division, '')
	, @i_generator_state	varchar(max) = isnull(@generator_state, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_transaction_id		varchar(max) = isnull(@transaction_id, '')
    , @i_transaction_type	varchar(20) = isnull(@transaction_type, 'all')
    , @i_facility			varchar(max) = isnull(@facility, '')
    , @i_status				varchar(max) = isnull(@status, '')
    , @i_approval_code_list		varchar(max) = isnull(@approval_code, '')
    , @i_release_code       varchar(50) = isnull(@release_code, '')
    , @i_purchase_order     varchar(20) = isnull(@purchase_order, '')
	, @i_project_code		varchar(max) = isnull(@project_code, '')
	, @i_search				varchar(max) = dbo.fn_CleanPunctuation(isnull(@search, ''))
    , @i_adv_search			varchar(max) = @adv_search
	, @i_sort				varchar(20) = isnull(@sort, '')
	, @i_page				bigint = isnull(@page, 1)
	, @i_perpage			bigint = isnull(@perpage, 20)
	, @debugstarttime	datetime = getdate()
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_combine_transactions bit = isnull(@combine_transactions, 0)
	, @i_dashboard_service_status varchar(20) = isnull(@dashboard_service_status, '')
	, @i_dashboard_service_status_period	varchar(2) = isnull(@dashboard_service_status_period,'')
	, @i_contact_id			int
	

--#region Parse/Handle Inputs

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if @i_sort not in ('Transaction Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status','Customer Name', 'Generator Name') set @i_sort = ''
if @i_date_start = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if @i_date_end = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'
if @i_transaction_type not in ('all', 'receipt', 'workorder') set @i_transaction_type = 'all'

-- Define the 'today' variable used in the selects  
DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   

 declare @customer_list table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer_list select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator_list table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator_list select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @tcustomer table (
	customer_id	int
)
if @i_customer_search <> ''
insert @tcustomer
select customer_id from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 

declare @tscheduletype table (
	schedule_type	varchar(20)
)
if @i_schedule_type <> ''
insert @tscheduletype
select left(row, 20) from dbo.fn_SplitXsvText(',',1,@i_schedule_type)

declare @tservicetype table (
	service_type	varchar(100) -- generator sublocation
)
if @i_service_type <> ''
insert @tservicetype
select left(row, 100) from dbo.fn_SplitXsvText(',',1,@i_service_type)

/*
declare @tgenerator table (
	generator_id	int
)
if @i_generator_search <> ''
insert @tgenerator
select generator_id from dbo.fn_COR_GeneratorID_Search(@i_web_userid, @i_generator_search) 
*/

declare @epaids table (
	epa_id	varchar(20)
)
if @i_epa_id <> ''
insert @epaids (epa_id)
select left(row, 20) from dbo.fn_SplitXsvText(',', 1, @i_epa_id)
where row is not null

declare @tdistrict table (
	generator_district	varchar(50)
)
if @i_generator_district <> ''
insert @tdistrict
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_district)

declare @tdivision table (
	generator_division	varchar(40)
)
if @i_generator_division <> ''
insert @tdivision
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_division)

/*
declare @tstate table (
	generator_state	varchar(2)
)
if @i_generator_state <> ''
insert @tstate
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_state)
*/

declare @statecodes table (
	state_name varchar(50)
	, country	varchar(3)
)
if @i_generator_state <> ''
insert @statecodes (state_name, country)
select sa.abbr, sa.country_code
from dbo.fn_SplitXsvText(',', 1, @i_generator_state) x
join stateabbreviation sa
on (
	sa.state_name = x.row and x.row not like '%-%'
	or
	sa.abbr = x.row and x.row not like '%-%'
	or
	sa.abbr + '-' + sa.country_code = x.row and x.row like '%-%'
	or
	sa.country_code  + '-' + sa.abbr= x.row and x.row like '%-%'
)
where row is not null

declare @tstorenumber table (
	site_code	varchar(16),
	idx	int not null
)
if @i_store_number <> ''
insert @tstorenumber (site_code, idx)
select row, idx from dbo.fn_SplitXsvText(',', 1, @i_store_number) where row is not null

declare @tsitetype table (
	site_type	varchar(40)
)
if @i_site_type <> ''
insert @tsitetype (site_type)
select row from dbo.fn_SplitXsvText(',', 1, @i_site_type) where row is not null

declare @tgeneratorregion table (
	generator_region_code	varchar(40)
)
if @i_generator_region <> ''
insert @tgeneratorregion
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_region)

declare @tmanifest table (
	manifest	varchar(20)
)
if @i_manifest <> ''
insert @tmanifest
select row 
from dbo.fn_splitxsvtext(',', 1, @i_manifest) 
where row is not null

declare @approvalcode table (
	approval_code	varchar(15)
)
if @i_approval_code_list <> ''
insert @approvalcode
select row 
from dbo.fn_splitxsvtext(',', 1, @i_approval_code_list) 
where row is not null

declare @ttransid table (
	transaction_id int
)
if @i_transaction_id <> ''
insert @ttransid
select convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @i_transaction_id) 
where row is not null

declare @copc table (
	company_id int
	, profit_ctr_id int
)
IF LTRIM(RTRIM(@i_facility)) in ('', 'ALL')
	INSERT @copc
	SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	WHERE ProfitCenter.status = 'A'
ELSE
	INSERT @copc
	SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	INNER JOIN (
		SELECT
			RTRIM(LTRIM(SUBSTRING(ROW, 1, CHARINDEX('|',ROW) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(ROW, CHARINDEX('|',ROW) + 1, LEN(ROW) - (CHARINDEX('|',ROW)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @i_facility)
		WHERE ISNULL(ROW, '') <> '') selected_copc ON
			ProfitCenter.company_id = selected_copc.company_id
			AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
	WHERE ProfitCenter.status = 'A'

declare @tstatus table (
	status	varchar(20)
)
if @i_status <> ''
insert @tstatus
select row from dbo.fn_SplitXsvText(',', 1, @i_status)  where isnull(row, '') not in ('', 'all')
-- all is the absence of any other specific type


--#endregion
--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after setup' as milestone

declare @foo table (
		source	char(1) NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date	datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
		, customer_id	int
		, generator_id	int
	)
	
-- The initial population of @foo.  Nothing gets in the SP results without starting here.	
-- If you wanted to totally change SP logic, you'd change this.

if @i_dashboard_service_status in (
	'service_date',
	'service_scheduled',
	'service_pending'
) begin -- population to match sp_cor_dashboard_service_status logic

	set @i_transaction_type = 'workorder'

	-- logic copied from sp_cor_dashboard_service_status
		declare
		@i_start_date	datetime = @i_date_start
		, @i_end_date	datetime = @i_date_end
		, @i_period		varchar(2)	= @i_dashboard_service_status_period

		if @i_end_date is null begin
			set @i_end_date = convert(date, getdate())
			set @i_start_date = convert(date, @i_end_date-7)
		end
		else 
			if @i_start_date is null 
				set @i_start_date = convert(date, @i_end_date-7)

		if datepart(hh, @i_end_date) = 0
			set @i_end_date = @i_end_date + 0.99999

		if isnull(@i_period, '') <> ''
			select @i_start_date = dbo.fn_FirstOrLastDateOfPeriod(0, @i_period, 'service_status')
				, @i_end_date = dbo.fn_FirstOrLastDateOfPeriod(1, @i_period, 'service_status')
	-- end of logic copied from sp_cor_dashboard_service_status

/*
2.2.1. The count of “Service Request” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order start date is within the period of time for the metric.
*/	
	if @i_dashboard_service_status = 'service_date'
		insert @foo
		SELECT  
				'W' as source,
				x.workorder_id,
				x.company_id,
				x.profit_ctr_id,
				isnull(x.service_date, x.start_date),
				x.prices
				, x.invoice_date
				, x.customer_id
				, x.generator_id
		from ContactCorWorkOrderHeaderBucket x (nolock)
		WHERE x.contact_id = @i_contact_id
		and x.start_date between @i_start_date and @i_end_date
		and x.generator_id is not null

/*
2.2.2. The count of “Service Scheduled” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order has a scheduled service date entered that is within the 
date range of the metric. To qualify, the work order should not have a 
status of completed and it should also not be submitted.
*/	
	if @i_dashboard_service_status = 'service_scheduled'
		insert @foo
		SELECT  
				'W' as source,
				x.workorder_id,
				x.company_id,
				x.profit_ctr_id,
				isnull(x.service_date, x.start_date),
				x.prices
				, x.invoice_date
				, x.customer_id
				, x.generator_id
		from ContactCorWorkOrderHeaderBucket x (nolock)
		join workorderheader h (nolock)
			on x.workorder_id = h.workorder_id
			and x.company_id = h.company_id
			and x.profit_ctr_id = h.profit_ctr_id
		WHERE x.contact_id = @i_contact_id
		and x.scheduled_date between @i_start_date and @i_end_date
		and x.report_status <> 'Completed'
		and isnull(h.submitted_flag, 'F') = 'F'
		and h.generator_id is not null

/*
2.2.3. The count of “Service Pending” is a count of all work orders that 
are not voided and not a template for the customer’s access where the 
work order start date is within the period of time for the metric and 
the work order does not have a scheduled service date entered.
*/	

	if @i_dashboard_service_status = 'service_pending'
		insert @foo
		SELECT  
				'W' as source,
				b.workorder_id,
				b.company_id,
				b.profit_ctr_id,
				isnull(b.service_date, b.start_date),
				b.prices
				, b.invoice_date
				, b.customer_id
				, b.generator_id
		from ContactCorWorkOrderHeaderBucket b (nolock)
		join WorkOrderHeader woh (nolock)
			on woh.company_id = b.company_id
			and woh.profit_ctr_id = b.profit_ctr_id
			and woh.workorder_ID = b.workorder_id
		WHERE b.contact_id = @i_contact_id
		and b.start_date between @i_start_date and @i_end_date
		and b.scheduled_date is null
		and woh.generator_id is not null

	-- after the 3 options for criteria
	-- use a @foo_copy table to restrict the rest of possible input criteria like @foo does below/historically.

	declare @foo_temp table (
		source	char(1) NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date	datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
		, customer_id	int
		, generator_id	int
	)
	insert @foo_temp
	SELECT  a.*  
	FROM    @foo a
	inner join ContactCORWorkorderHeaderBucket x
		on a.receipt_id = x.workorder_id
		and a.company_id= x.company_id
		and a.profit_ctr_id = x.profit_ctr_id
		and x.contact_id = @i_contact_id
	left join Generator d on x.generator_id = d.generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	WHERE 
		1=1
		and (
			@i_transaction_id = ''
			or 
			(exists (select top 1 1 from @ttransid where x.workorder_id = transaction_id))
		)
		and (
			@i_facility = ''
			or 
			(exists (select top 1 1 from @copc where company_id = x.company_id and profit_ctr_id = x.profit_ctr_id))
		)
		--and (
		--	@i_date_specifier <> 'service'
		--	or (@i_date_specifier = 'service' and isnull(x.service_date, x.start_date) between @i_date_start and @i_date_end)
		--)
		and (
			not exists (select 1 from @tcustomer) 
			or
			(x.customer_id in (select customer_id from @tcustomer))
		)
		and
			(
				@i_customer_id_list = ''
				or
				 (
					@i_customer_id_list <> ''
					and
					x.customer_id in (select customer_id from @customer_list)
				 )
			   )
			 and
			 (
				@i_generator_id_list = ''
				or
				(
					@i_generator_id_list <> ''
					and
				 x.Generator_id in (select generator_id from @generator_list)
				)
			  )

			and
			(
				@i_generator_name = ''
				or
				(
					@i_generator_name <> ''
					and
					isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
				)
			)
			and 
			(
				@i_epa_id = ''
				or
				(
					@i_epa_id <> ''
					and
					isnull(d.epa_id,'') in (select epa_id from @epaids)
				)
			)
			and 
			(
				@i_generator_region = ''
				or
				(
					@i_generator_region <> ''
					and
					isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
				)
			)
			and 
			(
				@i_generator_district = ''
				or
				(
					@i_generator_district <> ''
					and
					isnull(d.generator_district, '') in (select generator_district from @tdistrict)
				)
			)
			and (
				@i_generator_division = ''
				or
				(
					@i_generator_division <> ''
					and
					isnull(d.generator_division, '') in (select generator_division from @tdivision)
				)
			)
			and (
				@i_generator_state = ''
				or
				(
					@i_generator_state <> ''
					and	
					-- and isnull(d.generator_state, '') in (select generator_state from @tstate)
					exists(
						select 1 from @statecodes t 
						where isnull(nullif(d.generator_country, ''), 'USA') = t.country
						and isnull(d.generator_state, '') = t.state_name
					)
				)
			)
			and (
				@i_store_number = ''
				or
				(
					@i_store_number <> ''
					and
					s.idx is not null
				)
			)
			and 
			(
				@i_site_type = ''
				or
				(
					@i_site_type <> ''
					and
					isnull(d.site_type,'') in (select site_type from @tsitetype)
				)
			)

		delete from @foo
		insert @foo select * from @foo_temp
	

end 
else 
begin -- "normal" (work order + receipt) population
	insert @foo
	SELECT  
			'W' as source,
			x.workorder_id,
			x.company_id,
			x.profit_ctr_id,
			isnull(x.service_date, x.start_date),
			x.prices
			, x.invoice_date
			, x.customer_id
			, x.generator_id
	FROM    ContactCORWorkorderHeaderBucket x (nolock) 
	left join Generator d on x.generator_id = d.generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	WHERE 
		x.contact_id = @i_contact_id
		and @i_transaction_type in ('all', 'workorder')
		and (
			@i_transaction_id = ''
			or 
			(exists (select top 1 1 from @ttransid where x.workorder_id = transaction_id))
		)
		and (
			@i_facility = ''
			or 
			(exists (select top 1 1 from @copc where company_id = x.company_id and profit_ctr_id = x.profit_ctr_id))
		)
		and (
			@i_date_specifier <> 'service'
			or (@i_date_specifier = 'service' and isnull(x.service_date, x.start_date) between @i_date_start and @i_date_end)
		)
		and (
			not exists (select 1 from @tcustomer) 
			or
			(x.customer_id in (select customer_id from @tcustomer))
		)
		and
			(
				@i_customer_id_list = ''
				or
				 (
					@i_customer_id_list <> ''
					and
					x.customer_id in (select customer_id from @customer_list)
				 )
			   )
			 and
			 (
				@i_generator_id_list = ''
				or
				(
					@i_generator_id_list <> ''
					and
				 x.Generator_id in (select generator_id from @generator_list)
				)
			  )

			and
			(
				@i_generator_name = ''
				or
				(
					@i_generator_name <> ''
					and
					isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
				)
			)
			and 
			(
				@i_epa_id = ''
				or
				(
					@i_epa_id <> ''
					and
					isnull(d.epa_id,'') in (select epa_id from @epaids)
				)
			)
			and 
			(
				@i_generator_region = ''
				or
				(
					@i_generator_region <> ''
					and
					isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
				)
			)
			and 
			(
				@i_generator_district = ''
				or
				(
					@i_generator_district <> ''
					and
					isnull(d.generator_district, '') in (select generator_district from @tdistrict)
				)
			)
			and (
				@i_generator_division = ''
				or
				(
					@i_generator_division <> ''
					and
					isnull(d.generator_division, '') in (select generator_division from @tdivision)
				)
			)
			and (
				@i_generator_state = ''
				or
				(
					@i_generator_state <> ''
					and	
					-- and isnull(d.generator_state, '') in (select generator_state from @tstate)
					exists(
						select 1 from @statecodes t 
						where isnull(nullif(d.generator_country, ''), 'USA') = t.country
						and isnull(d.generator_state, '') = t.state_name
					)
				)
			)
			and (
				@i_store_number = ''
				or
				(
					@i_store_number <> ''
					and
					s.idx is not null
				)
			)
			and 
			(
				@i_site_type = ''
				or
				(
					@i_site_type <> ''
					and
					isnull(d.site_type,'') in (select site_type from @tsitetype)
				)
			)


	UNION
	SELECT  
			'R' as source,
			x.receipt_id,
			x.company_id,
			x.profit_ctr_id,
			isnull(x.pickup_date, x.receipt_date),
			x.prices
			, x.invoice_date
			, x.customer_id
			, x.generator_id
	FROM    ContactCORReceiptBucket x  (nolock) 
	left join Generator d on x.generator_id = d.generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	WHERE 
		x.contact_id = @i_contact_id
		and @i_transaction_type in ('all', 'receipt')
		and isnull(x.pickup_date, x.receipt_date) between @i_date_start and @i_date_end
		and x.invoice_date is not null
		and (
			isnull(@i_transaction_id, '') = ''
			or 
			(x.receipt_id in (select transaction_id from @ttransid))
		)
		and (
			isnull(@i_facility, '') = ''
			or 
			(exists (select 1 from @copc where company_id = x.company_id and profit_ctr_id = x.profit_ctr_id))
		)
		and (
			not exists (select 1 from @tcustomer) 
			or
			(x.customer_id in (select customer_id from @tcustomer))
		)
			and
			(
				@i_customer_id_list = ''
				or
				 (
					@i_customer_id_list <> ''
					and
					x.customer_id in (select customer_id from @customer_list)
				 )
			   )
			 and
			 (
				@i_generator_id_list = ''
				or
				(
					@i_generator_id_list <> ''
					and
				 x.Generator_id in (select generator_id from @generator_list)
				)
			  )

			and
			(
				@i_generator_name = ''
				or
				(
					@i_generator_name <> ''
					and
					isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
				)
			)
			and 
			(
				@i_epa_id = ''
				or
				(
					@i_epa_id <> ''
					and
					isnull(d.epa_id,'') in (select epa_id from @epaids)
				)
			)
			and 
			(
				@i_generator_region = ''
				or
				(
					@i_generator_region <> ''
					and
					isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
				)
			)
			and 
			(
				@i_generator_district = ''
				or
				(
					@i_generator_district <> ''
					and
					isnull(d.generator_district, '') in (select generator_district from @tdistrict)
				)
			)
			and (
				@i_generator_division = ''
				or
				(
					@i_generator_division <> ''
					and
					isnull(d.generator_division, '') in (select generator_division from @tdivision)
				)
			)
			and (
				@i_generator_state = ''
				or
				(
					@i_generator_state <> ''
					and	
					-- and isnull(d.generator_state, '') in (select generator_state from @tstate)
					exists(
						select 1 from @statecodes t 
						where isnull(nullif(d.generator_country, ''), 'USA') = t.country
						and isnull(d.generator_state, '') = t.state_name
					)
				)
			)
			and (
				@i_store_number = ''
				or
				(
					@i_store_number <> ''
					and
					s.idx is not null
				)
			)
			and 
			(
				@i_site_type = ''
				or
				(
					@i_site_type <> ''
					and
					isnull(d.site_type,'') in (select site_type from @tsitetype)
				)
			)
end -- end of "normal" (work order + receipt) population
-- end of the initial population of @foo.  Nothing gets in the SP results without starting here.

-- gather per-transaction billed amount
declare @billing table (
	trans_source	char(1)
	, receipt_id	int
	, company_id	int
	, profit_ctr_id	int
	, total_amount	money
)

insert @billing
	select
	b.trans_source
	, b.receipt_id
	, b.company_id
	, b.profit_ctr_id
	, sum(bd.extended_amt)
from @foo x
join billing b
	on x.receipt_id = b.receipt_id
	and b.line_id = b.line_id
	and b.price_id = b.price_id
	and x.source = b.trans_source
	and x.profit_ctr_id = b.profit_ctr_id
	and x.company_id = b.company_id
join billingdetail bd
	on b.billing_uid = bd.billing_uid
where
	x.prices > 0
	and b.status_code = 'I'
group by
	b.trans_source
	, b.receipt_id
	, b.company_id
	, b.profit_ctr_id

print 'Past @billing'
-- end of gather per-transaction billed amount


-- transaction combining optional logic
-- BillingLinkLookup reduction --
-- delete from @foo (the records included in the rest of this SP/output)
-- where they are receipts that are invoiced, that are billinglink'd to work orders
-- that are also in this output set.
-- we're setting source to X so we can examine affected records before actually deleting them
update @foo set source = 'X' from @foo x where exists (
	select 1
	from @foo r
	join @billing b
	on r.source = b.trans_source
	and r.receipt_id = b.receipt_id
	and r.company_id = b.company_id
	and r.profit_ctr_id = b.profit_ctr_id
	and r.source = 'R'
	join billinglinklookup bll
	on r.receipt_id = bll.receipt_id
	and r.company_id = bll.company_id
	and r.profit_ctr_id = bll.profit_ctr_id
	join @foo w
	on bll.source_id = w.receipt_id
	and bll.source_company_id = w.company_id
	and bll.source_profit_ctr_id = w.profit_ctr_id
	and w.source = 'W'
	where
	x.source = r.source
	and x.receipt_id = r.receipt_id
	and x.company_id = r.company_id
	and x.profit_ctr_id = r.profit_ctr_id
)
and @i_transaction_type = 'all'
and @i_combine_transactions = 1

-- SELECT  * FROM    @foo

-- orig: 80 total in @foo, 35 receipts
-- type R: 35 rows, all receipt
-- type W: 45 rows, all W
-- type A, combine: 80 total, all R's removed.
-- let's fudge an R _out_ of @billing, see if it works...
-- it works.


delete from @foo where source = 'X'
-- end of transaction combining optional logic


-- filter work orders by date specifier and range logic
if (@i_date_specifier <> 'service') begin
declare @foo_copy table (
		source	char(1) NOT NULL,
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date	datetime NULL,
		prices		bit NOT NULL
		, invoice_date datetime NULL
		, customer_id	int
		, generator_id	int
	)
	insert @foo_copy
	SELECT  x.*  FROM    @foo x
		inner join workorderstop wos (nolock)
		on wos.workorder_id = x.receipt_id 
		and wos.company_id = x.company_id 
		and wos.profit_ctr_id = x.profit_ctr_id
		and wos.stop_sequence_id = 1
		and (
			(@i_date_specifier = 'requested' and wos.date_request_initiated between @i_date_start and @i_date_end and wos.date_est_arrive is null)
			or (@i_date_specifier = 'scheduled' and wos.date_est_arrive between @i_date_start and @i_date_end)
		)
		where x.source = 'W'
		union
	SELECT x.* from @foo x
	WHERE x.source = 'R'
	delete from @foo
	insert @foo select * from @foo_copy
	delete from @foo_copy
end
-- end of filter work orders by date specifier and range logic	


-- filter by schedule type, service type, po and release, calculate display status
declare @bar table (
	source	char(1)
	, receipt_id	int
	, company_id int
	, profit_ctr_id int
	, min_line_id int
	, start_date datetime
	, prices int
	, invoice_date	datetime
	, customer_id int
	, generator_id int
	, status varchar(20)
	, service_date datetime
)

insert @bar
select distinct x.source, x.receipt_id, x.company_id, x.profit_ctr_id, 1, z.start_date, x.prices, x.invoice_date
, x.customer_id
, x.generator_id
, 	status = case 
		when ((wos.date_request_initiated is not null and wos.date_est_arrive is null
			-- and not completed
			and not isnull(z.end_date, getdate()+1) <= @today and b.billing_uid is null)
			OR (wos.date_request_initiated is null and wos.date_est_arrive is null and z.end_date is null
			and wos.date_est_arrive is null and z.start_date is null))
				then 'Requested'
		when (wos.date_est_arrive is not null
			-- and not completed
			and not isnull(z.end_date, getdate()+1) <= @today and b.billing_uid is null)
				then 'Scheduled'
		when (isnull(wos.date_act_arrive, getdate()+1) <= @today and b.billing_uid is null)
				then 'Completed'
		when (b.billing_uid is not null or z.submitted_flag = 'T')
				then 'Invoiced'
		else
			'Unknown'
		end
, x.receipt_date
from @foo x
join workorderheader z (nolock) on x.receipt_id = z.workorder_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
left join workorderstop wos  (nolock)
	on wos.workorder_id = x.receipt_id 
	and wos.company_id = x.company_id 
	and wos.profit_ctr_id = x.profit_ctr_id
	and wos.stop_sequence_id = 1
left join billing b (nolock)
	on b.receipt_id = x.receipt_id 
	and b.company_id = x.company_id 
	and b.profit_ctr_id = x.profit_ctr_id 
	and b.trans_source = 'w' 
	and b.status_code = 'I'
WHERE x.source = 'W'
	and z.workorder_status NOT IN ('V','X','T')
	and (
		(select count(*) from @tscheduletype) = 0
		or 
		(exists (select top 1 1 from @tscheduletype tst join WorkorderScheduleType wst on tst.schedule_type = wst.schedule_type where wst.workorderscheduletype_uid = z.workorderscheduletype_uid))
	)
	and (
		(select count(*) from @tservicetype) = 0
		or 
		(exists (select top 1 1 from @tservicetype tst join GeneratorSubLocation gsl on tst.service_type = gsl.description where gsl.generator_sublocation_ID = z.generator_sublocation_ID))
	)
	and (
		@i_release_code = ''
		OR z.release_code like '%' + @i_release_code + '%'
	)
	and (
		@i_purchase_order = ''
		OR z.purchase_order like '%' + @i_purchase_order + '%'
	)
UNION
select x.source, z.receipt_id, z.company_id, z.profit_ctr_id, min(z.line_id) as min_line_id, z.receipt_date, x.prices, x.invoice_date
, x.customer_id
, x.generator_id
, null as status
, x.receipt_date
from @foo x
join receipt z (nolock) on x.receipt_id = z.receipt_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
WHERE x.source = 'R'
and z.trans_mode = 'I' and z.receipt_status <> 'V' and z.receipt_status <> 'R'
and exists (select billing_uid from billing b (nolock) where b.receipt_id = z.receipt_id and b.line_id = z.line_id and b.price_id = b.price_id and b.trans_source = 'R' and b.profit_ctr_id = z.profit_ctr_id and b.company_id = z.company_id and b.status_code = 'I')
	--and (
	--	isnull(@i_approval_code_list, '') = ''
	--	or 
	--	(exists
	--		(
	--		select 1 from receipt _z (nolock)
	--		join @approvalcode ac 
	--		on _z.receipt_id = x.receipt_id
	--		and _z.company_id = x.company_id
	--		and _z.profit_ctr_id = x.profit_ctr_id
	--		and _z.approval_code like '%' + replace(ac.approval_code, ' ', '%') + '%'
	--		)
	--	)
	--)
	and (
		@i_release_code = ''
		OR z.release like '%' + @i_release_code + '%'
	)
	and (
		@i_purchase_order = ''
		OR z.purchase_order like '%' + @i_purchase_order + '%'
	)
group by x.source, z.receipt_id, z.company_id, z.profit_ctr_id, z.receipt_date, x.prices, x.invoice_date, x.customer_id, x.generator_id, x.receipt_date
-- end of filter by schedule type, service type, po and release, calculate display status


--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar' as milestone
	
---- debug:
--SELECT  count(*) as bar_count  FROM    @bar

-- start minimizng @bar contents to just 1 row per transaction
declare @bar_copy table (
	source	char(1)
	, receipt_id int
	, company_id int
	, profit_ctr_id int
	, min_line_id int
	, start_date datetime
	, prices int
	, invoice_date	datetime
	, customer_id int
	, generator_id int
	, status varchar(20)
	, service_date	datetime
)

	delete from @bar_copy
	insert @bar_copy 
	select 
		source, 
		receipt_id, 
		company_id, 
		profit_ctr_id, 
		min(min_line_id) min_line_id,
		start_date,
		max(prices) prices,
		invoice_date,
		customer_id,
		generator_id,
		status
		, service_date
	from @bar
	GROUP BY 
		source, 
		receipt_id, 
		company_id, 
		profit_ctr_id, 
		start_date,
		invoice_date,
		customer_id,
		generator_id,
		status
		, service_date
		
	delete from @bar
	insert @bar select * from @bar_copy
-- end of minimizng @bar contents to just 1 row per transaction



if (select count(*) from @tstatus) > 0 begin
	delete from @bar_copy
	insert @bar_copy select * from @bar
	where source = 'W' and status in (select status from @tstatus)
	union
	select * from @bar where source = 'R'
	delete from @bar
	insert @bar select * from @bar_copy
end

if (select count(*) from @approvalcode) > 0 begin
	delete from @bar_copy
	insert @bar_copy select * from @bar z
	where source = 'W' -- and status in (select status from @tstatus)
	and 
		exists
			(
			select 1 from workorderdetail _z (nolock)
			join @approvalcode ac on			
				_z.workorder_id = z.receipt_id
				and _z.company_id = z.company_id
				and _z.profit_ctr_id = z.profit_ctr_id
				and _z.resource_type= 'D' and _z.bill_rate > -2
				and _z.tsdf_approval_code like '%' + replace(ac.approval_code, ' ', '%') + '%'
			)
	union
	select * from @bar z where source = 'R'
	and 
		exists
			(
			select 1 from receipt _z (nolock)
			join @approvalcode ac on			
				_z.receipt_id = z.receipt_id
				and _z.company_id = z.company_id
				and _z.profit_ctr_id = z.profit_ctr_id
				and _z.approval_code like '%' + replace(ac.approval_code, ' ', '%') + '%'
			)
	
	delete from @bar
	insert @bar select * from @bar_copy
end

if (@i_manifest <> '') begin
	delete from @bar_copy
	insert @bar_copy 
	select z.* 
	from @bar z
	left join Receipt r (nolock) on z.source = 'R' and r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
	where 1=1
	and ( 
		@i_manifest = ''
		or 
		(
			(
				z.source = 'W' 
				and exists (
					select top 1 1 
					from workordermanifest m (nolock) 
					join @tmanifest t 
						on m.manifest like '%' + t.manifest + '%'
					where m.workorder_id = z.receipt_id 
					and m.company_id = z.company_id 
					and m.profit_ctr_id = z.profit_ctr_id
				)
			)
			or
			(
				z.source = 'R' 
				and r.manifest in (select manifest from @tmanifest)
			)
		)
	)
	delete from @bar
	insert @bar select distinct * from @bar_copy
end
print 'Past @manifest'



if (@i_search <> '') begin
	delete from @bar_copy
	insert @bar_copy 
	select z.* 
	from @bar z 
		join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
		join Customer c (nolock) on c.customer_id = z.customer_id
		left join Generator g (nolock) on g.generator_id = z.generator_id 
		left join WorkorderHeader h (nolock) on z.source = 'W' and h.workorder_id = z.receipt_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
		left join WorkorderDetail d (nolock) on z.source = 'W' and d.workorder_id = z.receipt_id and d.company_id = z.company_id and d.profit_ctr_id = z.profit_ctr_id
		left join Receipt r (nolock) on z.source = 'R' and r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
		left join WorkorderType wtype (nolock) on z.source = 'W' and h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
		left join workorderstop wos (nolock) on z.source = 'W' and wos.workorder_id = z.receipt_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1
		left join WorkorderScheduleType wst (nolock) on z.source = 'W' and h.workorderscheduletype_uid = wst.workorderscheduletype_uid
		LEFT JOIN WorkOrderTypeHeader t WITH (NOLOCK) ON t.workorder_type_id = h.workorder_type_id
		LEFT JOIN WorkOrderTypeDescription wotd (nolock) 
			ON h.workorder_type_desc_uid =  wotd.workorder_type_desc_uid 
			AND (t.account_desc like '%emergency response%' OR h.workorder_type_id in (3, 63, 77, 78, 79, 80))
		left join tsdfapproval ta (nolock) on d.tsdf_approval_id = ta.tsdf_approval_id and d.company_id = ta.company_id and d.profit_ctr_id = ta.profit_ctr_id
		left join tsdf (nolock) on d.tsdf_code = tsdf.tsdf_code
		left join profile p (nolock) on coalesce(r.profile_id, d.profile_id) = p.profile_id
	where ' ' +
		isnull(convert(varchar(20), z.receipt_id), '') + ' ' +
		isnull(c.cust_name, '') + ' ' +
		isnull(convert(varchar(20),c.customer_id), '') + ' ' +
		isnull(g.generator_name, '') + ' ' + 
		isnull(g.site_code, '') + ' ' + 
		isnull(g.site_type, '') + ' ' + 
		isnull(g.epa_id, '') + ' ' + 
		isnull(g.generator_city, '') + ' ' +
		isnull(g.generator_state, '') + ' ' +
		isnull(wst.schedule_type, '') + ' ' +
		isnull(wtype.account_desc, '') + ' ' +
		isnull(case z.source when 'W' then 
		substring((select ', ' + 
				case when wom.manifest_flag = 'T' then 
					-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
				+ 'Manifest ' else 'BOL ' end
				+ wom.manifest
				from workordermanifest wom (nolock)
				where wom.workorder_id = z.receipt_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
				for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
			else 
				r.manifest
			end, '') + ' ' +
		isnull(r.approval_code, '') + ' ' +
		isnull(p.approval_desc, '') + ' ' +
		isnull(ta.waste_stream, '') + ' ' +
		isnull(case z.source when 'R' then r.purchase_order else h.purchase_order end, '') + ' ' +
		isnull(case z.source when 'R' then r.release else h.release_code end, '') + ' ' +
		isnull(tsdf.tsdf_name, '') + ' ' +
		isnull(upc.name, '') + ' ' +
		''
	like '%' + replace(@i_search, ' ', '%') + '%'
	
	delete from @bar
	insert @bar select distinct * from @bar_copy
end
print 'Past @search'

declare @total int
select @total = count(*) from @bar

drop table if exists #foo

select * 
, convert(nvarchar(max), null) as manifest_list
, convert(nvarchar(max), null) as purchase_order
, convert(nvarchar(max), null) as release_code
, convert(nvarchar(max), null) as images
into #foo
from (
	select
		@total as _total
		,z.*
		,_row = row_number() over (order by 
			case when @i_sort in ('', 'Service Date') then case z.source when 'W' then coalesce(wos.date_act_arrive, h.start_date) else r.receipt_date end end desc,
			case when @i_sort = 'Customer Name' then c.cust_name end asc,
			case when @i_sort = 'Generator Name' then g.generator_name end asc,
			case when @i_sort = 'Schedule Type' then wst.schedule_type end desc, -- Fix when field exist
			case when @i_sort = 'Service Type' then wtype.account_desc end asc, 
			case when @i_sort = 'Requested Date' then case z.source when 'W' then wos.date_request_initiated else r.receipt_date end end desc, 
			case when @i_sort = 'Scheduled Date' then case z.source when 'W' then wos.date_est_arrive else r.receipt_date end end desc, 
			case when @i_sort = 'Status' then z.status end asc, 
			case when @i_sort = 'Manifest Number' then case z.source when 'W' then z.receipt_id else r.manifest end end desc, -- This is a CSV list subquery, not great for ordering
			case when @i_sort = 'Store Number' then g.site_code end asc,
			case when @i_sort = 'Transaction Number' then z.receipt_id end desc,
			z.start_date asc
		) 
	from @bar z 
--		join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
		join Customer c (nolock) on c.customer_id = z.customer_id
		left join Generator g (nolock) on g.generator_id = z.generator_id 
		left join WorkorderHeader h (nolock) on z.source = 'W' and h.workorder_id = z.receipt_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
		left join Receipt r (nolock) on z.source = 'R' and r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
		left join WorkorderType wtype (nolock) on z.source = 'W' and h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A' and @i_sort = 'Service Type'
		left join workorderstop wos (nolock) on z.source = 'W' and wos.workorder_id = z.receipt_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1 and @i_sort in ('Requested Date', 'Scheduled Date')
		left join WorkorderScheduleType wst (nolock) on z.source = 'W' and h.workorderscheduletype_uid = wst.workorderscheduletype_uid and @i_sort = 'Schedule Type' 
	
) y
where
    (
	(@excel_output = 0 and _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage))
	or
	(@excel_output = 1)
)
-- order by _row

update #foo set
manifest_list = case r.manifest_flag when 'M' then 'Manifest ' else 'BOL ' end + r.manifest
,purchase_order =
	( select substring(
		(select distinct ', ' + rpo.purchase_order
		FROM receipt rpo
		WHERE rpo.receipt_id = r.receipt_id
		and rpo.company_id = r.company_id
		and rpo.profit_ctr_id = r.profit_ctr_id
		order by ', ' + rpo.purchase_order
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)  
,release_code =
	( select substring(
		(select distinct ', ' + rpo.release
		FROM receipt rpo
		WHERE rpo.receipt_id = r.receipt_id
		and rpo.company_id = r.company_id
		and rpo.profit_ctr_id = r.profit_ctr_id
		order by ', ' + rpo.release
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)  
,images =
	( select substring(
		(select ', ' + coalesce(s.document_name, s.manifest, r.manifest, 'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number), '1') + '|'+coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
		FROM plt_image..scan s
		WHERE s.receipt_id = r.receipt_id
		and s.company_id = r.company_id
		and s.profit_ctr_id = r.profit_ctr_id
		and s.document_source = 'receipt'
		and s.status = 'A'
		and s.view_on_web = 'T'
		and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest') 
		order by coalesce(s.document_name, s.manifest, r.manifest), s.page_number, s.image_id
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)  
from #foo z
join Receipt r (nolock) on z.source = 'R' and r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
WHERE z.source = 'R'

update #foo set
manifest_list = 
	substring((select ', ' + 
	case when wom.manifest_flag = 'T' then 
		-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
	+ 'Manifest ' else 'BOL ' end
	+ wom.manifest
	from workordermanifest wom (nolock)
	where wom.workorder_id = z.receipt_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
	for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
,purchase_order = h.purchase_order
,release_code = h.release_code
,images =
	( select substring(
	(select ', ' + coalesce(s.document_name, s.manifest,'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number),'1') + '|'+ coalesce(s.file_type,'')+'|'+convert(Varchar(10), s.image_id)
	FROM plt_image..scan s
	WHERE s.workorder_id = h.workorder_id
	and s.company_id = h.company_id
	and s.profit_ctr_id = h.profit_ctr_id
	and s.document_source = 'workorder'
	and s.status = 'A'
	and s.view_on_web = 'T'
	and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest') 
	order by coalesce(s.document_name, s.manifest, 'Manifest'), s.page_number, s.image_id
	for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)  
from #foo z
inner join WorkorderHeader h (nolock) on z.source = 'W' and h.workorder_id = z.receipt_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
WHERE z.source = 'W'


--select * from (
	select
		case z.source when 'R' then 'Receipt' else 'Work Order' end as transaction_type
		, z.receipt_id transaction_id
		, z.company_id
		, z.profit_ctr_id
		, upc.name as USE_facility_name
		, c.cust_name
		, c.customer_id
		, g.generator_name
		, g.epa_id
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, g.site_type
		, g.generator_region_code
		, g.generator_division
		, g.site_code store_number
		, g.generator_id	
		, wos.date_request_initiated requested_date
		, wos.date_est_arrive scheduled_date
		--, case z.source when 'W' then h.start_date else r.receipt_date end as service_date
		, z.service_date
		, r.time_in
		, r.time_out
		, r.approval_code
		, wst.schedule_type
		, wtype.account_desc  as Service_Type
		, case when wtype.account_desc LIKE '%Emergency Response%' then wotd.description else null end as Emergency_Response_Type_Reason
		, z.status
		, z.manifest_list
		, z.purchase_order
		, z.release_code
/*
		, manifest_list = case z.source when 'W' then 
				substring((select ', ' + 
				case when wom.manifest_flag = 'T' then 
					-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
				+ 'Manifest ' else 'BOL ' end
				+ wom.manifest
				from workordermanifest wom (nolock)
				where wom.workorder_id = z.receipt_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
				for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
			else 
				case r.manifest_flag when 'M' then 'Manifest ' else 'BOL ' end
				+ r.manifest
			end
		, case z.source when 'W' then 
				h.purchase_order
			else
				( select substring(
					(select distinct ', ' + rpo.purchase_order
					FROM receipt rpo
					WHERE rpo.receipt_id = r.receipt_id
					and rpo.company_id = r.company_id
					and rpo.profit_ctr_id = r.profit_ctr_id
					order by ', ' + rpo.purchase_order
					for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
				)  
			end
		as purchase_order
		, case z.source when 'W' then 
				h.release_code
			else
				( select substring(
					(select distinct ', ' + rpo.release
					FROM receipt rpo
					WHERE rpo.receipt_id = r.receipt_id
					and rpo.company_id = r.company_id
					and rpo.profit_ctr_id = r.profit_ctr_id
					order by ', ' + rpo.release
					for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
				)  
			end
		as release_code		
*/
		, z.prices as show_prices
		, case when z.prices <= 0 then null else billing.total_amount end as transaction_total
		, z.images
/*
		, case z.source when 'W' then 
				( select substring(
				(select ', ' + coalesce(s.document_name, s.manifest,'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number),'1') + '|'+ coalesce(s.file_type,'')+'|'+convert(Varchar(10), s.image_id)
				FROM plt_image..scan s
				WHERE s.workorder_id = h.workorder_id
				and s.company_id = h.company_id
				and s.profit_ctr_id = h.profit_ctr_id
				and s.document_source = 'workorder'
				and s.status = 'A'
				and s.view_on_web = 'T'
				and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest') 
				order by coalesce(s.document_name, s.manifest, 'Manifest'), s.page_number, s.image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
				)  
			else
				( select substring(
				(select ', ' + coalesce(s.document_name, s.manifest, r.manifest, 'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number), '1') + '|'+coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
				FROM plt_image..scan s
				WHERE s.receipt_id = r.receipt_id
				and s.company_id = r.company_id
				and s.profit_ctr_id = r.profit_ctr_id
				and s.document_source = 'receipt'
				and s.status = 'A'
				and s.view_on_web = 'T'
				and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest') 
				order by coalesce(s.document_name, s.manifest, r.manifest), s.page_number, s.image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			)  
			end as images
*/			
		, case when z.invoice_date is not null 
			or isnull(h.submitted_flag,'F') = 'T'
				then 'T' else 'F' end as invoiced_flag
		, z._row
		, z._total

	from #foo z
		join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
		join Customer c (nolock) on c.customer_id = z.customer_id
		left join Generator g (nolock) on g.generator_id = z.generator_id 
		left join WorkorderHeader h (nolock) on z.source = 'W' and h.workorder_id = z.receipt_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
		left join Receipt r (nolock) on z.source = 'R' and r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
		left join WorkorderType wtype (nolock) on z.source = 'W' and h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
		left join workorderstop wos (nolock) on z.source = 'W' and wos.workorder_id = z.receipt_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1
		left join WorkorderScheduleType wst (nolock) on z.source = 'W' and h.workorderscheduletype_uid = wst.workorderscheduletype_uid
		LEFT JOIN WorkOrderTypeHeader t WITH (NOLOCK) ON t.workorder_type_id = h.workorder_type_id
		LEFT JOIN WorkOrderTypeDescription wotd (nolock) 
			ON h.workorder_type_desc_uid =  wotd.workorder_type_desc_uid 
			AND (t.account_desc like '%emergency response%' OR h.workorder_type_id in (3, 63, 77, 78, 79, 80))
		left join @billing billing on z.source = billing.trans_source and z.receipt_id = billing.receipt_id and z.company_id = billing.company_id and z.profit_ctr_id = billing.profit_ctr_id
	
--) y
/*
where
    (
	(@excel_output = 0 and _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage))
	or
	(@excel_output = 1)
)
*/
order by z._row


return 0
go

grant execute on sp_cor_schedule_service_receipt_list to eqai
go
grant execute on sp_cor_schedule_service_receipt_list to eqweb
go
grant execute on sp_cor_schedule_service_receipt_list to COR_USER
go
