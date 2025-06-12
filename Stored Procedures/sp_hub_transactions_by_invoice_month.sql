-- drop proc if exists sp_hub_transactions_by_invoice_month
go

create proc sp_hub_transactions_by_invoice_month (
	@start_date datetime = null
	, @end_date datetime = null
	, @user_code		varchar(20)
	, @permission_id	int
	, @debug_code			int = 0	
)
as
/* ****************************************************************************
sp_hub_transactions_by_invoice_month

Transactions by Invoice Month	
Generates an extract of transaction count by company, profit center and type 
with a total per invoicing month and year based on when the transaction is invoiced.	

History:
09/01/2020	JPB	Created

Sample:

	sp_hub_transactions_by_invoice_month '1/1/2017', '8/31/2020', 'jonathan', 159

declare @start_date datetime = '1/1/2017', --Approval Creation Start Date
		@end_date datetime = '8/17/2020'  --Approval Creation End Date

**************************************************************************** */
	
IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

SELECT DISTINCT customer_id INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id
	-- and sc.customer_id = @customer_id

select 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag as 'USE Internal Customer', --c.msg_customer_flag, 
	b.company_id, b.profit_ctr_id, b.trans_source,
	(select count(distinct receipt_id) 
		from billing (nolock)
		where trans_source = b.trans_source
			and company_id = b.company_id 
			and profit_ctr_id = b.profit_ctr_id 
			and customer_id = c.customer_id 
			and datepart(month, b.invoice_date) = datepart(month, invoice_date) 
			and datepart(year, b.invoice_date) = datepart(year, invoice_date)) as 'count of transactions',
	DATEPART(MONTH, b.invoice_date) as 'invoice month',
	DATEPART(year, b.invoice_date) as 'invoice year'
from billing b (nolock)
join customer c (nolock)
	on b.customer_id = c.customer_id
join #Secured_Customer sc
	on c.customer_id = sc.customer_id
where 
	b.invoice_date >= @start_date
	and b.invoice_date < @end_date
	and b.status_code in ('I')
group by 
	c.customer_id, c.cust_name, c.cust_category, c.eq_flag, --c.msg_customer_flag, 
	b.company_id, b.profit_ctr_id, b.trans_source, 
	DATEPART(MONTH, b.invoice_date), DATEPART(year, b.invoice_date)
order by 
	c.customer_id, DATEPART(MONTH, b.invoice_date), DATEPART(year, b.invoice_date)
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_invoice_month TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_invoice_month TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_transactions_by_invoice_month TO [EQAI]
    AS [dbo];

