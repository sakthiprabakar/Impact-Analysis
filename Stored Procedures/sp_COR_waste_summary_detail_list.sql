/*
DO-17159 - WSR changes

-- need a test customer.
SELECT  * FROM    customer WHERE  cust_name like '%lowes%'
SELECT  * FROM    contactcorcustomerbucket WHERE  customer_id = 601803
SELECT  * FROM    contact WHERE  contact_id = 210749
*/

-- 
USE PLT_AI

drop proc if exists sp_COR_waste_summary_detail_list
GO
create procedure sp_COR_waste_summary_detail_list (
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(20) = null	-- 'service' (default) or 'transaction'
    , @customer_search	varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list

    , @approval_code	varchar(max) = null
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */ 
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)	
AS
/* *******************************************************************
sp_COR_waste_summary_detail_list

This is basically the same selection logic as sp_cor_schedule_Services_receipt*
but a different output.  Easier to adapt the output from the existing code
than rewrite sp_reports_waste_summary

COMBINATION OF sp_cor_schedule_service_list
AND				sp_cor_receipt_list

2022-04-28 JPB	DO-40348 - String or binary data would be truncated (cust_name and gen_name fields made larger to match source tables)

Samples:

exec sp_COR_waste_summary_detail_list
	@web_userid = 'dcrozier@riteaid.com'
	, @date_start = '11/1/2015'
	, @date_end = '12/31/2015'

exec sp_COR_waste_summary_detail_list
	@web_userid = 'Bobbi.L.Tenborg@lowes.com'
	, @date_start = '7/1/2024'
	, @date_end = '12/31/2024'
	, @perpage = 2000
	, @page = 1
	
z
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

/*

DECLARE
	@web_userid			varchar(100)	= 'nyswyn100'
	, @date_start		datetime = '1/1/2018'
	, @date_end			datetime = '1/1/2020'
	, @date_specifier	varchar(10) = null	-- 'Requested', 'Scheduled', 'Service' (default = service)
		-- Receipts don't use a specifier, so this field does not apply to Receipts
	
    , @customer_search	varchar(max) = null
    /*
    , @manifest			varchar(max) = null
	*/
	, @schedule_type	varchar(max) = null	-- Ignored for Receipts
	, @service_type		varchar(max) = null	-- Ignored for Receipts

--    , @generator_search	varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    
    , @approval_code	varchar(max) = null
    
    , @transaction_id	varchar(max) = null
    , @facility			varchar(max) = null
    --, @status			varchar(max) = null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
		-- Ignored for Receipts
		-- Always 'invoiced' for WSR, implemented below.
    
	, @search			varchar(max) = null -- Common search
    , @adv_search		varchar(max) = null
--	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 

*/

SET NOCOUNT ON
SET ANSI_WARNINGS ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = isnull(@web_userid,'')
	, @i_date_start			datetime = convert(date, isnull(@date_start, '1/1/1999'))
	, @i_date_end			datetime = convert(date, isnull(@date_end, '1/1/1999'))
	, @i_date_specifier		varchar(20) = isnull(@date_specifier, 'service')
    , @i_customer_search	varchar(max) = isnull(@customer_search, '')
    -- , @i_manifest			varchar(max) = replace(isnull(@manifest, ''), ' ', ',')
	, @i_schedule_type		varchar(max) = '' -- @schedule_type
	, @i_service_type		varchar(max) = '' -- @service_type
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_approval_code		varchar(max) = isnull(@approval_code, '')
    , @i_transaction_id		varchar(max) = '' -- isnull(@transaction_id, '')
    -- , @i_transaction_type	varchar(20) = @transaction_type 
    , @i_facility			varchar(max) = '' -- isnull(@facility, '')
    -- , @i_status				varchar(max) = isnull(@status, '')
	, @i_search				varchar(max) = null -- dbo.fn_CleanPunctuation(isnull(@search, ''))
    , @i_adv_search			varchar(max) = null -- @adv_search
	-- , @i_sort				varchar(20) = isnull(@sort, '')
	, @i_page				bigint = isnull(@page, 1)
	, @i_perpage			bigint = isnull(@perpage, 20)
	, @i_debug			int = 0
	, @i_starttime		datetime = getdate()
	, @i_contact_id		int = 0
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    
select top 1  @i_contact_id = contact_id 
from CORcontact (nolock) 
where web_userid = @i_web_userid
    
-- if @i_sort not in ('Transaction Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status','Customer Name', 'Generator Name') set @i_sort = ''
if @i_date_start = '1/1/1999' 
	set @i_date_start = dateadd(m, -3, getdate())
if @i_date_end = '1/1/1999' 
	set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 
	set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' 
	set @i_date_specifier = 'service'

-- Define the 'today' variable used in the selects  
DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +    convert(varchar(2), datepart(dd, getdate())) + '/' +    convert(varchar(4), datepart(yyyy, getdate()))   

create table #customer (	customer_id	bigint)

if @i_customer_id_list <> ''
insert into #customer 
select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

create table #generator (	generator_id	bigint)

if @i_generator_id_list <> ''
insert into #generator 
select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

create table #tcustomer (	customer_id	int)
if @i_customer_search <> ''
insert into #tcustomer
select customer_id 
from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 

create table #tscheduletype (	schedule_type	varchar(20))
if @i_schedule_type <> ''
insert into #tscheduletype
select left(row, 20) 
from dbo.fn_SplitXsvText(',',1,@i_schedule_type)

create table #tservicetype (
	service_type	varchar(100) -- generator sublocation
)
if @i_service_type <> ''
insert into #tservicetype
select left(row, 100) 
from dbo.fn_SplitXsvText(',',1,@i_service_type)

create table #epaids (	epa_id	varchar(20))
if @i_epa_id <> ''
insert into #epaids (epa_id)
select left(row, 20) 
from dbo.fn_SplitXsvText(',', 1, @i_epa_id)
where row is not null

create table #tdistrict (	generator_district	varchar(50))
if @i_generator_district <> ''
insert into #tdistrict
select row 
from dbo.fn_SplitXsvText(',', 1, @i_generator_district)

create table #tstorenumber (
	site_code	varchar(16)
	,idx	int not null
)
if @i_store_number <> ''
insert into #tstorenumber (
	site_code
	, idx
	)
select row
, idx 
from dbo.fn_SplitXsvText(',', 1, @i_store_number) 
where row is not null

create table #tsitetype (	site_type	varchar(40))
if @i_site_type <> ''
insert into #tsitetype (site_type)
select row 
from dbo.fn_SplitXsvText(',', 1, @i_site_type) 
where row is not null

create table #tgeneratorregion (	generator_region_code	varchar(40))
if @i_generator_region <> ''
insert into #tgeneratorregion
select row 
from dbo.fn_SplitXsvText(',', 1, @i_generator_region)

create table #ttransid (	transaction_id int)
if @i_transaction_id <> ''
insert into #ttransid
select convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @i_transaction_id) 
where row is not null

create table #copc (
	company_id int
	, profit_ctr_id int
)
IF LTRIM(RTRIM(@i_facility)) in (
	''
	, 'ALL'
	)
	INSERT into #copc
	SELECT Profitcenter.company_id
	, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	WHERE ProfitCenter.status = 'A'
ELSE
	INSERT into #copc
	SELECT Profitcenter.company_id
	, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	INNER JOIN (
		SELECT
			RTRIM(LTRIM(SUBSTRING(ROW, 1, CHARINDEX('|',ROW) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(ROW, CHARINDEX('|',ROW) + 1, LEN(ROW) - (CHARINDEX('|',ROW)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @i_facility)
			WHERE ISNULL(ROW, '') <> ''
			) selected_copc ON ProfitCenter.company_id = selected_copc.company_id
			AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
	WHERE ProfitCenter.status = 'A'

	IF @i_debug >= 1
		PRINT 'Done with var setup: Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after setup' as milestone
	CREATE TABLE #foo (
		source CHAR(1) NOT NULL
		,receipt_id INT NOT NULL
		,company_id INT NOT NULL
		,profit_ctr_id INT NOT NULL
		,receipt_date DATETIME NULL
		,prices BIT NOT NULL
		)

	INSERT INTO #foo
	SELECT 'W' AS source
		,x.workorder_id
		,x.company_id
		,x.profit_ctr_id
		,isnull(x.service_date, x.start_date)
		,x.prices
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	LEFT JOIN #tstorenumber s ON d.site_code LIKE '%' + s.site_code + '%'
	WHERE x.contact_id = @i_contact_id
	and (
		@i_transaction_id = ''
			OR (
				EXISTS (
					SELECT TOP 1 1
					FROM #ttransid
					WHERE x.workorder_id = transaction_id
					)
				)
	)
	and (
		@i_facility = ''
			OR (
				EXISTS (
					SELECT TOP 1 1
					FROM #copc
					WHERE company_id = x.company_id
						AND profit_ctr_id = x.profit_ctr_id
					)
				)
	)
	and (
		@i_date_specifier <> 'service'
			OR (
				@i_date_specifier = 'service'
				AND isnull(x.service_date, x.start_date) BETWEEN @i_date_start
					AND @i_date_end
				)
	)
	and (
		@i_date_specifier <> 'transaction'
			OR (
				@i_date_specifier = 'transaction'
				AND x.start_date BETWEEN @i_date_start
					AND @i_date_end
				)
	)
		AND (
		@i_customer_id_list = ''
			OR (
			@i_customer_id_list <> ''
				AND x.customer_id IN (
					SELECT customer_id
					FROM #customer
		)
	)
			)
		AND (
		@i_generator_id_list = ''
			OR (
			@i_generator_id_list <> ''
				AND x.generator_id IN (
					SELECT generator_id
					FROM #generator
					)
		)
	)
		AND (
		@i_generator_name = ''
			OR (
			@i_generator_name <> ''
				AND isnull(d.generator_name, '') LIKE '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
		AND (
		@i_epa_id = ''
			OR (
			@i_epa_id <> ''
				AND isnull(d.epa_id, '') IN (
					SELECT epa_id
					FROM #epaids
					)
		)
	)
		AND (
		@i_generator_region = ''
			OR (
			@i_generator_region <> ''
				AND isnull(d.generator_region_code, '') IN (
					SELECT generator_region_code
					FROM #tgeneratorregion
					)
		)
	)
		AND (
		@i_generator_district = ''
			OR (
			@i_generator_district <> ''
				AND isnull(d.generator_district, '') IN (
					SELECT generator_district
					FROM #tdistrict
					)
		)
	)
		AND (
		@i_store_number = ''
			OR (
			@i_store_number <> ''
				AND s.idx IS NOT NULL
		)
	)
		AND (
		@i_site_type = ''
			OR (
			@i_site_type <> ''
				AND isnull(d.site_type, '') IN (
					SELECT site_type
					FROM #tsitetype
		)
	)
			)
		AND (
		@i_generator_id_list = ''
			OR (
			@i_generator_id_list <> ''
				AND x.generator_id IN (
					SELECT generator_id
					FROM #generator
					)
		)
	)

	UNION

	SELECT 'R' AS source
		,x.receipt_id
		,x.company_id
		,x.profit_ctr_id
		,isnull(x.pickup_date, x.receipt_date)
		,x.prices
FROM    ContactCORReceiptBucket x  (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	LEFT JOIN #tstorenumber s ON d.site_code LIKE '%' + s.site_code + '%'
	WHERE x.contact_id = @i_contact_id
		and (
		@i_date_specifier <> 'service'
			OR (
				@i_date_specifier = 'service'
				AND isnull(x.pickup_date, x.receipt_date) BETWEEN @i_date_start
					AND @i_date_end
				)
	)
	and (
		@i_date_specifier <> 'transaction'
			OR (
				@i_date_specifier = 'transaction'
				AND x.receipt_date BETWEEN @i_date_start
					AND @i_date_end
				)
	)
	and (
		isnull(@i_transaction_id, '') = ''
			OR (
				x.receipt_id IN (
					SELECT transaction_id
					FROM #ttransid
					)
				)
	)
	and (
		isnull(@i_facility, '') = ''
			OR (
				EXISTS (
					SELECT 1
					FROM #copc
					WHERE company_id = x.company_id
						AND profit_ctr_id = x.profit_ctr_id
					)
				)
	)
		AND (
		@i_customer_id_list = ''
			OR (
			@i_customer_id_list <> ''
				AND x.customer_id IN (
					SELECT customer_id
					FROM #customer
		)
	)
			)
		AND (
		@i_generator_id_list = ''
			OR (
			@i_generator_id_list <> ''
				AND x.generator_id IN (
					SELECT generator_id
					FROM #generator
		)
	)	
			)
		AND (
		@i_generator_name = ''
			OR (
			@i_generator_name <> ''
				AND isnull(d.generator_name, '') LIKE '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
		AND (
		@i_epa_id = ''
			OR (
			@i_epa_id <> ''
				AND isnull(d.epa_id, '') IN (
					SELECT epa_id
					FROM #epaids
					)
		)
	)
		AND (
		@i_generator_region = ''
			OR (
			@i_generator_region <> ''
				AND isnull(d.generator_region_code, '') IN (
					SELECT generator_region_code
					FROM #tgeneratorregion
		)
	)
			)
		AND (
		@i_generator_district = ''
			OR (
			@i_generator_district <> ''
				AND isnull(d.generator_district, '') IN (
					SELECT generator_district
					FROM #tdistrict
		)
	)
			)
		AND (
		@i_store_number = ''
			OR (
			@i_store_number <> ''
				AND s.idx IS NOT NULL
		)
	)
		AND (
		@i_site_type = ''
			OR (
			@i_site_type <> ''
				AND isnull(d.site_type, '') IN (
					SELECT site_type
					FROM #tsitetype
		)
	)	
		)

	IF @i_debug >= 1
		PRINT 'Done populating #foo: Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

	IF @i_debug >= 1
		PRINT 'Done with service_date foo copy: Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

	CREATE TABLE #bar (
	source	char(1)
	, receipt_id	int
	, company_id int
	, profit_ctr_id int
	, resource_type char(1)
	, line_id int
	, start_date datetime
	, prices int
)

	--	, status varchar(20)
	INSERT INTO #bar
-- Also per sp_reports_waste_summary, MUST be invoiced.
select distinct x.source
, x.receipt_id
, x.company_id
, x.profit_ctr_id
, d.resource_type
, d.sequence_id
, z.start_date
, x.prices
FROM #foo x
join workorderheader z (nolock) on x.receipt_id = z.workorder_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
join workorderdetail d (nolock) on x.receipt_id = d.workorder_id and x.company_id = d.company_id and x.profit_ctr_id = d.profit_ctr_id and d.resource_type = 'D' and d.bill_rate > -2
-- join billing b (nolock) on b.receipt_id = x.receipt_id and b.trans_source = 'W' and b.profit_ctr_id = x.profit_ctr_id and b.company_id = x.company_id and b.status_code = 'I' and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id
INNER JOIN Company cpy ON z.company_id = cpy.company_id
INNER JOIN ProfitCenter pfc ON z.company_id = pfc.company_id 
	AND z.profit_ctr_id = pfc.profit_ctr_id
WHERE x.source = 'W'
	AND z.submitted_flag = 'T'
	AND pfc.status = 'A'
		AND pfc.view_on_web IN (
			'P'
			,'C'
			)
	AND pfc.view_workorders_on_web = 'T'
	AND cpy.VIEW_ON_WEB = 'T'
		AND z.workorder_status NOT IN (
			'V'
			,'X'
			,'T'
			)
	and (
			(
				SELECT count(*)
				FROM #tcustomer
				) = 0
			OR (
				EXISTS (
					SELECT TOP 1 1
					FROM #tcustomer
					WHERE customer_id = z.customer_id
					)
				)
	)
	and (
			(
				SELECT count(*)
				FROM #tscheduletype
				) = 0
			OR (
				EXISTS (
					SELECT TOP 1 1
					FROM #tscheduletype tst
					INNER JOIN WorkorderScheduleType wst ON tst.schedule_type = wst.schedule_type
					WHERE wst.workorderscheduletype_uid = z.workorderscheduletype_uid
					)
				)
	)
	and (
			(
				SELECT count(*)
				FROM #tservicetype
				) = 0
			OR (
				EXISTS (
					SELECT TOP 1 1
					FROM #tservicetype tst
					INNER JOIN GeneratorSubLocation gsl ON tst.service_type = gsl.description
					WHERE gsl.generator_sublocation_ID = z.generator_sublocation_ID
					)
				)
	)
	and (
		isnull(@i_approval_code, '') = ''
			OR (d.tsdf_approval_code LIKE '%' + replace(@i_approval_code, ' ', '%') + '%')
	)

	IF @i_debug >= 1
		PRINT 'Done with bar insert 1: Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

insert #bar
select x.source, z.receipt_id, z.company_id, z.profit_ctr_id, null as resource_type, z.line_id, z.receipt_date, x.prices --, null as status
from #foo x
join receipt z (nolock) on x.receipt_id = z.receipt_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
-- join billing b (nolock) on b.receipt_id = z.receipt_id and b.line_id = z.line_id and b.price_id = b.price_id and b.trans_source = 'R' and b.profit_ctr_id = z.profit_ctr_id and b.company_id = z.company_id and b.status_code = 'I'
INNER JOIN Company cpy ON z.company_id = cpy.company_id
	INNER JOIN ProfitCenter pfc ON z.company_id = pfc.company_id
	and z.profit_ctr_id = pfc.profit_ctr_id
WHERE x.source = 'R'
		AND z.trans_mode = 'I'
		AND z.receipt_status <> 'V'
		AND z.receipt_status <> 'R'
AND z.submitted_flag = 'T' 
AND z.trans_type = 'D' 
AND z.receipt_status = 'A' 
AND pfc.status = 'A' 
		AND pfc.view_on_web IN (
			'P'
			,'C'
			)
AND pfc.view_waste_summary_on_web = 'T' 
AND cpy.view_on_web = 'T'
	and (
		isnull(@i_approval_code, '') = ''
			OR (z.approval_code LIKE '%' + replace(@i_approval_code, ' ', '%') + '%')
	)
	and (
			(
				SELECT count(*)
				FROM #tcustomer
				) = 0
			OR (
				z.customer_id IN (
					SELECT customer_id
					FROM #tcustomer
					)
	)
	)

	IF @i_debug >= 1
		PRINT 'Done with bar insert 2: Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

	CREATE TABLE #Work_WasteReceivedSummaryListResult (
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		[facility] [varchar](50) NULL,
		[customer_id] [int] NULL,
		[cust_name] [varchar](75) NULL,
		[approval_code] [varchar](40) NULL,
		[profile_id] [int] NULL,
		[waste_description] [varchar](150) NULL,
		[haz_flag] [char](1) NULL,
		[dot_shipping_desc] varchar(max) NULL,
		[generator_id] [int] NULL,
		[epa_id] [varchar](12) NULL,
		[generator_name] [varchar](75) NULL,
		[generator_address] [varchar](max) NULL,
		[generator_state] [varchar](2) NULL,
		[generator_city] [varchar](40) NULL,
		[generator_zip_code] [varchar](15) NULL,
		[generator_county] [varchar](30) NULL,
		[site_code] [varchar](16) NULL,
		--
		line_quantity varchar(max) NULL,
		--
		-- [bill_unit_code] [varchar](4) NULL,
		-- [bill_unit_desc] [varchar](40) NULL,
		-- [quantity] [float] NULL,
		--
		[management_code] [varchar](4) NULL,
		[epa_form_code] [varchar](10) NULL,
		[epa_source_code] [varchar](10) NULL,
		[total_pounds] [float] NULL,
		[percent_of_container] [float] NULL,
		[mode] [varchar](20) NULL,
		[transaction_id] [varchar](20) NULL,
		[receipt_date] [datetime] NULL,
		[service_date] [datetime] NULL,
		[row_num] [int] IDENTITY(1,1) NOT NULL,
		[facility_epa_id] [varchar](20) NULL,
		[pcb_flag] [char](1) NULL,
		[transporter_code] [varchar](20) NULL,
		[transporter_name] [varchar](60) NULL,
		[transporter_epa_id] [varchar](20) NULL,
		[waste_code_list] [varchar](max) NULL,
		[state_waste_code_list] [varchar](max) NULL,
		[weight_method] [varchar](40) NULL,
		[manifest] [varchar](20) NULL,
		[manifest_page] int NULL,
		[manifest_line] [int] NULL,
		[manifest quantity] [float] NULL,
		[manifest unit] [varchar](4) NULL,
		[Manifest Container Count] [float] NULL,
		[Manifest Container Code] [varchar](15) NULL,
		TSDF_Code	[varchar](15) NULL
		,source char(1)
		,receipt_id int
		,billed bit
	)

-- This is Inbound Receipt data
	if exists (select top 1 1 from #bar where source = 'R') begin
		INSERT INTO #Work_WasteReceivedSummaryListResult (
			company_id, 
			profit_ctr_id, 
			facility, 
			customer_id, 
			cust_name, 
			approval_code, 
			profile_id,
			waste_description, 
			haz_flag, 
			dot_shipping_desc,
			generator_id, 
			epa_id, 
			generator_name, 
			generator_address,
			generator_state, 
			generator_city,
			generator_zip_code,
			generator_county,
			site_code, 
--
			line_quantity,
			-- bill_unit_code, 
			-- bill_unit_desc, 
			-- quantity, 
--
			management_code,
			epa_form_code,
			epa_source_code,
			total_pounds, 
			weight_method,
			mode, 
			transaction_id, 
			receipt_date, 
			service_date,
			facility_epa_id,
			waste_code_list,
			state_waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_page,
			manifest_line,
			[manifest quantity],
			[manifest unit],
			[Manifest Container Count],
			[Manifest Container Code],
			[TSDF_Code]
			, source
			, receipt_id
			, billed
		)
		SELECT 
			t.company_id,
			t.profit_ctr_id AS profit_ctr_id,
			null as facility,
			r.customer_id,
			cust.cust_name AS cust_name,
			r.approval_code,
			r.profile_id,
			(
				select convert(varchar(150), ltrim(rtrim(isnull(p.approval_desc, '')))) 
				from profile p
				where p.profile_id = r.profile_id
			) as waste_description,
			haz_flag = case when exists (
				select 1 
				from wastecode wc 
				inner join receiptwastecode rwc on wc.waste_code_uid = rwc.waste_code_uid
				where rwc.receipt_id = t.receipt_id 
				and rwc.line_id = t.line_id 
				and rwc.company_id = t.company_id 
				and rwc.profit_ctr_id = t.profit_ctr_id 
				AND wc.waste_code_origin = 'F'
				AND IsNull(wc.haz_flag,'F') = 'T'
			) then 'T' else 'F' end,
			dot_shipping_desc =  -- borrowed from sp_emanifest_waste 1/8/2021
				ltrim(rtrim(replace(replace(replace(replace(
				case when isnull(r.manifest_RQ_flag, '') = 'T' then 'RQ, ' else '' end
				+
				case when isnull(r.manifest_un_na_flag, '') = 'X' then '' else isnull(r.manifest_un_na_flag, '') end
				+
				case when isnull(r.manifest_UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), r.manifest_UN_NA_number), 4) end
				+
				case when
					(
					case when isnull(r.manifest_un_na_flag, '') = 'X' then '' else isnull(r.manifest_un_na_flag, '') end
					+
					case when isnull(r.manifest_UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), r.manifest_UN_NA_number), 4) end
					)
					<> '' then ', ' else ''
				end
				+
				isnull(convert(varchar(max), r.manifest_DOT_shipping_name), '')
				+
				case when isnull(r.manifest_hazmat_class, '') = '' then '' else ', ' + isnull(r.manifest_hazmat_class, '') end
				+
				case when isnull(r.manifest_sub_hazmat_class, '') = '' then '' else '(' + isnull(r.manifest_sub_hazmat_class, '') + ')' end
				+
				case when isnull(r.manifest_package_group, '') = '' then '' else ', PG' + isnull(r.manifest_package_group, '') end
				+
				case when isnull(r.manifest_RQ_reason, '') = '' then '' else ', ' + isnull(r.manifest_RQ_reason, '') end
				+
				case when isnull(CONVERT(Varchar(20), r.manifest_ERG_number), '') + isnull(r.manifest_ERG_suffix, '') = '' then '' else ', ERG#' + isnull(CONVERT(Varchar(20), r.manifest_ERG_number), '') + isnull(r.manifest_ERG_suffix, '') end
				+
				case when isnull(r.manifest_dot_sp_number, '') = '' then '' else ', DOT-SP ' + isnull(r.manifest_dot_sp_number, '') end
				, char(10), ' '), char(13), ' '), '  ', ' '), ',,', ',')))
			,	r.generator_id,
			g.epa_id AS epa_id,
			g.generator_name,
			isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '') as generator_address,
			g.generator_state,
			g.generator_city,
			g.generator_zip_code,
			gc.county_name as generator_county,
			g.site_code,
			--
			/* construct line_quantity */
			(
				select substring(
				(
					select 
						', ' + 
						format(isnull(rp.bill_quantity, 0), 'g15') + 
						' ' + 
						b.bill_unit_desc
					from ReceiptPrice rp (nolock) 
					LEFT OUTER JOIN Billunit b ON rp.bill_unit_code = b.bill_unit_code
					WHERE 
						rp.receipt_id = r.receipt_id
						AND rp.company_id = r.company_id
						AND rp.profit_ctr_id = r.profit_ctr_id
						AND rp.line_id = r.line_id
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as line_quantity,
			
--			
			--rp.bill_unit_code,
			--b.bill_unit_desc,
			--isnull(rp.bill_quantity, 0) AS quantity,
--			
			treatment.management_code,
			profile.epa_form_code,
			profile.epa_source_code,
			isnull(dbo.fn_receipt_weight_line (t.receipt_id, t.line_id, t.profit_ctr_id, t.company_id), 0) as total_pounds, 
			dbo.fn_receipt_weight_line_description (t.receipt_id, t.line_id, t.profit_ctr_id, t.company_id, 0) as weight_method,
			'Inbound' as mode,
			'R' + convert(varchar(15), t.receipt_id) as transaction_id,
			r.receipt_date,
			dbo.fn_get_service_date(t.company_id, t.profit_ctr_id, t.receipt_id, 'R') as service_date,
				null, --dbo.fn_web_profitctr_display_epa_id(t.company_id, t.profit_ctr_id) as facility_epa_id,
			dbo.fn_receipt_waste_code_list_long(t.company_id, t.profit_ctr_id, t.receipt_id, t.line_id) as waste_code_list,
			dbo.fn_receipt_waste_code_list_state_long(t.company_id, t.profit_ctr_id, t.receipt_id, t.line_id) as state_waste_code_list,
			rt1.transporter_code,
			trans.transporter_name,
			trans.transporter_epa_id,
			r.manifest,
			r.manifest_page_num,
			r.manifest_line
			,r.manifest_quantity
			,r.manifest_unit
			,r.container_count
			,r.manifest_container_code
			, (
				select top 1 tsdf_code
				from tsdf (nolock)
				WHERE eq_company = r.company_id
				and eq_profit_ctr = r.profit_ctr_id
				and tsdf_status = 'A'
				and isnull(eq_flag, 'F') = 'T'
			) as tsdf_code
			, t.source
			, t.receipt_id
			, 0 as billed
		FROM #bar t
		/*
			source	char(1)
			, receipt_id	int
			, company_id int
			, profit_ctr_id int
			, resource_type char(1)
			, line_id int
			, start_date datetime
			, prices int
		*/		
		inner join Receipt r (nolock) on 
			t.receipt_id = r.receipt_id 
			and t.line_id = r.line_id
			and t.company_id = r.company_id 
			and t.profit_ctr_id = r.profit_ctr_id
		INNER JOIN Customer cust  (nolock) ON r.customer_id = cust.customer_id
		LEFT OUTER JOIN Generator g  (nolock) on r.generator_id = g.generator_id
		LEFT OUTER JOIN County gc  (nolock)on g.generator_county = gc.county_code
		INNER JOIN Profile  WITH(NOLOCK) ON (r.profile_id = Profile.Profile_id)
		INNER JOIN ProfileQuoteApproval PQA  (nolock) ON (r.approval_code = PQA.approval_code
			AND r.profit_ctr_id = PQA.profit_ctr_id
			AND r.company_id = PQA.company_id)
		INNER JOIN Treatment WITH(NOLOCK)  ON (
			CASE WHEN ISnull(r.treatment_id,0) <> 0 
				THEN ISnull(r.treatment_id,0) 
				ELSE
					isnull(PQA.Treatment_ID, 0)
			END = Treatment.treatment_id )
			and r.company_id = Treatment.company_id
			and r.profit_ctr_id = Treatment.profit_ctr_id
		LEFT JOIN ReceiptTransporter rt1  (nolock)
			ON r.receipt_id = rt1.receipt_id 
			AND r.company_id = rt1.company_id 
			AND r.profit_ctr_id = rt1.profit_ctr_id 
			AND rt1.transporter_sequence_id = 1
		LEFT JOIN Transporter trans (nolock)
			ON rt1.transporter_code = trans.transporter_code
		--left join billing bill (nolock)
		--	on r.receipt_id = bill.receipt_id
		--	and r.company_id = bill.company_id
		--	and r.profit_ctr_id = bill.profit_ctr_id
		--	and r.line_id = bill.line_id
		--	and bill.trans_source = 'R'
		--	and bill.status_code = 'I'
		WHERE t.source = 'R'
	end	
	
--- ORIG: Done with Work_WasteReceivedSummaryListResult 1: Elapsed time: 25300ms
	-- Minus subqueries and fn_ calls:  Whoa.	1376ms. 
	-- restored waste description subquery:		1436ms
	-- restored haz_flag lookup:				1656ms
	-- restored total pounds + weight method:	27360ms	PAIN
	-- remove pounds/method,restore 
	--		service date, waste code list		2810ms
	-- rewrote the pounds/method functions		5720ms

update r set billed = 1
from #Work_WasteReceivedSummaryListResult r
join billing bill
		on r.receipt_id = bill.receipt_id
		and r.company_id = bill.company_id
		and r.profit_ctr_id = bill.profit_ctr_id
		-- and r.line_id = bill.line_id
		and bill.trans_source = 'R'
		and bill.status_code = 'I'

if @i_debug >= 1 print 'Done with Work_WasteReceivedSummaryListResult 1: Elapsed time: ' + convert(varchar(20), datediff(ms, @i_starttime, getdate())) + 'ms'

			
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------  Hey, might THIS line be redundant?
	if exists (select top 1 1 from #bar where source = 'W') begin

		INSERT #Work_WasteReceivedSummaryListResult (
			company_id, 
			profit_ctr_id, 
			facility, 
			customer_id, 
			cust_name, 
			approval_code, 
			profile_id,
			waste_description, 
			haz_flag, 
			dot_shipping_desc,
			generator_id, 
			epa_id, 
			generator_name, 
			generator_address,
			generator_state, 
			generator_city, 
			generator_zip_code,
			generator_county,
			site_code, 
--			
			line_quantity,
			-- bill_unit_code, 
			-- bill_unit_desc, 
			-- quantity, 
--			
			management_code,
			epa_form_code,
			epa_source_code,
			total_pounds, 
			weight_method,
			mode, 
			transaction_id, 
			receipt_date, 
			service_date,
			facility_epa_id,
			waste_code_list,
			state_waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_page,
			manifest_line,
			[manifest quantity],
			[manifest unit],
			[Manifest Container Count],
			[Manifest Container Code],
			tsdf_code
			, source
			, receipt_id
			, billed
		)
		SELECT DISTINCT
			w.company_id,
			w.profit_ctr_id,
			coalesce(tsdf.tsdf_name, ppc.profit_ctr_name) as facility,
			w.customer_id,
			cust.cust_name AS cust_name,
			d.tsdf_approval_code as approval_code,
			null as profile_id,
			convert(varchar(150), ltrim(rtrim(coalesce(t.waste_desc, p.approval_desc, '')))) as waste_description,
			haz_flag = case when exists (
				select 1 
				from wastecode wc 
				inner join tsdfapprovalwastecode twc on wc.waste_code_uid = twc.waste_code_uid 
				where t.tsdf_approval_id = twc.tsdf_approval_id 
				and t.company_id = twc.company_id 
				and t.profit_ctr_id = twc.profit_ctr_id 
				AND wc.waste_code_origin = 'F'
				AND IsNull(wc.haz_flag,'F') = 'T'
				union
				select 1 
				from wastecode wc 
				inner join profilewastecode pwc on wc.waste_code_uid = pwc.waste_code_uid 
				where d.profile_id = pwc.profile_id
				AND wc.waste_code_origin = 'F'
				AND IsNull(wc.haz_flag,'F') = 'T'
			) then 'T' else 'F' end,
			dot_shipping_desc =
				ltrim(rtrim(replace(replace(replace(replace(
				case when isnull(d.reportable_quantity_flag, '') = 'T' then 'RQ, ' else '' end
				+
				case when isnull(d.un_na_flag, '') = 'X' then '' else isnull(d.un_na_flag, '') end
				+
				case when isnull(d.UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), d.UN_NA_number), 4) end
				+
				case when
					(
					case when isnull(d.un_na_flag, '') = 'X' then '' else isnull(d.un_na_flag, '') end
					+
					case when isnull(d.UN_NA_number, 0) = 0 then '' else right('0000' + convert(varchar(20), d.UN_NA_number), 4) end
					)
					<> '' then ', ' else ''
				end
				+
				isnull(convert(varchar(max), d.DOT_shipping_name), '')
				+
				case when isnull(d.hazmat_class, '') = '' then '' else ', ' + isnull(d.hazmat_class, '') end
				+
				case when isnull(d.subsidiary_haz_mat_class, '') = '' then '' else '(' + isnull(d.subsidiary_haz_mat_class, '') + ')' end
				+
				case when isnull(d.package_group, '') = '' then '' else ', PG' + isnull(d.package_group, '') end
				+
				case when isnull(d.RQ_reason, '') = '' then '' else ', ' + isnull(d.RQ_reason, '') end
				+
				case when isnull(CONVERT(Varchar(20), d.ERG_number), '') + isnull(d.ERG_suffix, '') = '' then '' else ', ERG#' + isnull(CONVERT(Varchar(20), d.ERG_number), '') + isnull(d.ERG_suffix, '') end
				+
				case when isnull(d.manifest_dot_sp_number, '') = '' then '' else ', DOT-SP ' + isnull(d.manifest_dot_sp_number, '') end
				, char(10), ' '), char(13), ' '), '  ', ' '), ',,', ',')))		
			,
			w.generator_id,
			g.epa_id AS epa_id,
			g.generator_name,
			isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '') as generator_address,
			g.generator_state,
			g.generator_city,
			g.generator_zip_code,
			gc.county_name as generator_county,
			g.site_code,
--			
			/* construct line_quantity */
			(
				select substring(
				(
					select 
						', ' + 
						format(coalesce(wodu.quantity, d.quantity,0), 'g15') + 
						' ' + 
						b.bill_unit_desc
					from WorkOrderDetailUnit wodu (nolock)
					LEFT OUTER JOIN Billunit b ON wodu.bill_unit_code = b.bill_unit_code
					WHERE 
						wodu.workorder_id = d.workorder_id
						AND wodu.company_id = d.company_id
						AND wodu.profit_ctr_id = d.profit_ctr_id
						AND wodu.sequence_id = d.sequence_id
						and d.resource_type = 'D'
						AND wodu.billing_flag = 'T'
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as line_quantity,

			--wodu.bill_unit_code,
			--b.bill_unit_desc,
			--isnull(wodu.quantity, d.quantity) as quantity,
--
			isnull(d.management_code, t.management_code),
			coalesce(t.epa_form_code, p.epa_form_code) epa_form_code,
			coalesce(t.epa_source_code, p.epa_source_code) epa_source_code,
			dbo.fn_workorder_weight_line (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as total_pounds,
			dbo.fn_workorder_weight_line_description (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as weight_method,
			'Outbound' as mode,
			'W' + convert(varchar(15), w.workorder_id) as transaction_id,
			w.start_date as receipt_date,
			dbo.fn_get_service_date(w.company_id, w.profit_ctr_id, w.workorder_id, 'W') as service_date,
			coalesce(tsdf.TSDF_EPA_ID, ppc.epa_id) as facility_epa_id,
			dbo.fn_workorder_waste_code_list_origin_filtered(w.workorder_id, w.company_id, w.profit_ctr_id, d.sequence_id, 'F') as waste_code_list,
			dbo.fn_workorder_waste_code_list_origin_filtered(w.workorder_id, w.company_id, w.profit_ctr_id, d.sequence_id, 'S') as state_waste_code_list,
			wt1.transporter_code,
			trans.transporter_name,
			trans.transporter_epa_id,
			d.manifest,
			d.manifest_page_num,
			d.manifest_line

			, wodu_man.quantity
			, wodu_man_unit.manifest_unit
			, d.container_count
			, d.container_code
			, d.tsdf_code
			, waf.source
			, waf.receipt_id
			, 0 as billed

			FROM #bar waf
		/*
			source	char(1)
			, receipt_id	int
			, company_id int
			, profit_ctr_id int
			, resource_type char(1)
			, line_id int
			, start_date datetime
			, prices int
		*/		
			INNER JOIN WorkorderHeader w ON
				waf.receipt_id = w.workorder_id
				AND waf.company_id = w.company_id
				AND waf.profit_ctr_id = w.profit_ctr_id
				and waf.source = 'W'
			INNER JOIN WorkorderDetail d on 
				w.workorder_id = d.workorder_id
				AND w.company_id = d.company_id
				AND w.profit_ctr_id = d.profit_ctr_id
				and waf.resource_type = d.resource_type
				and waf.line_id = d.sequence_id
				and waf.source = 'W'
				and d.bill_rate > -2
			LEFT JOIN WorkOrderDetailUnit wodu_man ON
				wodu_man.workorder_id = d.workorder_id
				AND wodu_man.company_id = d.company_id
				AND wodu_man.profit_ctr_id = d.profit_ctr_id
				AND wodu_man.sequence_id = d.sequence_id
				and d.resource_type = 'D'
				AND wodu_man.manifest_flag = 'T'
			LEFT JOIN billunit wodu_man_unit ON
				wodu_man.bill_unit_code = wodu_man_unit.bill_unit_code
			LEFT JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
			LEFT JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
			LEFT JOIN profile p ON d.profile_id = p.profile_id and d.tsdf_approval_id is null
			LEFT JOIN profitcenter ppc ON d.profile_company_id = ppc.company_id and d.profile_profit_ctr_id = ppc.profit_ctr_id
			INNER JOIN Customer cust ON w.customer_id = cust.customer_id
			--LEFT JOIN Billing bill ON bill.company_id = w.company_id
			--	AND bill.profit_ctr_id = w.profit_ctr_id
			--	AND bill.receipt_id = w.workorder_id 
			--	AND bill.workorder_resource_type = d.resource_type
			--	and bill.workorder_sequence_id = d.sequence_id
			--	AND bill.trans_source = 'W'
			--	and bill.status_code = 'I'
			LEFT OUTER JOIN Generator g ON w.generator_id = g.generator_id
			LEFT OUTER JOIN County gc on g.generator_county = gc.county_code
			LEFT OUTER JOIN tsdfapprovalwastecode twc on t.tsdf_approval_id = twc.tsdf_approval_id and t.company_id = twc.company_id and t.profit_ctr_id = twc.profit_ctr_id and twc.primary_flag = 'T' 
			LEFT JOIN workordertransporter wt1 ON w.workorder_id = wt1.workorder_id and w.company_id = wt1.company_id and w.profit_ctr_id = wt1.profit_ctr_id and wt1.transporter_sequence_id = 1 and wt1.manifest = d.manifest
			LEFT JOIN transporter trans ON wt1.transporter_code = trans.transporter_code
		WHERE 
			waf.source = 'W'
			AND w.submitted_flag = 'T'

	end

	update w set billed = 1
	from #Work_WasteReceivedSummaryListResult w
	join billing bill
	ON bill.company_id = w.company_id
			AND bill.profit_ctr_id = w.profit_ctr_id
			AND bill.receipt_id = w.receipt_id 
			--AND bill.workorder_resource_type = d.resource_type
			--and bill.workorder_sequence_id = d.sequence_id
			AND bill.trans_source = 'W'
			and bill.status_code = 'I'
	WHERE transaction_id like 'W%'



if @i_debug >= 1 print 'Done with Work_WasteReceivedSummaryListResult 2: Elapsed time: ' + convert(varchar(20), datediff(ms, @i_starttime, getdate())) + 'ms'
	


-- clear from @bar where there's a work order also represented by a receipt?
select distinct 'WO also represented by R' as issue
, b.* 
into #doubles
from #Work_WasteReceivedSummaryListResult b
join billinglinklookup l
	on b.receipt_id = l.source_id
	and b.company_id = l.source_company_id
	and b.profit_ctr_id = l.source_profit_ctr_id
join #Work_WasteReceivedSummaryListResult br
	on br.source = 'R'
	and l.receipt_id = br.receipt_id
	and l.company_id = br.company_id
	and l.profit_ctr_id = br.profit_ctr_id
WHERE 
b.source = 'W'
and b.manifest = br.manifest
and b.approval_code = br.approval_code

/*
declare #bar table (
	source	char(1)
	, receipt_id	int
	, company_id int
	, profit_ctr_id int
	, resource_type char(1)
	, line_id int
	, start_date datetime
	, prices int
--	, status varchar(20)
)

*/


---------------------------------------------------------------
----------------------- RETURN RESULTS ------------------------
---------------------------------------------------------------

returnresults:

SET NOCOUNT OFF

BEGIN

	BEGIN -- Detail, Group by Approval
		select * from (
		
			SELECT 
				dbo.fn_web_profitctr_display_name(company_id, profit_ctr_id) Facility,
				dbo.fn_web_profitctr_display_epa_id(company_id, profit_ctr_id) Facility_EPA_ID,
				cust_name as Customer_Name,
				customer_id as Customer_ID,
				Generator_Name,
				EPA_ID,
				Generator_State,
				Generator_City,
				site_code as Generator_Site_Code,
				Transporter_Name,
				Transporter_EPA_ID,
				tsdf.TSDF_Code,	-- varchar(15)
				tsdf.TSDF_Name,	-- varchar(40)
				tsdf.TSDF_Addr1 + isnull(' ' + tsdf.TSDF_Addr2, '') + isnull(' ' + tsdf.TSDF_Addr3, '') as TSDF_Address, -- varchar(max)
				tsdf.TSDF_City, -- varchar(40)
				tsdf.TSDF_State, -- char(2)
				tsdf.TSDF_Zip_Code, -- varchar(15)
				tsdf.TSDF_Country_Code, -- varchar(3)

				approval_code as Approval,
				Waste_Description,
				case haz_flag when 'T' then 'Hazardous' else 'Non-Hazardous' end as [Hazardous?],
				Waste_Code_List,
				
				Management_Code,
				EPA_Form_Code,
				EPA_Source_Code,
				
				transaction_id as [Transaction],
				receipt_date as [Transaction Date],
				service_date as [Service Date],
				Manifest,
				Manifest_Page, -- int
				Manifest_Line,

				[Manifest Quantity],
				[Manifest Unit],
				[Manifest Container Count],
				[Manifest Container Code],

--
				line_quantity,
				-- bill_unit_desc as Container,
				-- SUM(isnull(quantity, 0)) Quantity,
--				
				Weight_Method,
				SUM(isnull(total_pounds, 0)) Total_Pounds
				
			,_row = row_number() over (order by 
				facility,
				approval_code,
				generator_name,
				epa_id,
				cust_name,
				receipt_date,
				service_date
			) 
			, profile_id _profile_id
			, DOT_Shipping_Desc
			, Generator_Address
			, Generator_Zip_Code			
			, Generator_County
			, State_Waste_Code_List
			, billed
			
/*
F- Site Address
G – Site City
H – Site State
I -Site Zip code
J- County
K-Site Code
L-Generator EPA ID
M- Transporter Name
N – Transporter EPA ID
O- Approval Code
P- Waste Description
Q-Hazardous?
R-Waste Code List
S-State Waste Code
(Resume with Management Code after “State Waste Code”)
“Manifest” column = rename to “Manifest/BOL” 
*/
				
				FROM #Work_WasteReceivedSummaryListResult a
				LEFT JOIN tsdf (nolock) on a.tsdf_code = tsdf.tsdf_code
				where not exists (
					select 1 from #doubles b
					where a.company_id = b.company_id
					and a.profit_ctr_id = b.profit_ctr_id
					and a.source = b.source
					and a.receipt_id = b.receipt_id
					and a.manifest = b.manifest
					and a.approval_code = b.approval_code
				)
				GROUP BY 
					company_id,
					profit_ctr_id,
					facility,
					customer_id,
					cust_name,
					generator_id,
					epa_id,
					generator_address,
					generator_name,
					generator_state,
					generator_city,
					site_code,
					approval_code,
					profile_id,
					waste_description,
					haz_flag,
					receipt_date,
					service_date,
					transaction_id,
--
					line_quantity,
					-- bill_unit_code,
					-- bill_unit_desc,
--					
					management_code,
					epa_form_code,
					weight_method,
					epa_source_code,
					mode,
					waste_code_list,
					transporter_code,
					transporter_name,
					transporter_epa_id,
					tsdf.TSDF_Code,	-- varchar(15)
					tsdf.TSDF_Name,	-- varchar(40)
					tsdf.TSDF_Addr1 + isnull(' ' + tsdf.TSDF_Addr2, '') + isnull(' ' + tsdf.TSDF_Addr3, '') ,--  as TSDF_Address, -- varchar(max)
					tsdf.TSDF_City, -- varchar(40)
					tsdf.TSDF_State, -- char(2)
					tsdf.TSDF_Zip_Code, -- varchar(15)
					tsdf.TSDF_Country_Code, -- varchar(3)
					manifest,
					Manifest_Page, -- int
					manifest_line,
					[Manifest Quantity],
					[Manifest Unit],
					[Manifest Container Count],
					[Manifest Container Code]

					, DOT_Shipping_Desc
					, Generator_Address
					, Generator_Zip_Code			
					, Generator_County
					, State_Waste_Code_List
					,billed

		) y
		where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
		order by _row

	END
END

DROP TABLE IF EXISTS #customer
DROP TABLE IF EXISTS #generator
DROP TABLE IF EXISTS #tcustomer
DROP TABLE IF EXISTS #tscheduletype
DROP TABLE IF EXISTS #tservicetype
DROP TABLE IF EXISTS #epaids
DROP TABLE IF EXISTS #tdistrict
DROP TABLE IF EXISTS #tstorenumber
DROP TABLE IF EXISTS #tsitetype
DROP TABLE IF EXISTS #tgeneratorregion
DROP TABLE IF EXISTS #ttransid
DROP TABLE IF EXISTS #copc
DROP TABLE IF EXISTS #foo
DROP TABLE IF EXISTS #bar
DROP TABLE IF EXISTS #Work_WasteReceivedSummaryListResult

if @i_debug >= 1 print 'End Elapsed time: ' + convert(varchar(20), datediff(ms, @i_starttime, getdate())) + 'ms'

RETURN 0

GO

GRANT EXECUTE ON sp_COR_waste_summary_detail_list to eqweb, eqai, cor_user
GO
