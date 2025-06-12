-- drop procedure if exists sp_cor_receipt_lines_lpx
go

create procedure sp_cor_receipt_lines_lpx (
	@web_userid			varchar(100)
	, @receipt_id		int
	, @company_id		int
    , @profit_ctr_id	int
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @lpx_rollup_override int = 3
) as

/* *******************************************************************
sp_cor_receipt_lines_lpx

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

select b.*, c.web_userid
from ContactCORReceiptBucket b
join contact c on b.contact_id = c.contact_id
join Receipt r
	on b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id
	and r.receipt_status = 'A'
	and r.fingerpr_status = 'A'
	and r.submitted_flag = 'T'
WHERE r.trans_type = 'D'
and exists (select 1 from receipt r2
	where r2.receipt_id = r.receipt_id
	and r2.company_id = r.company_id
	and r2.profit_ctr_id = r.profit_ctr_id
	and r2.receipt_status ='A'
	and r2.trans_type = 'S'
	and r2.fingerpr_status = 'A'
	and r2.submitted_flag = 'T'
)

exec sp_cor_receipt_lines_lpx
	@web_userid = 'mgregg@wtsonline.com'
	, @receipt_id = 338858
	, @company_id = 42
	, @profit_ctr_id = 0
	, @lpx_rollup_override =1
	


******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_receipt_id		int = @receipt_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id
    , @ilpx_rollup_override int = isnull(@lpx_rollup_override,3)

declare @foo table (
		receipt_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		receipt_date datetime NULL,
		prices		bit NOT NULL
	)
	
insert @foo
SELECT  
		x.receipt_id,
		x.company_id,
		x.profit_ctr_id,
		x.receipt_date,
		x.prices
FROM    ContactCORReceiptBucket x (nolock) 
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.receipt_id = @i_receipt_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id

	select
		r.trans_type
		, r.service_desc
		, r.manifest
		, upc.name tsdf_name
		, upc.address_1
		, upc.address_2
		, upc.address_3
		, upc.epa_id
		, r.receipt_date
		, r.manifest_page_num
		, r.manifest_line
		, r.approval_code
		, p.approval_desc
		, r.manifest_quantity
		, r.manifest_unit
		, r.container_count					
		, r.manifest_container_code			

		, b.quantity
		, bu.bill_unit_desc
		, case when z.prices = 1 then b.total_extended_amt else null end as line_total_price
		, case when z.prices = 1 then b.currency_code else null end as currency_code
		, r.purchase_order
		, r.release as release_code
    , 'Receipt' as record_source
    , r.receipt_id
    , r.company_id
    , r.profit_ctr_id
    , case r.trans_type
		when 'D' then 'Disposal'
		when 'S' then 'Service'
		when 'W' then 'Wash'
		end as resource_type
    , convert(float, row_number() over (order by r.line_id, manifest_page_num, manifest_line, b.line_id, b.price_id)) as _row
    
  into #lpxdata
	from @foo z 
	join receipt r (nolock) on z.receipt_id = r.receipt_id and z.company_id = r.company_id and z.profit_ctr_id = r.profit_ctr_id and r.trans_mode = 'I'
	join billing b (nolock) on r.receipt_id = b.receipt_id and r.line_id = b.line_id and r.company_id = b.company_id and r.profit_ctr_id = b.profit_ctr_id and b.trans_source = 'R' and b.status_code = 'I'
	join billunit bu (nolock) on b.bill_unit_code = bu.bill_unit_code
	left join profile p (nolock) on r.profile_id = p.profile_id
	left join USE_ProfitCenter upc on z.company_id = upc.company_id and z.profit_ctr_id = upc.profit_ctr_id

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

  update #lpxdata set line_total_price = null
  
	select
		trans_type
		, service_desc
		, manifest
		, tsdf_name
		, address_1
		, address_2
		, address_3
		, epa_id
		, receipt_date
		, manifest_page_num
		, manifest_line
		, approval_code
		, approval_desc
		, manifest_quantity
		, manifest_unit
		, container_count					
		, manifest_container_code			
		, quantity
		, bill_unit_desc
		, line_total_price
		, currency_code
		, purchase_order
		, release_code
    , _row
    , null as resource_type
    , null as subtotal
  from #lpxdata
  order by _row
end

-- end region


-- region LPX output option 2
if isnull(@labpack_pricing_rollup, '3') = '2' 
begin
-- 2: Summary by category only.  You list the lines but there's a subtotal line injected after each section with the total, individ lines don't get pricing.

  update #lpxdata set line_total_price = null

  	select
		trans_type
		, service_desc
		, manifest
		, tsdf_name
		, address_1
		, address_2
		, address_3
		, epa_id
		, receipt_date
		, manifest_page_num
		, manifest_line
		, approval_code
		, approval_desc
		, manifest_quantity
		, manifest_unit
		, container_count					
		, manifest_container_code			
		, quantity
		, bill_unit_desc
		, line_total_price
		, currency_code
		, purchase_order
		, release_code
    , _row
    , null as resource_type
    , null as subtotal
  from #lpxdata
    union all
	select
		null as trans_type
		, null as service_desc
		, null as manifest
		, null as tsdf_name
		, null as address_1
		, null as address_2
		, null as address_3
		, null as epa_id
		, null as receipt_date
		, null as manifest_page_num
		, null as manifest_line
		, null as approval_code
		, null as approval_desc
		, null as manifest_quantity
		, null as manifest_unit
		, null as container_count					
		, null as manifest_container_code			
		, null as quantity
		, null as bill_unit_desc
		, null as line_total_price
		, currency_code
		, null as purchase_order
		, null as release_code
    , _row
    , resource_type
    , subtotal
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
		trans_type
		, service_desc
		, manifest
		, tsdf_name
		, address_1
		, address_2
		, address_3
		, epa_id
		, receipt_date
		, manifest_page_num
		, manifest_line
		, approval_code
		, approval_desc
		, manifest_quantity
		, manifest_unit
		, container_count					
		, manifest_container_code			
		, quantity
		, bill_unit_desc
		, line_total_price
		, currency_code
		, purchase_order
		, release_code
    , _row
    , null as resource_type
    , null as subtotal
  from #lpxdata
    union all
	select
		null as trans_type
		, null as service_desc
		, null as manifest
		, null as tsdf_name
		, null as address_1
		, null as address_2
		, null as address_3
		, null as epa_id
		, null as receipt_date
		, null as manifest_page_num
		, null as manifest_line
		, null as approval_code
		, null as approval_desc
		, null as manifest_quantity
		, null as manifest_unit
		, null as container_count					
		, null as manifest_container_code			
		, null as quantity
		, null as bill_unit_desc
		, null as line_total_price
		, currency_code
		, null as purchase_order
		, null as release_code
    , _row
    , resource_type
    , subtotal
   from #lpxdatasubtotal
 order by _row

end

-- end region
	    
return 0
go

grant execute on sp_cor_receipt_lines_lpx to eqai, eqweb
go

