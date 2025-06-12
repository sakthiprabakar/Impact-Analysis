
create proc sp_eqip_store_closing_report (
	@customer_id				int
	, @billing_project_id_list	varchar(max) /* Optional list of billing project id's that indicate a closing */
	, @start_date				datetime
	, @end_date					datetime
	, @user_code				varchar(20)
	, @permission_id			int
	, @debug_code				int = 0	
) as
/* *************************************************************************
sp_eqip_store_closing_report

Retrieves generator and last-date-of-visit information for generators with a facility closing date
within the given date range, or on a provided billing project id within the given date range.

History:

	9/16/2013	JPB	Created
	02/07/2014	JPB	Added code to include end-of-day range on @end_date
					Now Omitting void/template work orders

Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

	sp_eqip_store_closing_report 14231, '5775', '1/1/2012', '6/23/2013', 'jonathan', 159
	sp_eqip_store_closing_report 14231, '-1', '1/1/2012', '6/23/2013', 'jonathan', 159
	
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

create table #customerbilling (customer_id int, billing_project_id int)
insert #customerbilling 
select cb.customer_id, cb.billing_project_id
from #Secured_Customer sc 
inner join CustomerBilling cb (nolock)
	on sc.customer_id = cb.customer_id
inner join dbo.fn_splitxsvtext(',', 1, @billing_project_id_list) x
	on cb.billing_project_id = convert(int, x.row)
where x.row is not null

-- Note for later, there's not a handling of -1 here becuase we WANT the insert above to fail in the -1 case
-- That's what makes the select from workorders below fail, and fall back to the generator data only.

-- DOing this as a table with multiple fill steps below to cover poor data maintenance.
create table #ClosedGenerator (
	generator_id		int
	, closed_date		datetime
	, workorder_id		int
	, company_id		int
	, profit_ctr_id		int
	, last_wo_date		datetime
)


-- 1. Most likely, they used some "special" billing project on a workorder visit to that generator
--		And never updated the generator record at all, because lazy.
insert #ClosedGenerator
select w.generator_id, isnull(wos.date_act_arrive, w.start_date), w.workorder_id, w.company_id, w.profit_ctr_id, isnull(wos.date_act_arrive, w.start_date)
from WorkOrderHeader w (nolock)
inner join #Secured_COPC copc 
	on w.company_id = copc.company_id 
	and w.profit_ctr_id = copc.profit_ctr_id
inner join #CustomerBilling cb (nolock)
	on w.customer_id = cb.customer_id
	and w.billing_project_id = cb.billing_project_id
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
	and w.workorder_status NOT IN('V','T')

-- 2. But also possible... They updated the generator, not the WO
insert #ClosedGenerator
select g.generator_id, g.generator_facility_date_closed, w.workorder_id, w.company_id, w.profit_ctr_id, isnull(wos.date_act_arrive, w.start_date)
from generator g
inner join customergenerator cg on g.generator_id = cg.generator_id
inner join #Secured_Customer sc on cg.customer_id = sc.customer_id
inner join workorderheader w (nolock) on g.generator_id = w.generator_id and w.start_date = (select max(lw.start_date) start_date from workorderheader lw where lw.generator_id = g.generator_id and lw.workorder_status IN ('A','C','D','N','P'))
LEFT OUTER JOIN WorkOrderStop wos (nolock) 
	ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
where g.generator_id not in (select generator_id from #ClosedGenerator)
and g.generator_facility_date_closed between @start_date and @end_date

select distinct
	g.site_code
	, g.generator_city
	, g.generator_state
	, g.generator_facility_date_closed
	, c.last_wo_date as service_date
	, tq.answer_text as notes
from #ClosedGenerator c
inner join generator g (nolock)
	on c.generator_id = g.generator_id
left outer join TripQuestion tq (nolock)
	on tq.workorder_id = c.workorder_id
	and tq.company_id = c.company_id
	and tq.profit_ctr_id = c.profit_ctr_id
	and tq.answer_type_id = 1


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_store_closing_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_store_closing_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_store_closing_report] TO [EQAI]
    AS [dbo];

