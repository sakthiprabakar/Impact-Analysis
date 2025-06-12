
CREATE PROCEDURE sp_dash_energy_surcharge_revenue (
	@StartDate 	datetime,
	@EndDate 	datetime,
	@user_code 	varchar(100) = NULL, -- for associates
	@contact_id	int = NULL, -- for customers
	@permission_id int
)
AS
/************************************************************
Procedure    : sp_dash_energy_surcharge_revenue
Database     : PLT_AI
Created      : Oct 20, 2009 - Jonathan Broome
Description  : Returns data on Linked transactions
	between @StartDate AND @EndDate

10/20/2009 - JPB Created	

sp_dash_energy_surcharge_revenue 
	@StartDate='2009-08-01 00:00:00',
	@EndDate='2009-08-31 23:59:59',
	@user_code='JONATHAN',
	@contact_id=-1
	
************************************************************/

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL


select 
	datename(m, @StartDate) + ' ' + convert(varchar(4), datepart(yyyy, @StartDate)) as [Period],
	b.company_id,
	cb.Territory_code, 
	sum(isnull(ensr_extended_amt,0)) as sum_ensr_extended_amt
from 
	billing b
	inner join customerbilling cb 
		on b.customer_id = cb.customer_id 
		and b.billing_project_id = cb.billing_project_id 
	INNER JOIN ProfitCenter copc
		ON b.company_id = copc.company_id 
		AND b.profit_ctr_id = copc.profit_ctr_id
		and copc.status = 'A'
	INNER JOIN Customer customer ON (customer.customer_id = b.customer_id)		
where 
	invoice_date between @StartDate and @EndDate
	and status_code = 'I'
Group by 
	b.company_id,
	cb.Territory_code
order by 
	b.company_id,
	cb.Territory_code
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_energy_surcharge_revenue] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_energy_surcharge_revenue] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_energy_surcharge_revenue] TO [EQAI]
    AS [dbo];

