
create proc sp_eqip_manifest_mailing_report (
	@customer_id	int,
	@start_date	datetime,
	@end_date	datetime,
	@user_code		varchar(20),
	@permission_id	int,
	@debug_code			int = 0	
) as
/* *************************************************************************
sp_eqip_manifest_mailing_report

Lists information about receipts' manifests for a customer within a date range
including the pickup dates, receipt dates, and estimated mailing dates
- estimated mailing is a hard coded fixed value, so take it with a chunk of salt.

History:

	6/26/2013	JPB	Created 
	9/12/2013	JPB	Copied from sp_rite_aid_prebilling_worksheet and modified for Weekly Report use.
					Converted input from @trip_id to @start_date, @end_date
					Receipts might not exist yet, so check for them first, but fall back to WorkOrderDetailUnit where necessary.
	9/13/2013	JPB	Converted to sp_eqip_manifest_mailing_report
					- Not built for a specific customer
					- Meant for EQIP/SSRS
					- Uses EQIP Row level security
	02/07/2014	JPB	Added code to include end-of-day range on @end_date
					Now Omitting void/template work orders

Sample:

	sp_eqip_manifest_mailing_report 14231, '5/1/2013', '6/30/2013', 'jonathan', 159

************************************************************************* */

IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

if OBJECT_ID('tempdb..#Secured_Customer') is not null drop table #Secured_Customer
if OBJECT_ID('tempdb..#Secured_COPC') is not null drop table #Secured_COPC
if OBJECT_ID('tempdb..#manifests') is not null drop table #manifests


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

select
	convert(varchar(20), coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date), 101) as service_date
	, r.manifest
	, g.site_code as store_number
	, g.generator_state
	, pc.profit_ctr_name
	, convert(varchar(20), r.receipt_date, 101) as receipt_date
	, convert(varchar(20), r.receipt_date, 101) as preparing_to_mail_date
	, datediff(d, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date), r.receipt_date) as ship_days
	, 7 as mail_days
	, datediff(d, coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date), r.receipt_date) + 7 as delivery_days
from receipt r (nolock)
inner join #Secured_COPC copc 
	on r.company_id = copc.company_id 
	and r.profit_ctr_id = copc.profit_ctr_id
inner join profitcenter pc (nolock)
	on r.company_id = pc.company_id
	and r.profit_ctr_id = pc.profit_ctr_id
inner join generator g (nolock) on r.generator_id = g.generator_id
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
where (
	r.customer_id in (Select customer_id from #Secured_Customer)
	or
	r.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	)
	and coalesce(wos.date_act_arrive, wo.start_date, rt.transporter_sign_date, r.receipt_date) between @start_date and @end_date
	and r.receipt_status = 'A' and r.fingerpr_status = 'A'



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_manifest_mailing_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_manifest_mailing_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_manifest_mailing_report] TO [EQAI]
    AS [dbo];

