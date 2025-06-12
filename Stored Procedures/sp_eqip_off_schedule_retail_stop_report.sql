
create proc sp_eqip_off_schedule_retail_stop_report (
	@customer_id				int
	, @billing_project_id_list	varchar(max) /* Optional list of billing project id's that indicate a closing */
	, @start_date				datetime
	, @end_date					datetime
	, @user_code				varchar(20)
	, @permission_id			int
	, @debug_code				int = 0	
) as
/* *************************************************************************
sp_eqip_off_schedule_retail_stop_report

Lists Generator, Status & Question/Answer information for workorders within a certain service date range
and that belong to a customer.  Billing project list is optional, but intended.

History:

	9/16/2013	JPB	Created

Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

	sp_eqip_off_schedule_retail_stop_report 14231, '', '5/1/2013', '6/23/2013', 'jonathan', 159
	
************************************************************************* */

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

create table #customerbilling (customer_id int, billing_project_id int)
insert #customerbilling 
select cb.customer_id, cb.billing_project_id
from #Secured_Customer sc 
inner join CustomerBilling cb (nolock)
	on sc.customer_id = cb.customer_id
inner join dbo.fn_splitxsvtext(',', 1, @billing_project_id_list) x
	on cb.billing_project_id = convert(int, x.row)
where x.row is not null

if 0 = (select count(*) from #customerbilling) and isnull(@billing_project_id_list, '') = ''
	insert #customerbilling 
	select cb.customer_id, cb.billing_project_id
	from #Secured_Customer sc 
	inner join CustomerBilling cb (nolock)
		on sc.customer_id = cb.customer_id

select distinct
	g.site_code
	, g.generator_city
	, g.generator_state
	, isnull(wos.date_act_arrive, w.start_date) as service_date
	, case when w.start_date > getdate() then 'Scheduled' else  
	   case when w.end_date < getdate() then 'Complete' else  
		case when w.start_date <= getdate() and w.end_date >= getdate() then 'In Progress' else 'Unknown' end  
	   end  
	  end as status
	, tq.answer_text as notes
from workorderheader w (nolock)
inner join #Secured_COPC copc
	on w.company_id = copc.company_id
	and w.profit_ctr_id = copc.profit_ctr_id
inner join generator g (nolock)
	on w.generator_id = g.generator_id
left outer join WorkOrderStop wos (nolock)
	on w.workorder_id = wos.workorder_id
	and w.company_id = wos.company_id
	and w.profit_ctr_id = wos.profit_ctr_id
left outer join TripQuestion tq (nolock)
	on tq.workorder_id = w.workorder_id
	and tq.company_id = w.company_id
	and tq.profit_ctr_id = w.profit_ctr_id
	and tq.answer_type_id = 1
where (
	w.customer_id in (Select customer_id from #Secured_Customer)
	or
	w.generator_id in (select generator_id from customergenerator cg (nolock) inner join #secured_Customer sc on cg.customer_id = sc.customer_id)
	)
	and coalesce(wos.date_act_arrive, w.start_date) between @start_date and @end_date
and	w.workorder_status NOT IN ('V', 'X', 'T')  
order by
 	g.site_code
	, isnull(wos.date_act_arrive, w.start_date)



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_off_schedule_retail_stop_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_off_schedule_retail_stop_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_off_schedule_retail_stop_report] TO [EQAI]
    AS [dbo];

