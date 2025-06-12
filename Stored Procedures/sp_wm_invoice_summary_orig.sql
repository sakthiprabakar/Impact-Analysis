
CREATE PROCEDURE [sp_wm_invoice_summary_orig] (
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

sp_wm_invoice_summary '40488370'


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

insert #WMBilling
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
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
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
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
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and (b.workorder_resource_type = 'S' 
or b.workorder_resource_item = 'MISC'
)
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.workorder_resource_item = 'LABTEST'
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'FEEGASSR'
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'STOPFEE'
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'DEMURRAGE'
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type <> 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
inner join BillUnit bu  (nolock)
	on b.bill_unit_code = bu.bill_unit_code
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
union all
select
	bd.billingdetail_uid
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
	and bd.billing_type = 'SalesTax'
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
where b.invoice_id = @invoice_id
and b.billing_project_id <> 6105
union all
-- Now the 6105 specific set:
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
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
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
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
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and (b.workorder_resource_type = 'S' 
	or b.workorder_resource_item = 'MISC'
	)
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.workorder_resource_item = 'LABTEST'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'FEEGASSR'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'STOPFEE'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'DEMURRAGE'
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type <> 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	inner join BillUnit bu  (nolock)
		on b.bill_unit_code = bu.bill_unit_code
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
	union all
	select
		bd.billingdetail_uid
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
		and bd.billing_type = 'SalesTax'
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	where b.invoice_id = @invoice_id
	and b.billing_project_id = 6105


select 
	1 as orderby
	, 'Materials' as cost_item
	, 'Disposal' as cost_item_type
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
	/*
	+ ' - ' 
	+ CASE b.trans_source -- This part appends the approval code to the end of the description so they're all in the same format.
		WHEN 'W' THEN 
			ta.tsdf_approval_code
		WHEN 'R' THEN 
			b.approval_code
	END
	*/ as item_description
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
-- and b.invoice_date > '1/1/2010'
and ((b.trans_source = 'W' and b.workorder_resource_type = 'D')
	or (b.trans_source = 'R' and b.trans_type = 'D')
	or (b.trans_source = 'R' and b.trans_type = 'S' and b.waste_code = 'LMIN')
	or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'DISPOSAL-RETAIL'))
	or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'LMIN'))
)
group by
CASE b.trans_source -- This part just cleans up the "native" approval description
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
	/*
	+ ' - ' 
	+ CASE b.trans_source -- This part appends the approval code to the end of the description so they're all in the same format.
		WHEN 'W' THEN 
			ta.tsdf_approval_code
		WHEN 'R' THEN 
			b.approval_code
	END
	*/
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
	
union all

select 
	2 as orderby
	, 'Materials' as cost_item
	, 'Supplies' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and (b.workorder_resource_type = 'S' 
or b.workorder_resource_item = 'MISC'
)
group by b.service_desc_1
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

union all

select 
	3 as orderby
	, 'Materials' as cost_item
	, 'Laboratory Analysis' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.workorder_resource_item = 'LABTEST'
group by b.service_desc_1
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

union all

-- Workorder Fuel Surcharge
select 
	4 as orderby
	, 'Materials' as cost_item
	, 'Fuel Surcharge' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'FEEGASSR'
group by b.service_desc_1
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

union all

-- Workorder Stop Fee
select 
	5 as orderby
	, 'Labor' as cost_item
	, 'Stop Fee' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'STOPFEE'
group by b.service_desc_1
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
union all

-- Workorder Demurrage
select 
	6 as orderby
	, 'Labor' as cost_item
	, 'Demurrage' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_type = 'O'
and b.workorder_resource_item = 'DEMURRAGE'
group by b.service_desc_1
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
union all

-- Workorder Freight
select 
	7 as orderby
	, 'Freight' as cost_item
	, 'Parcel Services' as cost_item_type
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105
and b.trans_source = 'W'
and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
group by b.service_desc_1
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


union all

select 
	9 as orderby
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
from Billing b (nolock)
inner join BillingDetail bd (nolock)
	On b.billing_uid = bd.billing_uid
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join GeneratorSiteType gst (nolock)
	on g.site_type = gst.generator_site_type
where 
	b.invoice_id = @invoice_id
	and b.billing_project_id <> 6105
	and bd.billingdetail_uid not in (select billingdetail_uid from #WMBilling)
group by convert(varchar(20), b.company_id) + '-' +
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

-- Sales Tax was wonky.  The select, including the site type was fast.
-- Same select with grouping by site type, awful.  So we cheat:

-- Sales Tax
select 
	'Sales Tax' as cost_item
	, null as cost_item_type
	, st.tax_description as item_description
	, null as qty
	, null as bill_unit_desc
	, null as unit_price
	, bd.extended_amt as amt
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
	, 1 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
and b.billing_project_id <> 6105

insert #BillingInfo
select
	1000 as orderby
	, 'Sales Tax'
	, '' as cost_item_type
	, item_description
	, s.qty
	, '' as bill_unit_desc
	, s.unit_price
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
		where project_grouping = 1
	) b 
LEFT OUTER JOIN #SalesTax s ON s.site_type = b.site_type
and s.project_grouping = b.project_grouping
GROUP BY 	
	item_description
	, s.qty
	, s.unit_price
	, b.site_type
	, b.project_grouping


-- separate handling for 6105
	insert #BillingInfo
	select 
		2001 as orderby
		, 'Materials' as cost_item
		, 'Disposal' as cost_item_type
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
		/*
		+ ' - ' 
		+ CASE b.trans_source -- This part appends the approval code to the end of the description so they're all in the same format.
			WHEN 'W' THEN 
				ta.tsdf_approval_code
			WHEN 'R' THEN 
				b.approval_code
		END
		*/ as item_description
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	-- and b.invoice_date > '1/1/2010'
	and ((b.trans_source = 'W' and b.workorder_resource_type = 'D')
		or (b.trans_source = 'R' and b.trans_type = 'D')
		or (b.trans_source = 'R' and b.trans_type = 'S' and b.waste_code = 'LMIN')
		or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'DISPOSAL-RETAIL'))
		or (b.trans_source = 'R' and b.trans_type = 'S' and bd.product_id in (select product_id from PRODUCT where product_code = 'LMIN'))
	)
	group by
	CASE b.trans_source -- This part just cleans up the "native" approval description
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
		/*
		+ ' - ' 
		+ CASE b.trans_source -- This part appends the approval code to the end of the description so they're all in the same format.
			WHEN 'W' THEN 
				ta.tsdf_approval_code
			WHEN 'R' THEN 
				b.approval_code
		END
		*/
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
		
	union all

	select 
		2002 as orderby
		, 'Materials' as cost_item
		, 'Supplies' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and (b.workorder_resource_type = 'S' 
	or b.workorder_resource_item = 'MISC'
	)
	group by b.service_desc_1
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

	union all

	select 
		2003 as orderby
		, 'Materials' as cost_item
		, 'Laboratory Analysis' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.workorder_resource_item = 'LABTEST'
	group by b.service_desc_1
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

	union all

	-- Workorder Fuel Surcharge
	select 
		2004 as orderby
		, 'Materials' as cost_item
		, 'Fuel Surcharge' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'FEEGASSR'
	group by b.service_desc_1
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

	union all

	-- Workorder Stop Fee
	select 
		2005 as orderby
		, 'Labor' as cost_item
		, 'Stop Fee' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'STOPFEE'
	group by b.service_desc_1
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
	union all

	-- Workorder Demurrage
	select 
		2006 as orderby
		, 'Labor' as cost_item
		, 'Demurrage' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_type = 'O'
	and b.workorder_resource_item = 'DEMURRAGE'
	group by b.service_desc_1
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
	union all

	-- Workorder Freight
	select 
		2007 as orderby
		, 'Freight' as cost_item
		, 'Parcel Services' as cost_item_type
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105
	and b.trans_source = 'W'
	and b.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')
	group by b.service_desc_1
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


	union all

	select 
		2009 as orderby
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
	from Billing b (nolock)
	inner join BillingDetail bd (nolock)
		On b.billing_uid = bd.billing_uid
	inner join generator g (nolock)
		on b.generator_id = g.generator_id
	inner join GeneratorSiteType gst (nolock)
		on g.site_type = gst.generator_site_type
	where 
		b.invoice_id = @invoice_id
		and b.billing_project_id = 6105
		and bd.billingdetail_uid not in (select billingdetail_uid from #WMBilling)
	group by convert(varchar(20), b.company_id) + '-' +
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

	-- Sales Tax was wonky.  The select, including the site type was fast.
	-- Same select with grouping by site type, awful.  So we cheat:

	-- Sales Tax
	insert #SalesTax
	select 
		'Sales Tax' as cost_item
		, null as cost_item_type
		, st.tax_description as item_description
		, null as qty
		, null as bill_unit_desc
		, null as unit_price
		, bd.extended_amt as amt
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
		, 2 as project_grouping -- So the 'normal' bucket program stuff comes first and the 6105 fuel program can come second
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
	and b.billing_project_id = 6105

	insert #BillingInfo
	select
		3000 as orderby
		, 'Sales Tax'
		, '' as cost_item_type
		, item_description
		, s.qty
		, '' as bill_unit_desc
		, s.unit_price
		, isnull(SUM(s.amt), 0)
		, b.site_type
		, '' trans_source
		, 0 company_id
		, 0 profit_ctr_id
		, 0 receipt_id
		, '' waste_code
		, b.project_grouping
	FROM (
		select distinct 
			site_type
			, project_grouping
			from #BillingInfo
		where project_grouping = 2
		) b 
	LEFT OUTER JOIN #SalesTax s ON s.site_type = b.site_type
	and s.project_grouping = b.project_grouping
	GROUP BY 	
		item_description
		, s.qty
		, s.unit_price
		, b.site_type
		, b.project_grouping
-- end of 6105 separation

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
	, case when project_grouping = 1 then site_type else 'Fuel Station Services' end as site_type
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
	, case when project_grouping = 1 then site_type else 'Fuel Station Services' end
	, project_grouping
order by project_grouping, case when project_grouping = 1 then site_type else 'Fuel Station Services' end desc, orderby, item_description

select 
	orderby
	, row_number() over (partition by site_type, orderby order by site_type, orderby, amt desc) as type_rank
	, cost_item
	, cost_item_type
	, item_description
	, qty
	, bill_unit_desc
	, unit_price
	, amt
	, case when project_grouping = 1 then site_type else 'Fuel Station Services' end as site_type
	, project_grouping
from #UnifiedBillingInfo
-- WHERE (site_type like '%' + @store_type + '%' or @store_type is null)
order by project_grouping, case when project_grouping = 1 then site_type else 'Fuel Station Services' end desc, orderby, amt desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary_orig] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary_orig] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_summary_orig] TO [EQAI]
    AS [dbo];

