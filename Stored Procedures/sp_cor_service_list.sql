-- drop proc if exists sp_cor_service_list
go
-- Stored Procedure

create procedure [dbo].[sp_cor_service_list] (
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
	--    , @generator_search	varchar(max) = null
	, @generator_district varchar(max) = null -- can take CSV list
	, @generator_division varchar(max) = null -- can take CSV list
	, @generator_state	varchar(max) = null -- can take CSV list
	, @generator_region	varchar(max) = null -- can take CSV list
	, @approval_code	varchar(max) = null	-- Approval Code List
	, @transaction_id	varchar(max) = null
	-- , @transaction_type	varchar(20) = 'receipt' -- always receipt in this proc
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

) as

/* *******************************************************************
sp_cor_service_list

10/7/2019 - MPM	- DevOps 11613: Added logic to filter the result set
					using optional input parameters @customer_id_list
					and @generator_id_list.

Description
	Provides a listing of all receipt and work order service transactions, displayed in a list format.

	Assumptions/constraints

		For a receipt to be displayed in this list, it should be for an 
			inbound receipt (trans_mode = ‘I’), it should not have a status of 
			void or rejected and should be invoiced.

		For a work order to be displayed in this list, it should not 
			have a status of void or template and it does not matter if it is 
			invoiced or not.

	Inputs

		User access limitation for customer(s) & generator(s)

		Users should be able to Search and Filter their data by the following 
		items: 
			1) Service Date range 
			2) Customer account (if the user has access to multiple accounts) 
			3) Manifest / BOL document number 
			4) Generator location 
			5) Approval Code 
			6) Transaction Number 
			7) Transaction Type 
			8) US Ecology facility (the company & profit center on the transaction) 

		When a user clicks on an individual transaction in the list, the additional 
		details regarding the transaction should appear. 

		For a receipt, the following information should appear on the screen: 
		Receipt Header Information: 
			Transaction Type (Receipt or Work Order), 
			US Ecology facility, 
			Transaction ID, 
			Customer Name, 
			Customer ID, 
			Generator Name, 
			Generator EPA ID, 
			Generator ID, 

			If Receipt.manifest_flag = 'M' or 'C': 
				Manifest Number, 
				Manifest Form Type (Haz or Non-Haz), 

			If Receipt.manifest_flag = 'B': 
				BOL number, 

			Receipt Date, 
			Receipt Time In, 
			Receipt Time Out 

		For each receipt disposal line: 
			Manifest Page Number, 
			Manifest Line Number, 
			Manifest Approval Code, 
			Approval Waste Common Name, 
			Manifest Quantity, 
			Manifest Unit, 
			Manifest Container Count, 
			Manifest Container Code. 
			{If we are showing 	pricing, we may need to add more, here}

		For each receipt service line: 
			Receipt line item description, 
			Receipt line item quantity, 
			Receipt line item unit of measure. 
			{If we are showing pricing, we may need to add more, here} 

		For each receipt, the user should be able to: 
			1) View the Printable Receipt Document 
			2) View any Scanned documents that are linked to the receipt and marked 
				as 'T' for the View on Web status 
			3) Upload any documentation to the receipt 
			4) Save the Receipt detail lines to Excel. 

		For each work order, the following information should appear on the screen: 
			Work Order Header Information: 
			Transaction Type (Receipt or Work Order), 
			US Ecology facility, 
			Transaction ID, 
			Customer Name, 
			Customer ID, 
			Generator Name, 
			Generator EPA ID, 
			Generator ID.

		For Work Order detail lines that are marked as 'Equipment', 'Labor', 
			'Supplies' or 'Other' charges, the following items should be 
			displayed and grouped by their type (Equipment, Labor, Supplies, 
			Other): 

			Billing Order, 
			Line Description line 1, 
			Line Description line 2, 
			Quantity, 
			Bill Unit, 
			Bill Rate, 
			Price, 
			Extended Price, 
			Manifest Reference number (only for Other charges), 
			Manifest Reference Line Number (only for Other charges) 

		For Work Order Detail Disposal lines: 

			For each manifest / BOL: 
			If Manifest Flag = 'B', BOL Number, Else If Manifest Flag = 'M', Manifest Number, 
			Manifest Type (Haz or Non-Haz from Manifest_state = ' H' or Manifest_state = ' N'), 
			TSDF Name, 
			Generator Sign Name, 
			Generator Sign date, 
			Transporter details (0-many), 
			Transporter company name, 
			Transporter Sign Name, 
			Transporter Sign Date 

			For each disposal line item: 
				Manifest Page Number, 
				Manifest Line Number, 
				Manifest Approval Code, 
				Approval Waste Common Name, 
				Manifest Quantity, 
				Manifest Unit, 
				Manifest Container Count, 
				Manifest Container Code. 
				{If we are showing pricing, we may need to add more, here} 

		For each work order, the user should be able to: 
			1) View the Printable Customer Receipt Document 
			2) View any Scanned documents that are linked to the receipt and marked as 'T' for the View on Web status 
			3) Upload any documentation to the work order 
			4) Save the Work Order detail lines to Excel.



	Output
		For each transaction located, the following items should be displayed: 
			1. Transaction Type (Receipt or Work Order) 
			2. Customer Account (Name & number) 
			3. Generator (Name, EPA ID) 
				generator_id
			4. Transaction source company / profit center name. 
			5. Transaction number (receipt id or work order id) 
			6. Manifest/BOL shipping document number (for receipts, there will be 
				1, for work orders there could be 0 to many). 
			7. Transaction date (for receipts, the date would be the Receipt Date. 
				For work orders, the date should be the Work Order Start & End 
				Date. If they are the same, show one date. If they are different, 
				show a range. IE: If the start = 1/1/2019 and the end = 1/10/2019, 
				display 1/1/2019 - 1/10/2019)

		Excel Output: On the Excel Output: Display the 
			transaction type, 
			customer id, 
			customer name, 
			generator name, 
			generator EPA ID, 
			generator id, 
			transaction company id, 
			transaction profit center id, 
			transaction id, 
			manifest number(s), 
			transaction start date, 
			transaction end date (note: for a receipt, both dates would be the same. 
				for a work order, the dates would be the Work order Header start 
				date and Work Order Header end date)


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

exec sp_cor_service_list
	@web_userid = 'akalinka'
	, @date_start = '1/1/2021'
	, @date_end = '2/28/2021'
	, @excel_output = 0

exec sp_cor_receipt_list
	@web_userid = 'nyswyn125'
	, @date_start = '11/1/2018'
	, @date_end = '12/31/2019'
	, @excel_output = 0

exec sp_cor_service_count
	@web_userid = 'nyswyn125'
	, @date_start = '11/1/2018'
	, @date_end = '12/31/2019'

exec sp_cor_service_list
	@web_userid = 'thames'
	, @date_start = '1/1/2018'
	, @date_end = '10/7/2019'	
    , @customer_search	= null
    , @manifest			= null
    , @generator_search	= null
    , @approval_code	= null
    , @transaction_id	= null
    , @facility			= null
    , @adv_search		= null
	, @sort				= ''
	, @page				= 1
	, @perpage			= 20 
    , @excel_output		= 0
	, @customer_id_list = null 
    , @generator_id_list = null

exec sp_cor_service_list
	@web_userid = 'thames'
	, @date_start = '1/1/2019'
	, @date_end = '10/7/2019'	
    , @customer_search	= null
    , @manifest			= null
    , @generator_search	= null
    , @approval_code	= null
    , @transaction_id	= null
    , @facility			= null
    , @adv_search		= null
	, @sort				= ''
	, @page				= 1
	, @perpage			= 20 
    , @excel_output		= 0
	, @customer_id_list = '15940' 
    , @generator_id_list = '137729, 140271, 137729'

exec sp_cor_service_list
	@web_userid = 'thames'
	, @date_start = '1/1/2019'
	, @date_end = '10/7/2019'	
    , @customer_search	= null
    , @manifest			= null
    , @generator_search	= null
    , @approval_code	= null
    , @transaction_id	= null
    , @facility			= null
    , @adv_search		= null
	, @sort				= ''
	, @page				= 1
	, @perpage			= 20 
    , @excel_output		= 0
	, @customer_id_list = '15940' 
    , @generator_id_list = null

exec sp_cor_service_list
	@web_userid = 'thames'
	, @date_start = '1/1/2019'
	, @date_end = '10/7/2019'	
    , @customer_search	= null
    , @manifest			= null
    , @generator_search	= null
    , @approval_code	= null
    , @transaction_id	= null
    , @facility			= null
    , @adv_search		= null
	, @sort				= ''
	, @page				= 1
	, @perpage			= 20 
    , @excel_output		= 0
	, @customer_id_list = null 
    , @generator_id_list = '137729, 140271, 137729'

******************************************************************* */
/*
-- debugging
declare
	@web_userid			varchar(100) = 'nyswyn100'
	, @date_start		datetime = '1/1/2000'
	, @date_end			datetime = '1/1/2020'
    , @customer_search	varchar(max) = null
    , @manifest			varchar(max) = null
    , @generator_search	varchar(max) = null
    , @approval_code	varchar(max) = null
    , @transaction_id	varchar(max) = null
    -- , @transaction_type	varchar(20) = 'receipt' -- always receipt in this proc
    , @facility			varchar(max) = null
    , @adv_search		varchar(max) = null
	, @sort				varchar(20) = ''
	, @page				bigint = 1
	, @perpage			bigint = 20

*/
/*

declare @tapproval table (
	approval_code	varchar(20)
)
if isnull('BLEACH,FLAMLIQ', '') <> ''
insert @tapproval
select row 
from dbo.fn_splitxsvtext(',', 1, 'BLEACH,FLAMLIQ') 
where row is not null
SELECT  *  FROM    @tapproval
SELECT  d.*  FROM    workorderheader z
join workorderdetail d on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id
 where customer_id = 888880 and start_date between '1/1/2000' and '1/1/2020'
and 
		(exists (select top 1 1 from workordermanifest m 
			join @tmanifest t on m.manifest like '%' + t.manifest + '%'
			where m.workorder_id = z.workorder_id and m.company_id = z.company_id and m.profit_ctr_id = z.profit_ctr_id)
		)

SELECT  *  FROM    workorderdetail where workorder_id = 12308100 and company_id = 14
*/


-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_date_start			datetime = convert(date, @date_start)
	, @i_date_end			datetime = convert(date, @date_end)
	, @i_date_specifier		varchar(10) = isnull(@date_specifier, 'service')
	, @i_schedule_type		varchar(max) = @schedule_type
	, @i_service_type		varchar(max) = @service_type
    , @i_customer_search	varchar(max) = @customer_search
    , @i_manifest			varchar(max) = replace(@manifest, ' ', ',')
    -- , @i_generator_search	varchar(max) = @generator_search
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
	, @i_generator_division	varchar(max) = isnull(@generator_division, '')
	, @i_generator_state	varchar(max) = isnull(@generator_state, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_approval_code		varchar(max) = replace(@approval_code, ' ', ',')
    , @i_release_code       varchar(50) = isnull(@release_code, '')
    , @i_purchase_order     varchar(20) = isnull(@purchase_order, '')
    , @i_transaction_id		varchar(max) = @transaction_id
    -- , @i_transaction_type	varchar(20) = @transaction_type 
	, @i_status				varchar(max) = isnull(@status,'')
	, @i_project_code		varchar(max) = isnull(@project_code,'')
	, @i_search				varchar(max) = isnull(@search,'')
    , @i_facility			varchar(max) = @facility
    , @i_adv_search			varchar(max) = @adv_search
	, @i_sort				varchar(20) = @sort
	, @i_page				bigint = @page
	, @i_perpage			bigint = @perpage 
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @i_contact_id			int

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if isnull(@i_sort, '') not in ('Service Date', 'Customer Name', 'Generator Name', 'Manifest/BOL', 'Transaction Type', 'Transaction Number') set @i_sort = ''
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'

DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   

declare @tcustomer table (
	customer_id	int
)
if isnull(@i_customer_search, '') <> ''
insert @tcustomer
select customer_id from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 

--declare @tgenerator table (
--	generator_id	int
--)
--if isnull(@i_generator_search, '') <> ''
--insert @tgenerator
--select generator_id from dbo.fn_COR_GeneratorID_Search(@i_web_userid, @i_generator_search) 

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

declare @tstate table (
	generator_state	varchar(2)
)
if @i_generator_state <> ''
insert @tstate
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_state)

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
if isnull(@i_manifest, '') <> ''
insert @tmanifest
select row 
from dbo.fn_splitxsvtext(',', 1, @i_manifest) 
where row is not null

declare @tapproval table (
	approval_code	varchar(20)
)
if isnull(@i_approval_code, '') <> ''
insert @tapproval
select row 
from dbo.fn_splitxsvtext(',', 1, @i_approval_code) 
where row is not null

declare @ttransid table (
	transaction_id int
)
if isnull(@i_transaction_id, '') <> ''
insert @ttransid
select convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @i_transaction_id) 
where row is not null

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


declare @copc table (
	company_id int
	, profit_ctr_id int
)
IF LTRIM(RTRIM(ISNULL(@i_facility, ''))) in ('', 'ALL')
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

	/* Generator IDs from Search parameters 
declare @generators table (Generator_id int)

if @i_generator_name + @i_epa_id + @i_store_number + @i_generator_district + @i_generator_division + @i_generator_state + @i_generator_region + @i_site_type <> ''
	insert @generators
	SELECT  
			x.Generator_id
	FROM    ContactCORGeneratorBucket x (nolock)
	join Contact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
	join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	where 
	(
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
	and (
		@i_generator_division = ''
		or
		(
			@i_generator_division <> ''
			and
			d.generator_division in (select generator_division from @tdivision)
		)
	)
	and (
		@i_generator_state = ''
		or
		(
			@i_generator_state <> ''
			and
			d.generator_state in (select generator_state from @tstate)
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
*/

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		customer_id int NULL,
		generator_id int NULL,
		start_date	datetime NULL,
		service_date datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
	)


insert @foo
SELECT  distinct
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.customer_id,
		x.generator_id,
		isnull(x.service_date, x.start_date),
		x.service_date,
		x.prices,
		x.invoice_date
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE
	x.contact_id = @i_contact_id
	and (
		@i_date_specifier <> 'service'
		or (@i_date_specifier = 'service' and isnull(x.service_date, x.start_date) between @i_date_start and @i_date_end)
	)
	and (
		isnull(@i_transaction_id, '') = ''
		or 
		(exists (select top 1 1 from @ttransid where x.workorder_id = transaction_id))
	)
	and (
		isnull(@i_facility, '') = ''
		or 
		(exists (select top 1 1 from @copc where company_id = x.company_id and profit_ctr_id = x.profit_ctr_id))
	)
	and 
	(
		@i_customer_id_list = ''
		or
		(
			@i_customer_id_list <> ''
			and
			x.customer_id in (select customer_id from @customer)
		)
	)
	and
	(
		@i_generator_id_list = ''
		or
		(
			@i_generator_id_list <> ''
			and
			x.generator_id in (select generator_id from @generator)
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
			isnull(d.generator_state, '') in (select generator_state from @tstate)
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



declare @bar_copy table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		customer_id int null,
		generator_id int null,
		start_date	datetime NULL,
		service_date datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
	)

if (@i_search <> '') begin
	delete from @bar_copy
	
	insert @bar_copy 
	select z.* 
	from @foo z 
		join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
		join Customer c (nolock) on c.customer_id = z.customer_id
		left join Generator g (nolock) on g.generator_id = z.generator_id 
		left join WorkorderHeader h (nolock) on h.workorder_id = z.workorder_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
		left join WorkorderDetail d (nolock) on d.workorder_id = z.workorder_id and d.company_id = z.company_id and d.profit_ctr_id = z.profit_ctr_id
		left join WorkorderType wtype (nolock) on h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
		left join workorderstop wos (nolock) on wos.workorder_id = z.workorder_id and wos.company_id = z.company_id and wos.profit_ctr_id = z.profit_ctr_id and wos.stop_sequence_id = 1
		left join WorkorderScheduleType wst (nolock) on h.workorderscheduletype_uid = wst.workorderscheduletype_uid
		left join WorkOrderTypeDescription wotd (nolock) on h.workorder_type_desc_uid =  wotd.workorder_type_desc_uid and h.workorder_type_id = 63
		left join tsdfapproval ta (nolock) on d.tsdf_approval_id = ta.tsdf_approval_id and d.company_id = ta.company_id and d.profit_ctr_id = ta.profit_ctr_id
		left join tsdf (nolock) on d.tsdf_code = tsdf.tsdf_code
	where ' ' +
		isnull(convert(varchar(20), z.workorder_id), '') + ' ' +
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
		isnull(
			substring((select ', ' + 
			case when wom.manifest_flag = 'T' then 
				-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
			+ 'Manifest ' else 'BOL ' end
			+ wom.manifest
			from workordermanifest wom (nolock)
			where wom.workorder_id = z.workorder_id and wom.company_id = z.company_id and wom.profit_ctr_id = z.profit_ctr_id and wom.manifest not like 'manifest__%'
			for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
		, '') + ' ' +
		isnull(ta.waste_stream, '') + ' ' +
		isnull(h.purchase_order, '') + ' ' +
		isnull(h.release_code, '') + ' ' +
		isnull(tsdf.tsdf_name, '') + ' ' +
		isnull(upc.name, '') + ' ' +
		''
	like '%' + replace(@i_search, ' ', '%') + '%'
	

	delete from @foo
	insert @foo select distinct * from @bar_copy
end
print 'Past @search'


if (@i_date_specifier <> 'service') begin
declare @foo_copy table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		customer_id int null,
		generator_id int null,
		start_date	datetime NULL,
		service_date	datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
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

declare @bar table (
	workorder_id	int
	, company_id int
	, profit_ctr_id int
	, customer_id int
	, generator_id int
	, start_date datetime
	, service_date	datetime NULL
	, prices int
	, invoice_date	datetime
)


insert @bar
-- Limit results to 1 line per receipt, for members of @foo
select z.workorder_id, z.company_id, z.profit_ctr_id, z.customer_id, z.generator_id, z.start_date, x.service_date, x.prices, x.invoice_date
from @foo x
join workorderheader z (nolock) on x.workorder_id = z.workorder_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
WHERE z.workorder_status NOT IN ('V','X','T')
	and (
		(select count(*) from @tcustomer) = 0
		or 
		(exists (select top 1 1 from @tcustomer where customer_id = z.customer_id))
	)
	--and (
	--	(select count(*) from @tgenerator) = 0
	--	or 
	--	(exists (select top 1 1 from @tgenerator where generator_id = z.generator_id))
	--)
	and (
		isnull(@i_approval_code, '') = ''
		or 
		(exists (
			select 1 from 
			workorderdetail d (nolock) 
			join @foo fa
				on d.workorder_id = fa.workorder_id
				and d.company_id = fa.company_id 
				and d.profit_ctr_id = fa.profit_ctr_id
				and d.bill_rate > -2
			join @tapproval t
				on d.tsdf_approval_code like '%' + t.approval_code + '%'
			WHERE 
				x.workorder_id = fa.workorder_id
				and x.company_id = fa.company_id 
				and x.profit_ctr_id = fa.profit_ctr_id
			)
		)
	)
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
from @bar x
join billing b
	on x.workorder_id = b.receipt_id
	and b.line_id = b.line_id
	and b.price_id = b.price_id
	and 'W' = b.trans_source
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


if isnull(@excel_output, 0) = 0

	select * from (

		select
			'Work Order' as transaction_type
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
			, h.company_id
			, h.profit_ctr_id
			, upc.name company_name
			, upc.name as profitcenter_name
			, h.workorder_id transaction_id
			, (
							select substring(
							(
								select ', Manifest ' + wom.manifest
								FROM workordermanifest wom (nolock)
								where
									wom.workorder_id = h.workorder_id
									and wom.company_id = h.company_id
									and wom.profit_ctr_id = h.profit_ctr_id
									and wom.manifest not like 'manifest%'
									and wom.manifest_flag = 'T'
									and wom.manifest is not null
								for xml path, TYPE).value('.[1]','nvarchar(max)'
							),2,20000)
				) as manifest
			, h.start_date transaction_date_start
			, h.end_date transaction_date_end
			, z.service_date
			, null as time_in
			, null as time_out
			, (
							select substring(
							(
								select ', ' + wod.tsdf_approval_code
								from workorderdetail wod
								where wod.workorder_id =h.workorder_id 
								and wod.company_id = h.company_id
								and wod.profit_ctr_id = h.profit_ctr_id
								and wod.resource_type = 'D'
								and wod.bill_rate > -2
								and wod.tsdf_approval_code is not null
								for xml path, TYPE).value('.[1]','nvarchar(max)'
							),2,20000)
				) as approval_code
			, h.purchase_order
			, h.release_code
			, z.prices as show_prices
			, case when z.prices <= 0 then null else billing.total_amount end as transaction_total
			, ( select substring(
				(
					select ', ' + document_type + ' ' + coalesce(document_name, manifest, 'Manifest')+case relation when 'input' then '' else ' (from a related ' + document_source + ')' end + '|'+coalesce(convert(varchar(3),page_number), '1') + '|'+coalesce(file_type, '') + '|' + convert(Varchar(10), image_id)
					FROM    dbo.fn_cor_scan_lookup (@i_web_userid, 'workorder', h.workorder_id, h.company_id, h.profit_ctr_id, 1, 'manifest, cod')
					order by coalesce(document_name, manifest), page_number, image_id
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			)  images
		, case when z.invoice_date is not null 
			or isnull(h.submitted_flag,'F') = 'T'
				then 'T' else 'F' end as invoiced_flag

		,_row = row_number() over (order by 

				case when isnull(@i_sort, '') in ('', 'Service Date') then z.start_date end desc,
				case when isnull(@i_sort, '') = 'Customer Name' then c.cust_name end asc,
				case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
				case when isnull(@i_sort, '') = 'Transaction Number' then z.workorder_id end desc,
				z.start_date asc
			) 
		from @bar z 
			join WorkorderHeader h (nolock) on h.workorder_id = z.workorder_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
			join Customer c (nolock) on z.customer_id = c.customer_id
			left join Generator g (nolock) on z.generator_id = g.generator_id
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
			left join @billing billing on z.workorder_id = billing.receipt_id and z.company_id = billing.company_id and z.profit_ctr_id = billing.profit_ctr_id			
		where 1=1
		and ( 
			isnull(@i_manifest, '') = ''
			or 
			(exists (select top 1 1 from workordermanifest m (nolock) 
				join @tmanifest t on m.manifest like '%' + t.manifest + '%'
				where m.workorder_id = z.workorder_id and m.company_id = z.company_id and m.profit_ctr_id = z.profit_ctr_id)
			)
		)
	) y
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	order by _row

else -- Excel Output:

	select * from (

		select
			'Work Order' as transaction_type
			, h.workorder_id transaction_id
			, 	status = case 
					when ((wos.date_request_initiated is not null and wos.date_est_arrive is null
						-- and not completed
						and not isnull(h.end_date, getdate()+1) <= @today and b.billing_uid is null)
						OR (wos.date_request_initiated is null and wos.date_est_arrive is null and h.end_date is null
						and wos.date_est_arrive is null and z.start_date is null))
							then 'Requested'
					when (wos.date_est_arrive is not null
						-- and not completed
						and not isnull(h.end_date, getdate()+1) <= @today and b.billing_uid is null)
							then 'Scheduled'
					when (isnull(wos.date_act_arrive, getdate()+1) <= @today and b.billing_uid is null)
							then 'Completed'
					when (b.billing_uid is not null)
							then 'Invoiced'
					else
						'Unknown'
					end
			, h.company_id
			, h.profit_ctr_id
			, upc.name as USE_facility_name

			, c.customer_id
			, c.cust_name
			, g.generator_name
			, g.epa_id
			, g.generator_city
			, g.generator_state
			, g.generator_zip_code
			, g.site_code
			, g.site_type
			, g.generator_region_code
			, g.generator_division
			, h.project_name
			, h.start_date transaction_date_start
			, h.end_date transaction_date_end
			, wos.date_request_initiated requested_date
			, wos.date_est_arrive scheduled_date
			, z.service_date
			, wst.schedule_type
			, wtype.account_desc  as Service_Type
			, h.purchase_order
			, h.release_code
			, z.prices as show_prices
			, case when z.prices <= 0 then null else billing.total_amount end as transaction_total
			, (
							select substring(
							(
								select ', Manifest ' + wom.manifest
								FROM workordermanifest wom (nolock)
								where
									wom.workorder_id = h.workorder_id
									and wom.company_id = h.company_id
									and wom.profit_ctr_id = h.profit_ctr_id
									and wom.manifest not like 'manifest%'
									and wom.manifest_flag = 'T'
									and wom.manifest is not null
								for xml path, TYPE).value('.[1]','nvarchar(max)'
							),2,20000)
				) as manifest
			, (
							select substring(
							(
								select ', ' + wod.tsdf_approval_code
								from workorderdetail wod
								where wod.workorder_id =h.workorder_id 
								and wod.company_id = h.company_id
								and wod.profit_ctr_id = h.profit_ctr_id
								and wod.resource_type = 'D'
								and wod.bill_rate > -2
								and wod.tsdf_approval_code is not null
								for xml path, TYPE).value('.[1]','nvarchar(max)'
							),2,20000)
				) as approval_code			
				--, case when z.invoice_date is null then 'F' else 'T' end as invoiced_flag
				, case when z.invoice_date is not null 
					or isnull(h.submitted_flag,'F') = 'T'
						then 'T' else 'F' end as invoiced_flag
				,_row = row_number() over (order by 

				case when isnull(@i_sort, '') in ('', 'Service Date') then z.start_date end desc,
				case when isnull(@i_sort, '') = 'Customer Name' then c.cust_name end asc,
				case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
				case when isnull(@i_sort, '') = 'Transaction Number' then z.workorder_id end desc,
				z.start_date asc
			) 



		from @bar z 
			join WorkorderHeader h (nolock) on h.workorder_id = z.workorder_id and h.company_id = z.company_id and h.profit_ctr_id = z.profit_ctr_id and h.workorder_status NOT IN ('V','X','T')
			join Customer c (nolock) on z.customer_id = c.customer_id
			left join Generator g (nolock) on z.generator_id = g.generator_id
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
			left join WorkorderType wtype (nolock) on h.workorder_type = wtype.account_type and h.company_id = wtype.company_id and wtype.status = 'A'
			left join WorkorderScheduleType wst (nolock) on h.workorderscheduletype_uid = wst.workorderscheduletype_uid
			left join workorderstop wos  (nolock)
				on wos.workorder_id = z.workorder_id 
				and wos.company_id = z.company_id 
				and wos.profit_ctr_id = z.profit_ctr_id
				and wos.stop_sequence_id = 1
			left join billing b
				on b.receipt_id = z.workorder_id
				and b.company_id = z.company_id
				and b.profit_ctr_id = z.profit_ctr_id
				and b.trans_source = 'W'
				and b.status_code = 'I'
				and b.line_id = (select min(line_id) from billing bmin WHERE 
					bmin.receipt_id = b.receipt_id
					and bmin.company_id = b.company_id
					and bmin.profit_ctr_id = b.profit_ctr_id
					and bmin.trans_source = b.trans_source
					and bmin.status_code = b.status_code
					)
			left join @billing billing on z.workorder_id = billing.receipt_id and z.company_id = billing.company_id and z.profit_ctr_id = billing.profit_ctr_id			
		where 1=1
		and ( 
			isnull(@i_manifest, '') = ''
			or 
			(exists (select top 1 1 from workordermanifest m (nolock) 
				join @tmanifest t on m.manifest like '%' + t.manifest + '%'
				where m.workorder_id = z.workorder_id and m.company_id = z.company_id and m.profit_ctr_id = z.profit_ctr_id)
			)
		)
	) y
	order by _row



return 0
GO
-- Permissions

GRANT EXECUTE ON  [dbo].[sp_cor_service_list] TO [COR_USER]
GO
GRANT EXECUTE ON  [dbo].[sp_cor_service_list] TO [EQAI]
GO
GRANT EXECUTE ON  [dbo].[sp_cor_service_list] TO [EQWEB]
GO
