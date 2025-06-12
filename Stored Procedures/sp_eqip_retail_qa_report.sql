
create proc sp_eqip_retail_qa_report (
	@customer_id				int
	, @start_date				datetime
	, @end_date					datetime
	, @user_code				varchar(20)
	, @permission_id			int
	, @debug_code				int = 0	
) as
/* *************************************************************************
sp_eqip_retail_qa_report

Retrieves generator, service date and Trip Question data for a customer within
a given service date range

History:

	9/16/2013	JPB	Created
	02/07/2014	JPB	Added code to include end-of-day range on @end_date
					Now Omitting void/template work orders
					Changed TripQuestion join from LOJ to IJ.

Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

	sp_eqip_retail_qa_report 888880, '1/1/2000', '6/23/2013', 'jonathan', 159
	
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


-- 1. Most likely, they used some "special" billing project on a workorder visit to that generator
--		And never updated the generator record at all, because lazy.
select 
	g.site_code
	, g.generator_city
	, g.generator_state
	, g.generator_region_code
	, g.generator_division
	, w.workorder_id as service_number
	, isnull(wos.date_act_arrive, w.start_date) as service_date
	, tq.question_text
	, tq.answer_text
from WorkOrderHeader w (nolock)
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
inner join generator g (nolock)
	on w.generator_id = g.generator_id	
INNER join TripQuestion tq (nolock)
	on tq.workorder_id = w.workorder_id
	and tq.company_id = w.company_id
	and tq.profit_ctr_id = w.profit_ctr_id
	-- and tq.answer_type_id = 1
LEFT OUTER JOIN WorkOrderStop wos (nolock) 
	ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
where (
	w.customer_id in (Select customer_id from #Secured_Customer)
	or
	w.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
	and workorder_status NOT IN('V','T')
order by
g.site_code
	, g.generator_city
	, g.generator_state
	, g.generator_region_code
	, g.generator_division
	, w.workorder_id
	, isnull(wos.date_act_arrive, w.start_date)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_qa_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_qa_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_qa_report] TO [EQAI]
    AS [dbo];

