-- drop proc if exists sp_hub_transactions_by_service_date
go

create proc sp_hub_transactions_by_service_date (
	@start_date datetime = null
	, @end_date datetime = null
	, @user_code		varchar(20)
	, @permission_id	int
	, @debug_code			int = 0	
)
as
/* ****************************************************************************
sp_hub_transactions_by_service_date

Transactions by Service Date	
Generates an extract of transaction count by company, profit center and type 
with a total per transaction month and year based on when the transaction is created.	

History:
09/01/2020	JPB	Created

Sample:

	sp_hub_transactions_by_service_date '1/1/2017', '8/31/2020', 'jonathan', 159

declare @start_date datetime = '1/1/2017', --Approval Creation Start Date
		@end_date datetime = '8/17/2020'  --Approval Creation End Date

**************************************************************************** */
	
IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

SELECT DISTINCT customer_id INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id
	-- and sc.customer_id = @customer_id

SELECT secured_copc.company_id
       ,secured_copc.profit_ctr_id
INTO   #Secured_COPC
FROM   SecuredProfitCenter secured_copc (nolock)
WHERE  secured_copc.permission_id = @permission_id
       AND secured_copc.user_code = @user_code 

select 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, 
	count( distinct concat(r.company_id, '-', r.profit_ctr_id, '-', r.receipt_id)) as 'count of transactions',
	r.company_id, r.profit_ctr_id, 'R' as 'trans_source',
	DATEPART(MONTH, r.receipt_date) as 'transaction month', DATEPART(year, r.receipt_date) as 'transaction year'
from receipt r 
	join customer c (nolock)
		on r.customer_id = c.customer_id
join #Secured_Customer sc
	on c.customer_id = sc.customer_id
join #secured_COPC copc
	on r.company_id = r.company_id
	and r.profit_ctr_id = copc.profit_ctr_id
where r.receipt_status not in ('v', 'r') and r.trans_mode = 'I' 
	and r.receipt_date >= @start_date and r.receipt_date < @end_date
group by 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, 
	r.company_id, r.profit_ctr_id, 
	DATEPART(MONTH, r.receipt_date), DATEPART(year, r.receipt_date)

union

select 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, 
	count( distinct concat(w.company_id, '-', w.profit_ctr_id, '-', w.workorder_id)),
	w.company_id, w.profit_ctr_id, 'W' as 'trans_source',
	DATEPART(MONTH, w.start_date), DATEPART(year, w.start_date)
from workorderheader w
	join customer c (nolock)
		on w.customer_id = c.customer_id
join #Secured_Customer sc
	on c.customer_id = sc.customer_id
join #secured_COPC copc
	on w.company_id = copc.company_id
	and w.profit_ctr_id = copc.profit_ctr_id
where w.workorder_status not in ('v', 'r', 't')
	and w.start_date >= @start_date and w.start_date < @end_date
group by 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, 
	w.company_id, w.profit_ctr_id, 
	DATEPART(MONTH, w.start_date), DATEPART(year, w.start_date)

union
	
select 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, 
	count( distinct concat(od.company_id, '-', od.profit_ctr_id, '-', od.order_id, '-', od.line_id)),
	od.company_id, od.profit_ctr_id, 'O' as 'trans_source',
	DATEPART(MONTH, oh.order_date), DATEPART(year, oh.order_date)
from orderheader oh
	join customer c (nolock)
		on oh.customer_id = c.customer_id
	join orderdetail od
		on oh.order_id = od.order_id
join #Secured_Customer sc
	on c.customer_id = sc.customer_id
join #secured_COPC copc
	on od.company_id = copc.company_id
	and od.profit_ctr_id = copc.profit_ctr_id
where oh.status not in ('v', 'r', 't')
	and oh.order_date >= @start_date and oh.order_date < @end_date
group by 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag,
	od.company_id, od.profit_ctr_id, 
	DATEPART(MONTH, oh.order_date), DATEPART(year, oh.order_date)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_service_date TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_service_date TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_service_date TO [EQAI]
    AS [dbo];

