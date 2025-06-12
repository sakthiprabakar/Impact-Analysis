-- drop proc sp_ContactCORStatsGeneratorTotal_Maintain

go

create proc sp_ContactCORStatsGeneratorTotal_Maintain (
	@days_back	int = 1095 /* 365 X 3    On 3/10/20, this took 7m to run */
)
as
begin

SET Transaction isolation level read uncommitted  

-- declare @days_back	int = 1095

-- SELECT  COUNT(*)  FROM    #foo
-- 799301
-- drop table #foo

-- This version creates a #foo record for every detail line X each contact with access to it. BIG.
select /* h.contact_id, */ h.customer_id, h.generator_id
, /* h.prices, */ 'W' as trans_source
, h.workorder_id
, d.sequence_id
, h.profit_ctr_id
, h.company_id

, profile_id = convert(int, null)
, d.tsdf_approval_id
, ta.wastetype_id
, ta.treatment_process_id
, ta.disposal_service_id

, ta.waste_desc waste_stream
, isnull(w.offschedule_service_flag, 'F') as offschedule_service_flag, 
convert(date, isnull(h.service_date, h.start_date)) as _date
, convert(char(1), 'F') as haz_flag
-- , case when exists (select top 1 1 from wastecode wc join WorkOrderWasteCode wwc on wwc.waste_code_uid = wc.waste_code_uid where wwc.workorder_id = h.workorder_id and wwc.company_id = h.company_id and wwc.profit_ctr_id = h.profit_ctr_id and wwc.sequence_id = d.sequence_ID and wc.haz_flag = 'T' and wc.waste_code_origin = 'F') then 'H' else 'N' end as haz_flag
, convert(datetime, null) as date_modified
--, max(isnull(d.date_modified, d.date_added)) as date_modified

into #foo
from ContactCORWorkorderHeaderBucket h
join workorderheader w on h.workorder_id = w.workorder_id and h.company_id = w.company_id and h.profit_ctr_id = w.profit_ctr_id
join workorderdetail d on h.workorder_id = d.workorder_id and h.company_id = d.company_id and h.profit_ctr_id = d.profit_ctr_id and d.resource_type = 'D' and d.bill_rate > -2
join tsdf t on d.tsdf_code = t.tsdf_code and t.eq_flag = 'F' and t.tsdf_code <> 'UNDEFINED'
join tsdfapproval ta on d.tsdf_approval_id = ta.tsdf_approval_id
WHERE isnull(h.service_date, h.start_date) > getdate()-@days_back
and h.invoice_date <= getdate()
-- and w.workorder_status not in ('V', 'X', 'T')
and exists (
	select top 1 1 from billing b where b.receipt_id = h.workorder_id and b.company_id = h.company_id and b.profit_ctr_id = h.profit_ctr_id and b.trans_source = 'W' and b.status_code = 'I'
)
and h.contact_id not in (select contact_id from CORContact WHERE web_userid = 'all_customers')
--GROUP BY 
--/* h.contact_id, */ w.customer_id, w.generator_id
--, h.workorder_id
--, d.sequence_id
--, h.profit_ctr_id
--, h.company_id

--, d.tsdf_approval_id
--, ta.wastetype_id
--, ta.treatment_process_id
--, ta.disposal_service_id

--, ta.waste_stream
--, isnull(w.offschedule_service_flag, 'F')
--, convert(date, isnull(h.service_date, h.start_date))
union
select /* h.contact_id, */ h.customer_id
, h.generator_id
, /* h.prices, */ 'R' as trans_source
, h.receipt_id
, r.line_id
, h.profit_ctr_id
, h.company_id
, r.profile_id
, convert(int, null) as tsdf_approval_id
, t.wastetype_id
, t.treatment_process_id
, t.disposal_service_id
, p.approval_desc
, 'F' as offschedule_service_flag, 
convert(date, isnull(h.pickup_date, h.receipt_date)) as _date
, convert(char(1), 'F') as haz_flag
-- , case when exists (select top 1 1 from wastecode wc join ReceiptWasteCode rwc on rwc.waste_code_uid = wc.waste_code_uid where rwc.receipt_id = h.receipt_id and rwc.company_id = h.company_id and rwc.profit_ctr_id = h.profit_ctr_id and rwc.line_id = r.line_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F') then 'H' else 'N' end as haz_flag
, convert(datetime, null) as date_modified
-- , max(isnull(r.date_modified, r.date_added)) as date_modified
from ContactCORReceiptBucket h
join receipt r on h.receipt_id = r.receipt_id and h.company_id = r.company_id and h.profit_ctr_id = r.profit_ctr_id and r.trans_mode = 'I' and r.trans_type = 'D'
join profile p on r.profile_id = p.profile_id
join treatment t on r.treatment_id = t.treatment_id and r.company_id = t.company_id and r.profit_ctr_id = t.profit_ctr_id
WHERE isnull(h.pickup_date, h.receipt_date) > getdate()-@days_back
and h.invoice_date <= getdate()
-- and r.receipt_status = 'A'
-- and r.submitted_flag = 'T'
and exists (
	select top 1 1 from billing b where b.receipt_id = r.receipt_id and b.company_id = r.company_id and b.profit_ctr_id = r.profit_ctr_id and b.trans_source = 'R'
)
and h.contact_id <> (select contact_id from CORContact WHERE web_userid = 'all_customers')
--GROUP BY 
--r.customer_id
--, r.generator_id
--, h.receipt_id
--, r.line_id
--, h.profit_ctr_id
--, h.company_id
--, r.profile_id
--, t.wastetype_id
--, t.treatment_process_id
--, t.disposal_service_id
--, p.approval_desc
--, convert(date, isnull(h.pickup_date, h.receipt_date))



update #foo
set haz_flag = 'T'
from #foo h
where h.trans_source = 'W'
and exists (
	select top 1 1 
	from wastecode wc 
	join WorkOrderWasteCode wwc on wwc.waste_code_uid = wc.waste_code_uid 
	and wc.haz_flag = 'T' 
	and wc.waste_code_origin = 'F'
	where wwc.workorder_id = h.workorder_id 
	and wwc.company_id = h.company_id 
	and wwc.profit_ctr_id = h.profit_ctr_id 
	and wwc.sequence_id = h.sequence_ID 
	)

update #foo
set haz_flag = 'T'
from #foo h
where h.trans_source = 'R'
and exists (
	select top 1 1 
	from wastecode wc 
	join ReceiptWasteCode rwc on rwc.waste_code_uid = wc.waste_code_uid 
	and wc.haz_flag = 'T'
	and wc.waste_code_origin = 'F'	
	where rwc.receipt_id = h.workorder_id 
	and rwc.company_id = h.company_id 
	and rwc.profit_ctr_id = h.profit_ctr_id 
	and rwc.line_id = h.sequence_id 
	)

-- drop table #bar
-- drop table #container_pounds

select distinct /* contact_id, customer_id, */ generator_id, /* prices, */ waste_stream, offschedule_service_flag
-- , _year, _month
, _date
, haz_flag,
trans_source, workorder_id, sequence_id, profit_ctr_id, company_id

, profile_id
, tsdf_approval_id
, wastetype_id
, treatment_process_id
, disposal_service_id
, date_modified
, 0 as weight_flag
, convert(DECIMAL(18,4), 0) as total_pounds
-- dbo.fn_workorder_weight_line (workorder_id, sequence_id, profit_ctr_id, company_id) as total_pounds
, convert(money,0) as total_spend
, convert(char(3), null) as currency_code
into #bar
from #foo 



	-- 1.	WorkOrderDetailUnit LBS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 1
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds = SUM(WorkorderDetailUnit.quantity)
from #bar b
JOIN WorkorderDetailUnit (NOLOCK)
ON WorkorderDetailUnit.workorder_id = b.workorder_id
	AND WorkorderDetailUnit.company_id = b.company_id
	AND WorkorderDetailUnit.profit_ctr_id = b.profit_ctr_id
	AND WorkorderDetailUnit.sequence_id = b.sequence_id
	AND WorkorderDetailUnit.bill_unit_code = 'LBS'
	AND WorkorderDetailUnit.quantity is not null
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0

	-- 2.	WorkOrderDetailUnit TONS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 2
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds =  SUM(WorkorderDetailUnit.quantity * 2000.00)
from #bar b
JOIN WorkorderDetailUnit (NOLOCK)
ON WorkorderDetailUnit.workorder_id = b.workorder_id
	AND WorkorderDetailUnit.company_id = b.company_id
	AND WorkorderDetailUnit.profit_ctr_id = b.profit_ctr_id
	AND WorkorderDetailUnit.sequence_id = b.sequence_id
	AND WorkorderDetailUnit.bill_unit_code = 'TONS'
	AND WorkorderDetailUnit.quantity is not null
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0

	-- 3.	WorkOrderDetailUnit Manifested converted to LBS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 3
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds =  sum( wodu.quantity * bu.pound_conv )
	from #bar b
	JOIN WorkOrderDetailUnit wodu (nolock)
	ON wodu.workorder_id = b.workorder_id
	AND wodu.company_id = b.company_id
	AND wodu.profit_ctr_id = b.profit_ctr_id
	AND wodu.sequence_id = b.sequence_id
	AND wodu.manifest_flag = 'T'
	AND wodu.quantity is not null
	INNER JOIN BillUnit bu (nolock)
		ON wodu.bill_unit_code = bu.bill_unit_code
	AND bu.pound_conv is not null
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0


	-- 4.	WorkOrderDetailUnit Billed converted to LBS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 4
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds =  sum( wodu.quantity * bu.pound_conv )
	from #bar b
	JOIN WorkOrderDetailUnit wodu (nolock)
	ON wodu.workorder_id = b.workorder_id
	AND wodu.company_id = b.company_id
	AND wodu.profit_ctr_id = b.profit_ctr_id
	AND wodu.sequence_id = b.sequence_id
	AND wodu.billing_flag = 'T'
	AND wodu.quantity is not null
	INNER JOIN BillUnit bu (nolock)
		ON wodu.bill_unit_code = bu.bill_unit_code
	AND bu.pound_conv is not null
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0

	-- 5.	WorkOrderDetail LBS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 5
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds =  isnull(w.quantity_used, w.quantity)
	from #bar b
	JOIN WorkorderDetail w (NOLOCK)
	ON w.workorder_id = b.workorder_id
	AND w.resource_type = 'D'
	AND w.sequence_id = b.sequence_id
	AND w.profit_ctr_id = b.profit_ctr_id
	AND w.company_id = b.company_id
	and w.bill_unit_code = 'LBS'
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id, isnull(w.quantity_used, w.quantity)
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0

	-- 6.	WorkOrderDetail unit converted to LBS
update #bar
set total_pounds = x.total_pounds
, weight_flag = 6
from #bar b2
join (
select b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id
, total_pounds =  (isnull(w.quantity_used, w.quantity) * bu.pound_conv)
	from #bar b
	JOIN WorkorderDetail w (NOLOCK)
		ON w.workorder_id = b.workorder_id
		AND w.resource_type = 'D'
		AND w.sequence_id = b.sequence_id
		AND w.profit_ctr_id = b.profit_ctr_id
		AND w.company_id = b.company_id
		--and w.bill_unit_code = 'LBS'
		JOIN BillUnit bu (NOLOCK)
		ON bu.bill_unit_code = w.bill_unit_code
			AND bu.pound_conv is not null
WHERE b.trans_source = 'W'
and b.weight_flag = 0
GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.sequence_id, (isnull(w.quantity_used, w.quantity) * bu.pound_conv)
) x
on 
b2.workorder_id = x.workorder_id
	AND b2.company_id = x.company_id
	AND b2.profit_ctr_id = x.profit_ctr_id
	AND b2.sequence_id = x.sequence_id
WHERE b2.trans_source = 'W'
and b2.weight_flag = 0
and x.total_pounds > 0

	-- If all else fails... zero
update #bar set total_pounds = 0, weight_flag = 7 where trans_source = 'W' and weight_flag = 0


--while exists (select 1 from #bar where weight_flag = 0 and trans_source = 'W') begin
--	set rowcount 1000
--	update #bar
--	set weight_flag = 1
--	, total_pounds = dbo.fn_workorder_weight_line (workorder_id, sequence_id, profit_ctr_id, company_id)
--	WHERE trans_source = 'W'
--	and weight_flag = 0
--	set rowcount 0
--end

-- drop table #container_pounds
-- update #bar set weight_flag = 0, total_pounds = 0 where trans_source = 'R'

-- option 2
	select bar.workorder_id, bar.sequence_id, bar.company_id, bar.profit_ctr_id, sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) ) total_pounds
	into #container_pounds
	from #bar bar
	inner join container c (nolock)
		on bar.workorder_id = c.receipt_id
		and bar.sequence_id = c.line_id
		and bar.company_id = c.company_id
		and bar.profit_ctr_id = c.profit_ctr_id
	inner join containerdestination cd (nolock)
		on c.receipt_id = cd.receipt_id
		and c.line_id = cd.line_id
		and c.container_id = cd.container_id
		and c.company_id = cd.company_id
		and c.profit_ctr_id = cd.profit_ctr_id
	WHERE bar.trans_source = 'R'
	and bar.weight_flag = 0
		AND NOT EXISTS (
			-- You MUST make sure there's no containers for this line 
			--- with an unrecorded/zero weight, or this section returns bad data
			select top 1 1 
			from container c1 (nolock)
			where 
				c1.receipt_id = c.receipt_id
				and c1.line_id = c.line_id
				and c1.company_id = c.company_id
				and c1.profit_ctr_id = c.profit_ctr_id
				and isnull(c1.container_weight, 0) = 0
		)
		GROUP BY bar.workorder_id, bar.sequence_id, bar.company_id, bar.profit_ctr_id
		having sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) ) > 0


	update #bar
	set weight_flag = 1
	, total_pounds = 	x.total_pounds
	from #bar barx
	join #container_pounds x
	on barx.workorder_id = x.workorder_id
	and barx.sequence_id = x.sequence_id
	and barx.company_id = x.company_id
	and barx.profit_ctr_id = x.profit_ctr_id
	and barx.trans_Source = 'R'
	and barx.weight_flag = 0		
	and x.total_pounds > 0

	update #bar
	set weight_flag = 2
	, total_pounds = 
		case when isnull(r.line_weight, 0) > 0 then isnull(r.line_weight, 0)
		else 
			CASE WHEN r.manifest_unit = 'P' then convert(float, (r.manifest_quantity) ) -- pounds
			else case when r.manifest_unit = 'T' then convert(float, ((r.manifest_quantity * 2000.0) ) ) -- tons
				else 0
				end
			end
		end
	from #bar bar
	join receipt r (nolock) 
		on r.receipt_id = bar.workorder_id
		and r.line_id = bar.sequence_id
		and r.profit_ctr_id = bar.profit_ctr_id
		and r.company_id = bar.company_id
	where bar.trans_source = 'R'
	and bar.weight_flag = 0
	and (isnull(r.line_weight, 0) > 0 or r.manifest_unit in ('P', 'T'))

	update #bar
	set weight_flag = 3
	, total_pounds = 
		convert(float, ((r.manifest_quantity * (
				select 
				case when isnull(pl.specific_gravity, 0) <> 0 then
					pound_conv * pl.specific_gravity 
				else 
					pound_conv 
				end 
				from billunit where isnull(manifest_unit, '') = r.manifest_unit
				/*
				select pound_conv from billunit where isnull(manifest_unit, '') = r.manifest_unit
				*/
				)) ) )
	from #bar bar
	join receipt r (nolock) 
		on r.receipt_id = bar.workorder_id
		and r.line_id = bar.sequence_id
		and r.profit_ctr_id = bar.profit_ctr_id
		and r.company_id = bar.company_id
	LEFT JOIN ProfileLab pl
		on r.profile_id = pl.profile_id
		and pl.type = 'A'
	where bar.trans_source = 'R'
	and bar.weight_flag = 0
		and r.manifest_unit in (select manifest_unit from billunit where isnull(manifest_unit, '') not in ('P', 'T', '')) 

-- select count(*) from #bar where weight_flag = 0 and trans_source = 'R'		
-- option 1
while exists (select 1 from #bar where weight_flag = 0 and trans_source = 'R') begin
	set rowcount 1000
	update #bar
	set weight_flag = 4
	, total_pounds = dbo.fn_receipt_weight_line (workorder_id, sequence_id, profit_ctr_id, company_id)
	WHERE trans_source = 'R'
	and weight_flag = 0
	set rowcount 0
end


update #bar
set date_modified = x.date_modified
from #bar b
join (
	select b.workorder_id, b.company_id, b.profit_ctr_id, b.trans_source
	, max(d.date_modified) as date_modified
	from #bar b
	join workorderdetail d 
		on b.workorder_id = d.workorder_id 
		and b.company_id = d.company_id 
		and b.profit_ctr_id = d.profit_ctr_id
	where b.trans_source = 'W'
	GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.trans_source
	union
	select b.workorder_id, b.company_id, b.profit_ctr_id, b.trans_source
	, max(r.date_modified) as date_modified
	from #bar b
	join receipt r
		on b.workorder_id = r.receipt_id
		and b.company_id = r.company_id 
		and b.profit_ctr_id = r.profit_ctr_id
	where b.trans_source = 'R'
	GROUP BY b.workorder_id, b.company_id, b.profit_ctr_id, b.trans_source
) x
	on b.trans_source = x.trans_Source
	and b.workorder_id = x.workorder_id
	and b.company_id = x.company_id
	and b.profit_ctr_id = x.profit_ctr_id

-- drop table #to_rex
select b.*
into #to_rex
FROM    WasteSummaryStats w
join #bar b
on w.receipt_id = b.workorder_id
and w.company_id = b.company_id
and w.profit_ctr_id = b.profit_ctr_id
and w.trans_source = b.trans_source
and w.line_id = b.sequence_id
WHERE isnull(w.date_modified, '1/1/1900') < isnull(b.date_modified, getdate())



-- drop table #rex

select 
	x.trans_source
	, x.workorder_id
	, x.company_id
	, x.profit_ctr_id
	, x.sequence_id
	, sum(extended_amt) total_spend
into #rex
from #to_rex x
join billing b (nolock)
	on x.trans_source = b.trans_source
	and x.workorder_id = b.receipt_id
	and x.company_id = b.company_id
	and x.profit_ctr_id = b.profit_ctr_id
	and b.status_code = 'I'
	and isnull(b.line_id, -1) = case when x.trans_source = 'R' then x.sequence_id else isnull(b.line_id, -1) end
	and isnull(b.workorder_resource_type, '') = case when x.trans_source = 'W' then 'D' else isnull(b.workorder_resource_type, '') end
	and isnull(b.workorder_sequence_id, -1) = case when x.trans_source = 'W' then x.sequence_id else isnull(b.workorder_sequence_id, -1) end
join billingdetail bd (nolock) on b.billing_uid = bd.billing_uid
GROUP BY 
	x.trans_source
	, x.workorder_id
	, x.company_id
	, x.profit_ctr_id
	, x.sequence_id

update #bar set 
total_spend = r.total_spend
from #bar b
join #rex r
	on b.trans_source = r.trans_source
	and b.workorder_id = r.workorder_id
	and b.sequence_id = r.sequence_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id


	

delete WasteSummaryStats
-- select w.*, b.date_modified
FROM    WasteSummaryStats w
join #bar b
on w.receipt_id = b.workorder_id
and w.company_id = b.company_id
and w.profit_ctr_id = b.profit_ctr_id
and w.trans_source = b.trans_source
and w.line_id = b.sequence_id
WHERE isnull(w.date_modified, '1/1/1900') < isnull(b.date_modified, getdate())

insert WasteSummaryStats (
	trans_source
	, receipt_id
	, line_id
	, resource_type
	, sequence_id
	, company_id
	, profit_ctr_id
	, tsdf_code
	, customer_id
	, generator_id
	, profile_id
	, tsdf_approval_id
	, wastetype_id
	, treatment_process_id
	, disposal_service_id
	, trans_date
	, service_date
	, haz_flag
	, pounds
	, charges
	, date_modified
	)
SELECT  
	b.trans_source
	, b.workorder_id
	, b.sequence_id
	, 'D' as resource_type
	, b.sequence_id
	, b.company_id
	, b.profit_ctr_id
	, null as tsdf_code
	, coalesce(w.customer_id, r.customer_id) customer_id
	, b.generator_id
	, b.profile_id
	, b.tsdf_approval_id
	, b.wastetype_id
	, b.treatment_process_id
	, b.disposal_service_id
	, b._date as trans_date
	, b._date as service_date
	, b.haz_flag
	, b.total_pounds pounds
	, b.total_spend charges
	, b.date_modified  
FROM    #bar b
	LEFT JOIN workorderheader w
		on b.workorder_id = w.workorder_id
		and b.company_id = w.company_id
		and b.profit_ctr_id = w.profit_ctr_id
		and b.trans_source = 'W'
	LEFT JOIN receiptheader r
		on b.workorder_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and b.trans_source = 'R'
WHERE NOT EXISTS (
	select w.*
	FROM    WasteSummaryStats w
	where w.receipt_id = b.workorder_id
	and w.company_id = b.company_id
	and w.profit_ctr_id = b.profit_ctr_id
	and w.trans_source = b.trans_source
	and w.line_id = b.sequence_id
)


-- drop table #abc

select coalesce(wb.contact_id, rb.contact_id) contact_id
, coalesce(wb.customer_id, rb.customer_id) customer_id
, b.generator_id
-- , _year, _month
, _date
, coalesce(wb.prices, rb.prices) prices, waste_stream
, haz_flag
, sum(b.total_pounds) total_pounds
, convert(money,0) total_spend
, convert(char(3), null) currency_code
into #abc
from #bar b
LEFT JOIN ContactCORWorkorderHeaderBucket wb
	on b.trans_source = 'W'
	and b.workorder_id = wb.workorder_id
	and b.company_id = wb.company_id
	and b.profit_ctr_id = wb.profit_ctr_id
LEFT JOIN ContactCORReceiptBucket rb
	on b.trans_source = 'R'
	and b.workorder_id = rb.receipt_id
	and b.company_id = rb.company_id
	and b.profit_ctr_id = rb.profit_ctr_id
GROUP BY coalesce(wb.contact_id, rb.contact_id),coalesce(wb.customer_id, rb.customer_id), b.generator_id
, _date
--, _year, _month
, coalesce(wb.prices, rb.prices), waste_stream, haz_flag



-- drop table #xyz

select coalesce(wb.contact_id, rb.contact_id) contact_id, coalesce(wb.customer_id, rb.customer_id) customer_id, x.generator_id, coalesce(wb.prices, rb.prices) prices
, _date
-- , _year, _month
, offschedule_service_flag, waste_stream, haz_flag, 
sum(b.total_extended_amt) total_amt
, isnull(b.currency_code, 'USD') as currency_code
into #xyz
from #foo x
join billing b on b.trans_source = x.trans_source
and b.receipt_id = x.workorder_id 
and b.company_id = x.company_id 
and b.profit_ctr_id = x.profit_ctr_id 
and x.sequence_id = case b.trans_source when 'R' then b.line_id when 'W' then b.workorder_sequence_id end
and b.workorder_resource_type = case b.trans_source when 'R' then b.workorder_resource_type when 'W' then 'D' end
and b.status_code = 'I'
LEFT JOIN ContactCORWorkorderHeaderBucket wb
	on x.trans_source = 'W'
	and x.workorder_id = wb.workorder_id
	and x.company_id = wb.company_id
	and x.profit_ctr_id = wb.profit_ctr_id
LEFT JOIN ContactCORReceiptBucket rb
	on x.trans_source = 'R'
	and x.workorder_id = rb.receipt_id
	and x.company_id = rb.company_id
	and x.profit_ctr_id = rb.profit_ctr_id
where coalesce(wb.prices, rb.prices) = 1
GROUP BY coalesce(wb.contact_id, rb.contact_id), coalesce(wb.customer_id, rb.customer_id), x.generator_id, coalesce(wb.prices, rb.prices)
, _date
-- , _year, _month
, offschedule_service_flag, waste_stream, haz_flag
, isnull(b.currency_code, 'USD')


update #abc
set total_spend = x.total_amt
, currency_code = isnull(x.currency_code, 'USD')
from #abc b join (
	select sum(total_amt) total_amt, isnull(currency_code, 'USD') currency_code, contact_id, customer_id, generator_id, waste_stream
	, _date
	-- , _year, _month
	, haz_flag
	from #xyz 
	GROUP BY isnull(currency_code, 'USD'), contact_id, customer_id, generator_id, waste_stream
	, _date
	-- , _year, _month
	, haz_flag
) x
on b.contact_id = x.contact_id
and b.customer_id = x.customer_id
and b.generator_id = x.generator_id
and b.waste_stream = x.waste_stream
and b._date = x._date
--and b._year = x._year
--and b._month = x._month
and b.haz_flag = x.haz_flag
where prices = 1

update #abc set currency_code = 'USD' where currency_code is null


-- Can go from here into #abc to get overall totals

if exists (select 1 from sysobjects where xtype = 'u' and name = 'ContactCORStatsGeneratorTotal')
	drop table ContactCORStatsGeneratorTotal
	
select *
into ContactCORStatsGeneratorTotal
from #abc

CREATE INDEX [IX_ContactCORStatsGeneratorTotal_contact_id] ON [dbo].ContactCORStatsGeneratorTotal (contact_id, customer_id, generator_id) INCLUDE (total_pounds, total_spend, currency_code)
grant select on ContactCORStatsGeneratorTotal to COR_USER
grant select, insert, update, delete on ContactCORStatsGeneratorTotal to EQAI

-- SELECT  *  FROM    ContactCORStatsGeneratorTotal


return 0

end

go

grant execute on sp_ContactCORStatsGeneratorTotal_Maintain to eqweb
go
grant execute on sp_ContactCORStatsGeneratorTotal_Maintain to eqai
go
grant execute on sp_ContactCORStatsGeneratorTotal_Maintain to cor_user
go
