-- 
drop proc if exists sp_cor_service_ELSO_lpx
go
create procedure sp_cor_service_ELSO_lpx (
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
    , @resource_type	char(1) 
      -- 'E'quipment, 'L'abor, 'S'upplies or 'O'ther.  Null returns all (non-disposal) types.
	, @customer_id_list varchar(max)=''  
    , @generator_id_list varchar(max)='' 
    , @lpx_rollup_override int = 3
) as

/* *******************************************************************
sp_cor_service_ELSO_lpx

Description
	Provides a listing of all receipt disposal lines

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


exec sp_cor_service_ELSO_lpx
	@web_userid = 'dcrozier@riteaid.com'
	, @workorder_id = 21374000
	, @company_id = 14
	, @profit_ctr_id = 0
	, @resource_type = null -- 'O'

exec sp_cor_service_ELSO_lpx
	@web_userid = 'sarah'
	, @workorder_id = 2286501  
	, @company_id = 14
	, @profit_ctr_id = 15
	, @resource_type = null -- 'O'
  , @lpx_rollup_override = 1
  

SELECT  distinct TOP 100 b.*  FROM    contactcorworkorderheaderbucket b
join workorderdetail d on b.workorder_id = d.workorder_id and b.company_id = d.company_id and b.profit_ctr_id = d.profit_ctr_id
and d.resource_type in ('S', 'L', 'E')
and b.invoice_date is  null
WHERE b.service_date < getdate() ORDER BY service_date desc

SELECT  *  FROM    workorderdetail WHERE workorder_id = 4331100 and company_id = 25 and profit_ctr_id = 0
SELECT  *  FROM    billing WHERE receipt_id = 4331100 and company_id = 25 and profit_ctr_id = 0

******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_workorder_id	int = @workorder_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id
    , @i_resource_type	char(1) = @resource_type
    , @ilpx_rollup_override int = isnull(@lpx_rollup_override,3)

if @i_resource_type = '' set @i_resource_type = null

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date datetime NULL,
		service_date datetime NULL,
		prices		bit NOT NULL,
		invoice_date	datetime NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.service_date,
		x.prices,
		x.invoice_date
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.workorder_id = @i_workorder_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id

declare @billed int = 0
select @billed = 1 from billing b
	where b.receipt_id = @i_workorder_id
	and b.company_id = @i_company_id
	and b.profit_ctr_id = @i_profit_ctr_id

  drop table if exists #lpxdata
  
	select
		d.billing_sequence_id
		, case d.resource_type
			when 'O' then 'Other'
			when 'S' then 'Supplies'
			when 'L' then 'Labor'
			when 'E' then 'Equipment'
			else d.resource_type
		end as resource_type
		, d.description
		, d.description_2
--		, d.quantity
		, isnull(case d.resource_type
			when 'D' then convert(varchar(20),d.quantity)
			else convert(varchar(20),d.quantity_used)
		end, 'TBD') as quantity
		, bu.bill_unit_desc
		, d.bill_rate
		, case when z.prices = 1 then d.price else null end as line_item_price
		, case when z.prices = 1 then d.extended_price else null end as line_total_price
		, case when d.resource_type = 'o' then d.manifest else null end as manifest_reference_number
		, case when d.resource_type = 'o' then d.manifest_line else null end as manifest_reference_line_number
		, case when z.prices = 1 then d.currency_code else null end as currency_code
		--, case when z.invoice_date is null then 'F' else 'T' end as invoiced_flag
		, case when z.invoice_date is not null 
			or isnull(h.submitted_flag,'F') = 'T'
				then 'T' else 'F' end as invoiced_flag
		, z.service_date
		, h.purchase_order
		, h.release_code
    , z.workorder_id as receipt_id
    , z.company_id
    , z.profit_ctr_id
    , 'Work Order' as record_source
    , row_number() over (order by d.resource_type, d.billing_sequence_id, d.sequence_id) as _row
  into #lpxdata
	from @foo z 
	join workorderheader h (nolock) on z.workorder_id = h.workorder_id and z.company_id = h.company_id and z.profit_ctr_id = h.profit_ctr_id
	join workorderdetail d (nolock) on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and d.resource_type = isnull(@i_resource_type, d.resource_type) and d.resource_type <> 'D' 
		and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
	left join billing b (nolock) 
		on d.workorder_id = b.receipt_id 
		and b.workorder_resource_type = d.resource_type 
		and d.sequence_id = b.workorder_sequence_id 
		and d.company_id = b.company_id 
		and d.profit_ctr_id = b.profit_ctr_id 
		and b.trans_source = 'W' 
		-- and b.status_code = 'I'
	join billunit bu (nolock) on d.bill_unit_code = bu.bill_unit_code
	where
		-- point of this is to enforce that only invoiced lines show up if this
		-- wo is in billing already.
		d.sequence_id = case when @billed=1 then b.workorder_sequence_id else d.sequence_id end
		and d.resource_type = case when @billed=1 then b.workorder_resource_type else d.resource_type end
	order by d.resource_type, d.billing_sequence_id, d.sequence_id


  -- region Get LPX Flag & Rollup Setting
  declare @labpack_quote_flag char(1)
  , @labpack_pricing_rollup char(1)

  select @labpack_quote_flag = labpack_quote_flag
    , @labpack_pricing_rollup = labpack_pricing_rollup
  from (
  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
  from workorderheader h
  join #lpxdata d
    on h.workorder_ID = d.receipt_id
    and h.company_id = d.company_id
    and h.profit_ctr_ID = d.profit_ctr_id
    and d.record_source in ('Work Order', 'workorder')
  left join workorderquoteheader  qh 
    on h.quote_id = qh.quote_id
    and h.company_id = qh.company_id
    and h.profit_ctr_id = qh.profit_ctr_id
  union
  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
  from BillingLinkLookup bll
  join #lpxdata d
    on bll.receipt_id = d.receipt_id
    and bll.company_id = d.company_id
    and bll.profit_ctr_ID = d.profit_ctr_id
    and d.record_source in ('receipt')
  join workorderheader h
    on bll.source_id = h.workorder_ID
    and bll.source_company_id = h.company_id
    and bll.source_profit_ctr_id = h.profit_ctr_ID
  left join workorderquoteheader  qh 
    on h.quote_id = qh.quote_id
    and h.company_id = qh.company_id
    and h.profit_ctr_id = qh.profit_ctr_id
  ) s

  if isnull(@ilpx_rollup_override, '3') <> isnull(@labpack_pricing_rollup, '3') set @labpack_pricing_rollup = convert(char(1),@ilpx_rollup_override)
      
-- region LPX Output options

   -- region Calculate LPX Subtotals
  drop table if exists #lpxdatasubtotal
  select record_source, receipt_id, company_id, profit_ctr_id, resource_type + ' Subtotal' as resource_type, currency_code
  , sum(line_total_price) as subtotal
  , max(_row) + 0.5 as _row
  into #lpxdatasubtotal
  from #lpxdata
  group by record_source, receipt_id, company_id, profit_ctr_id, resource_type, currency_code

  -- end region

-- region LPX output option 1
if isnull(@labpack_pricing_rollup, '3') = '1' 
begin
-- 1: Summary pricing only.  You list the details, but they have no prices.

  update #lpxdata set line_item_price = null, line_total_price = null
      
	select
		billing_sequence_id
    , resource_type
		, description
		, description_2
		, quantity
		, bill_unit_desc
		, bill_rate
		, line_item_price
		, line_total_price
		, manifest_reference_number
		, manifest_reference_line_number
		, currency_code
		, invoiced_flag
		, service_date
		, purchase_order
		, release_code
    , null as subtotal
    , _row
  from #lpxdata
  order by _row

end

-- end region


-- region LPX output option 2
if isnull(@labpack_pricing_rollup, '3') = '2' 
begin
-- 2: Summary by category only.  You list the lines but there's a subtotal line injected after each section with the total, individ lines don't get pricing.

  update #lpxdata set line_item_price = null, line_total_price = null

	select
		billing_sequence_id
    , resource_type
		, description
		, description_2
		, quantity
		, bill_unit_desc
		, bill_rate
		, line_item_price
		, line_total_price
		, manifest_reference_number
		, manifest_reference_line_number
		, currency_code
		, invoiced_flag
		, service_date
		, purchase_order
		, release_code
    , null as subtotal
    , _row
  from #lpxdata
    union all
	select
		null as billing_sequence_id
    , resource_type
		, null as description
		, null as description_2
		, null as quantity
		, null as bill_unit_desc
		, null as bill_rate
		, null as line_item_price
		, null as line_total_price
		, null as manifest_reference_number
		, null as manifest_reference_line_number
		, currency_code
		, null as invoiced_flag
		, null as service_date
		, null as purchase_order
		, null as release_code
    , subtotal
    , _row
   from #lpxdatasubtotal
 order by _row

end

-- end region


-- region LPX output option 3 (default)

if isnull(@labpack_pricing_rollup, '3') = '3' 
begin
-- 3: Line by line: Everything gets prices, same as default/past.
--    AND add a subtotal line after each section with totals.

	select
		billing_sequence_id
    , resource_type
		, description
		, description_2
		, quantity
		, bill_unit_desc
		, bill_rate
		, line_item_price
		, line_total_price
		, manifest_reference_number
		, manifest_reference_line_number
		, currency_code
		, invoiced_flag
		, service_date
		, purchase_order
		, release_code
    , null as subtotal
    , _row
  from #lpxdata
    union all
	select
		null as billing_sequence_id
    , resource_type
		, null as description
		, null as description_2
		, null as quantity
		, null as bill_unit_desc
		, null as bill_rate
		, null as line_item_price
		, null as line_total_price
		, null as manifest_reference_number
		, null as manifest_reference_line_number
		, currency_code
		, null as invoiced_flag
		, null as service_date
		, null as purchase_order
		, null as release_code
    , subtotal
    , _row
   from #lpxdatasubtotal
 order by _row

end

-- end region

   
return 0
go

grant execute on sp_cor_service_ELSO_lpx to eqai, eqweb, COR_USER
go
