
CREATE PROCEDURE sp_wm_invoice_summary (
	@invoice_code	varchar(16)
)
AS
/* *************************************
sp_wm_invoice_summary
  WM-formatted export of invoice summary data.
  Accepts input: 
      invoice_code to view

10/27/2010 - JPB - Created
01/31/2010 - JPB - Rewrote the min/max service date field selects as more efficient sub-selects
	- instead of an inefficient join, because for 40283596 it was verrrry slow. (20+mins)
06/01/2012 - JPB - Added breakdown queries to this sp to fulfill WM Invoice Design request.
06/20/2012 - JPB - Modified per Brie (GEM-21696) to include the LMIN quantities so the unit prices * qty matches the total.
06/13/2013 - JPB - Updated per GEM-25201 for Fuel Station Services
10/14/2013 - JPB - Fixed math - Now using billing.detail for all amounts.
					Also only counting b.quantities in the disposal section for the 'Disposal' billing type, 
					to avoid join multiplication problems.
12/16/2013 - JPB -
					Walmart corporate has requested additional separation of information on their monthly 
					invoice, effective for the November invoice (generated in December)

					Follow same format of separating Walmart & Sams Club services with the Fuel Station Services section.

					Billing projects #6105 & #6474 - Sams 
					Billing projects #6473 & #6476 - Walmart 
					
					Output order:
						Wal-mart
						Sams
						Wal-mart Fuel Station Services
						Sams Fuel Station Services

03/31/2016 - JPB - Updates per GEM:36872
					Changed how cost item and cost item type are populated
					Add the Approval # to the Type column on the Invoice Summary for the Materials - Disposal section.
					Sum all Demurrage Resources together and list as total hours & total amount
					Sum all Shipping Fees & Freight charges together and list as 1 Lot with the total Unit Price & Total Amount the same rate
					Sum all Laboratory Analysis
					Sum all NY county taxes together as 1 line item list as 1 Lot with the total Unit Price & total amount the same value
					Sum Resources: Drum Labels, Hazardous and Labels_________ together and list as 1 line item
					Sum all transportation charges together. List total Billable Qty as the # summed, Unit is Hours
					Reorganize Line numbering, if lines have the same value, use alpha/numeric to put in sequential order
					
					
sp_wm_invoice_summary '185408'

select top 200 invoice_code, status, total_amt_due from invoiceheader where customer_id = 10673 order by invoice_date desc



select top 1 wba.* 
, 'EQ_' +
	CASE wba.wm_account_id 
		WHEN 4490 THEN 'Routine'
		WHEN 6015 THEN 'Off-Schedule'
		ELSE 'Other'
	END +
	' ' +
	CASE wba.wm_division_id
		WHEN 1 THEN 'Walmart'
		WHEN 18 THEN 'Sams Club'
		ELSE 'Other'
	END + 
	'_Invoice#' +
	b.invoice_code +
	'_' +
	right('00' + convert(varchar(2), DATEPART(mm, getdate())), 2) + 
	right('00' + convert(varchar(2), DATEPART(dd, getdate())), 2) + 
	right(convert(varchar(4), DATEPART(yyyy, getdate())), 2)
as filename
FROM Billing b
INNER JOIN WalmartBillingAccount wba
	ON b.billing_project_id = wba.billing_project_id
WHERE b.invoice_code = '40283596'

************************************* */

DECLARE @invoice_id int, @revision_id int

SELECT @invoice_id = invoice_id, @revision_id = revision_id
FROM invoiceheader WHERE invoice_code = @invoice_code AND status = 'I'

if object_id('tempdb..#SalesTax') is not null drop table #SalesTax
if object_id('tempdb..#BillingInfo') is not null drop table #BillingInfo
if object_id('tempdb..#WMBilling') is not null drop table #WMBilling

create table #WMBilling (
	billingdetail_uid		bigint
)
create index idx_wmbilling on #WMBilling(billingdetail_uid)

--
-- Collecting billingdetail_uids to include
--

	insert #WMBilling
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	left outer join TSDFApproval ta (nolock)
		on ta.tsdf_approval_id = b.tsdf_approval_id
		and ta.company_id = b.company_id
		and ta.profit_ctr_id = b.profit_ctr_id
		and b.trans_source = 'W'
	left outer join Profile p (nolock) on p.profile_id = b.profile_id
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and ((b.trans_source = 'W' and b.workorder_resource_type = 'D')
		or (b.trans_source = 'R' and b.trans_type = 'D')
		or (b.trans_source = 'R' and b.trans_type = 'S' and b.waste_code = 'LMIN')
		or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'DISPOSAL-RETAIL'))
		or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'LMIN'))
	)
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.trans_source = 'W'
	and (b.workorder_resource_type = 'S' 
	or b.workorder_resource_item = 'MISC'
	)
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.workorder_resource_item = 'LABTEST'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'FEEGASSR'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'STOPFEE'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'DEMURRAGE'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock) on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.trans_source = 'W'
	and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock) On b.billing_uid = bd.billing_uid and bd.billing_type = 'SalesTax'
	inner join generator g (nolock) on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock) on g.site_type = gst.generator_site_type
	where b.invoice_id = @invoice_id

--
-- End of collecting billingdetail_uids to include
--


select 
	1 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Materials - Disposal' as cost_item
	,  CASE b.trans_source -- This part just cleans up the "native" approval description
		WHEN 'W' THEN 
			ltrim(rtrim(ta.tsdf_approval_code))
		WHEN 'R' THEN 
			ltrim(rtrim(b.approval_code))
		ELSE b.service_desc_1
		END as cost_item_type
	, CASE b.trans_source -- This part just cleans up the "native" approval description
		WHEN 'W' THEN 
			ltrim(rtrim(
				REPLACE(
					REPLACE(
						REPLACE(ta.waste_desc, ta.tsdf_approval_code + '-', '')
					, ta.tsdf_approval_code + ' -', '')
				, ta.tsdf_approval_code, '')
			))
		WHEN 'R' THEN 
			ltrim(rtrim(
				REPLACE(
					REPLACE(
						REPLACE(p.approval_desc, b.approval_code + '-', '')
					, b.approval_code + ' -', '')
				, b.approval_code, '')
			))
		ELSE b.service_desc_1
	END as item_description
	, SUM(case when bd.billing_type = 'disposal' then b.quantity else 0 end) as qty
	, bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
into #BillingInfo
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
left outer join TSDFApproval ta (nolock)
	on ta.tsdf_approval_id = b.tsdf_approval_id
	and ta.company_id = b.company_id
	and ta.profit_ctr_id = b.profit_ctr_id
	and b.trans_source = 'W'
left outer join Profile p (nolock)
	on p.profile_id = b.profile_id
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
where b.invoice_id = @invoice_id
and ((b.trans_source = 'W' and b.workorder_resource_type = 'D')
	or (b.trans_source = 'R' and b.trans_type = 'D')
	or (b.trans_source = 'R' and b.trans_type = 'S' and b.waste_code = 'LMIN')
	or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'DISPOSAL-RETAIL'))
	or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'LMIN'))
)
group by
	1 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END
	,  CASE b.trans_source -- This part just cleans up the "native" approval description
		WHEN 'W' THEN 
			ltrim(rtrim(ta.tsdf_approval_code))
		WHEN 'R' THEN 
			ltrim(rtrim(b.approval_code))
		ELSE b.service_desc_1
		END
	, CASE b.trans_source -- This part just cleans up the "native" approval description
		WHEN 'W' THEN 
			ltrim(rtrim(
				REPLACE(
					REPLACE(
						REPLACE(ta.waste_desc, ta.tsdf_approval_code + '-', '')
					, ta.tsdf_approval_code + ' -', '')
				, ta.tsdf_approval_code, '')
			))
		WHEN 'R' THEN 
			ltrim(rtrim(
				REPLACE(
					REPLACE(
						REPLACE(p.approval_desc, b.approval_code + '-', '')
					, b.approval_code + ' -', '')
				, b.approval_code, '')
			))
		ELSE b.service_desc_1
	  END
	, bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END	
union all

select -- Only 'Drum Labels, Hazardous' or 'Labels ______________' which get grouped together
	2 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Materials - Supplies' as cost_item
	, '' as cost_item_type
	, 'Drum Labels, Hazardous / Labels ______________' as item_description
	, SUM(b.quantity) as qty
	, 'Each' -- Always Export "Each" for Supplies (6/7/12) bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and (b.workorder_resource_type = 'S' 
or b.workorder_resource_item = 'MISC'
)
and b.service_desc_1 in ('Drum Labels, Hazardous', 'Labels ______________')
group by
	2 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	b.service_desc_1
	-- , bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END
	  
union all
select -- NOT 'Drum Labels, Hazardous' or 'Labels __________________'
	2 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Materials - Supplies' as cost_item
	, '' as cost_item_type
	, b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	, 'Each' -- Always Export "Each" for Supplies (6/7/12) bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and (b.workorder_resource_type = 'S' 
or b.workorder_resource_item = 'MISC'
)
and b.service_desc_1 NOT in ('Drum Labels, Hazardous', 'Labels ______________')

group by
	2 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	b.service_desc_1
	-- , bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END
	  
union all

select 
	3 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Materials - Laboratory Analysis' as cost_item
	, '' as cost_item_type
	, b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	, bu.bill_unit_desc
	, null as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.workorder_resource_item = 'LABTEST'
group by
	3 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	 b.service_desc_1
	, bu.bill_unit_desc
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END

union all

-- Workorder Fuel Surcharge
select 
	4 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Materials - Fuel Surcharge' as cost_item
	, '' as cost_item_type
	, b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	, bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'FEEGASSR'
group by
	4 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	 b.service_desc_1
	, bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END

union all

-- Workorder Stop Fee
select 
	5 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Labor - Stop Fee' as cost_item
	, '' as cost_item_type
	, b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	, bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'STOPFEE'
group by
	5 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	 b.service_desc_1
	, bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END

union all

-- Workorder Demurrage
select 
	6 as orderby
	, 'Labor - Demurrage' as cost_item
	, '' as cost_item_type
	, 'Demurrage' as item_description
	, SUM(b.quantity) as qty
	, bu.bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'DEMURRAGE'
group by
	bu.bill_unit_desc
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END
union all

-- Workorder Freight
select 
	7 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Freight - Parcel Services' as cost_item
	, '' as cost_item_type
	, 'Freight Charges' as item_description --b.service_desc_1 as item_description
	, 1 as qty
	, bu.bill_unit_desc
	, SUM(bd.extended_amt) as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.trans_source = 'W'
and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
group by
	7 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END
	, bu.bill_unit_desc
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END

union all
-- Transportation (copied again without transportation below)
select 
	9 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Other' as cost_item
	, '' as cost_item_type
	, b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	-- , (b.quantity) as qty
	, 'Hours' as bill_unit_desc
	, SUM(bd.extended_amt) as unit_price
	, SUM(bd.extended_amt) as amt
	-- , (b.waste_extended_amt + b.sr_extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
where 
	b.invoice_id = @invoice_id
	and bd.billingdetail_uid not in (select billingdetail_uid from #WMBilling)
	and b.service_desc_1 = 'Transportation'
group by
	9 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END
	, b.service_desc_1
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END

union all

select 
	9 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END as orderby
	, 'Other' as cost_item
	, '' as cost_item_type
	, convert(varchar(20), b.company_id) + '-' +
		convert(varchar(20), b.profit_ctr_id) + ' ' +
		b.trans_source + ': ' + 
		convert(varchar(20), b.receipt_id) + ' - ' + 
		b.service_desc_1 as item_description
	, SUM(b.quantity) as qty
	-- , (b.quantity) as qty
	, '' as bill_unit_desc
	, b.price as unit_price
	, SUM(bd.extended_amt) as amt
	-- , (b.waste_extended_amt + b.sr_extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
where 
	b.invoice_id = @invoice_id
	and bd.billingdetail_uid not in (select billingdetail_uid from #WMBilling)
	and b.service_desc_1 <> 'Transportation'
group by
	9 + CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 0
	  END,
	 convert(varchar(20), b.company_id) + '-' +
		convert(varchar(20), b.profit_ctr_id) + ' ' + 
		b.trans_source + ': ' + 
		convert(varchar(20), b.receipt_id) + ' - ' + 
		b.service_desc_1
	, b.price
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, b.trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END
	  
-- Sales Tax was wonky.  The select, including the site type was fast.
-- Same select with grouping by site type, awful.  So we cheat:

-- Sales Tax
select 
	'Sales Tax' as cost_item
	, null as cost_item_type
	-- , st.tax_description as item_description
	, st.sales_tax_state + ' Sales Tax' as item_description
	, 1 as qty
	, null as bill_unit_desc
	, SUM(bd.extended_amt) as unit_price
	, SUM(bd.extended_amt) as amt
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END as site_type
	, null trans_source
	, null company_id
	, null profit_ctr_id
	, null receipt_id
	, null waste_code
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END as project_grouping
into #SalesTax		
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type = 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join salestax st 
	on bd.sales_tax_id = st.sales_tax_id
where b.invoice_id = @invoice_id
group by
	st.sales_tax_state + ' Sales Tax'
	, case gst.generator_site_type_abbr
		WHEN 'WM' THEN 'Wal-Mart'
		WHEN 'SUP' THEN 'Wal-Mart'
		WHEN 'WNM' THEN 'Wal-Mart'
		WHEN 'XPS' THEN 'Wal-Mart'
		WHEN 'SAMS' THEN 'Sams'
		ELSE gst.generator_site_type_abbr
		END
	, CASE b.billing_project_id
		WHEN /* Sams Fuel Station Services: */ 6105 THEN 100000
		WHEN /* Sams Fuel Station Services: */ 6474 THEN 100000		
		WHEN /* Walmart Fuel Station Svcs : */ 6473 THEN 10000
		WHEN /* Walmart Fuel Station Svcs : */ 6476 THEN 10000
		ELSE 1
	  END


insert #BillingInfo
select
	1000 + b.project_grouping as orderby
	, 'Sales Tax'
	, '' as cost_item_type
	, item_description
	, 1 qty
	, '' as bill_unit_desc
	, isnull(SUM(s.amt), 0) bill_unit_price
	, isnull(SUM(s.amt), 0)
	, b.site_type
	, '' trans_source
	, 0 company_id
	, 0 profit_ctr_id
	, 0 receipt_id
	, '' waste_code
	, b.project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
FROM (
	select distinct 
		site_type
		, project_grouping
		from #BillingInfo
	) b 
LEFT OUTER JOIN #SalesTax s ON s.site_type = b.site_type
and s.project_grouping = b.project_grouping
group by
	1000 + b.project_grouping,
	item_description
	, b.site_type
	, b.project_grouping
having isnull(SUM(s.amt), 0) > 0

-- Now eliminate duplicate lines per receipt_id for the same approval:
select 
	orderby
	, cost_item
	, cost_item_type
	, item_description
	-- 6/20/2012- JPB: Count LMIN qty's too now.
	, SUM(qty) as qty
	-- Old:
		-- , SUM(case when waste_code = 'LMIN' then 0 else qty end) as qty
		-- -- LMIN rows don't count toward quantity, but do count toward amount.
	, bill_unit_desc
	, unit_price
	, SUM(amt) as amt
	, case project_grouping
		WHEN 1 then site_type 
		WHEN 10000 THEN 'Wal-Mart Fuel Station Services'
		WHEN 100000 THEN 'Sams Fuel Station Services'
	  end as site_type
	, project_grouping
into #UnifiedBillingInfo
from #BillingInfo
group by	
	orderby
	, cost_item
	, cost_item_type
	, item_description
	, bill_unit_desc
	, unit_price
	, case project_grouping
		WHEN 1 then site_type 
		WHEN 10000 THEN 'Wal-Mart Fuel Station Services'
		WHEN 100000 THEN 'Sams Fuel Station Services'
	  end
	, project_grouping
order by project_grouping, case project_grouping
		WHEN 1 then site_type 
		WHEN 10000 THEN 'Wal-Mart Fuel Station Services'
		WHEN 100000 THEN 'Sams Fuel Station Services'
	  end desc, orderby, item_description

select 
	orderby
	, row_number() over (partition by site_type, orderby order by site_type, orderby, amt desc, item_description) as type_rank
	, cost_item
	, cost_item_type
	, item_description
	, qty
	, bill_unit_desc
	, unit_price
	, amt
	, site_type
	, project_grouping
from #UnifiedBillingInfo
-- WHERE (site_type like '%' + @store_type + '%' or @store_type is null)
order by project_grouping, site_type desc, orderby, amt desc, item_description

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary] TO [EQAI]
    AS [dbo];

