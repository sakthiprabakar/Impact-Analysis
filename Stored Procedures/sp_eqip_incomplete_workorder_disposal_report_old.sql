
CREATE PROC sp_eqip_incomplete_workorder_disposal_report_old (
	@customer_id	int
	, @start_date	datetime -- Trip Arrive or else Start date begin
	, @end_date		datetime -- Trip Arrive or else Start date end
	, @resource_type_list	varchar(100) = NULL -- Distinct set of WorkOrderDetail.Resource_Type
	, @billing_status_list	varchar(100) = NULL -- Unsubmitted, Submitted, Invoiced
) AS
/* ******************************************************************
sp_eqip_incomplete_workorder_disposal_report_old

Amazon Work Order Information Report.  Generic for any customer.

History

	2014-07-29	JPB	Created
	2015-10-08	JPB	GEM-33271
					Work Order Type column now populates
					Added sort by co, pc, trip id
					Added manifest #
					Total billed per line is added
					Unit Price & Billed Total are money types in ssrs report
					
11/5/2015 Notes:
	Add Param for submitted/not
	Add resource type option filter 

Sample
	sp_eqip_incomplete_workorder_disposal_report_old
		@customer_id	= 13022
		, @start_date	= '6/1/2015'
		, @end_date		= '8/1/2015'
		, @resource_type_list	= 'D'
		, @billing_status_list	= 'US'

	sp_eqip_incomplete_workorder_disposal_report_old
		@customer_id	= 888880 
		, @start_date	= '1/1/2000'
		, @end_date		= '1/1/2020'
		, @resource_type_list	= 'D'
		, @billing_status_list	= 'USI'

		

select * from ResourceType
select distinct Resource_Type from WOrkOrderDetail

		
SELECT  TOP 10 *
FROM    workorderheader wh
join workorderdetail wd on wh.workorder_id = wd.workorder_id
and wh.company_id  = wd.company_id
and wh.profit_ctr_id = wd.profit_ctr_id
where wd.resource_type = 'D'
and wh.submitted_flag = 'T'
and wd.bill_rate > 0
order by wh.date_added desc

5834, 6403, 10729, 13022

SELECT  *
FROM    workorderdetail
where workorder_id = 12517900
and company_id = 14
and profit_ctr_id = 0

SELECT  workorder_resource_Type, *
FROM    billing
where receipt_id in (12516100, 12516200, 12516300, 12516400, 12516500, 12516600, 12516700, 12516800, 12516900, 12517000, 12517100, 12517200, 12517300, 12517400, 12517500, 12517600, 12517700, 12517800, 12517900, 12518000, 12518100, 12518200, 12518300, 12518600, 12518700, 12518800, 12518900, 12519000, 12519100, 12519200, 12519400, 12519500, 12519600, 12519700, 12519800)
and company_id = 14
and profit_ctr_id = 0




				MIN(billing.invoice_code) as invoice_code
				, SUM( billingdetail.extended_amt ) extended_amt
				, MIN(billing.invoice_date) as invoice_date
			FROM   billing (nolock)
			JOIN	billingdetail
				on billing.billing_uid = billingdetail.billing_uid
			WHERE  12516100 = billing.receipt_id
				AND 0 = billing.profit_ctr_id
				AND 14 = billing.company_id
				and 'D' = billing.workorder_resource_type
				and d.sequence_id = billing.workorder_sequence_id
				AND billing.trans_source = 'W'


****************************************************************** */

set nocount on

-- drop table #src
-- declare 		@customer_id	int = 13022		, @start_date datetime	= '6/1/2015'		, @end_date	datetime	= '8/1/2015'
	
if DATEPART(hh, @end_date) = 0
	set @end_date = @end_date + 0.99999

create table #ResourceTypeFilter (
	resource_type char(1)
)

insert #ResourceTypeFilter values ('H'), ('G') -- Fixed price and Group values always count.

insert #ResourceTypeFilter
select row from dbo.fn_SplitXsvText(',', 1, @resource_type_list)
where isnull(row, '') <> ''


if (select count(*) from #ResourceTypeFilter) = 0
	insert #ResourceTypeFilter
	select resource_type from ResourceType

if isnull(@billing_status_list, '') = '' set @billing_status_list = 'USI'

-- Billing Status handling
--	, @resource_type_list	varchar(100) -- Distinct set of WorkOrderDetail.Resource_Type
--	, @billing_status_list	varchar(100) -- 'U'nsubmitted, 'S'ubmitted, 'I'nvoiced
	

select h.workorder_id, h.company_id, h.profit_ctr_id, h.workorder_status, h.start_date, h.customer_id, wos.date_act_arrive, submitted_flag, status_code as billing_status_code
into #src
from
(
	select wh.workorder_id, wh.company_id, wh.profit_ctr_id, wh.workorder_status, wh.start_date, wh.customer_id, wh.submitted_flag, b.status_code
	from workorderheader wh (nolock)
	left join billing b (nolock)
		on wh.workorder_id = b.receipt_id
		and wh.company_id = b.company_id
		and wh.profit_ctr_id = b.profit_ctr_id
	where wh.customer_id = @customer_id
	and workorder_status in ( 'A', 'C', 'D', 'N', 'P', 'X' )
) h
left join 
(		
	select workorder_id, company_id, profit_ctr_id, date_act_arrive
	from workorderstop
	where date_act_arrive between @start_date AND @end_date
) wos
on h.workorder_id = wos.workorder_id
	and h.company_id = wos.company_id
	and h.profit_ctr_id = wos.profit_ctr_id
where
	customer_id = @customer_id
	and coalesce(wos.date_act_arrive, h.start_date) between @start_date AND @end_date
	--AND generator.site_code = '1'
	and h.workorder_status IN ( 'A', 'C', 'D', 'N', 'P', 'X' )

set nocount off

SELECT DISTINCT
    s.company_id,
    s.profit_ctr_id, -- AS profit_center_id,
    profitcenter.profit_ctr_name, -- AS profit_center_name,
    profitcenter.EPA_ID as profit_ctr_epa_id,

    s.customer_id,
    customer.cust_name AS customer_name, -- AS customer_name,
    customer.cust_city as customer_city,
    customer.cust_state as customer_state,
    
    cb.project_name,

	workorderheader.trip_id,
	workorderheader.trip_sequence_id,
	case tripheader.trip_status
		when 'A' then 'Arrived'
		when 'C' then 'Complete'
		when 'D' then 'Dispatched'
		when 'H' then 'Hold'
		when 'N' then 'New'
		when 'U' then 'Unloading'
		when 'V' then 'Void'
		else tripheader.trip_status
	end AS trip_status,

    s.workorder_id,
    workorderheader.start_date,
    workorderheader.end_date,
	s.date_act_arrive as service_date,
    CASE s.workorder_status
        WHEN 'N' THEN 'New'
        WHEN 'H' THEN 'On Hold'
        WHEN 'D' THEN 'Dispatched'
        WHEN 'C' THEN 'Complete'
        WHEN 'P' THEN 'Priced'
        WHEN 'A' THEN 'Accepted'
        WHEN 'X' THEN 'Submitted'
        ELSE ''
    END AS workorder_status,

    woth.account_desc as workorder_type,
    
    generator.generator_id,
    generator.epa_id, -- AS generator_epa_id,
    generator.generator_name,
    generator.site_code AS generator_site_code,
    generator.site_type AS generator_site_type,
    
	generator.generator_address_1 as 'Generator Address 1',
	generator.generator_address_2 as 'Generator Address 2',
	generator.generator_address_3 as 'Generator Address 3',
	generator.generator_zip_code as 'Generator Zip Code',
    generator.generator_city,
    county.county_name as generator_county,
    generator.generator_state,
    generator.generator_country,
    
    workorderheader.purchase_order,
    workorderheader.release_code,
    
    nullif( b.invoice_code, '' ) AS invoice_code,
    b.invoice_date,

	submitted_flag = CASE
			 WHEN workorderheader.submitted_flag = 'T' THEN 'Submitted'
			 ELSE 'Not Submitted'
		 END,

	case d.resource_type
		when 'd' then 'Disposal'
		when 'e' then 'Equipment'
		when 'l' then 'Labor'
		when 's' then 'Supplies'
		when 'o' then 'Other'
		else d.resource_type
	end as resource_type,

	d.sequence_id,
	d.manifest,
	d.quantity_used,
	d.resource_class_code,
	d.tsdf_code,
	t.tsdf_name,
	t.TSDF_EPA_ID,
	t.tsdf_addr1,
	t.tsdf_addr2,
	t.tsdf_addr3,
	t.tsdf_city,
	t.tsdf_state,
	t.tsdf_zip_code,
	
	coalesce(d.tsdf_approval_id, d.profile_id) as tsdf_approval_id,
	
	d.TSDF_approval_code,
	d.DESCRIPTION, -- as service_desc_1,
	d.description_2, -- as service_desc_2,
	wodu_bu.bill_unit_desc as billing_unit,
	
	coalesce(ds.disposal_service_desc, treat.disposal_service_Desc) as 'Disposal Method',
	wt.description as 'Waste Type Description',
	wt.category as 'Waste Type Category',
	coalesce(ta.RCRA_Haz_flag, p.RCRA_Haz_flag) as 'RCRA Haz Flag',
	case when d.resource_type = 'D' then
		isnull(convert(varchar(20), wodu_b.quantity), 'Unknown') 
	else NULL end as billing_quantity,
	wodu_mu.bill_unit_desc as manifest_unit,
	case when d.resource_type = 'D' then
		isnull(convert(varchar(20), wodu_m.quantity), 'Unknown') 
	else NULL end as manifest_quantity,
	
	case when (wodu_m.quantity * wodu_mu.pound_conv) is not null then
		'Manifested Unit'
		else 
		'Billed Unit'
	end as 'Weight Source',

	case when (wodu_m.quantity * wodu_mu.pound_conv) is not null then
		wodu_mu.pound_conv
		else 
		wodu_bu.pound_conv 
	end as 'Pound Conversion',
	
	coalesce(wodu_m.quantity * wodu_mu.pound_conv, wodu_b.quantity * wodu_bu.pound_conv) as weight
	, case when d.resource_type = 'D' then
		case when d.profile_id is not null then
			( select sum(isnull(price, 0))
				from ProfileQuoteDetail pqd (nolock)
				where pqd.profile_id = d.profile_id
				AND pqd.company_id = d.profile_company_id
				AND pqd.profit_ctr_id = d.profile_profit_ctr_id
				AND pqd.bill_unit_code = wodu_b.bill_unit_code
				AND pqd.status = 'A'
			)
			else
			( select sum(isnull(price, 0))
				from TSDFApprovalPrice tap (nolock)
				where tap.TSDF_approval_id = d.TSDF_approval_id
				AND tap.company_id = d.company_id
				AND tap.profit_ctr_id = d.profit_ctr_ID
				AND tap.bill_unit_code = wodu_b.bill_unit_code
				AND tap.status = 'A'
			)
		end
	else
		NULL 
	end as unit_price,
    billed_total = b.extended_amt
FROM   #src s
		join workorderheader (nolock)
			on s.workorder_id = workorderheader.workorder_id
			and s.company_id = workorderheader.company_id
			and s.profit_ctr_id = workorderheader.profit_ctr_id
       INNER JOIN profitcenter (nolock)
           ON profitcenter.company_id = s.company_id
              AND profitcenter.profit_ctr_id = s.profit_ctr_id
       INNER JOIN workorderdetail d (nolock)
			ON s.workorder_id = d.workorder_id
				AND s.profit_ctr_id = d.profit_ctr_id
				AND s.company_id = d.company_id
				AND d.bill_rate > -2
		LEFT JOIN customerbilling cb (nolock) 
			on workorderheader.customer_id = cb.customer_id 
				and workorderheader.billing_project_id = cb.billing_project_id
		LEFT JOIN WorkOrderDetailUnit wodu_b (nolock)
			ON d.workorder_id = wodu_b.workorder_id
				AND d.profit_ctr_id = wodu_b.profit_ctr_id
				AND d.company_id = wodu_b.company_id
				and d.sequence_ID = wodu_b.sequence_id
				and d.resource_type = 'D'
				and wodu_b.billing_flag = 'T'
		LEFT JOIN WorkOrderDetailUnit wodu_m (nolock)
			ON d.workorder_id = wodu_m.workorder_id
				AND d.profit_ctr_id = wodu_m.profit_ctr_id
				AND d.company_id = wodu_m.company_id
				and d.sequence_ID = wodu_m.sequence_id
				and d.resource_type = 'D'
				and wodu_m.manifest_flag = 'T'
		left join BillUnit wodu_bu (nolock)
			on wodu_b.bill_unit_code = wodu_bu.bill_unit_code
		left join BillUnit wodu_mu (nolock)
			on wodu_m.bill_unit_code = wodu_mu.bill_unit_code
       --LEFT OUTER JOIN workorderproblem
       --    ON workorderheader.problem_id = workorderproblem.problem_id
       LEFT OUTER JOIN customer (nolock)
           ON s.customer_id = customer.customer_id
       LEFT OUTER JOIN generator (nolock)
           ON workorderheader.generator_id = generator.generator_id
       LEFT OUTER JOIN County (nolock)
			ON generator.generator_county = county.county_code
       LEFT JOIN TripHeader (nolock)
			on workorderheader.trip_id = TripHeader.trip_id
			AND workorderheader.company_id = TripHeader.company_id
			AND workorderheader.profit_ctr_id = TripHeader.profit_ctr_id
		LEFT JOIN WorkOrderTypeHeader woth (nolock)
			on workorderheader.workorder_type_id = woth.workorder_type_id
		LEFT JOIN profile p (nolock) 
			on d.resource_type = 'D'
				and d.profile_id = p.profile_id
		LEFT JOIN tsdfapproval ta (nolock) 
			on d.resource_type = 'D'
				and d.tsdf_approval_id = ta.tsdf_approval_id 
		LEFT JOIN ProfilequoteApproval pqa (nolock) 
			on d.resource_type = 'D'
				and d.profile_id = pqa.profile_id
				and d.profile_company_id = pqa.company_id
				and d.profile_profit_ctr_id = pqa.profit_ctr_id
		left join Treatment	treat (nolock)
			on d.resource_type = 'D'
				and pqa.treatment_id = treat.treatment_id
				and pqa.company_id = treat.company_id
				and pqa.profit_ctr_id = treat.profit_ctr_id
		LEFT JOIN disposalservice ds (nolock) 
			on ta.disposal_service_id = ds.disposal_service_id
		LEFT JOIN wastetype wt (nolock) 
			on p.wastetype_id = wt.wastetype_id
		LEFT JOIN TSDF t (nolock)
			on d.tsdf_code = t.tsdf_code
		CROSS APPLY (
			select 
				MIN(billing.invoice_code) as invoice_code
				, SUM( billingdetail.extended_amt ) extended_amt
				, MIN(billing.invoice_date) as invoice_date
			FROM   billing (nolock)
			JOIN	billingdetail
				on billing.billing_uid = billingdetail.billing_uid
			WHERE  d.workorder_id = billing.receipt_id
				AND d.profit_ctr_id = billing.profit_ctr_id
				AND d.company_id = billing.company_id
				and d.resource_type = billing.workorder_resource_type
				and d.sequence_id = billing.workorder_sequence_id
				AND billing.trans_source = 'W'
		) b
WHERE
	s.workorder_status IN ( 'A', 'C', 'D', 'N', 'P', 'X' )
	--AND generator.site_code = '1'
	AND d.resource_type in (select resource_type from #ResourceTypeFilter)
	-- and s.customer_ID = @customer_id
	-- and coalesce(wos.date_act_arrive, workorderheader.start_date) between @start_date AND @end_date
	AND 1 = case when @billing_status_list like '%U%'
		and isnull(s.submitted_flag, 'F') = 'F'
		and isnull(s.billing_status_code, 'N') <> 'I'
		then 1
		else
			case when @billing_status_list like '%S%'
			and isnull(s.submitted_flag, 'F') = 'T'
			and isnull(s.billing_status_code, 'N') <> 'I'
			then 1
			else 
				case when @billing_status_list like '%I%'
				and isnull(s.submitted_flag, 'F') = 'T'
				and isnull(s.billing_status_code, 'N') = 'I'
				then 1
				else 0
				end
			end
		end
		
ORDER BY 
    s.company_id,
    s.profit_ctr_id, -- AS profit_center_id,
	workorderheader.trip_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report_old] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report_old] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report_old] TO [EQAI]
    AS [dbo];

