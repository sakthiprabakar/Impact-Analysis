﻿
create proc sp_eqip_retail_no_waste_shipped_report_rite_aid (
	-- @customer_id	int, -- 14231 hard coded, it's a rite aid report using a hard coded rite aid view (which is sad)
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@debug_code		int = 0	
) as
/* *************************************************************************
sp_eqip_retail_no_waste_shipped_report_rite_aid

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

Sample:

	sp_eqip_retail_no_waste_shipped_report_rite_aid '4/6/2014', '4/12/2014', 'jonathan', 159
	-- 10948, missing both. Woo.
************************************************************************* */

-- declare @start_date datetime = '4/6/2014', @end_date datetime = '4/12/2014', @user_code varchar(20) = 'jonathan', @permission_id int = 159, @debug int = 0

declare @customer_id int = 14231 -- sad, sad, sad.

--#region PreBillingDataGeneration

if OBJECT_ID('tempdb..#Secured_Customer') is not null drop table #Secured_Customer
if OBJECT_ID('tempdb..#Secured_COPC') is not null drop table #Secured_COPC
if OBJECT_ID('tempdb..#keys') is not null drop table #keys
if OBJECT_ID('tempdb..#ReceiptTransporter') is not null drop table #ReceiptTransporter
if OBJECT_ID('tempdb..#detail') is not null drop table #detail
if OBJECT_ID('tempdb..#summary') is not null drop table #summary
if OBJECT_ID('tempdb..#prebilldata') is not null drop table #prebilldata
if OBJECT_ID('tempdb..#prebilldataNWP') is not null drop table #prebilldataNWP


SELECT DISTINCT customer_id INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id
	and sc.customer_id = @customer_id

SELECT secured_copc.company_id
       ,secured_copc.profit_ctr_id
INTO   #Secured_COPC
FROM   SecuredProfitCenter secured_copc (nolock)
WHERE  secured_copc.permission_id = @permission_id
       AND secured_copc.user_code = @user_code 
       
if datepart(hh, @end_date) = 0
	set @end_date = @end_date + 0.99999

if OBJECT_ID('tempdb..#keys') is not null drop table #keys
if OBJECT_ID('tempdb..#ReceiptTransporter') is not null drop table #ReceiptTransporter
if OBJECT_ID('tempdb..#detail') is not null drop table #detail
if OBJECT_ID('tempdb..#summary') is not null drop table #summary
if OBJECT_ID('tempdb..#prebilldata') is not null drop table #prebilldata
if OBJECT_ID('tempdb..#prebilldataNWP') is not null drop table #prebilldataNWP

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
SELECT DISTINCT
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
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
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
	w.customer_id in (Select customer_id from #Secured_Customer)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate > -2
	and d.resource_type = 'D'
union
SELECT DISTINCT
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
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
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
	w.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate > -2
	and d.resource_type = 'D'

-- Pre-Receipt Select info...
    select distinct
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
SELECT DISTINCT
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
	r.customer_id in (Select customer_id from #Secured_Customer)
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
	, raap.category
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
inner join generator g on r.generator_id = g.generator_id
inner join profile p on r.profile_id = p.profile_id
inner join vw_RiteAidApprovalPrice raap (nolock)	
	on r.approval_code = raap.approval_code
	and g.generator_state = raap.state
where k.trans_source = 'R'
and r.trans_mode = 'I'
UNION
-- Now add workorders:
-- insert #detail
select 
g.generator_id
, k.trip_id
, k.company_id, k.profit_ctr_id, k.receipt_id
, k.receipt_id, k.company_id, k.profit_ctr_id -- workorder_id, workorder_company_id, workorder_profit_ctr_id
, g.site_code
, g.generator_state
, d.profile_id
, d.tsdf_approval_code
, raap.category
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
inner join vw_RiteAidApprovalPrice raap (nolock)	
	on d.tsdf_approval_code = raap.approval_code
	and g.generator_state = raap.state
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
, cat.category
, convert(float, null) as sum_detail_weight
into #summary	
from #detail d
cross join (select 'FE' as category union select 'Rx') cat
inner join vw_RiteAidApprovalPrice raap (nolock)	
	on cat.category = raap.category
	and d.generator_state = raap.state
group by
generator_id
, site_code
, generator_state
, pickup_date
, cat.category

-- update #summary set sum_detail_weight = null

-- Update #summary from #detail to sum the weights per site_code & category combination.
update #summary set
 sum_detail_weight = 
	(
		select sum(detail_weight) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.pickup_date = s.pickup_date and d2.trans_source = 'R'
	)
	
from #summary s
where sum_detail_weight is null

update #summary set
 sum_detail_weight = isnull(
	(
		select sum(detail_weight) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.pickup_date = s.pickup_date and d2.trans_source = 'W'
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
, d.category
, d.approval_desc
, d.detail_weight
, case when d.row_number = 1 then (select sum_detail_weight from #summary where site_code = d.site_code and category = 'FE' and pickup_date = d.pickup_date) else null end as FRONT_END_total_weight
, case when d.row_number = 1 then (select sum_detail_weight from #summary where site_code = d.site_code and category = 'Rx' and pickup_date = d.pickup_date) else null end as RX_total_weight
into #prebilldata
from #detail d
where d.row_number = 1
order by d.site_code, d.row_number


-- declare @start_date datetime = '4/6/2014', @end_date datetime = '4/12/2014', @user_code varchar(20) = 'jonathan', @permission_id int = 159, @debug int = 0

-- Need to "artificially" add valid No-Waste-Pickup cases to #prebilldata with 0 weights.
select distinct
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
, null as FRONT_END_total_weight
, null as RX_total_weight
INTO #prebilldataNWP
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN generator g on g.generator_id = w.generator_id	
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	and wos.decline_id <> 2
where 
	w.customer_id in (Select customer_id from #Secured_Customer)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate >= 1
	and d.resource_type = 'O'
	and (d.resource_class_code like '%STOP%' or d.resource_class_code like 'STPFE%')
	and not exists (select 1 from #prebilldata where generator_id = w.generator_id)
union
select distinct
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
, null as FRONT_END_total_weight
, null as RX_total_weight
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN generator g on g.generator_id = w.generator_id	
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	and wos.decline_id <> 2
where 
	w.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	and d.bill_rate >= 1
	and d.resource_type = 'O'
	and (d.resource_class_code like '%STOP%' or d.resource_class_code like 'STPFE%')
	and not exists (select 1 from #prebilldata where generator_id = w.generator_id)

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
, cat.category
, x.approval_desc
, x.detail_weight
, x.FRONT_END_total_weight
, x.RX_total_weight
-- , 0
from #PreBillDataNWP x
cross join (select 'FE' as category union select 'Rx') cat


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
	g.site_code as store_number
	, g.generator_city
	, g.generator_state
	, convert(varchar(12), pickup_date, 101) as service_date
	, workorder_id as service_number
	, 'No FE Waste' as exception
from #prebilldata p
inner join generator g on p.generator_id = g.generator_id
where isnull(p.FRONT_END_total_weight, 0) = 0
union 
select 
	g.site_code as store_number
	, g.generator_city
	, g.generator_state
	, convert(varchar(12), pickup_date, 101) as service_date
	, workorder_id as service_number
	, 'No Rx Waste' as exception
from #prebilldata p
inner join generator g on p.generator_id = g.generator_id
where isnull(p.RX_total_weight, 0) = 0
order by g.generator_state, g.generator_city, g.site_code

--#endregion


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_no_waste_shipped_report_rite_aid] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_no_waste_shipped_report_rite_aid] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_no_waste_shipped_report_rite_aid] TO [EQAI]
    AS [dbo];

