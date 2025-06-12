
create proc sp_rite_aid_prebilling_worksheet_v2 (
	@trip_id int
) as
/* *************************************************************************
sp_rite_aid_prebilling_worksheet_v2

Runs against a Rite Aid trip id and returns a spreadsheet format dictated by Amy Kasa,
where users will see the details of receipts related to the trip and a
summary of the work order stop fee charges with prices adjusted downward
to compensate for the receipt charges.

This is some wacky stuff.

History:

	6/26/2013	JPB	Created 
	9/18/2013	JPB	Use of RiteAidApprovalPrice is a problem - users can't edit it.
					But they CAN edit the same data in ResourceClassBundle. So switch to it.

Sample:
	sp_rite_aid_prebilling_worksheet 19388
	go
	sp_rite_aid_prebilling_worksheet_v2 19388


SELECT * FROM workorderdetail where workorder_id = 4158700 and company_id = 15 and profit_ctr_id = 0
SELECT * FROM ResourceClassBundle where state = 'PA'

select top 100 woh.trip_id, wod.* from workorderdetail wod
inner join workorderheader woh on wod.workorder_id = woh.workorder_id
and wod.company_id = woh.company_id and wod.profit_ctr_id = woh.profit_ctr_id
where woh.customer_id = 14231
and wod.resource_class_code in (
SELECT resource_class_code FROM ResourceClassBundle  where stop_fee_description not like '%off schedule%'
)
order by woh.trip_id desc

************************************************************************* */

if OBJECT_ID('tempdb..#keys') is not null drop table #keys
if OBJECT_ID('tempdb..#ReceiptTransporter') is not null drop table #ReceiptTransporter
if OBJECT_ID('tempdb..#detail') is not null drop table #detail
if OBJECT_ID('tempdb..#summary') is not null drop table #summary

-- Create a #Keys table to hold the id info and other useful data for records to include.
create table #Keys(
	receipt_id				int
	, line_id				int
	, resource_type			varchar(15)
	, company_id			int
	, profit_ctr_id			int
	, trans_source			char(1)
	, billing_status_code	char(1)
	, pickup_date			datetime
	, billing_date			datetime
	, detail_weight			float
	, workorder_id			int
	, workorder_company_id	int
	, workorder_profit_ctr_id	int
	, trip_id				int
)

-- Fill #Keys with data from 
-- Work Orders using TSDFApprovals
INSERT #Keys
SELECT DISTINCT
    w.workorder_id as receipt_id,
    billing.line_id as line_id,
    d.resource_type as resource_type,
    w.company_id,
    w.profit_ctr_id,
    'W' as trans_source,
    billing.status_code as billing_status_code,
    coalesce(wos.date_act_arrive, w.start_date) as pickup_date,
    w.start_date as billing_date
    , null as detail_weight
    , null as workorder_id
    , null as workorder_company_id
    , null as workorder_profit_ctr_id
    , trip_id
FROM WorkOrderHeader w (nolock) 
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
WHERE 1=1
AND w.trip_id = @trip_id
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)



-- Pre-Receipt Select info...
    select distinct
        r.receipt_id,
        r.line_id,
        r.company_id,
        r.profit_ctr_id,
        wo.workorder_id as receipt_workorder_id,
        wo.company_id as workorder_company_id,
        wo.profit_ctr_id as workorder_profit_ctr_id,
        isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
        wo.trip_id
 	into #ReceiptTransporter
    from workorderheader wo (nolock) 
    inner join billinglinklookup bll  (nolock) on
        wo.company_id = bll.source_company_id
        and wo.profit_ctr_id = bll.source_profit_ctr_id
        and wo.workorder_id = bll.source_id
    inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id
        and bll.profit_ctr_id = r.profit_ctr_id
        and bll.company_id = r.company_id
    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
        and rt1.profit_ctr_id = r.profit_ctr_id
        and rt1.company_id = r.company_id
        and rt1.transporter_sequence_id = 1
    where
        wo.trip_id = @trip_id

-- Fill #Keys with data from 
-- Receipts
INSERT #Keys
SELECT DISTINCT
    r.receipt_id as receipt_id,
    billing.line_id as line_id,
    NULL as resource_type,
    r.company_id,
    r.profit_ctr_id,
    'R' as trans_source,
    billing.status_code as billing_status_code,
    wrt.service_date AS pickup_date,
    r.receipt_date as billing_date
    , null as detail_weight
	, wrt.receipt_workorder_id
	, wrt.workorder_company_id
	, wrt.workorder_profit_ctr_id
	, wrt.trip_id
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN #ReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
INNER JOIN ProfitCenter pr (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
    on r.profile_id = pqa.profile_id 
    and r.company_id = pqa.company_id 
    and r.profit_ctr_id = pqa.profit_ctr_id 
LEFT OUTER JOIN DisposalService ds  (nolock)
    on pqa.disposal_service_id = ds.disposal_service_id
left outer join Billing billing	(nolock) on r.receipt_id = billing.receipt_id
	and billing.trans_source = 'R'
	and R.company_id = billing.company_id
	and r.profit_ctr_ID = billing.profit_ctr_id
	and r.line_id = billing.line_id
	and rp.price_id = billing.price_id
WHERE 
r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
-- AND ISNULL(r.trans_type, '') = 'D'
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

-- Fill #Detail with per-approval weights, prices etc.
select 
trip_id
, r.company_id, r.profit_ctr_id, r.receipt_id
, workorder_id, workorder_company_id, workorder_profit_ctr_id
, row_number() over (partition by site_code order by g.site_code, r.approval_code) as row_number
, g.site_code
, g.generator_state
, r.approval_code
, raap.resource_class_code
, raap.stop_fee_description
, raap.category
, p.approval_desc
, k.detail_weight
, raap.price_per_pound
, raap.weight_included
, raap.stop_fee_price
, round(raap.price_per_pound * k.detail_weight, 2) as weight_charge
into #detail
from Receipt r (nolock)
inner join #keys k
	on k.receipt_id = r.receipt_id
	and k.line_id = r.line_id
	and k.company_id = r.company_id
	and k.profit_ctr_id = r.profit_ctr_id
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
inner join generator g on r.generator_id = g.generator_id
inner join profile p on r.profile_id = p.profile_id
left outer join (
	SELECT DISTINCT
		p.customer_id
		, rcb.state
		, rcb.resource_class_code
		, rcb.stop_fee_description
		, pqa.profile_id
		, pqa.approval_code
		, case when rcb.pharmacy_flag = 'F' then 'FE' else 'Rx' end as category
		, rcb.unit_price as price_per_pound
		, rcb.pounds_included as weight_included
		, rcb.stop_fee_price
	FROM profile p (nolock)
	INNER JOIN ProfileQuoteApproval pqa (nolock)
		on p.profile_id = pqa.profile_id
	INNER JOIN ProfileQuoteDetail pqd (nolock)
		on pqa.profile_id = pqd.profile_id
		and pqa.quote_id = pqd.quote_id
		and pqa.company_id = pqd.company_id
		and pqa.profit_ctr_id = pqd.profit_ctr_id
	INNER JOIN ResourceClassBundle rcb 
		on pqd.resource_class_code = RCB.resource_class_code -- and pqd.bill_unit_code = rcb.bill_unit_code
		and rcb.effective_date = (
			select max(effective_date) from ResourceClassBundle b2
			where b2.resource_class_code = rcb.resource_class_code
			and b2.bill_unit_code = rcb.bill_unit_code
			and effective_date <= getdate()
		)
	) raap
	on raap.customer_id = r.customer_id
	and raap.approval_code = r.approval_code
	and raap.state = g.generator_state
	and raap.resource_class_code in (Select resource_class_code from workorderdetail wod (nolock)
		where wod.workorder_id = k.workorder_id
		and wod.company_id = k.workorder_company_id
		and wod.profit_ctr_id = k.workorder_profit_ctr_id
		and wod.bill_rate > 0
		and wod.resource_type = 'O'
	)
where k.trans_source = 'R'

-- Create a blank (ish) #Summary table from the distinct site codes, states, and price categories
-- defined for Rite Aid from the #detail set + a superset of the possible categories
-- plus data from the RiteAidApprovalPrice table that holds all their unique categories, prices, included weights, etc.

select distinct
site_code
, generator_state
, d.resource_class_code
, cat.category
, max(isnull(raap.stop_fee_price, 0)) as stop_fee_price
, convert(float, 0.000000000000000) as sum_detail_weight
, max(isnull(raap.price_per_pound, 0)) as price_per_pound
, convert(money, 0.00) as sum_weight_charge
, max(isnull(raap.weight_included, 0)) as weight_included 
, convert(money, 0.00) as stop_fee_charge
into #summary	
from #detail d
cross join (select 'FE' as category union select 'Rx') cat
/*
inner join RiteAidApprovalPrice raap (nolock)	
	on cat.category = raap.category
	and d.generator_state = raap.state
*/	
left outer join (
	SELECT DISTINCT
		p.customer_id
		, rcb.state
		, rcb.resource_class_code
		, pqa.profile_id
		, pqa.approval_code
		, case when rcb.pharmacy_flag = 'F' then 'FE' else 'Rx' end as category
		, rcb.unit_price as price_per_pound
		, rcb.pounds_included as weight_included
		, rcb.stop_fee_price
	FROM profile p (nolock)
	INNER JOIN ProfileQuoteApproval pqa (nolock)
		on p.profile_id = pqa.profile_id
	INNER JOIN ProfileQuoteDetail pqd (nolock)
		on pqa.profile_id = pqd.profile_id
		and pqa.quote_id = pqd.quote_id
		and pqa.company_id = pqd.company_id
		and pqa.profit_ctr_id = pqd.profit_ctr_id
	INNER JOIN ResourceClassBundle rcb 
		on pqd.resource_class_code = RCB.resource_class_code -- and pqd.bill_unit_code = rcb.bill_unit_code
		and rcb.effective_date = (
			select max(effective_date) from ResourceClassBundle b2
			where b2.resource_class_code = rcb.resource_class_code
			and b2.bill_unit_code = rcb.bill_unit_code
			and effective_date <= getdate()
		)
	) raap
	on cat.category = raap.category
	and d.resource_class_code = raap.resource_class_code
	and d.generator_state = raap.state
where isnull(raap.stop_fee_price, 0) > 0
group by
site_code
, generator_state
, cat.category
, d.resource_class_code

-- Update #summary from #detail to sum the weights per site_code & category combination.
update #summary set
 sum_detail_weight = isnull((select sum(isnull(detail_weight, 0)) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.resource_class_code = s.resource_class_code), 0)
from #summary s

-- Update #summary to calculate the summary weight charges
-- Special handling: If the weight of a site's category waste exceeds the maximum included, use the max included value instead of the actual weight.
-- Otherwise (where the weight <= max included weight) just use the regular price * weight
-- Found out we have to do this is a subquery or the rounding gets weirdly wrong.
update #summary set
sum_weight_charge = case when sum_detail_weight > weight_included then
	round(isnull(weight_included * price_per_pound, 0), 2)
else
	isnull((select sum(round(isnull(detail_weight, 0) * isnull(price_per_pound, 0), 2)) from #detail d2 where d2.site_code = s.site_code and d2.category = s.category and d2.resource_class_code = s.resource_class_code), 0)
end
from #summary s

-- Update #summary now that we know the weights & weight charges... adjust the stop fee charges downward to compensate
-- for the charges from the receipt.  Told you this was wacky.
update #summary set
stop_fee_charge = stop_fee_price - sum_weight_charge

/*
insert #summary
select distinct
s.site_code, s.generator_state, s.resource_class_code, cat.category, raap.stop_fee_price, 0 as sum_detail_weight, 0 as price_per_pound, 0 as sum_weight_charge, 0 as weight_included, raap.stop_fee_price as stop_fee_charge
from #summary s
cross join (select 'FE' as category union select 'Rx') cat
cross join (
	SELECT DISTINCT
		p.customer_id
		, rcb.state
		, rcb.resource_class_code
		, pqa.profile_id
		, pqa.approval_code
		, case when rcb.pharmacy_flag = 'F' then 'FE' else 'Rx' end as category
		, rcb.unit_price as price_per_pound
		, rcb.pounds_included as weight_included
		, rcb.stop_fee_price
	FROM profile p (nolock)
	INNER JOIN ProfileQuoteApproval pqa (nolock)
		on p.profile_id = pqa.profile_id
	INNER JOIN ProfileQuoteDetail pqd (nolock)
		on pqa.profile_id = pqd.profile_id
		and pqa.quote_id = pqd.quote_id
		and pqa.company_id = pqd.company_id
		and pqa.profit_ctr_id = pqd.profit_ctr_id
	INNER JOIN ResourceClassBundle rcb 
		on pqd.resource_class_code = RCB.resource_class_code -- and pqd.bill_unit_code = rcb.bill_unit_code
		and rcb.effective_date = (
			select max(effective_date) from ResourceClassBundle b2
			where b2.resource_class_code = rcb.resource_class_code
			and b2.bill_unit_code = rcb.bill_unit_code
			and effective_date <= getdate()
		)
		where rcb.state = 'PA' and rcb.pharmacy_flag = 'F'
	) raap
where 1=1
and s.generator_state = raap.state
and cat.category = raap.category
and not exists
	(select 1 from #summary where site_code = s.site_code and category = cat.category)	
*/ 

-- Output the detail info (all of it) and for every 1st row for a particular site_code, also include the summary info.
select 
d.trip_id
, d.workorder_id
, d.workorder_company_id
, d.workorder_profit_ctr_id
, d.receipt_id
, d.company_id as receipt_company_id
, d.profit_ctr_id as receipt_profit_ctr_id
, d.site_code
, d.generator_state
, d.approval_code
, d.stop_fee_description
, d.category
, d.approval_desc
, d.detail_weight
, d.price_per_pound
, d.weight_charge

, case when d.row_number = 1 then isnull((select max(sum_detail_weight) from #summary where site_code = d.site_code and category = 'FE' ), 0) else null end as FRONT_END_total_weight
, case when d.row_number = 1 then isnull((select max(sum_detail_weight) from #summary where site_code = d.site_code and category = 'Rx' ), 0) else null end as RX_total_weight
, case when d.row_number = 1 then isnull((select max(stop_fee_charge) from #summary where site_code = d.site_code and category = 'FE'), 0) else null end as FRONT_END_stop_fee_charge
, case when d.row_number = 1 then isnull((select max(stop_fee_charge) from #summary where site_code = d.site_code and category = 'Rx'), 0) else null end as RX_stop_fee_charge

from #detail d
where d.category is not null
order by d.site_code, d.row_number


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_worksheet_v2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_worksheet_v2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_worksheet_v2] TO [EQAI]
    AS [dbo];

