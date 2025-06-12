-- region sp_cor_service_disposal
--
drop proc if exists sp_cor_service_disposal
go
create procedure sp_cor_service_disposal (
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
    , @manifest			varchar(15)
    , @customer_id_list varchar(max)='' 
    , @generator_id_list varchar(max)=''  
    , @combine_transactions bit = 0
    , @lpx_rollup_override char(1) = 'X'
) as

/* *******************************************************************
sp_cor_service_disposal

sp_helptext sp_cor_service_disposal
 10/16/2019  DevOps:11608 - AM - Added customer_id and generator_id temp tables and added receipt join.
 01/05/2021	 DO:16826 - Hide pricing info when it shouldn't appear.
 06/10/2021  DO:15510 - Show receipt details if linked transaction data exists
 06/10/2021  DO:18914 - Show work order info even if not billed.

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


exec sp_cor_service_disposal_list
	@web_userid = 'dcrozier@riteaid.com'
	, @workorder_id = 21374000
	, @company_id = 14
	, @profit_ctr_id = 0

exec sp_cor_service_disposal
	@web_userid = 'dcrozier@riteaid.com'
	, @workorder_id = 21374000
	, @company_id = 14
	, @profit_ctr_id = 0
	, @manifest = '015178284 JJK'

exec sp_cor_service_disposal
	@web_userid = 'nyswyn100'
	, @workorder_id = 12519200
	, @company_id = 14
	, @profit_ctr_id = 0
	, @manifest = '006168867JJK'
	, @combine_transactions = 1
  , @lpx_rollup_override = 3
	
SELECT  * FROM    workorderdetail WHERE workorder_id = 	12519200 and company_id = 14

******************************************************************* */
/*
-- debug:

DECLARE
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
    , @manifest			varchar(15)
    , @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @combine_transactions bit = 0

select	@web_userid = 'sarah'
	, @workorder_id = 2286501
	, @company_id = 14
	, @profit_ctr_id = 15
	, @manifest = '0271272'
  
*/


-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_workorder_id	int = @workorder_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id
    , @i_manifest		varchar(15) = @manifest
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_combine_transactions bit = isnull(@combine_transactions, 0)
    , @contact_id int
    , @ilpx_rollup_override char(1) = isnull(@lpx_rollup_override,'X')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid

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

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date datetime NULL,
		prices		int NOT NULL,
		invoice_date	datetime NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		max(convert(int, x.prices)) prices
		, x.invoice_date
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
WHERE
	x.contact_id = @contact_id
	and x.workorder_id = @i_workorder_id
	and x.company_id = @i_company_id
	and x.profit_ctr_id = @i_profit_ctr_id
GROUP BY 
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.invoice_date

--declare @i_combine_transactions bit = 1, @contact_id int = 11289
--declare @foo table (workorder_id int, company_id int, profit_ctr_id int, start_date datetime, prices int, invoice_date datetime)
--insert @foo values (12519200, 14, 0, '2021-05-09 21:52', 1, '2021-05-12 21:59')
		
declare @link table (
	workorder_id	int
	, w_company_id	int
	, w_profit_ctr_id int
	, w_sequence_id int
	, receipt_id	int
	, r_line_id		int
	, r_company_id	int
	, r_profit_ctr_id	int
	, r_prices		bit
	, invoice_date datetime
)


insert @link (workorder_id, w_company_id, w_profit_ctr_id, w_sequence_id, receipt_id, r_line_id, r_company_id, r_profit_ctr_id, r_prices, invoice_date)
select
w.workorder_id, w.company_id, w.profit_ctr_id, d.sequence_id
, r.receipt_id, r.line_id, r.company_id, r.profit_ctr_id
, rb.prices
, rb.invoice_date
from @foo w
join workorderdetail d (nolock)
	on w.workorder_id = d.workorder_id
	and w.company_id = d.company_id
	and w.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
join billinglinklookup bll (nolock)
	on w.workorder_id = bll.source_id
	and w.company_id = bll.source_company_id
	and w.profit_ctr_id= bll.source_profit_ctr_id
join ContactCORReceiptBucket rb (nolock)
	on bll.receipt_id = rb.receipt_id
	and bll.company_id = rb.company_id
	and bll.profit_ctr_id = rb.profit_ctr_id
	and rb.contact_id = @contact_id
	and rb.invoice_date is not null
join receipt r (nolock)
	on bll.receipt_id = r.receipt_id
	and bll.company_id = r.company_id
	and bll.profit_ctr_id = r.profit_ctr_id
	and r.manifest = d.manifest
	and r.manifest_line = d.manifest_line
where @i_combine_transactions = 1

declare @billed int = 0
select @billed = 1 from billing b
	where b.receipt_id = @i_workorder_id
	and b.company_id = @i_company_id
	and b.profit_ctr_id = @i_profit_ctr_id


select *, convert(float, row_number() over (order by  resource_type, manifest, manifest_page_num, manifest_line, billing_sequence_id, sequence_id)) as _row
into #lpxdata
from (
	-- work order sourced information
	select
		'Work Order' as record_source
		, d.workorder_id as receipt_id
		, d.company_id
		, d.profit_ctr_id
		, d.billing_sequence_id
		, d.sequence_id
		, 'Disposal' as resource_type
		, case isnull(m.manifest_flag, '') when 'T' then 'Manifest' else 'BOL' end as manifest_bol
		, m.manifest
--		, -- transporter info??
		, t.tsdf_name
		, t.tsdf_addr1 tsdf_address_1
		, t.tsdf_addr2 tsdf_address_2
		, t.tsdf_addr3 tsdf_address_3
		, t.tsdf_city
		, t.tsdf_state
		, t.tsdf_zip_code
		, t.tsdf_country_code
		, t.tsdf_epa_id
		, d.manifest_page_num
		, d.manifest_line
		, d.TSDF_approval_code
		, coalesce(ta.waste_desc, p.approval_desc) waste_desc
		, coalesce(wodu.quantity, wodu_not_manifested.quantity, d.quantity) quantity
		, coalesce(wodu.bill_unit_code, wodu_not_manifested.bill_unit_code, d.manifest_wt_vol_unit) manifest_wt_vol_unit
		, d.container_count
		, d.container_code
		, case when z.prices = 1 then case when @billed = 1 then b.price else d.price end else null end as line_item_price
		, case when z.prices = 1 then case when @billed = 1 then b.total_extended_amt else d.extended_price end else null end as line_total_price
		, case when z.prices = 1 then case when @billed = 1 then b.currency_code else d.currency_code end else null end as currency_code
		, case when b.billing_uid is not null
				then 'T' else 'F' end as invoiced_flag
		, w.purchase_order
		, w.release_code
		, null as linked_receipt
	from @foo z 
	join workorderdetail d (nolock) on z.workorder_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id 
		and d.resource_type = 'D' 
		and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
	join workorderheader w (nolock) on w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id 
	left join workorderdetailunit wodu (nolock) 
		on z.workorder_id = wodu.workorder_id 
		and z.company_id = wodu.company_id 
		and z.profit_ctr_id = wodu.profit_ctr_id 
		and d.resource_type = 'D' 
		and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
		and wodu.sequence_id = d.sequence_id 
		and wodu.manifest_flag = 'T'
	left join workorderdetailunit wodu_not_manifested (nolock) 
		on z.workorder_id = wodu_not_manifested.workorder_id 
		and z.company_id = wodu_not_manifested.company_id 
		and z.profit_ctr_id = wodu_not_manifested.profit_ctr_id 
		and d.resource_type = 'D' 
		and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
		and wodu_not_manifested.sequence_id = d.sequence_id
		and isnull(wodu.manifest_flag, 'X') = 'X'
		-- The wodu_not_manifestd version is identical to wodu except doens't require the manifested flag, because
		-- apparently sometimes they don't check it.  But we should prefer the data they did check it, if they did.
		-- Sigh.
	join workordermanifest m (nolock) on z.workorder_id = m.workorder_id and z.company_id = m.company_id and z.profit_ctr_id = m.profit_ctr_id and d.resource_type = 'D' and d.manifest = m.manifest
	left join tsdfapproval ta (nolock) on d.tsdf_approval_id = ta.tsdf_approval_id and d.company_id = ta.company_id and d.profit_ctr_id = ta.profit_ctr_id
	left join profile p (nolock) on d.profile_id = p.profile_id
	join tsdf t on d.tsdf_code = t.tsdf_code
	left join billing b (nolock) 
		on @billed=1
		and d.workorder_id = b.receipt_id 
		and b.workorder_resource_type = d.resource_type 
		and d.sequence_id = b.workorder_sequence_id 
		and d.company_id = b.company_id 
		and d.profit_ctr_id = b.profit_ctr_id 
		and b.trans_source = 'W' 
--		and b.status_code = 'I'
	LEFT JOIN @link link
		on z.workorder_id = link.workorder_id
		and z.company_id = link.w_company_id
		and z.profit_ctr_id = link.w_profit_ctr_id
		and d.sequence_id = link.w_sequence_id
	WHERE 
	1=1
	and link.receipt_id is null -- null if we're not combine transactions or there's no match
	and isnull(@i_manifest, d.manifest) = d.manifest
	and  (
			@i_customer_id_list = ''
			or
			 (
				@i_customer_id_list <> ''
				and
				w.customer_id in (select customer_id from @customer_list)
			 )
		   )
		 and
		 (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
			 w.Generator_id in (select generator_id from @generator_list)
			)
		  )
		  -- force: only billed wo disposal lines appear
		  -- DO-18810: nah.
		-- and d.sequence_id = case when @billed=1 then b.workorder_sequence_id else d.sequence_id end
		-- and d.resource_type = case when @billed=1 then b.workorder_resource_type else d.resource_type end
UNION ALL
-- receipt-sourced info...
	select
		'Receipt' as record_source
		, link.receipt_id as receipt_id
		, link.r_company_id
		, link.r_profit_ctr_id
		, r.line_id as billing_sequence_id
		, r.line_id as sequence_id
		, 'Disposal' as resource_type
		, case isnull(r.manifest_flag, '') when 'M' then 'Manifest' else 'BOL' end as manifest_bol
		, r.manifest
--		, -- transporter info??
		, upc.name tsdf_name
		, upc.address_1 tsdf_address_1
		, upc.address_2 tsdf_address_2
		, upc.address_3 tsdf_address_3
		, upc.city tsdf_city
		, upc.state tsdf_state
		, upc.zip_code tsdf_zip_code
		, upc.country_code tsdf_country_code
		, upc.epa_id tsdf_epa_id
		, r.manifest_page_num
		, r.manifest_line
		, r.approval_code
		, p.approval_desc waste_desc
		, r.manifest_quantity quantity
		, r.manifest_unit manifest_wt_vol_unit
		, r.container_count
		, r.manifest_container_code container_code
		, case when link.r_prices = 1 then case when @billed = 1 then b.price else null end else null end as line_item_price
		, case when link.r_prices = 1 then case when @billed = 1 then b.total_extended_amt else null end else null end as line_total_price
		, case when link.r_prices = 1 then case when @billed = 1 then b.currency_code else null end else null end as currency_code
		, case when link.invoice_date is not null 
				then 'T' else 'F' end as invoiced_flag
		, r.purchase_order
		, r.release release_code
		, link.receipt_id as linked_receipt
	from @foo z 
	join @link link on z.workorder_id = link.workorder_id and z.company_id = link.w_company_id and z.profit_ctr_id = link.w_profit_ctr_id 
	join receipt r (nolock) on link.receipt_id = r.receipt_id and link.r_company_id = r.company_id and link.r_profit_ctr_id = r.profit_ctr_id and link.r_line_id = r.line_id
	join USE_ProfitCenter upc on r.company_id = upc.company_id and r.profit_ctr_id = upc.profit_ctr_id
	left join profile p (nolock) on r.profile_id = p.profile_id
	left join billing b (nolock) 
		on link.invoice_date is not null
		and r.receipt_id = b.receipt_id 
		and r.line_id = b.line_id
		and r.company_id = b.company_id 
		and r.profit_ctr_id = b.profit_ctr_id 
		and b.trans_source = 'R' 
		and b.status_code = 'I'
	WHERE 
	isnull(@i_manifest, r.manifest) = r.manifest
	and  (
			@i_customer_id_list = ''
			or
			 (
				@i_customer_id_list <> ''
				and
				r.customer_id in (select customer_id from @customer_list)
			 )
		   )
		 and
		 (
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
			 r.Generator_id in (select generator_id from @generator_list)
			)
		  )
		
) src
--	order by resource_type, manifest, manifest_page_num, manifest_line, billing_sequence_id, sequence_id

-- Start LPX output handling

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
  -- and h.profit_ctr_id = qh.profit_ctr_id
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
  -- and h.profit_ctr_id = qh.profit_ctr_id
) s

if @ilpx_rollup_override <> 'X' set @labpack_pricing_rollup = @ilpx_rollup_override

-- select @labpack_quote_flag labpack_quote_flag, @labpack_pricing_rollup labpack_pricing_rollup
-- end region

-- region Calculate LPX Subtotals
drop table if exists #lpxdatasubtotal
select record_source, receipt_id, company_id, profit_ctr_id, resource_type + ' Subtotal' as resource_type, currency_code
, sum(line_total_price) as subtotal
, max(_row) + 0.5 as _row
into #lpxdatasubtotal
from #lpxdata
group by record_source, receipt_id, company_id, profit_ctr_id, resource_type, currency_code

-- end region


-- region LPX Output options

-- region LPX output option 1
if isnull(@labpack_pricing_rollup, 'L') = 'T' 
begin
-- 1: Summary pricing only.  You list the details, but they have no prices.

  update #lpxdata set line_item_price = null, line_total_price = null
  
  select
      record_source	
			,receipt_id	
			,company_id	
			,profit_ctr_id	
			,billing_sequence_id	
			,sequence_id	
			,resource_type	
			,manifest_bol	
			,manifest	
			,tsdf_name	
			,tsdf_address_1	
			,tsdf_address_2	
			,tsdf_address_3	
			,tsdf_city	
			,tsdf_state	
			,tsdf_zip_code	
			,tsdf_country_code	
			,tsdf_epa_id	
			,manifest_page_num	
			,manifest_line									
			,TSDF_approval_code	
			,waste_desc	
			,quantity	
			,manifest_wt_vol_unit	
			,container_count	
			,container_code	
			,line_item_price	
			,line_total_price	
			,currency_code	
			,invoiced_flag	
			,purchase_order	
			,release_code	
			,linked_receipt	
      , null as subtotal
      , _row
    from #lpxdata
    order by _row


end

-- end region


-- region LPX output option 2
if isnull(@labpack_pricing_rollup, 'L') = 'S' 
begin
-- 2: Summary by category only.  You list the lines but there's a subtotal line injected after each section with the total, individ lines don't get pricing.

  update #lpxdata set line_item_price = null, line_total_price = null
  
  select
      record_source	
			,receipt_id	
			,company_id	
			,profit_ctr_id	
			,billing_sequence_id	
			,sequence_id	
			,resource_type	
			,manifest_bol	
			,manifest	
			,tsdf_name	
			,tsdf_address_1	
			,tsdf_address_2	
			,tsdf_address_3	
			,tsdf_city	
			,tsdf_state	
			,tsdf_zip_code	
			,tsdf_country_code	
			,tsdf_epa_id	
			,manifest_page_num	
			,manifest_line									
			,TSDF_approval_code	
			,waste_desc	
			,quantity	
			,manifest_wt_vol_unit	
			,container_count	
			,container_code	
			,line_item_price	
			,line_total_price	
			,currency_code	
			,invoiced_flag	
			,purchase_order	
			,release_code	
			,linked_receipt	
      , null as subtotal
      , _row
    from #lpxdata
    union all
    select
      record_source	
			,receipt_id	
			,company_id	
			,profit_ctr_id	
			,null as billing_sequence_id	
			,null as sequence_id	
			,resource_type	
			,null as manifest_bol	
			,null as manifest	
			,null as tsdf_name	
			,null as tsdf_address_1	
			,null as tsdf_address_2	
			,null as tsdf_address_3	
			,null as tsdf_city	
			,null as tsdf_state	
			,null as tsdf_zip_code	
			,null as tsdf_country_code	
			,null as tsdf_epa_id	
			,null as manifest_page_num	
			,null as manifest_line									
			,null as TSDF_approval_code	
			,null as waste_desc	
			,null as quantity	
			,null as manifest_wt_vol_unit	
			,null as container_count	
			,null as container_code	
			,null as line_item_price	
			,null as line_total_price	
			,currency_code	
			,null as invoiced_flag	
			,null as purchase_order	
			,null as release_code	
			,null as linked_receipt	
      , subtotal
      , _row
    from #lpxdatasubtotal
    order by _row


end

-- end region


-- region LPX output option 3 (default)

if isnull(@labpack_pricing_rollup, 'L') = 'L' 
begin
-- 3: Line by line: Everything gets prices, same as default/past.
--    AND add a subtotal line after each section with totals.

  select
      record_source	
			,receipt_id	
			,company_id	
			,profit_ctr_id	
			,billing_sequence_id	
			,sequence_id	
			,resource_type	
			,manifest_bol	
			,manifest	
			,tsdf_name	
			,tsdf_address_1	
			,tsdf_address_2	
			,tsdf_address_3	
			,tsdf_city	
			,tsdf_state	
			,tsdf_zip_code	
			,tsdf_country_code	
			,tsdf_epa_id	
			,manifest_page_num	
			,manifest_line									
			,TSDF_approval_code	
			,waste_desc	
			,quantity	
			,manifest_wt_vol_unit	
			,container_count	
			,container_code	
			,line_item_price	
			,line_total_price	
			,currency_code	
			,invoiced_flag	
			,purchase_order	
			,release_code	
			,linked_receipt	
      , null as subtotal
      , _row
    from #lpxdata
    union all
    select
      record_source	
			,receipt_id	
			,company_id	
			,profit_ctr_id	
			,null as billing_sequence_id	
			,null as sequence_id	
			,resource_type	
			,null as manifest_bol	
			,null as manifest	
			,null as tsdf_name	
			,null as tsdf_address_1	
			,null as tsdf_address_2	
			,null as tsdf_address_3	
			,null as tsdf_city	
			,null as tsdf_state	
			,null as tsdf_zip_code	
			,null as tsdf_country_code	
			,null as tsdf_epa_id	
			,null as manifest_page_num	
			,null as manifest_line									
			,null as TSDF_approval_code	
			,null as waste_desc	
			,null as quantity	
			,null as manifest_wt_vol_unit	
			,null as container_count	
			,null as container_code	
			,null as line_item_price	
			,null as line_total_price	
			,currency_code	
			,null as invoiced_flag	
			,null as purchase_order	
			,null as release_code	
			,null as linked_receipt	
      , subtotal
      , _row
    from #lpxdatasubtotal
    order by _row


end

-- end region

  
return 0

go

grant execute on sp_cor_service_disposal to eqai, eqweb, COR_USER
go

-- end region
