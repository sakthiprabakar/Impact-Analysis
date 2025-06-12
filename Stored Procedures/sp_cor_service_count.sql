--drop procedure sp_cor_service_count 
go

create procedure sp_cor_service_count (
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
sp_cor_service_count

History:

	10/16/2019	MPM	DevOps 11607: Added logic to filter the result set
					using optional input parameters @customer_id_list and
					@generator_id_list.
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


exec sp_cor_service_count
	@web_userid = 'jamie.huens@wal-mart.com'
	, @date_start = '1/1/2009'
	, @date_end = '1/1/2010'

exec sp_cor_service_list
	@web_userid = 'jamie.huens@wal-mart.com'
	, @date_start = '1/1/2009'
	, @date_end = '1/1/2010'
	
	SELECT  *  FROM    billing WHERE customer_id = 10673 and trans_type = 'S'

exec sp_cor_service_count 
	@web_userid	= 'amber'
	, @date_start = '1/1/2018'
	, @date_end	= '12/31/2019'
    , @customer_search	= null
    , @manifest			= null
    , @generator_search	= null
    , @approval_code	= null
    , @transaction_id	= null
    -- , @transaction_type	= 'receipt' -- always receipt in this proc
    , @facility			= null
    , @adv_search		= null
	, @sort				= ''
	, @page				= 1
	, @perpage			= 20 
    , @customer_id_list = '6976'  
    , @generator_id_list ='141598, 141604, 141615'  
	
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
    
if isnull(@i_sort, '') not in ('Service Date', 'Customer Name', 'Generator Name', 'Manifest/BOL', 'Transaction Type', 'Transaction Number') set @i_sort = ''
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999
if @i_date_specifier = '' set @i_date_specifier = 'service'

DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   

 declare @out table (
	transaction_type	varchar(40)
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
	, company_id		int
	, profit_ctr_id		int
	, USE_facility_name	varchar(50)
	, profitcenter_name	varchar(50)
	, transaction_id	bigint
	, manifest			varchar(max)
	, transaction_date_start	datetime
	, transaction_date_end	datetime
	, service_date		datetime
	, time_in			datetime
	, time_out			datetime
	, approval_code		varchar(max)
	, purchase_order	varchar(20)
	, release_code		varchar(20)
	, show_prices		int
	, transaction_total money
	, images			varchar(max)
	, invoiced_flag		char(1)
	, _row				int
)

insert @out
exec sp_cor_service_list 
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
	, @approval_code	= @i_approval_code
	, @transaction_id	= @i_transaction_id
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


select count(*) from @out



return 0
go

grant execute on sp_cor_service_count to eqai, eqweb, COR_USER
go
