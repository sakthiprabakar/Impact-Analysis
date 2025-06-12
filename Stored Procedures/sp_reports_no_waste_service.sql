create proc sp_reports_no_waste_service (
	-- @customer_id	int, -- 14231 hard coded, it's a rite aid report using a hard coded rite aid view (which is sad)
	@start_date		datetime,
	@end_date		datetime,
	@contact_id		int
) as
/* *************************************************************************
sp_reports_no_waste_service

Lists generator and exception report data for waste picked up between given dates.
Exceptions are defined herein as no picked up waste from the rite aid front end or 
Rx locations at a store.

History:

	6/26/2013	JPB	Created 
	9/12/2013	JPB	Copied from sp_rite_aid_prebilling_worksheet and modified for Weekly Report use.
					Converted input from @trip_id to @start_date, @end_date
					Receipts might not exist yet, so check for them first, but fall back to WorkOrderDetailUnit where necessary.
	9/16/2013	JPB	Converted from earlier version into one-off RA specific report for EQIP
	3/12/2014	JPB	Force No Waste Shipped items to appear even when none in front or rx.
	4/17/2014	JPB	Fixes for data doubling in #summary table, and incorrect weights in Work Order transactions
	8/21/2014	JPB	Fix for #detail table calculation of detail_weight.
	12/6/2018 - JPB	Copied from sp_eqip_retail_no_waste_shipped_report_rite_aid and modified for COR2
	

Sample:

	sp_reports_no_waste_service '4/6/2014', '4/12/2014', @contact_id = 100913
	-- 10948, missing both. Woo.
	
SELECT  *  FROM    workorderdetail where workorder_id = 10918500 and profit_ctr_id = 4
SELECT  *  FROM    workorderstop where workorder_id = 10918500 and profit_ctr_id = 4
	
************************************************************************* */

-- declare @start_date datetime = '4/6/2014', @end_date datetime = '4/12/2014'


--#region PreBillingDataGeneration

if OBJECT_ID('tempdb..#keys') is not null drop table #keys
if OBJECT_ID('tempdb..#ReceiptTransporter') is not null drop table #ReceiptTransporter
if OBJECT_ID('tempdb..#detail') is not null drop table #detail
if OBJECT_ID('tempdb..#summary') is not null drop table #summary
if OBJECT_ID('tempdb..#prebilldata') is not null drop table #prebilldata
if OBJECT_ID('tempdb..#prebilldataNWP') is not null drop table #prebilldataNWP


if datepart(hh, @end_date) = 0
	set @end_date = @end_date + 0.99999


/*

-- Create a #Keys table to hold the id info and other useful data for records to include.
create table #Keys(
	receipt_id		int
	, line_id			int
	, resource_type		varchar(15)
	, company_id		int
	, profit_ctr_id		int
	, trans_source		char(1)
	, pickup_date		datetime
	, billing_date		datetime
	, detail_weight		float
	, workorder_id		int
	, workorder_company_id	int
	, workorder_profit_ctr_id	int
	, trip_id			int
	, generator_id		int
)

-- Fill #Keys with data from 
-- Work Orders
INSERT #Keys
SELECT 
    w.workorder_id as receipt_id,
    d.sequence_id as line_id,
    d.resource_type as resource_type,
    w.company_id,
    w.profit_ctr_id,
    'W' as trans_source,
    coalesce(wos.date_act_arrive, w.start_date) as pickup_date,
    w.start_date as billing_date
    , null as detail_weight
    , null as workorder_id
    , null as workorder_company_id
    , null as workorder_profit_ctr_id
    , w.trip_id
    , w.generator_id
FROM ContactCORWorkorderHeaderBucket sc (nolock)
INNER JOIN	WorkOrderHeader w (nolock) 
	ON sc.contact_id = @contact_id
	AND sc.workorder_id = w.workorder_id
	AND sc.company_id = w.company_id
	AND sc.profit_ctr_id = w.profit_ctr_id
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
left outer join Billing billing	(nolock) on d.workorder_ID = billing.receipt_id
	and billing.trans_source = 'W'
	and d.resource_type = billing.workorder_resource_type
	and d.company_id = billing.company_id
	and d.profit_ctr_ID = billing.profit_ctr_id
	and d.sequence_ID = billing.workorder_sequence_id
where 
	coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate > -2
	and d.resource_type = 'D'
union
SELECT 
    w.workorder_id as receipt_id,
    d.sequence_id as line_id,
    d.resource_type as resource_type,
    w.company_id,
    w.profit_ctr_id,
    'W' as trans_source,
    coalesce(wos.date_act_arrive, w.start_date) as pickup_date,
    w.start_date as billing_date
    , null as detail_weight
    , null as workorder_id
    , null as workorder_company_id
    , null as workorder_profit_ctr_id
    , w.trip_id
    , w.generator_id
FROM ContactCORWorkorderHeaderBucket sc (nolock)
INNER JOIN	WorkOrderHeader w (nolock) 
	ON sc.contact_id = @contact_id
	AND sc.workorder_id = w.workorder_id
	AND sc.company_id = w.company_id
	AND sc.profit_ctr_id = w.profit_ctr_id
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
left outer join Billing billing	(nolock) on d.workorder_ID = billing.receipt_id
	and billing.trans_source = 'W'
	and d.resource_type = billing.workorder_resource_type
	and d.company_id = billing.company_id
	and d.profit_ctr_ID = billing.profit_ctr_id
	and d.sequence_ID = billing.workorder_sequence_id
where 
	w.generator_id in (select generator_id from customergenerator cg (nolock) inner join ContactCORCustomerBucket sc on sc.contact_id = @contact_id and cg.customer_id = sc.customer_id)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate > -2
	and d.resource_type = 'D'

-- Pre-Receipt Select info...
    select 
        r.receipt_id,
        r.line_id,
        r.company_id,
        r.profit_ctr_id,
        k.receipt_id as receipt_workorder_id,
        k.company_id as workorder_company_id,
        k.profit_ctr_id as workorder_profit_ctr_id,
        k.pickup_date as service_date,
        k.trip_id
 	into #ReceiptTransporter
    from #keys k
    inner join billinglinklookup bll  (nolock) on
        k.company_id = bll.source_company_id
        and k.profit_ctr_id = bll.source_profit_ctr_id
        and k.receipt_id = bll.source_id
    inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id
        and bll.profit_ctr_id = r.profit_ctr_id
        and bll.company_id = r.company_id
	where k.trans_source = 'W'


-- Fill #Keys with data from 
-- Receipts
INSERT #Keys
SELECT 
    r.receipt_id as receipt_id,
    r.line_id as line_id,
    NULL as resource_type,
    r.company_id,
    r.profit_ctr_id,
    'R' as trans_source,
    wrt.service_date AS pickup_date,
    r.receipt_date as billing_date
    , case when isnull(p.residue_manifest_print_flag, 'F') = 'T' then
			p.residue_pounds_factor * r.quantity
			/* 2014-08-21 Noticed this is wrong, BUT it's overwritten correctly just below, so leaving it. */
		else null
		end as detail_weight
	, wrt.receipt_workorder_id
	, wrt.workorder_company_id
	, wrt.workorder_profit_ctr_id
	, wrt.trip_id
	, r.generator_id
FROM Receipt r (nolock) 
INNER JOIN #ReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
LEFT JOIN Profile p on r.profile_id = p.profile_id
where
	r.customer_id in (Select customer_id from ContactCORCustomerBucket where contact_id = @contact_id)
	and r.receipt_status = 'A'
	AND r.fingerpr_status = 'A'
	AND r.trans_mode = 'I'


-- Update #Keys info with the sums of weights from ReceiptDetailItem
update #Keys set detail_weight = 
	(
		select sum( 
			(
				isnull(rdi.pounds,0) * 1.0
			) + (
				isnull(rdi.ounces,0)/16.0
			) 
		)
		from ReceiptDetailItem rdi (nolock)
		where f.receipt_id = rdi.receipt_id
		and f.line_id = rdi.line_id
		and f.company_id = rdi.company_id
		and f.profit_ctr_id = rdi.profit_ctr_id
	)
from #Keys f
where f.trans_source = 'R'
and f.detail_weight is null

-- ALSO let's dump in the WO info then
update #Keys set detail_weight = 
	(
		select sum( 
			(
				isnull(wodi.pounds,0) * 1.0
			) + (
				isnull(wodi.ounces,0)/16.0
			) 
		)
		from WorkOrderDetailItem wodi (nolock)
		where f.receipt_id = wodi.workorder_id
		and f.line_id = wodi.sequence_id
		and f.company_id = wodi.company_id
		and f.profit_ctr_id = wodi.profit_ctr_id
	)
from #Keys f
where f.trans_source = 'W'
and f.resource_type = 'D'
and detail_weight is null


-- Fill #Detail with per-approval weights, prices etc. from receipt
-- drop table #detail
select *
, row_number() over (partition by site_code order by site_code, approval_code) as row_number
into #detail
from (
select 
	g.generator_id
	, k.trip_id
	, r.company_id, r.profit_ctr_id, r.receipt_id
	, workorder_id, workorder_company_id, workorder_profit_ctr_id
	, g.site_code
	, g.generator_state
	, r.profile_id
	, r.approval_code
	-- , raap.category
	, p.approval_desc
	, case when isnull(p.residue_pounds_factor, 0) <> 0 then
		/* p.residue_pounds_factor * r.container_count - 2014-08-21: Working on generic extract, realized I copied bad logic from here... fixed. */
		isnull(rdi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)
		else
		k.detail_weight
		end as detail_weight
	, k.pickup_date
	, k.trans_source
from Receipt r (nolock)
inner join #keys k
	on k.receipt_id = r.receipt_id
	and k.line_id = r.line_id
	and k.company_id = r.company_id
	and k.profit_ctr_id = r.profit_ctr_id
inner join ReceiptDetailItem rdi (nolock)
	on k.receipt_id = rdi.receipt_id
	and k.line_id = rdi.line_id
	and k.company_id = rdi.company_id
	and k.profit_ctr_id = rdi.profit_ctr_id
inner join generator g on r.generator_id = g.generator_id
inner join profile p on r.profile_id = p.profile_id
where k.trans_source = 'R'
and r.trans_mode = 'I'
UNION
-- Now add workorders:
-- insert #detail
select 
g.generator_id
, k.trip_id
, k.company_id, k.profit_ctr_id, k.receipt_id
, k.receipt_id as workorder_id, k.company_id as workorder_company_id, k.profit_ctr_id as workorder_profit_ctr_id -- workorder_id, workorder_company_id, workorder_profit_ctr_id
, g.site_code
, g.generator_state
, d.profile_id
, d.tsdf_approval_code
-- , raap.category
, p.approval_desc
	, case when isnull(p.residue_pounds_factor, 0) <> 0 then
		p.residue_pounds_factor * wodi.merchandise_quantity
		else
		k.detail_weight
		end as detail_weight
, k.pickup_date
	, k.trans_source
from WorkorderDetail d (nolock)
inner join #keys k
	on k.receipt_id = d.workorder_id
	and k.line_id = d.sequence_id
	and k.company_id = d.company_id
	and k.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
-- inner join workorderheader h on d.workorder_id = h.workorder_id and d.company_id = h.company_id and d.profit_ctr_id = h.profit_ctr_id
LEFT JOIN WorkOrderDetailItem wodi
	on k.receipt_id = wodi.workorder_id
	and k.line_id = wodi.sequence_id
	and k.company_id = wodi.company_id
	and k.profit_ctr_id = wodi.profit_ctr_id
inner join generator g on g.generator_id = k.generator_id
inner join profile p on d.profile_id = p.profile_id
where k.trans_source = 'W'
-- and g.generator_id = 104227
-- and not exists (select 1 from #detail where workorder_id = k.receipt_id and workorder_company_id = k.company_id and workorder_profit_ctr_id = k.profit_ctr_id)
) almostdetail


-- Create a blank (ish) #Summary table from the distinct site codes, states, and price categories
-- defined for Rite Aid from the #detail set + a superset of the possible categories
-- plus data from the RiteAidApprovalPrice table that holds all their unique categories, prices, included weights, etc.
-- drop table #summary
select distinct
generator_id
, site_code
, generator_state
, pickup_date
-- , cat.category
, convert(float, null) as sum_detail_weight
into #summary	
from #detail d
group by
generator_id
, site_code
, generator_state
, pickup_date
-- , cat.category

-- update #summary set sum_detail_weight = null


-- Update #summary from #detail to sum the weights per site_code & category combination.
update #summary set
 sum_detail_weight = 
	(
		select sum(detail_weight) from #detail d2 where d2.site_code = s.site_code /* and d2.category = s.category */ and d2.pickup_date = s.pickup_date and d2.trans_source = 'R'
	)
	
from #summary s
where sum_detail_weight is null

update #summary set
 sum_detail_weight = isnull(
	(
		select sum(detail_weight) from #detail d2 where d2.site_code = s.site_code /* and d2.category = s.category */ and d2.pickup_date = s.pickup_date and d2.trans_source = 'W'
	)
	, 0)
from #summary s
where sum_detail_weight is null

-- Output the detail info (all of it) and for every 1st row for a particular site_code, also include the summary info.
select 
d.generator_id
, d.trip_id
, d.workorder_id
, d.workorder_company_id
, d.workorder_profit_ctr_id
, d.receipt_id
, d.company_id as receipt_company_id
, d.profit_ctr_id as receipt_profit_ctr_id
, d.site_code
, d.generator_state
, d.profile_id
, d.approval_code
, d.pickup_date
-- , d.category
, d.approval_desc
, d.detail_weight
, case when d.row_number = 1 then (select sum_detail_weight from #summary where site_code = d.site_code and pickup_date = d.pickup_date) else null end as total_weight
into #prebilldata
from #detail d
where d.row_number = 1
order by d.site_code, d.row_number

*/

-- declare @start_date datetime = '4/6/2014', @end_date datetime = '4/12/2014', @contact_id varchar(20) = 'jonathan', @permission_id int = 159, @debug int = 0

-- Need to "artificially" add valid No-Waste-Pickup cases to #prebilldata with 0 weights.
select 
w.generator_id
, w.trip_id
, w.workorder_id
, w.company_id
, w.profit_ctr_id
, 0 as receipt_id
, 0 as receipt_company_id
, 0 as receipt_profit_ctr_id
, g.site_code
, g.generator_state
, 0 as profile_id
, null as approval_code
, coalesce(wos.date_act_arrive, w.start_date) as pickup_date
, 'NW' as category
, null as approval_desc
, 0 as detail_weight
, null as total_weight
-- , null as FRONT_END_total_weight
-- , null as RX_total_weight
INTO #prebilldataNWP
FROM ContactCORWorkorderHeaderBucket sc (nolock)
INNER JOIN	WorkOrderHeader w (nolock) 
	ON sc.contact_id = @contact_id
	AND sc.workorder_id = w.workorder_id
	AND sc.company_id = w.company_id
	AND sc.profit_ctr_id = w.profit_ctr_id
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN generator g on g.generator_id = w.generator_id	
INNER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	and wos.decline_id <> 1
where 
	coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate >= 1
	and d.resource_type = 'O'
	and (d.resource_class_code like '%STOP%' or d.resource_class_code like 'STPFE%')
	-- and not exists (select 1 from #keys where generator_id = w.generator_id)
union
select 
w.generator_id
, w.trip_id
, w.workorder_id
, w.company_id
, w.profit_ctr_id
, 0 as receipt_id
, 0 as receipt_company_id
, 0 as receipt_profit_ctr_id
, g.site_code
, g.generator_state
, 0 as profile_id
, null as approval_code
, coalesce(wos.date_act_arrive, w.start_date) as pickup_date
, 'NW' as category
, null as approval_desc
, 0 as detail_weight
, null as total_weight
--, null as FRONT_END_total_weight
--, null as RX_total_weight
FROM ContactCORWorkorderHeaderBucket sc (nolock)
INNER JOIN	WorkOrderHeader w (nolock) 
	ON sc.contact_id = @contact_id
	AND sc.workorder_id = w.workorder_id
	AND sc.company_id = w.company_id
	AND sc.profit_ctr_id = w.profit_ctr_id
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN generator g on g.generator_id = w.generator_id	
INNER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	and wos.decline_id <> 1
where 
	coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate >= 1
	and d.resource_type = 'O'
	and (d.resource_class_code like '%STOP%' or d.resource_class_code like 'STPFE%')
	-- and not exists (select 1 from #keys where generator_id = w.generator_id)

/*

SELECT decline_id, *  FROM    WorkOrderStop WHERE workorder_id = 4325900 and profit_ctr_id= 4
select * from sysobjects where name like '%decline%'
select * from syscolumns where name = 'decline_id'
select * from sysobjects where id = 1801942387
select distinct decline_id from workorderstop where profit_ctr_id = 4
select top 10 * from workorderstop where decline_id = 4 and company_id = 14 and profit_ctr_id = 4

1 = not declined
2  service declined ahead of pickup
3 = service declined at pickup
4 = no waste picked up

insert #prebilldata
select distinct
x.generator_id
, x.trip_id
, x.workorder_id
, x.company_id
, x.profit_ctr_id
, x.receipt_id
, x.receipt_company_id
, x.receipt_profit_ctr_id
, x.site_code
, x.generator_state
, x.profile_id
, x.approval_code
, x.pickup_date
-- , cat.category
, x.approval_desc
, x.detail_weight
, x.total_weight
-- , x.FRONT_END_total_weight
-- , x.RX_total_weight
-- , 0
from #PreBillDataNWP x
*/

--#endregion


/*
Here, finished with the prebilling worksheet logic.  Bring on the fun of weekly reporting...
*/


--#region FieldExceptionReport

-- Field Exception Report
-------------------------

	--Exceptions to report:
	--1.	Stops where the total weight picked up exceeds 150 pounds
	--2.	Stops that had no waste from the Front End or Pharmacy.

select 
	p.company_id, p.profit_ctr_id,
	g.site_code as store_number
	, g.generator_city
	, g.generator_state
	, convert(varchar(12), pickup_date, 101) as service_date
	, workorder_id as service_number
	, 'No Waste' as exception
from #PreBillDataNWP p
inner join generator g on p.generator_id = g.generator_id
where isnull(p.total_weight, 0) = 0
order by g.generator_state, g.generator_city, g.site_code

--#endregion
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_no_waste_service] TO [EQAI]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_no_waste_service] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_no_waste_service] TO [COR_USER]
    AS [dbo];

GO

