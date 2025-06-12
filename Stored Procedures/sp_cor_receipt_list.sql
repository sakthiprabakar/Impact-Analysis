-- drop proc sp_cor_receipt_list
go

create procedure sp_cor_receipt_list (
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(10) = null
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
	-- , @transaction_type	varchar(20) = 'receipt' -- always receipt in this proc
	, @facility			varchar(max) = null

	, @project_code       varchar(max) = null           -- Project Code Ignored for Receipts

	, @release_code       varchar(50) = null    -- Release code (NOT a list)
	, @purchase_order     varchar(20) = null    -- Purchase Order
	, @search			varchar(max) = null -- Common search
	, @adv_search		varchar(max) = null
	, @status			varchar(max) = null	--Ignored for Receipts
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */


) as

/* *******************************************************************
sp_cor_receipt_list

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


exec sp_cor_receipt_list
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2018'
	, @date_end = '1/1/2020'
    , @generator_name	= null
    , @generator_state = 'USA-CA'
    , @epa_id			= '' -- can take CSV list
    , @store_number		= '' -- can take CSV list
	, @generator_district = null -- can take CSV list
    , @generator_region	= null -- can take CSV list
    , @page = 1
	
	SELECT  *  FROM    billing WHERE customer_id = 10673 and trans_type = 'S'
	
	
******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_date_start			datetime = convert(date, @date_start)
	, @i_date_end			datetime = convert(date, @date_end)
    , @i_customer_search	varchar(max) = @customer_search
    , @i_manifest			varchar(max) = @manifest
    -- , @i_generator_search	varchar(max) = @generator_search
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
	, @i_generator_division	varchar(max) = isnull(@generator_division, '')
	, @i_generator_state	varchar(max) = isnull(@generator_state, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_approval_code		varchar(max) = isnull( @approval_code, '')
    , @i_transaction_id		varchar(max) =  isnull(@transaction_id, '')
    -- , @i_transaction_type	varchar(20) = @transaction_type 
    , @i_facility			varchar(max) =  isnull(@facility, '')
	, @i_release_code		varchar(20) = isnull(@release_code,'')
	, @i_purchase_order		varchar(20) = isnull(@purchase_order,'')
	, @i_search				varchar(max) = dbo.fn_CleanPunctuation(isnull(@search, ''))
    , @i_adv_search			varchar(max) =  isnull(@adv_search, '')
	, @i_sort				varchar(20) =  isnull(@sort, '')
	, @i_page				bigint = @page
	, @i_perpage			bigint = @perpage 
	, @i_customer_id_list varchar(max)= isnull(@customer_id_list, '')
    , @i_generator_id_list varchar(max)=isnull(@generator_id_list, '')
	, @i_contact_id			int
    
if isnull(@i_sort, '') not in ('Service Date', 'Customer Name', 'Generator Name', 'Manifest/BOL', 'Transaction Type', 'Transaction Number') set @i_sort = ''
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

declare @tcustomer table (
	customer_id	int
)
if isnull(@i_customer_search, '') <> ''
insert @tcustomer
select customer_id from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 

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
insert @tmanifest
select row 
from dbo.fn_splitxsvtext(',', 1, @i_manifest) 
where row is not null

declare @ttransid table (
	transaction_id int
)
insert @ttransid
select convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @i_transaction_id) 
where row is not null

declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	int
)
if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null


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

declare @foo table (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		customer_id int,
		generator_id int,
		prices		bit NOT NULL
	)
	
insert @foo
SELECT  
		x.receipt_id,
		x.company_id,
		x.profit_ctr_id,
		isnull(x.pickup_date, x.receipt_date),
		x.customer_id,
		x.generator_id,
		x.prices
FROM    ContactCORReceiptBucket x  (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE x.contact_id = @i_contact_id 
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
			-- and isnull(d.generator_state, '') in (select generator_state from @tstate)
			and
			exists(
				select 1 from @statecodes t 
				where isnull(nullif(d.generator_country, ''), 'USA') = t.country
				and isnull(d.generator_state, '') = t.state_name
			)
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



declare @bar table (
	receipt_id	int
	, company_id int
	, profit_ctr_id int
	, min_line_id int
	, customer_id int
	, generator_id int
	, receipt_date datetime
	, prices int
)

-- Limit results to 1 line per receipt, for members of @foo
; with cte as (
select z.receipt_id, z.company_id, z.profit_ctr_id, z.line_id as min_line_id, x.customer_id, x.generator_id, x.receipt_date, x.prices
	,         ROW_NUMBER() OVER (PARTITION BY z.receipt_id, z.company_id, z.profit_ctr_id ORDER BY z.line_id) AS rn
from @foo x
join receipt z (nolock) on x.receipt_id = z.receipt_id and x.company_id = z.company_id and x.profit_ctr_id = z.profit_ctr_id
WHERE 1=1
-- and exists (select billing_uid from billing b (nolock) where b.receipt_id = z.receipt_id and b.line_id = z.line_id and b.price_id = b.price_id and b.trans_source = 'R' and b.profit_ctr_id = z.profit_ctr_id and b.company_id = z.company_id and b.status_code = 'I')
	and (
		isnull(@i_approval_code, '') = ''
		or 
		(z.approval_code like '%' + replace(@i_approval_code, ' ', '%') + '%')
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
	and (
		isnull(@i_release_code, '') = ''
		or 
		(z.release like '%' + replace(@i_release_code, ' ', '%') + '%')
	)
	and (
		isnull(@i_purchase_order, '') = ''
		or 
		(z.purchase_order like '%' + replace(@i_purchase_order, ' ', '%') + '%')
	)
)
insert @bar (
	receipt_id	
	, company_id 
	, profit_ctr_id 
	, min_line_id 
	, customer_id 
	, generator_id 
	, receipt_date
	, prices 
)
select
	receipt_id	
	, company_id 
	, profit_ctr_id 
	, min_line_id 
	, customer_id 
	, generator_id 
	, receipt_date
	, prices 
from cte
where rn = 1



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
	on x.receipt_id = b.receipt_id
	and b.line_id = b.line_id
	and b.price_id = b.price_id
	and 'R' = b.trans_source
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
			'Receipt' as transaction_type
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
			, r.company_id
			, r.profit_ctr_id
			, upc.name company_name
			, upc.name as profitcenter_name
			, r.receipt_id transaction_id
			, case r.manifest_flag when 'M' then 'Manifest ' else 'BOL ' end + r.manifest as manifest
			/* manifest_flag = Manfest / BOL */
			, r.receipt_date transaction_date_start
			, r.receipt_date transaction_date_end
			, z.receipt_date service_date
			, r.time_in
			, r.time_out
			, r.approval_code
			, r.purchase_order
			, r.release release_code
			, z.prices as show_prices
			, case when z.prices <= 0 then null else billing.total_amount end as transaction_total
			, ( select substring(
				(
				
				select ', ' + coalesce(s.document_name, s.manifest, r.manifest, 'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number), '1') + '|'+coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
				FROM    dbo.fn_cor_scan_lookup (@i_web_userid, 'receipt', r.receipt_id, r.company_id, r.profit_ctr_id, 1, 'manifest, COD') s
				order by coalesce(s.document_name, s.manifest, r.manifest), s.page_number, s.image_id

				/*
				select ', ' + coalesce(s.document_name, s.manifest, r.manifest, 'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number), '1') + '|'+coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
				FROM plt_image..scan s
				WHERE s.receipt_id = r.receipt_id
				and s.company_id = r.company_id
				and s.profit_ctr_id = r.profit_ctr_id
				and s.document_source = 'receipt'
				and s.status = 'A'
				and s.view_on_web = 'T'
				and s.type_id in (select type_id from plt_image..scandocumenttype where document_type in( 'manifest', 'COD')) 
				order by coalesce(s.document_name, s.manifest, r.manifest), s.page_number, s.image_id
				*/
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			)  images
			,_row = row_number() over (order by 
		
				case when isnull(@i_sort, '') in ('', 'Service Date') then r.receipt_date end desc,
				case when isnull(@i_sort, '') = 'Customer Name' then c.cust_name end asc,
				case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
				case when isnull(@i_sort, '') = 'Manifest/BOL' then r.manifest end asc,
				case when isnull(@i_sort, '') = 'Transaction Number' then r.receipt_id end desc,
				r.receipt_date asc
			) 
		from @bar z 
			join Receipt r (nolock) on r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
			join Customer c (nolock) on z.customer_id = c.customer_id
			join Generator g (nolock) on z.generator_id = g.generator_id
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
			left join profile p (nolock) on r.profile_id = p.profile_id
			left join @billing billing on z.receipt_id = billing.receipt_id and z.company_id = billing.company_id and z.profit_ctr_id = billing.profit_ctr_id

		where 1=1
		and (
			(select count(*) from @tcustomer) = 0
			or 
			(z.customer_id in (select customer_id from @tcustomer))
		)
		/*
		and (
			(select count(*) from @tgenerator) = 0
			or 
			(z.generator_id in (select generator_id from @tgenerator))
		)
		*/
		and ( 
			isnull(@i_manifest, '') = ''
			or 
			(r.manifest in (select manifest from @tmanifest))
		)
		and (
			@i_search = ''
			or 
			(
				@i_search <> ''
				and
				isnull(c.cust_name, '') + ' ' +
				isnull(convert(varchar(20),c.customer_id), '') + ' ' +
				isnull(g.generator_name, '') + ' ' +
				isnull(g.epa_id, '') + ' ' +
				isnull(g.generator_city, '') + ' ' +
				isnull(g.site_type, '') + ' ' +
				isnull(g.generator_region_code, '') + ' ' +
				isnull(g.generator_division, '') + ' ' +
				isnull(g.site_code, '') + ' ' +
				isnull(convert(varchar(20),g.generator_id), '') + ' ' +
				isnull(upc.name, '') + ' ' +
				isnull(convert(varchar(20), r.receipt_id), '') + ' ' +
				isnull(r.manifest, '') + ' ' +
				isnull(r.approval_code, '') + ' ' +
				isnull(r.purchase_order, '') + ' ' +
				isnull(r.release, '') + ' ' +
				isnull(p.approval_desc, '') + ' '
				like '%' + @i_search + '%'
			)
		)
	
	) y
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	order by _row

else
	-- Excel output:

	select * from (

	/*
		On the Excel Output: Display the 
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
		transaction end date 
			(note: for a receipt, both dates would be the same. 
			for a work order, the dates would be the Work order Header start date and Work Order Header end date)

		NOTE ABOVE: That's less info than the actual report returns.  So Stick with the actual report for now - not robbing users of data.

	*/

		select
			'Receipt' as transaction_type
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
			, r.company_id
			, r.profit_ctr_id
			, upc.name company_name
			, upc.name as profitcenter_name
			, r.receipt_id transaction_id
			, r.manifest
			/* manifest_flag = Manfest / BOL */
			, r.receipt_date transaction_date_start
			, r.receipt_date transaction_date_end
			, z.receipt_date service_date
			, r.time_in
			, r.time_out
			, r.approval_code
			, r.purchase_order
			, r.release release_code
			, z.prices as show_prices
			, case when z.prices <= 0 then null else billing.total_amount end as transaction_total
			, ( select substring(
				(select ', ' + coalesce(s.document_name, s.manifest, r.manifest, 'Manifest')+ '|'+coalesce(convert(varchar(3),s.page_number), '1') + '|'+coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
				FROM plt_image..scan s
				WHERE s.receipt_id = r.receipt_id
				and s.company_id = r.company_id
				and s.profit_ctr_id = r.profit_ctr_id
				and s.document_source = 'receipt'
				and s.status = 'A'
				and s.view_on_web = 'T'
				and s.type_id in (select type_id from plt_image..scandocumenttype where document_type in( 'manifest', 'COD')) 
				order by coalesce(s.document_name, s.manifest, r.manifest), s.page_number, s.image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			)  images
			,_row = row_number() over (order by 
		
				case when isnull(@i_sort, '') in ('', 'Service Date') then r.receipt_date end desc,
				case when isnull(@i_sort, '') = 'Customer Name' then c.cust_name end asc,
				case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
				case when isnull(@i_sort, '') = 'Manifest/BOL' then r.manifest end asc,
				case when isnull(@i_sort, '') = 'Transaction Number' then r.receipt_id end desc,
				r.receipt_date asc
			) 
		from @bar z 
			join Receipt r (nolock) on r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and r.line_id = z.min_line_id and r.receipt_status not in ('V', 'R')
			join Customer c (nolock) on z.customer_id = c.customer_id
			join Generator g (nolock) on z.generator_id = g.generator_id
			join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id
			left join profile p (nolock) on r.profile_id = p.profile_id
			left join @billing billing on z.receipt_id = billing.receipt_id and z.company_id = billing.company_id and z.profit_ctr_id = billing.profit_ctr_id

		where 1=1
		and (
			(select count(*) from @tcustomer) = 0
			or 
			(z.customer_id in (select customer_id from @tcustomer))
		)
		/*
		and (
			(select count(*) from @tgenerator) = 0
			or 
			(z.generator_id in (select generator_id from @tgenerator))
		)
		*/
		and ( 
			isnull(@i_manifest, '') = ''
			or 
			(r.manifest in (select manifest from @tmanifest))
		)
		and (
			@i_search = ''
			or 
			(
				@i_search <> ''
				and
				isnull(c.cust_name, '') + ' ' +
				isnull(convert(varchar(20),c.customer_id), '') + ' ' +
				isnull(g.generator_name, '') + ' ' +
				isnull(g.epa_id, '') + ' ' +
				isnull(g.generator_city, '') + ' ' +
				isnull(g.site_type, '') + ' ' +
				isnull(g.generator_region_code, '') + ' ' +
				isnull(g.generator_division, '') + ' ' +
				isnull(g.site_code, '') + ' ' +
				isnull(convert(varchar(20),g.generator_id), '') + ' ' +
				isnull(upc.name, '') + ' ' +
				isnull(convert(varchar(20), r.receipt_id), '') + ' ' +
				isnull(r.manifest, '') + ' ' +
				isnull(r.approval_code, '') + ' ' +
				isnull(r.purchase_order, '') + ' ' +
				isnull(r.release, '') + ' ' +
				isnull(p.approval_desc, '') + ' '
				like '%' + @i_search + '%'
			)
		)
	) y
	order by _row
    
return 0
go

grant execute on sp_cor_receipt_list to eqai, eqweb, COR_USER
go

