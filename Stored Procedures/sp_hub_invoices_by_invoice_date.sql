-- drop proc if exists sp_hub_invoices_by_invoice_date
go

create proc sp_hub_invoices_by_invoice_date (
	@start_date datetime = null
	, @end_date datetime = null
	, @user_code		varchar(20)
	, @permission_id	int
	, @debug_code			int = 0	
)
as
/* ****************************************************************************
sp_hub_invoices_by_invoice_date

Invoices by invoice date	
Generates an extract of invoices created within a time frame with a count and 
total amount invoiced by month and year.

History:
09/01/2020	JPB	Created

Sample:

	sp_hub_invoices_by_invoice_date '1/1/2017', '8/31/2020', 'jonathan', 159

declare @start_date datetime = '1/1/2017', --Approval Creation Start Date
		@end_date datetime = '8/17/2020'  --Approval Creation End Date

**************************************************************************** */
	
IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

SELECT DISTINCT customer_id INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id
	-- and sc.customer_id = @customer_id

select 
	sum(ih.total_amt_due) as 'total invoiced', 
	count(distinct ih.invoice_code) as 'count of invoices', 
	c.customer_id, 
	c.cust_name, 
	c.cust_category, 
	c.eq_flag as 'USE Internal Customer',
	datepart(month, ih.invoice_date) as 'month added',
	datepart(year, ih.invoice_date) as 'year added',
	case when (ih.status = 'I') then 'Invoiced'
		when (ih.status = 'H') then 'Hold'
		when (ih.status = 'P') then 'Preview'
	end as 'status'
from invoiceheader ih 
	join #Secured_Customer sc
		on ih.customer_id = sc.customer_id
	join customer c (nolock)
		on ih.customer_id = c.customer_id
where ih.status not in ('v', 'r', 'o')
	and ih.invoice_date >= @start_date and ih.invoice_date < @end_date
group by c.customer_id, c.cust_name, c.cust_category, c.eq_flag,
		datepart(month, ih.invoice_date),
		datepart(year, ih.invoice_date), 
		ih.status
order by c.customer_id, c.cust_name, c.cust_category, c.eq_flag,
		datepart(year, ih.invoice_date), 
		datepart(month, ih.invoice_date),
		ih.status

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_invoices_by_invoice_date TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_invoices_by_invoice_date TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_invoices_by_invoice_date TO [EQAI]
    AS [dbo];

