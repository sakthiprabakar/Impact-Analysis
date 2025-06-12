
CREATE PROCEDURE sp_dash_top_customers_company (
	@num_returned		int = 100,
	@minimum_dollars	float = 1.00,
	@start_date			varchar(12),
	@end_date			varchar(12)
)
AS
/************************************************************
Procedure    : sp_dash_top_customers_company
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the top @num_returned customers billed across all companies
	with more than @minimum_dollars in activity between @start_date and @end_date,
	grouped by company (profit_ctr_id does not matter)

9/3/2009 - JPB Created	

04/26/2010 - RJG - Fixed bug that was returning multiple data sets (reporting svcs doesnt support them)
				   Added ORDER BY in the dynamic t-sql to correctly display the top 25 customers
05/23/2013 - JPB - Added (nolock) hints
04/14/2014 - JPB - Added void_status check.

sp_dash_top_customers_company 25, 1000, '9/1/2008', '9/30/2008'
-- first run: 190rows, 0:03s

exec sp_dash_top_customers_company 25, 1000, '03/1/2010', '03/31/2010'

************************************************************/

	SET NOCOUNT ON

	DECLARE @sql VARCHAR(5000), @company_id int
	
	CREATE TABLE #company (company_id int, flag int)
	
	INSERT #company 
	SELECT DISTINCT company_id, 0 from COMPANY (nolock)
	
	CREATE TABLE #output (
		company_id		int,
		customer_id		int,
		total			float
	)
	
	WHILE EXISTS (SELECT company_id from #company where flag = 0) BEGIN
		SET @company_id = (SELECT TOP 1 company_id from #company where flag = 0)
		
		SET @sql = '
			INSERT INTO #output
			SELECT TOP ' + CONVERT(VARCHAR(10), @num_returned) + '
				b.company_id,
				b.customer_id,
				SUM(d.extended_amt) total
			FROM
				BILLING b (nolock)
				INNER JOIN BILLINGDETAIL d (nolock) ON b.billing_uid = d.billing_uid
				INNER JOIN CUSTOMER c (nolock) ON b.customer_id = c.customer_id 
				INNER JOIN PROFITCENTER profitcenter (nolock) ON b.company_id = profitcenter.company_id and b.profit_ctr_id = profitcenter.profit_ctr_id
			WHERE
				b.invoice_date BETWEEN ''' + @start_date + ' 00:00'' AND ''' + @end_date + ' 23:59''
				AND b.company_id = ' + convert(varchar(10), @company_id) + '
				AND profitcenter.status = ''A''
				AND b.status_code = ''I''
				AND b.void_status = ''F''
				AND c.customer_type <> ''IC''
			GROUP BY 
				b.company_id,
				b.customer_id
			HAVING sum(d.extended_amt) >= ' + CONVERT(VARCHAR(20), @minimum_dollars) + '
			ORDER BY Sum(d.extended_amt) DESC
		'

		-- select @sql
		EXEC ( @sql )
		
		UPDATE #company SET flag = 1 where company_id = @company_id
	END
	
	SET NOCOUNT OFF
	
	SELECT
		a.company_id,
		b.company_name,
		a.customer_id,
		c.cust_name,
		c.customer_type,
		a.total
	FROM
		#output a
		INNER JOIN COMPANY b (nolock) on a.company_id = b.company_id
		INNER JOIN CUSTOMER c (nolock) on a.customer_id = c.customer_id
	ORDER BY 
		a.company_id,
		a.total DESC
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_company] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_company] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_company] TO [EQAI]
    AS [dbo];

