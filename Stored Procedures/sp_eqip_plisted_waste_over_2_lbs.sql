
create proc sp_eqip_plisted_waste_over_2_lbs (
	@customer_id	int,
	@start_date	datetime,
	@end_date	datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@debug_code			int = 0	
) as
/* *************************************************************************
sp_eqip_plisted_waste_over_2_lbs

Collects data on the weights and types of waste picked up for a customer and
lists pickup, generator, approval and weight information for cases where the
waste contains a federal P- waste code with a weight over 2.2 lbs.

History:

	6/26/2013	JPB	Created 
	9/12/2013	JPB	Copied from sp_rite_aid_prebilling_worksheet and modified for Weekly Report use.
					Converted input from @trip_id to @start_date, @end_date
					Receipts might not exist yet, so check for them first, but fall back to WorkOrderDetailUnit where necessary.
	9/13/2013	JPB	Converted to sp_eqip_plisted_waste_over_2_lbs
					- Not built for a specific customer
					- Meant for EQIP/SSRS
					- Uses EQIP Row level security
	02/07/2014	JPB	Added code to include end-of-day range on @end_date
					Now Omitting void/template work orders
	04/02/2014	JPB	Modified to list Started...
					Need to have all P-listed approvals pulled whenever a generator work order 
						exceeds 2.2 lbs. total of all P-listed waste approvals combined.
					Change column titles in report as shown in the screenshot above.
						(Location, Svc Date, Service No, Region, Division, City, St, Description, Weight)
					Need the following data added to the report
					Actual “Residue Weight” Empty P-Listed Pharmaceutical Containers
					That prints on manifest to 4 decimal places
					Bottle count for Empty P-Listed Pharmaceutical Containers
					Actual bottle weight of Empty P-Listed Pharmaceutical Containers
					Actual container weight that driver enters in on MIM.
	05/08/2014	JPB	Fixed bad join to WorkorderWasteCode.  Should use workorder_sequence_id, not sequence_id in joins.


Sample:

	sp_eqip_plisted_waste_over_2_lbs 14231, '4/21/2014', '5/8/2014', 'jonathan', 159

************************************************************************* */

if OBJECT_ID('tempdb..#Secured_Customer') is not null drop table #Secured_Customer
if OBJECT_ID('tempdb..#Secured_COPC') is not null drop table #Secured_COPC
if OBJECT_ID('tempdb..#keys') is not null drop table #keys
if OBJECT_ID('tempdb..#ReceiptTransporter') is not null drop table #ReceiptTransporter
if OBJECT_ID('tempdb..#detail') is not null drop table #detail
if OBJECT_ID('tempdb..#summary') is not null drop table #summary
if OBJECT_ID('tempdb..#prebilldata') is not null drop table #prebilldata
if OBJECT_ID('tempdb..#prebilldataNWP') is not null drop table #prebilldataNWP
if OBJECT_ID('tempdb..#heavies') is not null drop table #heavies

-- declare @customer_id int = 14231, @start_date datetime = '4/15/2014', @end_date datetime = '5/31/2014', @user_code varchar(10) = 'jonathan', @permission_id int = 159, @debug_code int = 0

declare @weight_limit float = 2.2

--#region PreBillingDataGeneration


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
	, container_count	int
	, residue_weight	float
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
    , null as container_count
    , null as residue_weight
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
    , null as container_count
    , null as residue_weight
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
    , null as container_count
    , null as residue_weight
	, null as detail_weight
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
	and wrt.service_date between @start_date and @end_date
	and r.receipt_status = 'A'
	AND r.fingerpr_status = 'A'
	AND r.trans_mode = 'I'
union
SELECT DISTINCT
    r.receipt_id as receipt_id,
    r.line_id as line_id,
    NULL as resource_type,
    r.company_id,
    r.profit_ctr_id,
    'R' as trans_source,
    wrt.service_date AS pickup_date,
    r.receipt_date as billing_date
    , null as container_count
    , null as residue_weight
	, null as detail_weight
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
	r.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	and r.receipt_status = 'A'
	AND r.fingerpr_status = 'A'
	AND r.trans_mode = 'I'

-- Update #Keys info with the sums of counts & weights from ReceiptDetailItem
update #Keys set 
	container_count = x.count_sum
	, residue_weight = x.weight_sum
	, detail_weight = x.pounds_sum
from #keys k
inner join
	(
		select 
		k.trans_source
		, k.receipt_id
		, k.line_id
		, k.company_id
		, k.profit_ctr_id
		, sum(
			isnull(rdi.merchandise_quantity, 0)
		) as count_sum
		, sum( 
			isnull(rdi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)
		) as weight_sum
		, sum( 
			(
				isnull(rdi.pounds,0) * 1.0
			) + (
				isnull(rdi.ounces,0)/16.0
			) 
		) as pounds_sum
		from #keys k
		INNER JOIN Receipt r (nolock)
			on k.receipt_id = r.receipt_id
			and k.line_id = r.line_id
			and k.company_id = r.company_id
			and k.profit_ctr_id = r.profit_ctr_id
			and k.trans_source = 'R'
		INNER JOIN ReceiptDetailItem rdi (nolock)
			on r.receipt_id = rdi.receipt_id
			and r.line_id = rdi.line_id
			and r.company_id = rdi.company_id
			and r.profit_ctr_id = rdi.profit_ctr_id
		LEFT JOIN Profile p
			on r.profile_id = p.profile_id
			and isnull(p.residue_manifest_print_flag, 'F') = 'T'
		GROUP BY
		k.trans_source
		, k.receipt_id
		, k.line_id
		, k.company_id
		, k.profit_ctr_id
	) x
		on x.trans_source = k.trans_source
		and x.receipt_id = k.receipt_id
		and x.line_id = k.line_id
		and x.company_id = k.company_id
		and x.profit_ctr_id = k.profit_ctr_id
where 1=1 -- k.trans_source = 'R'
and k.residue_weight is null

-- ALSO let's dump in the WO info then
update #Keys set 
	container_count = x.count_sum
	, residue_weight = x.weight_sum
	, detail_weight = x.pounds_sum
from #keys k
inner join
	(
		select 
		k.trans_source
		, k.receipt_id
		, k.line_id
		, k.company_id
		, k.profit_ctr_id
		, sum(
			isnull(wodi.merchandise_quantity, 0)
		) as count_sum
		, sum( 
			isnull(wodi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)
		) as weight_sum
		, sum( 
			(
				isnull(wodi.pounds,0) * 1.0
			) + (
				isnull(wodi.ounces,0)/16.0
			) 
		) as pounds_sum
		from #keys k
		INNER JOIN WorkOrderDetail d (nolock)
			on k.receipt_id = d.workorder_id
			and k.line_id = d.sequence_id
			and k.company_id = d.company_id
			and k.profit_ctr_id = d.profit_ctr_id
			and k.trans_source = 'W'
		INNER JOIN WorkOrderDetailItem wodi (nolock)
			on d.workorder_id = wodi.workorder_id
			and d.sequence_id = wodi.sequence_id
			and d.company_id = wodi.company_id
			and d.profit_ctr_id = wodi.profit_ctr_id
		LEFT JOIN Profile p
			on d.profile_id = p.profile_id
			and isnull(p.residue_manifest_print_flag, 'F') = 'T'
		GROUP BY
		k.trans_source
		, k.receipt_id
		, k.line_id
		, k.company_id
		, k.profit_ctr_id
	) x
		on x.trans_source = k.trans_source
		and x.receipt_id = k.receipt_id
		and x.line_id = k.line_id
		and x.company_id = k.company_id
		and x.profit_ctr_id = k.profit_ctr_id
where 1=1 -- k.trans_source = 'W'
and k.residue_weight is null

-- Fill #Detail with per-approval weights, prices etc. from receipt
-- drop table #detail
select *
, row_number() over (partition by site_code order by site_code, approval_code) as row_number
into #detail
from (
select 
	g.generator_id
	, k.trip_id
	, r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id
	, workorder_id, workorder_company_id, workorder_profit_ctr_id
	, g.site_code
	, g.generator_city
	, g.generator_state
	, r.profile_id
	, r.approval_code
	, raap.category
	, p.approval_desc
	, k.container_count
	, k.residue_weight
	, k.detail_weight
	, k.pickup_date
	, r.waste_accepted_flag
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
	, k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id
	, k.receipt_id, k.company_id, k.profit_ctr_id -- workorder_id, workorder_company_id, workorder_profit_ctr_id
	, g.site_code
	, g.generator_city
	, g.generator_state
	, d.profile_id
	, d.tsdf_approval_code
	, raap.category
	, p.approval_desc
	, k.container_count
	, k.residue_weight
	, k.detail_weight
	, k.pickup_date
	, 'F' as waste_accepted_flag
	, k.trans_source
from WorkorderDetail d (nolock)
inner join #keys k
	on k.receipt_id = d.workorder_id
	and k.line_id = d.sequence_id
	and k.company_id = d.company_id
	and k.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
-- inner join workorderheader h on d.workorder_id = h.workorder_id and d.company_id = h.company_id and d.profit_ctr_id = h.profit_ctr_id
inner join tsdf t on d.tsdf_code = t.tsdf_code -- and isnull(t.eq_flag, 'F') = 'F'
inner join generator g on g.generator_id = k.generator_id
inner join profile p on d.profile_id = p.profile_id
inner join vw_RiteAidApprovalPrice raap (nolock)	
	on d.tsdf_approval_code = raap.approval_code
	and g.generator_state = raap.state
where k.trans_source = 'W'
-- and g.generator_id = 104227
-- and not exists (select 1 from #detail where workorder_id = k.receipt_id and workorder_company_id = k.company_id and workorder_profit_ctr_id = k.profit_ctr_id)
) almostdetail

/*

	-- Don't need #summary or NWP records in this report.  Comment out for speed.
	
	

	-- Create a blank (ish) #Summary table from the distinct site codes, states, and price categories
	-- defined for Rite Aid from the #detail set + a superset of the possible categories
	-- plus data from the RiteAidApprovalPrice table that holds all their unique categories, prices, included weights, etc.
	select distinct
	generator_id
	, site_code
	, generator_city
	, generator_state
	, pickup_date
	, cat.category
	, 0 as sum_container_count
	, convert(float, 0.000000000000000) as sum_residue_weight
	, convert(float, 0.000000000000000) as sum_detail_weight
	into #summary	
	from #detail d
	cross join (select 'FE' as category union select 'Rx') cat
	inner join vw_RiteAidApprovalPrice raap (nolock)	
		on cat.category = raap.category
		and d.generator_state = raap.state
	group by
	generator_id
	, site_code
	, generator_city
	, generator_state
	, pickup_date
	, cat.category



	-- Update #summary from #detail to sum the weights per site_code & category combination.
	update #summary set
		sum_container_count = (select isnull(sum(container_count), 0) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.pickup_date = s.pickup_date)
		, sum_residue_weight = (select isnull(sum(residue_weight), 0) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.pickup_date = s.pickup_date)
		, sum_detail_weight = (select isnull(sum(detail_weight), 0) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.pickup_date = s.pickup_date)
	from #summary s


	-- Output the detail info (all of it) and for every 1st row for a particular site_code, also include the summary info.
	select 
	d.generator_id
	, d.trip_id
	, d.workorder_id
	, d.workorder_company_id
	, d.workorder_profit_ctr_id
	, d.receipt_id
	, d.line_id
	, d.company_id as receipt_company_id
	, d.profit_ctr_id as receipt_profit_ctr_id
	, d.site_code
	, d.generator_city
	, d.generator_state
	, d.profile_id
	, d.approval_code
	, d.pickup_date
	, d.category
	, d.approval_desc
	, d.container_count
	, d.residue_weight
	, d.detail_weight
	, case when d.row_number = 1 then (select sum_detail_weight from #summary where site_code = d.site_code and category = 'FE' and pickup_date = d.pickup_date) else null end as FRONT_END_total_weight
	, case when d.row_number = 1 then (select sum_detail_weight from #summary where site_code = d.site_code and category = 'Rx' and pickup_date = d.pickup_date) else null end as RX_total_weight
	into #prebilldata
	from #detail d
	where d.row_number = 1
	order by d.site_code, d.row_number

	-- Need to "artificially" add valid No-Waste-Pickup cases to #prebilldata with 0 weights.
	select distinct
	w.generator_id
	, w.trip_id
	, w.workorder_id
	, w.company_id
	, w.profit_ctr_id
	, 0 as receipt_id
	, 0 as line_id
	, 0 as receipt_company_id
	, 0 as receipt_profit_ctr_id
	, g.site_code
	, g.generator_city
	, g.generator_state
	, 0 as profile_id
	, null as approval_code
	, coalesce(wos.date_act_arrive, w.start_date) as pickup_date
	, 'NW' as category
	, null as approval_desc
	, 0 as container_count
	, 0 as residue_weight
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
	, 0 as line_id
	, 0 as receipt_company_id
	, 0 as receipt_profit_ctr_id
	, g.site_code
	, g.generator_city
	, g.generator_state
	, 0 as profile_id
	, null as approval_code
	, coalesce(wos.date_act_arrive, w.start_date) as pickup_date
	, 'NW' as category
	, null as approval_desc
	, 0 as container_count
	, 0 as residue_weight
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
	, x.line_id
	, x.receipt_company_id
	, x.receipt_profit_ctr_id
	, x.site_code
	, x.generator_city
	, x.generator_state
	, x.profile_id
	, x.approval_code
	, x.pickup_date
	, cat.category
	, x.approval_desc
	, x.container_count
	, x.residue_weight
	, x.detail_weight
	, x.FRONT_END_total_weight
	, x.RX_total_weight
	-- , 0
	from #PreBillDataNWP x
	cross join (select 'FE' as category union select 'Rx') cat
*/

--#endregion


/*
Here, finished with the prebilling worksheet logic.  Bring on the fun of weekly reporting...
*/

-- Find the pickups where the total weight is over the @weight_limit.
-- declare @weight_limit float = 2.2
-- drop table #heavies
select generator_id, site_code, pickup_date, MIN(trans_source) trans_source
into #heavies 
from (
	select 
		d.generator_id
		, d.site_code
		, d.pickup_date 
		, min(d.trans_source) trans_source
	from #detail d
	inner join receiptwastecode r
		on d.receipt_id = r.receipt_id 
		and d.line_id = r.line_id
		and d.company_id = r.company_id 
		and d.profit_ctr_id = r.profit_ctr_id
	inner join wastecode wc
		on r.waste_code_uid = wc.waste_code_uid
	where 
		wc.waste_code_origin = 'F'
		and wc.waste_type_code = 'L'
		and left(wc.display_name, 1) = 'P'
	group by
		d.generator_id
		, d.site_code
		, d.pickup_date 
	having
		sum(case when d.residue_weight > 0 then d.residue_weight else d.detail_weight end) > @weight_limit
	union
	select 
		d.generator_id
		, d.site_code
		, d.pickup_date 
		, min(d.trans_source) trans_source
	from #detail d
	inner join workorderwastecode r
		on d.receipt_id = r.workorder_id 
		and d.line_id = r.workorder_sequence_id
		and d.company_id = r.company_id 
		and d.profit_ctr_id = r.profit_ctr_id
	inner join wastecode wc
		on r.waste_code_uid = wc.waste_code_uid
	where 
		wc.waste_code_origin = 'F'
		and wc.waste_type_code = 'L'
		and left(wc.display_name, 1) = 'P'
	group by
		d.generator_id
		, d.site_code
		, d.pickup_date 
	having
		sum(case when d.residue_weight > 0 then d.residue_weight else d.detail_weight end) > @weight_limit
) x
group by generator_id, site_code, pickup_date

SELECT distinct
	g.site_code
	, d.trans_source
	, d.pickup_date
	, d.workorder_id
	, g.generator_region_code as region
	, g.generator_division as division
	, g.generator_city
	, g.generator_state
	, d.approval_desc
	, d.detail_weight
	, d.container_count
	, d.residue_weight
	, d.waste_accepted_flag
FROM #detail d 
inner join generator g on d.generator_id = g.generator_id
left join receiptwastecode r
	on d.receipt_id = r.receipt_id 
	and d.line_id = r.line_id
	and d.company_id = r.company_id 
	and d.profit_ctr_id = r.profit_ctr_id
	and d.trans_source = 'R'
left join WorkOrderWasteCode w
	on d.receipt_id = w.workorder_id
	and d.line_id = w.workorder_sequence_id
	and d.company_id = w.company_id
	and d.profit_ctr_id = w.profit_ctr_id
	and d.trans_source = 'W'
inner join wastecode wc
	on wc.waste_code_uid = case when d.trans_source = 'R' then r.waste_code_uid else w.waste_code_uid end
where 
exists (select 1 from #heavies h where h.generator_id = d.generator_id and h.pickup_date = d.pickup_date and h.trans_source = d.trans_source)
	and wc.waste_code_origin = 'F'
	and wc.waste_type_code = 'L'
	and left(wc.display_name, 1) = 'P'
--	and d.receipt_id <> d.workorder_id
order by g.site_code, d.pickup_date, d.workorder_id, d.approval_desc



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste_over_2_lbs] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste_over_2_lbs] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste_over_2_lbs] TO [EQAI]
    AS [dbo];

