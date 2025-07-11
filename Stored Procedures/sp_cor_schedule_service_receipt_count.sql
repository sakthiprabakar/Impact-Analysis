﻿-- drop proc sp_cor_schedule_service_receipt_count
go

create procedure sp_cor_schedule_service_receipt_count (
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
sp_cor_schedule_service_receipt_count

	10/15/2019	DevOps:11603 - AM - Added customer_id and generator_id temp tables and added receipt join.
	06/10/2021  DO:15510 - JPB - add logic to merge related transactions

COMBINATION OF sp_cor_schedule_service_list
AND sp_cor_receipt_list

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

SELECT	*	
into #e
FROM		#d d
where 1=1
and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'E')

SELECT	*	
into #f
FROM		#e d
where 1=1
and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'L')

SELECT	*	
into #g
FROM		#f d
where 1=1
and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'S')

SELECT	*	
into #h
FROM		#g d
where 1=1
and exists (select 1 from workorderdetail z where z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.bill_rate > 0 and z.resource_type = 'O')

SELECT	*	FROM		#h

--#endregion
Samples:

exec sp_cor_schedule_service_receipt_count
@web_userid = 'dcrozier@riteaid.com'
, @date_start = '11/1/2015'
, @date_end = '12/31/2015'

exec sp_cor_schedule_service_receipt_count
@web_userid = 'nyswyn100'
, @date_start = '11/1/2000'
, @date_end = '12/31/2015'
, @perpage = 20
, @page = 4

exec sp_cor_schedule_service_receipt_count
@web_userid = 'nyswyn100'
, @date_start = '4/1/2018'
, @date_end = '5/31/2022'
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
		 -- , @approval_code_list = 'HFUW13'
		 , @facility = null
		 , @status = null -- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
		 , @adv_search = null
, @sort = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
, @page = 1
, @perpage = 20
, @excel_output = 1
, @customer_id_list =	''
, @generator_id_list = ''
, @combine_transactions = 1

SELECT	*	FROM		receipt where receipt_id = 2009774 and company_id = 21 and approval_code = 'HFUW13'

-- SERVICE_TYPE testing:
-- No filter: 2390
-- Store: 12
-- Dist: 0
SELECT	*	FROM		workorderheader where customer_id = 15551 and generator_sublocation_id is not null and start_date <= '12/31/2015'
-- 12.	 All store.	 Seems legit.

SELECT	*	FROM		contact where web_userid = 'nyswyn100'
SELECT	*	FROM		contactxref WHERE contact_id = 185547
SELECT	*	FROM		generatorsublocation WHERE customer_id = 15551
-- Store: id = 28
-- Distribution Center: id = 37

-- SCHEDULE_TYPE testing:

SELECT	*	FROM		contact where web_userid = 'zachery.wright'
SELECT	*	FROM		contactxref WHERE contact_id = 184522
SELECT	*	FROM		generatorsublocation WHERE customer_id = 15622


SELECT	*	FROM		workorderheader where customer_id = 15622 and workorderscheduletype_uid is not null and start_date <= '12/31/2015'
-- none to test.


SELECT	*	FROM		workorderdetail WHERE workorder_id = 22445900 and company_id = 14 and profit_ctr_id = 0

******************************************************************* */


--#region debugging
/*
declare
	@web_userid			varchar(100) = 'dcrozier@riteaid.com'
	, @date_start		datetime = '7/1/2012'
	, @date_end			datetime = '1/1/2013'
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
	
	, @page				bigint = 1
	, @perpage			bigint = 20

*/	
-- SELECT  *  FROM    generator where generator_id = 75040

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
	, @i_dashboard_service_status_period varchar(2) = isnull(@dashboard_service_status_period, '')
	

    
if @i_sort not in ('Transaction Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status','Customer Name', 'Generator Name') set @i_sort = ''
if @i_date_start = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if @i_date_end = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'

-- Define the 'today' variable used in the selects  
DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   

declare @out table (
	transaction_type	varchar(40)
	, transaction_id	bigint
	, company_id		int
	, profit_ctr_id		int
	, USE_facility_name	varchar(50)
	, cust_name			varchar(75)
	, customer_id		bigint
	, generator_name	varchar(75)
	, epa_id			varchar(12)
	, generator_city	varchar(40)
	, generator_state	varchar(2)
	, generator_zip_code	varchar(15)
	, site_type			varchar(40)
	, generator_region_code	varchar(40)
	, generator_division	varchar(40)
	, store_number		varchar(16)
	, generator_id		bigint
	, requested_date	datetime
	, scheduled_date	datetime
	, service_date		datetime
	, time_in			datetime
	, time_out			datetime
	, approval_code		varchar(15)
	, schedule_type		varchar(20)
	, service_type		varchar(40)
	, Emergency_Response_Type_Reason	varchar(255)
	, status			varchar(20)
	, manifest_list		varchar(max)
	, purchase_order	varchar(max)
	, release_code		varchar(max)
	, show_prices		int
	, transaction_total money
	, images			varchar(max)
	, invoiced_flag		char(1)
	, _row				int
	, total				int
)

insert @out
exec sp_cor_schedule_service_receipt_list 
	@web_userid			= @i_web_userid
	, @date_start		= @i_date_start
	, @date_end			= @i_date_end
	, @date_specifier	= @i_date_specifier
	, @customer_search	= @i_customer_search
	, @manifest			= @i_manifest
	, @schedule_type	= @i_schedule_type
	, @service_type		= @i_service_type
	, @generator_name	= @i_generator_name
	, @epa_id			= @i_epa_id
	, @store_number		= @i_store_number
	, @site_type		= @i_site_type
	, @generator_district = @i_generator_district
	, @generator_division = @i_generator_division
	, @generator_state	= @i_generator_state
	, @generator_region	= @i_generator_region
	, @approval_code	= @i_approval_code_list
	, @transaction_id	= @i_transaction_id
	, @transaction_type = @i_transaction_type
	, @facility			= @i_facility
	, @status			= @i_status
	, @project_code		 = @i_project_code
	, @release_code			 = @i_release_code
	, @purchase_order		 = @i_purchase_order
	, @search			= @i_search
	, @adv_search		= @i_adv_search
	, @sort				= @i_sort
	, @page				= 1
	, @perpage			= 9999999
	, @excel_output		= 0
	, @customer_id_list = @i_customer_id_list
	, @generator_id_list = @i_generator_id_list
	, @combine_transactions= @i_combine_transactions
	, @dashboard_service_status = @i_dashboard_service_status
	, @dashboard_service_status_period = @i_dashboard_service_status_period


select count(*) from @out

return 0
go

grant execute on sp_cor_schedule_service_receipt_count to eqai, eqweb, COR_USER
go
