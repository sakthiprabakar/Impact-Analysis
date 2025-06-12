CREATE PROCEDURE sp_top_customers (
	@num_per_company	int = 100,
	@minimum_dollars	float = 1.00,
	@start_date			varchar(12) = null,
	@end_date			varchar(12) = null
)
AS
/************************************************************
Procedure    : sp_top_customers
Database     : PLT_AI
Created      : Sep 8, 2008 - Jonathan Broome
Description  : Returns 2 recordsets: 1st = top customers by billed amount per company.
	2nd = top customers by billed amount across all companies.

9/8/2008 - JPB Created	
	
sp_top_customers 25, 1000, '7/1/2008', '7/31/2008'
sp_top_customers 25, 1000

************************************************************/

	IF @start_date is null or @end_date is null return
	IF @start_date = '' or @end_date = '' return

	set nocount on
	declare @company_id int
	declare @sql varchar(1000)

	select distinct company_id, 0 as progress into #company_list from eqconnect

	create table #topcustomers (
		company_id		int, 
		profit_ctr_id	int, 
		cust_name		varchar(75), 
		customer_id		int,
		customer_type	varchar(20), 
		total			float)

	while (select count(*) from #company_list where progress = 0) > 0 begin
		select top 1 @company_id = company_id from #company_list where progress = 0
		set @sql = ''

		set @sql = @sql + 'insert #topcustomers select top ' + convert(varchar(10), @num_per_company) +
			' b.company_id, b.profit_ctr_id, c.cust_name, b.customer_id, ' +
			' c.customer_type, sum(b.waste_extended_amt) as total '

		set @sql = @sql + ' from billing b, customer c where 1=1 '

		if @start_date is not null set @sql = @sql + ' and b.invoice_date >= ''' + @start_date + ' 00:00:00'' '

		if @end_date is not null set @sql = @sql + ' and b.invoice_date <= ''' + @end_date + ' 23:59:59'' '

		set @sql = @sql + ' and b.status_code=''I'' ' +
			' and b.customer_id=c.customer_id ' +
			' and c.customer_type <> ''IC'' ' +
			' and b.company_id = ' + convert(varchar(10), @company_id) +
			' group by b.company_id, b.profit_ctr_id, b.customer_id, ' +
			' c.cust_name, c.customer_type ' +
			' having sum(b.waste_extended_amt) >= ' + convert(varchar(20), @minimum_dollars) +
			' order by sum(waste_extended_amt) desc '

		-- select @sql
		exec ( @sql )
		update #company_list set progress = 1 where company_id = @company_id
	end

	set nocount off

	-- First recordset: Group by company.
	select company_id, profit_ctr_id, cust_name, customer_id, customer_type, sum(total) as total 
	from #topcustomers
	group by company_id, profit_ctr_id, customer_id, cust_name, customer_type
	order by company_id, profit_ctr_id, total desc

	-- Second recordset: Overall (no grouping by company)
	set @sql = 'select top ' + convert(varchar(10), @num_per_company) +
	' cust_name, customer_id, customer_type, sum(total) as total 
	from #topcustomers
	group by cust_name, customer_id, customer_type
	order by total desc '
	
	exec ( @sql )
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_top_customers] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_top_customers] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_top_customers] TO [EQAI]
    AS [dbo];

