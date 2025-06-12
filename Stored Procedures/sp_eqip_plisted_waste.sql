
create proc sp_eqip_plisted_waste (
	@customer_id	int,
	@start_date	datetime,
	@end_date	datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@debug_code			int = 0	
) as
/* *************************************************************************
sp_eqip_plisted_waste

Collects data on the weights and types of waste picked up for a customer and
lists pickup, generator, approval and weight information for cases where the
waste contains a federal P- waste code.


History:

	6/26/2013	JPB	Created 
	9/12/2013	JPB	Copied from sp_rite_aid_prebilling_worksheet and modified for Weekly Report use.
					Converted input from @trip_id to @start_date, @end_date
					Receipts might not exist yet, so check for them first, but fall back to WorkOrderDetailUnit where necessary.
	9/13/2013	JPB	Converted to sp_eqip_plisted_waste
					- Not built for a specific customer
					- Meant for EQIP/SSRS
					- Uses EQIP Row level security
	02/07/2014	JPB	Added code to include end-of-day range on @end_date
					Now Omitting void/template work orders
	03/28/2014	JPB	Starting...
					GEM-27621 for Rite Aid, won't really hurt the rest.
					Add container count for plisted (pharma) profiles with a residue conv.
					Add residue weight for plisted (pharma) profiles with a residue conv.
	06/19/2015	JPB	GEM-33065  When a work order is split to multiple tsdfs, and 1 of those N tsdfs 
					creates an accepted receipt before the others, those other datas get dropped 
					off the report.
					Modify to check not just that A receipt exists for the work order, but that it 
					matches on manifest & line to the work order's detail lines.  This will return 
					Receipt lines where possible, but Work Order lines where each detail line is not 
					yet mapped to an accepted receipt

Sample:

	sp_eqip_plisted_waste 14231, '6/1/2015', '7/1/2015', 'jonathan', 159

************************************************************************* */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

if OBJECT_ID('tempdb..#Secured_Customer') is not null drop table #Secured_Customer
if OBJECT_ID('tempdb..#Secured_COPC') is not null drop table #Secured_COPC
if OBJECT_ID('tempdb..#weight') is not null drop table #weight

-- declare 	@customer_id	int = 14231,	@start_date	datetime = '6/1/2015',	@end_date	datetime = '7/1/2015',	@user_code		varchar(20) = 'jonathan',	@permission_id	int = 283,	@debug_code			int = 0	

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

-- declare 	@customer_id	int = 14231,	@start_date	datetime = '6/1/2015',	@end_date	datetime = '7/1/2015',	@user_code		varchar(20) = 'jonathan',	@permission_id	int = 283,	@debug_code			int = 0	

select
	'R' as trans_source
	, r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, r.profile_id
	, 'P' as profile_tsdfapproval_flag
	, isnull(p.empty_bottle_flag, 'F') as empty_bottle_flag
	, round(coalesce(sum(isnull(rdi.pounds,0) * 1.0 + isnull(rdi.ounces,0)/16.0), r.line_weight, 0), 10) as weight
	, sum(isnull(rdi.merchandise_quantity, 0)) as bottle_count
	, round(sum(isnull(rdi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)), 10) as residue_weight
	, r.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date) as service_date
	, bll.source_id as service_number
	, r.manifest
	, r.manifest_line
into #weight	
from receipt r (nolock)
inner join #Secured_COPC copc 
	on r.company_id = copc.company_id 
	and r.profit_ctr_id = copc.profit_ctr_id
inner join profile p (nolock) on r.profile_id = p.profile_id
left outer join BillingLinkLookup bll (nolock)
	on r.receipt_id = bll.receipt_id
	and r.company_id = bll.company_id
	and r.profit_ctr_id = bll.profit_ctr_id
left outer join WorkOrderStop wos (nolock)
	on bll.source_id = wos.workorder_id
	and bll.source_company_id = wos.company_id
	and bll.source_profit_ctr_id = wos.profit_ctr_id
left outer join WorkOrderHeader wo (nolock)
	on bll.source_id = wo.workorder_id
	and bll.source_company_id = wo.company_id
	and bll.source_profit_ctr_id = wo.profit_ctr_id
	and wo.workorder_status NOT IN('V','T')
left outer join ReceiptTransporter rt (nolock)
	on r.receipt_id = rt.receipt_id
	and r.company_id = rt.company_id
	and r.profit_ctr_id = rt.profit_ctr_id	
	and rt.transporter_sequence_id = 1
left outer join receiptdetailitem rdi (nolock)
	on r.receipt_id = rdi.receipt_id
	and r.line_id = rdi.line_id
	and r.company_id = rdi.company_id 
	and r.profit_ctr_id = rdi.profit_ctr_id
where (
	r.customer_id in (Select customer_id from #Secured_Customer)
	)
	and coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date) between @start_date and @end_date
	and r.receipt_status = 'A' and r.fingerpr_status = 'A'
group by
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, r.profile_id
	, isnull(p.empty_bottle_flag, 'F')
	, r.line_weight
	, r.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date)
	, bll.source_id
	, r.manifest
	, r.manifest_line
UNION
select
	'R' as trans_source
	, r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, r.profile_id
	, 'P' as profile_tsdfapproval_flag
	, isnull(p.empty_bottle_flag, 'F') as empty_bottle_flag
	, round(coalesce(sum(isnull(rdi.pounds,0) * 1.0 + isnull(rdi.ounces,0)/16.0), r.line_weight, 0), 10) as weight
	, sum(isnull(rdi.merchandise_quantity, 0)) as bottle_count
	, round(sum(isnull(rdi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)), 10) as residue_weight
	, r.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date) as service_date
	, bll.source_id as service_number
	, r.manifest
	, r.manifest_line
from receipt r (nolock)
inner join #Secured_COPC copc 
	on r.company_id = copc.company_id 
	and r.profit_ctr_id = copc.profit_ctr_id
inner join profile p (nolock) on r.profile_id = p.profile_id
left outer join BillingLinkLookup bll (nolock)
	on r.receipt_id = bll.receipt_id
	and r.company_id = bll.company_id
	and r.profit_ctr_id = bll.profit_ctr_id
left outer join WorkOrderStop wos (nolock)
	on bll.source_id = wos.workorder_id
	and bll.source_company_id = wos.company_id
	and bll.source_profit_ctr_id = wos.profit_ctr_id
left outer join WorkOrderHeader wo (nolock)
	on bll.source_id = wo.workorder_id
	and bll.source_company_id = wo.company_id
	and bll.source_profit_ctr_id = wo.profit_ctr_id
	and wo.workorder_status NOT IN('V','T')
left outer join ReceiptTransporter rt (nolock)
	on r.receipt_id = rt.receipt_id
	and r.company_id = rt.company_id
	and r.profit_ctr_id = rt.profit_ctr_id	
	and rt.transporter_sequence_id = 1
left outer join receiptdetailitem rdi (nolock)
	on r.receipt_id = rdi.receipt_id
	and r.line_id = rdi.line_id
	and r.company_id = rdi.company_id 
	and r.profit_ctr_id = rdi.profit_ctr_id
where (
	r.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	)
	and coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date) between @start_date and @end_date
	and r.receipt_status = 'A' and r.fingerpr_status = 'A'
group by
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, r.profile_id
	, isnull(p.empty_bottle_flag, 'F')
	, r.line_weight
	, r.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date)
	, bll.source_id
	, r.manifest
	, r.manifest_line

-- declare 	@customer_id	int = 14231,	@start_date	datetime = '6/1/2015',	@end_date	datetime = '7/1/2015',	@user_code		varchar(20) = 'jonathan',	@permission_id	int = 283,	@debug_code			int = 0	

insert #weight
select
	'W' as trans_source
	, wo.company_id
	, wo.profit_ctr_id
	, wo.workorder_id
	, wod.sequence_id
	, case when wod.profile_id is not null then wod.profile_id else wod.tsdf_approval_id end
	, case when wod.profile_id is not null then 'P' else 'T' end as profile_tsdfapproval_flag
	, case when wod.profile_id is not null then isnull(p.empty_bottle_flag, 'F') else 'F' end as empty_bottle_flag
	, round(coalesce(sum(isnull(wodi.pounds,0) * 1.0 + isnull(wodi.ounces,0)/16.0), 0), 10) as weight
	, sum(isnull(wodi.merchandise_quantity, 0)) as bottle_count
	, round(sum(wodi.merchandise_quantity * p.residue_pounds_factor), 10) as residue_weight
	, wo.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date) as service_date
	, wo.workorder_id as service_number
	, wod.manifest
	, wod.manifest_line
from WorkOrderHeader wo (nolock)
inner join #Secured_COPC copc 
	on wo.company_id = copc.company_id 
	and wo.profit_ctr_id = copc.profit_ctr_id
inner join WorkOrderDetail wod (nolock)
	on wo.workorder_id = wod.workorder_id
	and wo.company_id = wod.company_id
	and wo.profit_ctr_id = wod.profit_ctr_id
	and wod.bill_rate > -2
	and wod.resource_type = 'D'
left outer join WorkOrderDetailItem wodi (nolock)
	on wod.workorder_id = wodi.workorder_id
	and wod.company_id = wodi.company_id
	and wod.profit_ctr_id = wodi.profit_ctr_id
	and wod.sequence_id = wodi.sequence_id
left outer join WorkOrderStop wos (nolock)
	on wo.workorder_id = wos.workorder_id
	and wo.company_id = wos.company_id
	and wo.profit_ctr_id = wos.profit_ctr_id
left outer join profile p (nolock)
	on wod.profile_id = p.profile_id
	and wod.profile_id is not null
where (
	wo.customer_id in (Select customer_id from #Secured_Customer)
	)
	and coalesce(wos.date_act_arrive, wo.start_date) between @start_date and @end_date
	and wo.workorder_status NOT IN('V','T')
	and not exists (
		select 1 from #weight r
		inner join BillingLinkLookup bll (nolock)
		on r.receipt_id = bll.receipt_id
		and r.company_id = bll.company_id
		and r.profit_ctr_id = bll.profit_ctr_id
		where bll.source_id = wo.workorder_id
		and bll.source_company_id = wo.company_id
		and bll.source_profit_ctr_id = wo.profit_ctr_id
	)
group by
	wo.company_id
	, wo.profit_ctr_id
	, wo.workorder_id
	, wod.sequence_id
	, case when wod.profile_id is not null then wod.profile_id else wod.tsdf_approval_id end
	, case when wod.profile_id is not null then 'P' else 'T' end
	, wod.profile_id
	, p.empty_bottle_flag
	, p.residue_pounds_factor
	, wo.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date)
	, wo.workorder_id
	, wod.manifest
	, wod.manifest_line
UNION
select
	'W' as trans_source
	, wo.company_id
	, wo.profit_ctr_id
	, wo.workorder_id
	, wod.sequence_id
	, case when wod.profile_id is not null then wod.profile_id else wod.tsdf_approval_id end
	, case when wod.profile_id is not null then 'P' else 'T' end as profile_tsdfapproval_flag
	, case when wod.profile_id is not null then isnull(p.empty_bottle_flag, 'F') else 'F' end as empty_bottle_flag
	, round(coalesce(sum(isnull(wodi.pounds,0) * 1.0 + isnull(wodi.ounces,0)/16.0), 0), 10) as weight
	, sum(isnull(wodi.merchandise_quantity, 0)) as bottle_count
	, round(sum(wodi.merchandise_quantity * p.residue_pounds_factor), 10) as residue_weight
	, wo.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date) as service_date
	, wo.workorder_id as service_number
	, wod.manifest
	, wod.manifest_line
from WorkOrderHeader wo (nolock)
inner join #Secured_COPC copc 
	on wo.company_id = copc.company_id 
	and wo.profit_ctr_id = copc.profit_ctr_id
inner join WorkOrderDetail wod (nolock)
	on wo.workorder_id = wod.workorder_id
	and wo.company_id = wod.company_id
	and wo.profit_ctr_id = wod.profit_ctr_id
	and wod.bill_rate > -2
	and wod.resource_type = 'D'
left outer join WorkOrderDetailItem wodi (nolock)
	on wod.workorder_id = wodi.workorder_id
	and wod.company_id = wodi.company_id
	and wod.profit_ctr_id = wodi.profit_ctr_id
	and wod.sequence_id = wodi.sequence_id
left outer join WorkOrderStop wos (nolock)
	on wo.workorder_id = wos.workorder_id
	and wo.company_id = wos.company_id
	and wo.profit_ctr_id = wos.profit_ctr_id
left outer join profile p (nolock)
	on wod.profile_id = p.profile_id
	and wod.profile_id is not null
where (
	wo.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	)
	and coalesce(wos.date_act_arrive, wo.start_date) between @start_date and @end_date
	and wo.workorder_status NOT IN('V','T')
	and not exists (
		select 1 from #weight r
		inner join BillingLinkLookup bll (nolock)
		on r.receipt_id = bll.receipt_id
		and r.company_id = bll.company_id
		and r.profit_ctr_id = bll.profit_ctr_id
		where bll.source_id = wo.workorder_id
		and bll.source_company_id = wo.company_id
		and bll.source_profit_ctr_id = wo.profit_ctr_id
		-- 2016-06-19 - Trying to force detail matching because sometimes a single work order gets sent/split to multiple tsdfs.
		--   and 1 of those tsdfs might now have an accepted receipt, but the other doesn't.
		--   So we would want accepted receipt data for those lines, but work order data for the others.
		and wod.manifest = r.manifest
		and wod.manifest_line = r.manifest_line
	)
group by
	wo.company_id
	, wo.profit_ctr_id
	, wo.workorder_id
	, wod.sequence_id
	, case when wod.profile_id is not null then wod.profile_id else wod.tsdf_approval_id end
	, case when wod.profile_id is not null then 'P' else 'T' end
	, wod.profile_id
	, p.empty_bottle_flag
	, p.residue_pounds_factor
	, wo.generator_id
	, coalesce(wos.date_act_arrive, wo.start_date)
	, wo.workorder_id
	, wod.manifest
	, wod.manifest_line



SELECT 
	g.site_code as location
	, w.service_date
	, w.service_number
	, g.generator_region_code
	, g.generator_division
	, g.generator_city
	, g.generator_state
	, coalesce(p.approval_desc, t.waste_desc) as description
	, w.weight
	, w.bottle_count
	, w.residue_weight
	FROM #weight w
	inner join generator g (nolock) on w.generator_id = g.generator_id
	left outer join profile p (nolock) on w.profile_tsdfapproval_flag = 'P' and w.profile_id = p.profile_id
	left outer join tsdfapproval t (nolock) on w.profile_tsdfapproval_flag = 'T' and w.profile_id = t.tsdf_approval_id
where exists (
	select 1 from profilewastecode pwc (nolock)
	inner join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
	where pwc.profile_id = w.profile_id
	and wc.waste_code_origin = 'F' and left(wc.display_name, 1) = 'P'
	and wc.waste_type_code = 'L'
)
order by 
	g.site_code
	, w.service_date
	, w.service_number 
	, coalesce(p.approval_desc, t.waste_desc)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_plisted_waste] TO [EQAI]
    AS [dbo];

