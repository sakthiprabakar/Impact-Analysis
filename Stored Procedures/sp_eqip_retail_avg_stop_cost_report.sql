
create proc sp_eqip_retail_avg_stop_cost_report (
	@customer_id				int
	, @start_date				datetime
	, @end_date					datetime
	, @user_code				varchar(20)
	, @permission_id			int
	, @debug_code				int = 0	
) as
/* *************************************************************************
sp_eqip_retail_avg_stop_cost_report

Retrieves billing, service date and generator information for a customer id 
and date range, and lists the pickup count and average billing total per pickup.

History:

	9/16/2013	JPB	Created
	02/07/2014	JPB	Added code to include end-of-day range on @end_date

Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

	sp_eqip_retail_avg_stop_cost_report 14231, '4/1/2013', '6/23/2013', 'jonathan', 159
	
************************************************************************* */

IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

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
	b.billing_uid
	, b.generator_id
	, bc.service_date
	, g.site_code
	, g.generator_state
	, sum(bd.extended_amt) as total_cost
into #data	
from billing b (nolock)
inner join billingdetail bd (nolock)
	on b.billing_uid = bd.billing_uid
inner join generator g (nolock)
	on b.generator_id = g.generator_id
inner join #Secured_Customer sc on b.customer_id = sc.customer_id
inner join #Secured_COPC copc on b.company_id = copc.company_id and b.profit_ctr_id = copc.profit_ctr_id
inner join billingcomment bc (nolock)
	on b.receipt_id = bc.receipt_id
	and b.company_id = bc.company_id
	and b.profit_ctr_id= bc.profit_ctr_id
	and b.trans_source = bc.trans_source
where b.customer_id = @customer_id
and bc.service_date between @start_date and @end_date
group by
	b.billing_uid
	, b.generator_id
	, bc.service_date
	, g.site_code
	, g.generator_state

select 
	generator_state
	-- this count of services may include multiple dates at the same store. Is this ok?
	, (select count(*) from (select distinct generator_id, service_date FROM #data where generator_state = d.generator_state)x) as service_count
	, sum(total_cost) as total_cost
	, sum(total_cost) / (select count(*) from (select distinct generator_id, service_date FROM #data where generator_state = d.generator_state)x) as avg_cost
from #data d 
group by 
	generator_state


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_avg_stop_cost_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_avg_stop_cost_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_avg_stop_cost_report] TO [EQAI]
    AS [dbo];

