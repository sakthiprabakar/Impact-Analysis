
CREATE PROCEDURE sp_rite_aid_prebilling_validation
	@StartDate datetime,
	@EndDate datetime,
	@copc_list varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers
	@permission_id int,
	@debug int = 0
AS
/* *************************************************************************
sp_rite_aid_prebilling_validation

Runs against Rite Aid receipts and work orders to look for problems and reports them.

History:

	6/26/2013	JPB	Created 
	9/18/2013	JPB	Use of RiteAidApprovalPrice is a problem - users can't edit it.
					But they CAN edit the same data in ResourceClassBundle. So switch to it.
	1/29/2014	JPB	Added handling of non-billed receipts so users can see the problem
					Previously those workorders just did not appear in the report.					
	8/22/2014 - JPB	- GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0

	10/07/2014 - JPB - Massively rewritten so it uses Rite-Aid specific logic and can look
					for problems unique to Rite Aid's "special" invoice logic.
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

Sample:
	exec sp_rite_aid_prebilling_validation 
		@StartDate='2014-09-01 00:00:00',
		@EndDate='2015-10-31 00:00:00',
		@copc_list=N'2|0, 3|0, 3|2, 3|3, 12|0, 12|1, 12|2, 12|3, 12|4, 12|5, 12|7, 14|0, 14|1, 14|2, 14|3, 14|5, 14|6, 14|9, 14|10, 14|11, 14|13, 14|14, 15|0, 15|2, 15|3, 15|4, 15|6, 15|7, 16|0, 18|0, 21|0, 21|1, 21|2, 21|3, 22|0, 22|1, 22|2, 23|0, 24|0, 25|0, 25|4, 26|0, 27|0, 28|0, 29|0, 32|0',
		@user_code=N'JONATHAN',
		@contact_id=-1,
		@permission_id = 277,
		@debug = 0


************************************************************************* */

-- declare 	@StartDate datetime = '7/1/2014', @EndDate datetime = '10/31/2014', @copc_list varchar(500) = '15|0,15|4', @user_code varchar(100) = 'JONATHAN', @contact_id int = NULL, @permission_id int= 277, 	@debug int = 0

set nocount on

declare @customer_id int = 14231

declare @timer datetime = getdate()

IF @user_code = ''
	set @user_code = NULL
	
-- Fix/Set EndDate's time.
	if isnull(@EndDate,'') <> ''
		if datepart(hh, @EndDate) = 0 set @EndDate = @EndDate + 0.99999
	
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)
	
INSERT @tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
		FROM 
			SecuredProfitCenter secured_copc
		INNER JOIN (
			SELECT 
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list) 
			where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			and secured_copc.permission_id = @permission_id
			and secured_copc.user_code = @user_code

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
	, submitted_flag		char(1)
	, source_status			char(1)
	, source_alt_status	char(1)
	, billing_status_code	char(1)
	, pickup_date			datetime
	, billing_date			datetime
	, detail_weight			float
	, workorder_id			int
	, workorder_company_id	int
	, workorder_profit_ctr_id	int
	, linked_flag			char(1)
	, trip_id				int
)

-- Fill #Keys with data from 
-- Work Orders
INSERT #Keys
SELECT DISTINCT
    w.workorder_id as receipt_id,
    billing.line_id as line_id,
    d.resource_type as resource_type,
    w.company_id,
    w.profit_ctr_id,
    'W' as trans_source,
	w.submitted_flag,
	w.workorder_status,
	null as source_alt_status,
    billing.status_code as billing_status_code,
    coalesce(wos.date_act_arrive, w.start_date) as pickup_date,
    w.start_date as billing_date
    , null as detail_weight
    , null as workorder_id
    , null as workorder_company_id
    , null as workorder_profit_ctr_id
    , case when not exists (select 1 from billinglinklookup where source_id = w.workorder_id and source_company_id = w.company_id and source_profit_ctr_id = w.profit_ctr_id) then 0 else 1 end as linked_flag
    , trip_id
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
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
AND w.customer_id = @customer_id
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) between @StartDate and  @EndDate
AND w.workorder_status NOT IN ('V','X','T') 
AND d.bill_rate > 0
AND w.trip_id is not null
UNION
SELECT DISTINCT
    w.workorder_id as receipt_id,
    billing.line_id as line_id,
    d.resource_type as resource_type,
    w.company_id,
    w.profit_ctr_id,
    'W' as trans_source,
    w.submitted_flag,
    w.workorder_status,
    null as source_alt_status,
    billing.status_code as billing_status_code,
    coalesce(wos.date_act_arrive, w.start_date) as pickup_date,
    w.start_date as billing_date
    , null as detail_weight
    , null as workorder_id
    , null as workorder_company_id
    , null as workorder_profit_ctr_id
    , case when not exists (select 1 from billinglinklookup where source_id = w.workorder_id and source_company_id = w.company_id and source_profit_ctr_id = w.profit_ctr_id) then 0 else 1 end as linked_flag
    , trip_id
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) 
	ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
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
AND w.generator_id in (select generator_id from customergenerator (nolock) where customer_id = @customer_id)
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
-- AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) < @EndDate
AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) between @StartDate and  @EndDate
AND w.workorder_status NOT IN ('V','X','T') 
AND d.bill_rate > 0
AND w.trip_id is not null



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
    from #keys k
    inner join workorderheader wo (nolock) 
		on k.receipt_id = wo.workorder_id
		and k.company_id = wo.company_id
		and k.profit_ctr_id = wo.profit_ctr_id
		and k.trans_source = 'W'
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
    r.submitted_flag,
    r.receipt_status,
    r.fingerpr_status,
    billing.status_code as billing_status_code,
    wrt.service_date AS pickup_date,
    r.receipt_date as billing_date
    , null as detail_weight
	, wrt.receipt_workorder_id
	, wrt.workorder_company_id
	, wrt.workorder_profit_ctr_id
	, 'T' as linked_flag
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
and f.detail_weight is null
and exists (
	select 1
	from ReceiptDetailItem rdi (nolock)
	where f.receipt_id = rdi.receipt_id
	and f.line_id = rdi.line_id
	and f.company_id = rdi.company_id
	and f.profit_ctr_id = rdi.profit_ctr_id
)


-- Update #Keys info with the sums of weights from Receipt.line_weight where not set yet
update #Keys set detail_weight = 
	(
		select
		line_weight
		from Receipt r (nolock)
		where f.receipt_id = r.receipt_id
		and f.line_id = r.line_id
		and f.company_id = r.company_id
		and f.profit_ctr_id = r.profit_ctr_id
	)
from #Keys f
where f.trans_source = 'R'
and f.detail_weight is null


-- Fill #Detail with per-approval weights, prices etc.
select 
k.trip_id
, k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id
, k.workorder_id, k.workorder_company_id, k.workorder_profit_ctr_id
, row_number() over (partition by site_code order by g.site_code, r.approval_code) as row_number
, g.site_code
, g.generator_state
, r.profile_id
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
, k.billing_status_code
, k.submitted_flag
, k.source_status
, k.source_alt_status
into #detail
from #keys k
inner join Receipt r (nolock)
	on k.receipt_id = r.receipt_id
	and k.line_id = r.line_id
	and k.company_id = r.company_id
	and k.profit_ctr_id = r.profit_ctr_id
	and k.trans_source = 'R'
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


/* VALIDATION */

create table #tmp_validation (
	problem			varchar(max),
	source			varchar(max),
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	line_id			int,
	workorder_resource_type char(1),
	submitted_flag	char(1),
	source_status	char(1),
	source_alt_status	char(1)
)


INSERT #tmp_validation
SELECT DISTINCT
	'Invalid Manifest Number: ' + r.manifest as problem,
	'R' as trans_source,
	d.company_id,
	d.profit_ctr_id,
	d.receipt_id,
	d.line_id as line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d 
	INNER JOIN receipt r (nolock)
		ON r.receipt_id = d.receipt_id
		AND r.line_id = d.line_id
		AND r.company_id = d.company_id
		AND r.profit_ctr_id = d.profit_ctr_id
WHERE
	(
		len(r.manifest) <> 12
		or
		isnumeric(left(r.manifest, 9)) = 0
		or
		isnumeric(right(r.manifest, 3)) = 1
	)
order by d.company_id, d.profit_ctr_id, d.receipt_id, d.line_id

INSERT #tmp_validation
SELECT distinct
	'Receipt and Workorder not billed on same invoice: R'
	+ isnull(convert(varchar(2), bll.company_id), 0) + '-'
	+ isnull(convert(varchar(2), bll.profit_ctr_id), 0) + ':'
	+ isnull(convert(varchar(20), bll.receipt_id), 0) + ' vs W '
	+ convert(varchar(2), k.company_id) + '-'
	+ convert(varchar(2), k.profit_ctr_id) + ':'
	+ convert(varchar(20), k.receipt_id) as problem,
	'W' as trans_source,
	k.company_id,
	k.profit_ctr_id,
	k.receipt_id,
	null line_id,
	null as workorder_resource_type,
	k.submitted_flag,
	k.source_status,
	k.source_alt_status
FROM #keys k
	inner join billinglinklookup bll (nolock) on k.receipt_id = bll.source_id and k.company_id = bll.source_company_id and k.profit_ctr_id = bll.source_profit_ctr_id 
		and k.trans_source = 'W' AND bll.link_required_flag <> 'E'
	inner join receipt r (nolock) on bll.receipt_id = r.receipt_id and k.line_id = r.line_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
	inner join workorderheader w (nolock) on bll.source_id = w.workorder_id and bll.source_company_id = r.company_id and bll.source_profit_ctr_id = w.profit_ctr_id
	LEFT OUTER JOIN billing WB (nolock) ON k.receipt_id = WB.receipt_id and k.company_id = WB.company_id AND k.profit_ctr_id = WB.profit_ctr_id and k.trans_source = 'W' and WB.status_code = 'I'
	LEFT OUTER JOIN billing RB (nolock) ON bll.receipt_id = RB.receipt_id and bll.company_id = RB.company_id AND bll.profit_ctr_id = RB.profit_ctr_id and RB.status_code = 'I'
WHERE
	(
		(WB.invoice_id is not null OR RB.invoice_id is not null)
		AND
		(NOT (WB.invoice_id is null AND RB.invoice_id is null))
	)
	AND (
		isnull(WB.invoice_id, 0) <> isnull(RB.invoice_id, 1)
--		OR (wb.status_code <> rb.status_code)
	)


INSERT #tmp_validation
SELECT distinct
	'Arrive Date before Workorder Start Date: '
	+ convert(varchar(2), d.workorder_company_id) + '-'
	+ convert(varchar(2), d.workorder_profit_ctr_id) + ':'
	+ convert(varchar(20), d.workorder_id) + ' : arr = '
	+ convert(varchar(20), wos.date_act_arrive) + ' vs start = '
	+ convert(varchar(20), woh.start_date) as problem,
	'W' as trans_source,
	d.workorder_company_id,
	d.workorder_profit_ctr_id,
	d.workorder_id,
	null line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d
	inner join WorkOrderHeader woh (nolock)
		ON woh.workorder_id = d.workorder_id
		and woh.company_id = d.workorder_company_id
		and woh.profit_ctr_id = d.workorder_profit_ctr_id	
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = d.workorder_id
		and wos.company_id = d.workorder_company_id
		and wos.profit_ctr_id = d.workorder_profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive < woh.start_date


INSERT #tmp_validation
SELECT distinct
	'Arrive Date after Depart Date: '
	+ convert(varchar(2), d.workorder_company_id) + '-'
	+ convert(varchar(2), d.workorder_profit_ctr_id) + ':'
	+ convert(varchar(20), d.workorder_id) + ' : arr = '
	+ convert(varchar(20), wos.date_act_arrive) + ' vs dep = '
	+ convert(varchar(20), wos.date_act_depart) as problem,
	'W' as trans_source,
	d.workorder_company_id,
	d.workorder_profit_ctr_id,
	d.workorder_id,
	null line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = d.workorder_id
		and wos.company_id = d.workorder_company_id
		and wos.profit_ctr_id = d.workorder_profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive > wos.date_act_depart



INSERT #tmp_validation
SELECT DISTINCT
	'Receipt dated ' + convert(varchar(10), r.receipt_date, 121) + ' not Priced '
	+ convert(varchar(2), d.company_id) + '-'
	+ convert(varchar(2), d.profit_ctr_id) + ':'
	+ convert(varchar(20), d.receipt_id) as problem,
	'R' as trans_source,
	d.company_id,
	d.profit_ctr_id,
	d.receipt_id,
	d.line_id as line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d 
	INNER JOIN receipt r (nolock)
		ON r.receipt_id = d.receipt_id
		AND r.line_id = d.line_id
		AND r.company_id = d.company_id
		AND r.profit_ctr_id = d.profit_ctr_id
WHERE
	NOT EXISTS (
		select 1 from ReceiptPrice  (nolock)
			WHERE receipt_id = r.receipt_id
			AND line_id = r.line_id
			AND company_id = r.company_id
			AND profit_ctr_id = r.profit_ctr_id
			AND price > 0
	)	
order by d.company_id, d.profit_ctr_id, d.receipt_id, d.line_id


INSERT #tmp_validation
SELECT DISTINCT
	'Receipt weight missing or 0 - Receipt '
	+ convert(varchar(2), d.company_id) + '-'
	+ convert(varchar(2), d.profit_ctr_id) + ':'
	+ convert(varchar(20), d.receipt_id) + ' line '
	+ convert(varchar(20), d.line_id) as problem,
	'R' as trans_source,
	d.company_id,
	d.profit_ctr_id,
	d.receipt_id,
	d.line_id as line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d 
where isnull(d.detail_weight, 0) = 0
order by d.company_id, d.profit_ctr_id, d.receipt_id, d.line_id

-- This searches for category that is null.  Category should be FE or Rx, which is determined by the work order's resource class
-- for the stop fee being present, so the receipt's weight can be totaled in a category.  When category is null, report it.
INSERT #tmp_validation
SELECT DISTINCT
	'Uncategorized Receipt weight (Approval ' + isnull(d.approval_code, '') + ') - Perhaps missing valid stop fee on WO: '
	+ convert(varchar(2), d.workorder_company_id) + '-'
	+ convert(varchar(2), d.workorder_profit_ctr_id) + ':'
	+ convert(varchar(20), d.workorder_id) as problem,
	'R' as trans_source,
	d.company_id,
	d.profit_ctr_id,
	d.receipt_id,
	d.line_id as line_id,
	null as workorder_resource_type,
	d.submitted_flag,
	d.source_status,
	d.source_alt_status
FROM #detail d 
left join profilequotedetail pqd
	on d.profile_id = pqd.profile_id
	and d.company_id = pqd.company_id
	and d.profit_ctr_id = pqd.profit_ctr_id
	and d.workorder_company_id = pqd.resource_class_company_id
where d.category is null and pqd.resource_class_code is not null
order by d.company_id, d.profit_ctr_id, d.receipt_id, d.line_id

INSERT #tmp_validation
SELECT DISTINCT
	'Approvals on Receipt '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + ' differ from linked Work Order '
	+ convert(varchar(2), t.workorder_company_id) + '-'
	+ convert(varchar(2), t.workorder_profit_ctr_id) + ':'
	+ convert(varchar(20), t.workorder_id) + ' -- '
	+ dbo.fn_compare_approvals_wtor(t.workorder_id, t.workorder_company_id, t.workorder_profit_ctr_id) as problem,
	t.trans_source,
	t.workorder_company_id,
	t.workorder_profit_ctr_id,
	t.workorder_id,
	null as line_id,
	null as workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status
FROM
	#Keys t
WHERE
	t.trans_source = 'R'
	AND dbo.fn_compare_approvals_wtor(t.workorder_id, t.workorder_company_id, t.workorder_profit_ctr_id) <> ''

-- Check for records not submitted yet. - receipts
INSERT #tmp_validation
SELECT DISTINCT
	case k.trans_source when 'R' then 'Receipt' when 'W' then 'Workorder' else k.trans_source end + ' not submitted: '
	+ convert(varchar(2), k.company_id) + '-'
	+ convert(varchar(2), k.profit_ctr_id) + ':'
	+ convert(varchar(20), k.receipt_id) as problem,
	k.trans_source,
	k.company_id,
	k.profit_ctr_id,
	k.receipt_id,
	k.line_id as line_id,
	null as workorder_resource_type,
	k.submitted_flag,
	k.source_status,
	k.source_alt_status
FROM #Keys k
	where isnull(submitted_flag, 'F') <> 'T'
	and k.trans_source = 'R'
    and 0 < (
		select sum(
			case when isnull(rp.total_extended_amt, 0) > 0 
				then isnull(rp.total_extended_amt, 0)
				else 
					case when isnull(rp.total_extended_amt, 0) = 0 and rp.print_on_invoice_flag = 'T' 
						then 1 
						else isnull(rp.total_extended_amt, 0)
					end 
			end
		)
		from receiptprice rp (nolock)
		where rp.receipt_id = k.receipt_id
		and rp.company_id = k.company_id
		and rp.profit_ctr_id = k.profit_ctr_id
    )

-- Check for records not submitted yet. - work orders
INSERT #tmp_validation
SELECT DISTINCT
	case k.trans_source when 'R' then 'Receipt' when 'W' then 'Workorder' else k.trans_source end + ' not submitted: '
	+ convert(varchar(2), k.company_id) + '-'
	+ convert(varchar(2), k.profit_ctr_id) + ':'
	+ convert(varchar(20), k.receipt_id) as problem,
	k.trans_source,
	k.company_id,
	k.profit_ctr_id,
	k.receipt_id,
	k.line_id as line_id,
	null as workorder_resource_type,
	k.submitted_flag,
	k.source_status,
	k.source_alt_status
FROM #Keys k
	where isnull(submitted_flag, 'F') <> 'T'
	and trans_Source = 'W'
    and 0 < (
		select sum(isnull(wh.total_price, 0))
		from workorderheader wh (nolock)
		where wh.workorder_id = k.receipt_id
		and wh.company_id = k.company_id
		and wh.profit_ctr_id = k.profit_ctr_id
    )

INSERT #tmp_validation
SELECT
	case k.trans_source when 'R' then 'Receipt' when 'W' then 'Workorder' else k.trans_source end + ' not billed, older than ' + convert(varchar(12), @StartDate, 101) + ' : '
	+ convert(varchar(2), k.company_id) + '-'
	+ convert(varchar(2), k.profit_ctr_id) + ':'
	+ convert(varchar(20), k.receipt_id) as problem,
	k.trans_source,
	k.company_id,
	k.profit_ctr_id,
	k.receipt_id,
	k.line_id,
	null, -- k.workorder_resource_type,
	k.submitted_flag,
	k.source_status,
	k.source_alt_status
FROM #Keys k
	where isnull(submitted_flag, 'F') <> 'T'
	and pickup_date < @StartDate
	
INSERT #tmp_validation
SELECT
	case t.trans_source when 'R' then 'Receipt' when 'W' then 'Workorder' else t.trans_source end + ' not linked : '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) as problem,
	t.trans_source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	null, -- as t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status
FROM #keys t
	where isnull(linked_flag, 'F') <> 'T'
	and trans_source <> 'O'
	and pickup_date between @StartDate and @EndDate
		
set nocount off

if @debug >= 10 select * from #tmp_flash

-- OUTPUT:
SELECT DISTINCT 
	problem,
	source,
	company_id, 
	profit_ctr_id, 
	receipt_id,
--	line_id,
--	workorder_resource_type,
	submitted_flag,
	source_status,
	source_alt_status
FROM 
	#tmp_validation
ORDER BY
	company_id,
	profit_ctr_id,
	source,
	receipt_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_prebilling_validation] TO [EQAI]
    AS [dbo];

