DROP PROCEDURE IF EXISTS sp_cor_schedule_service_list
GO

create procedure sp_cor_schedule_service_list (
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(10) = null	-- 'Requested', 'Scheduled', 'Service' (default = service)
	
    , @customer_search	varchar(max) = null
    , @manifest			varchar(max) = null

	, @schedule_type	varchar(max) = null
	, @service_type		varchar(max) = null

--    , @generator_search	varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    
    , @transaction_id	varchar(max) = null
    , @facility			varchar(max) = null
    , @status			varchar(max) = null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
    , @project_code       varchar(max) = null           -- Project Code
    , @approval_code_list	varchar(max) = null	-- Approval Code List
    , @release_code       varchar(50) = null    -- Release code (NOT a list)
    , @purchase_order     varchar(20) = null    -- Purchase Order list
	, @search			varchar(max) = null -- Common search
    , @adv_search		varchar(max) = null
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @excel_output		int = 0
    , @customer_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
	, @count_output		int = 0	-- Only used if calling from the _count sibling SP, this skips doing some hard fields to make it faster.
) as

/* *******************************************************************
sp_cor_schedule_service_list

History:
Date		Who		Comments
---------------------------------------------------------------------------------------------------------		
 2/22/2022	 MPM	DevOps 19126 - Added "fuzzy logic" for emergency response workorder_type_ids.
 3/18/2022	 MPM	DevOps 19126 - Added "fuzzy logic" for Emergency_Response_Type_Reason.

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

--#endregion
Samples:

exec sp_cor_schedule_service_list
	@web_userid = 'dcrozier@riteaid.com'
	, @date_start = '11/1/2015'
	, @date_end = '12/31/2015'

exec sp_cor_schedule_service_list
	@web_userid = 'nyswyn100'
	, @date_start = '11/1/2000'
	, @date_end = '12/31/2020'
	, @perpage = 20000
	, @page = 1
	, @epa_id = 'ALR000061796'
	, @customer_id_list = '15551'
	-- , @generator_id_list = '116167'
	-- , @approval_code_list = 'RA11L'

SELECT  *  FROM    ContactCORCustomerBucket WHERE contact_id = 185547	
	
	
exec sp_cor_schedule_service_list
	@web_userid = 'nyswyn100'
	, @date_start = '9/16/2019'
	, @date_end = '12/16/2019'
	, @date_specifier	= null	-- 'Requested', 'Scheduled', 'Service' (default = service)
    , @customer_search	= null
    , @manifest			= null
	, @schedule_type	= null
	, @service_type		= null -- 'Distribution Center'
    , @generator_name	= null
    , @epa_id			= null -- can take CSV list
    , @store_number		= null -- can take CSV list
	, @generator_district = null -- can take CSV list
    , @generator_region	= null -- can take CSV list
    , @transaction_id	= null
    , @facility			= null
    , @status			= null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
    , @project_code		= ''
    , @adv_search		= null
	, @sort				= '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				= 1
	, @perpage			= 20000
	, @excel_output = 1
	
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


--#region debugging
/*
declare
	@web_userid			varchar(100) = 'nyswyn100'
	, @date_start		datetime = '7/1/2010'
	, @date_end			datetime = '1/1/2018'
	, @date_specifier	varchar(10) = ''	-- 'Requested', 'Scheduled', 'Service' (default = service)
    , @customer_search	varchar(max) = null
    , @manifest			varchar(max) = null
    , @generator_search	varchar(max) = ''
    , @store_number		varchar(max) = ''
    , @generator_region	varchar(max) = null
    , @approval_code	varchar(max) = null
    , @transaction_id	varchar(max) = null
    -- , @transaction_type	varchar(20) = 'receipt' -- always receipt in this proc
    , @facility			varchar(max) = null
    , @status			varchar(max) = ''	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
    , @adv_search		varchar(max) = null
	, @sort				varchar(20) = 'Workorder Number' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @customer_id_list varchar(max) = '15551'
	, @page				bigint = 1
	, @perpage			bigint = 20

	, @schedule_type	varchar(max) = null
	, @service_type		varchar(max) = null

    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    
    , @project_code       varchar(max) = null           -- Project Code
    , @approval_code_list	varchar(max) = null	-- Approval Code List
    , @release_code       varchar(50) = null    -- Release code (NOT a list)
    , @purchase_order     varchar(20) = null    -- Purchase Order list
	, @search			varchar(max) = null -- Common search
	, @excel_output		int = 0
    , @generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
	, @count_output		int = 0	-- Only used if calling from the _count sibling SP, this skips doing some hard fields to make it faster.
*/
	
-- SELECT  *  FROM    generator where generator_id = 75040

-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_contact_id			int
	, @i_date_start			datetime = convert(date, isnull(@date_start, '1/1/1999'))
	, @i_date_end			datetime = convert(date, isnull(@date_end, '1/1/1999'))
	, @i_date_specifier		varchar(10) = isnull(@date_specifier, 'service')
    , @i_customer_search	varchar(max) = isnull(@customer_search, '')
    , @i_manifest			varchar(max) = replace(isnull(@manifest, ''), ' ', ',')
	, @i_schedule_type		varchar(max) = isnull(@schedule_type, '')
	, @i_service_type		varchar(max) = isnull(@service_type, '')
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_transaction_id		varchar(max) = isnull(@transaction_id, '')
    -- , @i_transaction_type	varchar(20) = @transaction_type 
    , @i_facility			varchar(max) = isnull(@facility, '')
    , @i_status				varchar(max) = isnull(@status, '')
    , @i_project_code       varchar(max) = isnull(@project_code, '')
    , @i_approval_code_list	varchar(max) = isnull(@approval_code_list, '')
    , @i_release_code       varchar(50) = isnull(@release_code, '')
    , @i_purchase_order     varchar(20) = isnull(@purchase_order, '')
	, @i_search				varchar(max) = dbo.fn_CleanPunctuation(isnull(@search, ''))
    , @i_adv_search			varchar(max) = isnull(@adv_search, '')
	, @i_sort				varchar(20) = isnull(@sort, '')
	, @i_page				bigint = isnull(@page, 1)
	, @i_perpage			bigint = isnull(@perpage, 20)
	, @debugstarttime	datetime = getdate()
    , @i_customer_id_list varchar(max)= isnull(@customer_id_list ,'')
    , @i_generator_id_list varchar(max)= isnull(@generator_id_list, '')
	, @i_excel_output		int = isnull(@excel_output, 0)
	, @i_count_output		int = isnull(@count_output, 0)


select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid    
    
if @i_sort not in ('Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status') set @i_sort = ''
if @i_date_start = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if @i_date_end = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'

-- Define the 'today' variable used in the selects  
DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   

declare @tcustomer table (
	customer_id	int
)
if @i_customer_search + @i_customer_id_list <> ''
insert @tcustomer
select customer_id from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 
WHERE @i_customer_search <> ''
union
select customer_id from ContactCORCustomerBucket b
where contact_id = @i_contact_id
and customer_id in (
	select convert(int, row)
	from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
	WHERE row is not null
)
and @i_customer_id_list <> ''


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

declare @ttransid table (
	transaction_id int
)
if @i_transaction_id <> ''
insert @ttransid
select convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @i_transaction_id) 
where row is not null


-- Project Codes:
declare @tproject table (
	project_code varchar(15)
)
if @i_project_code <> ''
insert @tproject
select left(row,15)
from dbo.fn_splitxsvtext(',', 1, @i_project_code) 
where row is not null

-- Approval Codes:
declare @tapproval table (
	approval_code varchar(15)
)
if @i_approval_code_list <> ''
insert @tapproval
select left(row,15)
from dbo.fn_splitxsvtext(',', 1, @i_approval_code_list) 
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

/* Generator IDs from Search parameters 
declare @generators table (Generator_id int)

if @i_generator_name + @i_epa_id + @i_store_number + @i_generator_district + @i_generator_region + @i_generator_id_list + @i_site_type <> ''
	insert @generators
	SELECT  
			x.Generator_id
	FROM    ContactCORGeneratorBucket x (nolock)
	join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	where 
	x.contact_id = @i_contact_id
	and (
		@i_generator_name = ''
		or
		(
			@i_generator_name <> ''
			and
			d.generator_name like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
	and 
	(
		@i_epa_id = ''
		or
		(
			@i_epa_id <> ''
			and
			d.epa_id in (select epa_id from @epaids)
		)
	)
	and 
	(
		@i_generator_region = ''
		or
		(
			@i_generator_region <> ''
			and
			d.generator_region_code in (select generator_region_code from @tgeneratorregion)
		)
	)
	and 
	(
		@i_generator_district = ''
		or
		(
			@i_generator_district <> ''
			and
			d.generator_district in (select generator_district from @tdistrict)
		)
	)
	and 
	(
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
			d.site_type in (select site_type from @tsitetype)
		)
	)
	and
	(
		@i_generator_id_list = ''
		or
		(
			x.generator_id in (select convert(int, row)
			from dbo.fn_SplitXsvText(',',1,@i_generator_id_list)
			where row is not null)
		)
	)
*/


--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after setup' as milestone


declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		service_date	datetime NULL,
		scheduled_date	datetime NULL,
		report_status	varchar(20) NULL,
		prices		bit NOT NULL
		, invoice_date	datetime NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.service_date,
		x.scheduled_date,
		x.report_status,
		x.prices
		, x.invoice_date
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE x.contact_id = @i_contact_id
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
			isnull(d.epa_id, '') in (select epa_id from @epaids)
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
	and 
	(
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
			isnull(d.site_type, '') in (select site_type from @tsitetype)
		)
	)
	and
	(
		@i_generator_id_list = ''
		or
		(
			x.generator_id in (select convert(int, row)
			from dbo.fn_SplitXsvText(',',1,@i_generator_id_list)
			where row is not null)
		)
	)

-- select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @foo' as milestone

if (@i_date_specifier <> 'service') begin
declare @foo_copy table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		service_date	datetime NULL,
		scheduled_date	datetime NULL,
		report_status	varchar(20) NULL,
		prices		bit NOT NULL
		, invoice_date	datetime NULL
	)
	insert @foo_copy
	SELECT  x.*  FROM    @foo x
		inner join workorderstop wos (nolock)
		on wos.workorder_id = x.workorder_id 
		and wos.company_id = x.company_id 
		and wos.profit_ctr_id = x.profit_ctr_id
		and wos.stop_sequence_id = 1
		and (
			(@i_date_specifier = 'requested' and wos.date_request_initiated between @i_date_start and @i_date_end and wos.date_est_arrive is null)
			or (@i_date_specifier = 'scheduled' and wos.date_est_arrive between @i_date_start and @i_date_end)
		)
	delete from @foo
	insert @foo select * from @foo_copy
	delete from @foo_copy
end
	
-- select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @foo limiting' as milestone


declare @bar table (
	workorder_id	int
	, company_id int
	, profit_ctr_id int
	, start_date	datetime NULL
	, service_date	datetime NULL
	, scheduled_date	datetime NULL
	, report_status	varchar(20) NULL
	, prices int
	, invoice_date	datetime
	, status varchar(20)
)

insert @bar
-- Limit results to 1 line per receipt, for members of @foo
select distinct z.workorder_id, z.company_id, z.profit_ctr_id, z.start_date, x.service_date, x.scheduled_date, x.report_status, x.prices, x.invoice_date
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
		when (b.billing_uid is not null)
				then 'Invoiced'
		else
			'Unknown'
		end
from @foo x
join workorderheader z (nolock) on x.workorder_id = z.workorder_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
left join workorderstop wos  (nolock)
	on wos.workorder_id = x.workorder_id 
	and wos.company_id = x.company_id 
	and wos.profit_ctr_id = x.profit_ctr_id
	and wos.stop_sequence_id = 1
left join billing b (nolock)
	on b.receipt_id = x.workorder_id 
	and b.company_id = x.company_id 
	and b.profit_ctr_id = x.profit_ctr_id 
	and b.trans_source = 'W' 
	and b.status_code = 'I'
WHERE z.workorder_status NOT IN ('V','X','T')
	and (
		(select count(*) from @tcustomer) = 0
		or 
		(exists (select top 1 1 from @tcustomer where customer_id = z.customer_id))
	)
	and (
		(select count(*) from @tscheduletype) = 0
		or  (
			(exists (select top 1 1 from @tscheduletype tst join WorkorderScheduleType wst on tst.schedule_type = wst.schedule_type where wst.workorderscheduletype_uid = z.workorderscheduletype_uid))
			or
			(
				-- "Pending" according to sp_cor_dashboard_service_status:
				@i_date_specifier = 'service' and isnull(x.service_date, x.start_date) between @i_date_start and @i_date_end
				and @i_schedule_type = 'pending'
				and x.scheduled_date is null
			)
			or
			(
				-- "Scheduled" according to sp_cor_dashboard_service_status:
				x.report_status <> 'Completed'
				and isnull(z.submitted_flag, 'F') = 'F'
				and x.scheduled_date between @i_date_start and @i_date_end
				and @i_schedule_type = 'scheduled'
			)
		)
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
	and (
		(select count(*) from @tproject) = 0
		or 
		(z.project_code in (select project_code from @tproject))
	)


-- select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar' as milestone
	
---- debug:
--SELECT  count(*) as bar_count  FROM    @bar

if (select count(*) from @tstatus) > 0 begin
	declare @bar_copy table (
		workorder_id	int
		, company_id int
		, profit_ctr_id int
		, start_date	datetime NULL
		, service_date	datetime NULL
		, scheduled_date	datetime NULL
		, report_status	varchar(20) NULL
		, prices int
		, invoice_date datetime
		, status varchar(20)
	)
	insert @bar_copy select * from @bar
	where status in (select status from @tstatus)
	delete from @bar
	insert @bar select * from @bar_copy
	delete from @bar_copy
end

--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar status filter' as milestone

if ((select count(*) from @tapproval) > 0) begin
declare @bar_app table (
		workorder_id	int
		, company_id int
		, profit_ctr_id int
		, start_date	datetime NULL
		, service_date	datetime NULL
		, scheduled_date	datetime NULL
		, report_status	varchar(20) NULL
		, prices int
		, invoice_date	datetime
		, status varchar(20)
	)
	insert @bar_app
	SELECT  x.*  FROM    @bar x
	where exists (select top 1 1 from workorderdetail d (nolock)
		where d.workorder_id = x.workorder_id 
		and d.company_id = x.company_id 
		and d.profit_ctr_id = x.profit_ctr_id
		and d.tsdf_approval_code in (select approval_code from @tapproval)
	)
	
	--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar approval filter' as milestone

	delete from @bar
	insert @bar select * from @bar_app
	delete from @bar_app
	
	--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar approval delete ' as milestone

end

/*

sp_help workorderdetail

drop index workorderdetail.idx_tsdf_approval_workorder_id

create index idx_tsdf_approval_workorder_id on workorderdetail (workorder_id, company_id, profit_ctr_id, tsdf_approval_code)



*/

--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'after @bar approval block' as milestone

if @i_excel_output = 0

	select * from (

		select
			h.workorder_id transaction_id
			, h.company_id
			, h.profit_ctr_id
			, upc.name company_name
			, upc.name as profitcenter_name
			, g.generator_name
			, g.epa_id
			, g.generator_city
			, g.generator_state
			, g.site_type
			, g.generator_region_code
			, g.generator_division
			, g.site_code store_number
			, g.generator_id
			, wos.date_request_initiated requested_date
			, wos.date_est_arrive scheduled_date
			, h.start_date service_date
			, wst.schedule_type
			, wtype.account_desc  as Service_Type
			, case when wtype.account_desc LIKE '%Emergency Response%' then wotd.description else null end as Emergency_Response_Type_Reason
			, z.status
			, manifest_list = substring((select ', ' + 
				case when wom.manifest_flag = 'T' then 
					-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
				+ 'Manifest ' else 'BOL ' end
				+ wom.manifest
				from workordermanifest wom (nolock)
				where @i_count_output = 0
				and wom.workorder_id = z.workorder_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
				for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)

			, z.prices as show_prices
			, ( select substring(
				(
				select ', ' + document_type + ' ' + coalesce(document_name, manifest, 'Manifest')+case relation when 'input' then '' else ' (from a related ' + document_source + ')' end + '|'+coalesce(convert(varchar(3),page_number), '1') + '|'+coalesce(file_type, '') + '|' + convert(Varchar(10), image_id)
				FROM    dbo.fn_cor_scan_lookup (@i_web_userid, 'workorder', h.workorder_id, h.company_id, h.profit_ctr_id, 1, 'manifest')
				order by coalesce(document_name, manifest), page_number, image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'

			/*
				(select ', ' + coalesce(s.document_name, s.manifest,'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number),'1') + '|'+ coalesce(s.file_type,'')+'|'+convert(Varchar(10), s.image_id)
				FROM plt_image..scan s
				WHERE @i_count_output = 0
				and s.workorder_id = h.workorder_id
				and s.company_id = h.company_id
				and s.profit_ctr_id = h.profit_ctr_id
				and s.document_source = 'workorder'
				and s.status = 'A'
				and s.view_on_web = 'T'
				and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest') 
				order by coalesce(s.document_name, s.manifest, 'Manifest'), s.page_number, s.image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'
			*/
				),2,20000)
				
			)  images
			, case when z.invoice_date is not null 
				or isnull(h.submitted_flag,'F') = 'T'
					then 'T' else 'F' end as invoiced_flag
			, h.purchase_order
			, h.release_code
			,_row = row_number() over (order by 
				case when @i_sort in ('', 'Service Date') then z.start_date end desc,
				case when @i_sort = 'Customer Name' then c.cust_name end asc,
				case when @i_sort = 'Generator Name' then g.generator_name end asc,
				case when @i_sort = 'Schedule Type' then wst.schedule_type end desc,
				case when @i_sort = 'Service Type' then wtype.account_desc end asc, 
				case when @i_sort = 'Requested Date' then wos.date_request_initiated end desc, 
				case when @i_sort = 'Scheduled Date' then wos.date_est_arrive end desc, 
				case when @i_sort = 'Status' then z.status end asc, 
				case when @i_sort = 'Manifest Number' then z.workorder_id end desc, -- This is a CSV list subquery, not great for ordering
				case when @i_sort = 'Store Number' then g.site_code end asc,
				case when @i_sort = 'Workorder Number' then z.workorder_id end desc,
				z.start_date asc
			) 
		from @bar z 
			join WorkorderHeader h (nolock) on h.workorder_id = z.workorder_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
			join Customer c (nolock) on h.customer_id = c.customer_id
			left join Generator g (nolock) on h.generator_id = g.generator_id
			left join WorkorderType wtype (nolock) on h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
			left join workorderstop wos (nolock) on wos.workorder_id = z.workorder_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1
			left join WorkorderScheduleType wst (nolock) on h.workorderscheduletype_uid = wst.workorderscheduletype_uid
			LEFT JOIN WorkOrderTypeHeader t WITH (NOLOCK) ON t.workorder_type_id = h.workorder_type_id
			LEFT JOIN WorkOrderTypeDescription wotd (nolock) 
				ON h.workorder_type_desc_uid =  wotd.workorder_type_desc_uid 
				AND (t.account_desc like '%emergency response%' OR h.workorder_type_id in (3, 63, 77, 78, 79, 80))
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
		where 1=1
		and ( 
			@i_manifest = ''
			or 
			(exists (select top 1 1 from workordermanifest m (nolock) 
				join @tmanifest t on m.manifest like '%' + t.manifest + '%'
				where m.workorder_id = z.workorder_id and m.company_id = z.company_id and m.profit_ctr_id = z.profit_ctr_id)
			)
		)
		and 
		(
			@i_search = ''
			or
			(
				@i_search <> ''
				and
	
					isnull(convert(varchar(20), h.workorder_id), '') + ' ' +
					isnull(g.generator_name, '') + ' ' + 
					isnull(g.site_code, '') + ' ' + 
					isnull(g.site_type, '') + ' ' + 
					isnull(g.epa_id, '') + ' ' + 
					isnull(g.generator_city, '') + ' ' +
					isnull(g.generator_state, '') + ' ' +
					isnull(wst.schedule_type, '') + ' ' +
					isnull(wtype.account_desc, '') + ' ' +
					isnull(substring((select ', ' + 
						case when wom.manifest_flag = 'T' then 
							-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
						+ 'Manifest ' else 'BOL ' end
						+ wom.manifest
						from workordermanifest wom (nolock)
						where wom.workorder_id = z.workorder_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
						for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000), '') + ' '

				like '%' + replace(@i_search, ' ', '%') + '%'
	
			)
		)

	
	) y
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	order by _row

else

	-- excel output:
		select * from (

		select
			-- Header
			h.workorder_id transaction_id
			, h.company_id
			, h.profit_ctr_id
			, upc.name company_name
			, upc.name as profitcenter_name
			, c.customer_id
			, c.cust_name
			, g.generator_name
			, g.epa_id
			, g.generator_city
			, g.generator_state
			, g.site_type
			, g.generator_region_code
			, g.generator_division
			, g.site_code store_number
			, h.project_name
			, h.start_date
			, h.end_date
			, wos.date_request_initiated requested_date
			, wos.date_est_arrive scheduled_date
			, wst.schedule_type
			, wtype.account_desc  as Service_Type
			, z.status
			, wos.confirmation_date
			, wos.schedule_contact
			, wos.schedule_contact_title
			-- driver??
			, h.purchase_order
			, h.release_code
			, wos.pickup_contact
			, wos.pickup_contact_title
			-- Declined Status ??
			, h.description header_description
			, b.invoice_code
			, b.invoice_date
			
			-- Detail
			, case d.resource_type
				when 'E' then 'Equipment'
				when 'L' then 'Labor'
				when 'S' then 'Supplies'
				when 'O' then 'Other'
				when 'D' then 'Disposal'
				else d.resource_type
				end as resource_type
			, d.description detail_description
			, d.description_2 detail_description_2
			, d.tsdf_approval_code
			, d.manifest
			, coalesce(wodu.quantity, d.quantity) quantity
			-- Quantity Estimated??
			, bu.bill_unit_desc
			, case when z.prices = 1
				then d.extended_price
				else null
				end as price
			, case when z.prices = 1
				then b.total_extended_amt
				else null
				end as extended_total
			, case when z.invoice_date is not null 
				or isnull(h.submitted_flag,'F') = 'T'
					then 'T' else 'F' end as invoiced_flag
			, case when z.prices = 1
				then d.currency_code
				else null
				end as currency_code
			,_row = row_number() over (order by 
				case when @i_sort in ('', 'Service Date') then z.start_date end desc,
				case when @i_sort = 'Customer Name' then c.cust_name end asc,
				case when @i_sort = 'Generator Name' then g.generator_name end asc,
				case when @i_sort = 'Schedule Type' then wst.schedule_type end desc,
				case when @i_sort = 'Service Type' then wtype.account_desc end asc, 
				case when @i_sort = 'Requested Date' then wos.date_request_initiated end desc, 
				case when @i_sort = 'Scheduled Date' then wos.date_est_arrive end desc, 
				case when @i_sort = 'Status' then z.status end asc, 
				case when @i_sort = 'Manifest Number' then z.workorder_id end desc, -- This is a CSV list subquery, not great for ordering
				case when @i_sort = 'Store Number' then g.site_code end asc,
				case when @i_sort = 'Workorder Number' then z.workorder_id end desc,
				z.start_date asc
				, upc.name, z.workorder_id, b.billing_uid, d.resource_type, d.sequence_id
			) 
		from @bar z 
			join WorkorderHeader h (nolock) on h.workorder_id = z.workorder_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
			join WorkorderDetail d (nolock) on h.workorder_id = d.workorder_id and h.company_id = d.company_id and h.profit_ctr_id = d.profit_ctr_id and d.bill_rate >= -2
			left join workorderdetailunit wodu (nolock) on wodu.workorder_id = d.workorder_id and wodu.company_id = d.company_id and wodu.profit_ctr_id = d.profit_ctr_id and d.bill_rate >= -2 and d.resource_type = 'D' and d.sequence_id = wodu.sequence_id and wodu.billing_flag = 'T'
			left join billing b on b.receipt_id = h.workorder_id and b.company_id = h.company_id and b.profit_ctr_id = h.profit_ctr_id and b.status_code = 'I' and b.trans_source = 'W'
				and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id
			join BillUnit bu on coalesce(b.bill_unit_code, wodu.bill_unit_code, d.bill_unit_code) = bu.bill_unit_code
			join Customer c (nolock) on h.customer_id = c.customer_id
			left join Generator g (nolock) on h.generator_id = g.generator_id
			left join WorkorderType wtype (nolock) on h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
			left join workorderstop wos (nolock) on wos.workorder_id = z.workorder_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1
			left join WorkorderScheduleType wst (nolock) on h.workorderscheduletype_uid = wst.workorderscheduletype_uid
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
			
		where 1=1
		and ( 
			@i_manifest = ''
			or 
			(exists (select top 1 1 from workordermanifest m (nolock) 
				join @tmanifest t on m.manifest like '%' + t.manifest + '%'
				where m.workorder_id = z.workorder_id and m.company_id = z.company_id and m.profit_ctr_id = z.profit_ctr_id)
			)
		)
		and 
		(
			@i_search = ''
			or
			(
				@i_search <> ''
				and
	
					isnull(convert(varchar(20), h.workorder_id), '') + ' ' +
					isnull(g.generator_name, '') + ' ' + 
					isnull(g.site_code, '') + ' ' + 
					isnull(g.site_type, '') + ' ' + 
					isnull(g.epa_id, '') + ' ' + 
					isnull(g.generator_city, '') + ' ' +
					isnull(g.generator_state, '') + ' ' +
					isnull(wst.schedule_type, '') + ' ' +
					isnull(wtype.account_desc, '') + ' ' +
					isnull(substring((select ', ' + 
						case when wom.manifest_flag = 'T' then 
							-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
						+ 'Manifest ' else 'BOL ' end
						+ wom.manifest
						from workordermanifest wom (nolock)
						where wom.workorder_id = z.workorder_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
						for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000), '') + ' '

				like '%' + replace(@i_search, ' ', '%') + '%'
	
			)
		)

	
	) y
	order by _row

--select datediff(ms, @debugstarttime, getdate()) as debug_timing, 'end' as milestone

return 0
go

grant execute on sp_cor_schedule_service_list to eqai, eqweb, COR_USER
go


