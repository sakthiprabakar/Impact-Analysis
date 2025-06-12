
CREATE PROCEDURE sp_dash_top_customers_profitcenter (
	@num_returned		int = 100,
	@minimum_dollars	float = 1.00,
	@start_date			varchar(12),
	@end_date			varchar(12)
)
AS
/************************************************************
Procedure    : sp_dash_top_customers_profitcenter
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the top @num_returned customers billed across all companies
	with more than @minimum_dollars in activity between @start_date and @end_date,
	grouped by company and profit_ctr_id

9/3/2009 - JPB Created	

04/26/2010 - RJG - Fixed bug.  Added ORDER BY in the dynamic t-sql to 
					correctly display the top 25 customers
11/01/2012 - JPB - Converted the "total" column to sum BillingDetail 
					records amounts, instead of using billing's
					waste_extended_amt.
05/23/2013 - JPB - Added (nolock) hints
04/14/2014 - JPB - Added void_status check


exec sp_dash_top_customers_profitcenter 25, 1000, '9/1/2008', '9/30/2008'
exec sp_dash_top_customers_profitcenter 25, 1000, '9/1/2008', '9/30/2008'

************************************************************/

	SET NOCOUNT ON

	DECLARE @sql VARCHAR(5000), @company_id int, @profit_ctr_id int
	
	CREATE TABLE #company (company_id int, profit_ctr_id int, flag int)
	
	INSERT #company 
	SELECT DISTINCT company_id, profit_ctr_id, 0 from PROFITCENTER (nolock) WHERE status = 'A'
	
	CREATE TABLE #output (
		company_id		int,
		profit_ctr_id	int,
		customer_id		int,
		total			float
	)
	
	WHILE EXISTS (SELECT company_id from #company where flag = 0) BEGIN
		SELECT TOP 1 
			@company_id = company_id,
			@profit_ctr_id = profit_ctr_id
		FROM #company where flag = 0
		
		SET @sql = '
			INSERT #output
			SELECT TOP ' + CONVERT(VARCHAR(10), @num_returned) + '
				b.company_id,
				b.profit_ctr_id,
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
				AND b.profit_ctr_id = ' + convert(varchar(10), @profit_ctr_id) + '
				AND profitcenter.status = ''A''
				AND b.status_code = ''I''
				AND b.void_status = ''F''
				AND c.customer_type <> ''IC''
			GROUP BY 
				b.company_id,
				b.profit_ctr_id,
				b.customer_id
			HAVING sum(d.extended_amt) >= ' + CONVERT(VARCHAR(20), @minimum_dollars) + '
			ORDER BY Sum(d.extended_amt) DESC
		'

		--select @company_id, @profit_ctr_id, @sql
		EXEC ( @sql )
				
		UPDATE #company SET flag = 1 where company_id = @company_id and profit_ctr_id = @profit_ctr_id
	END
	
	SET NOCOUNT OFF
	
	SELECT
		a.company_id,
		a.profit_ctr_id,
		b.profit_ctr_name,
		a.customer_id,
		c.cust_name,
		c.customer_type,
		a.total
	FROM
		#output a
		INNER JOIN PROFITCENTER b (nolock) on a.company_id = b.company_id and a.profit_ctr_id = b.profit_ctr_id
		INNER JOIN CUSTOMER c (nolock) on a.customer_id = c.customer_id
	ORDER BY 
		a.company_id,
		a.profit_ctr_id,
		a.total DESC
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_profitcenter] TO [EQAI]
    AS [dbo];

