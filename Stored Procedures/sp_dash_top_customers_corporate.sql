
CREATE PROCEDURE sp_dash_top_customers_corporate (
	@num_returned		int = 100,
	@minimum_dollars	float = 1.00,
	@start_date			varchar(12),
	@end_date			varchar(12)
)
AS
/************************************************************
Procedure    : sp_dash_top_customers_corporate
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the top @num_returned customers billed across all companies
	with more than @minimum_dollars in activity between @start_date and @end_date

9/3/2009 - JPB Created	

04/26/2010 - RJG - Added ":59" to the end of the end_date query to include the last minute of the day
04/14/2014 - JPB - Added void_status check

exec sp_dash_top_customers_corporate 25, 1000, '9/1/2008', '9/30/2008'
exec sp_dash_top_customers_corporate 25, 1000, '03/1/2010', '03/31/2010'

************************************************************/

	SET NOCOUNT ON

	DECLARE @sql VARCHAR(5000)

	CREATE TABLE #output (
		customer_id		int,
		total			float
	)
	
	SET @sql = '
		INSERT #output
		SELECT TOP ' + CONVERT(VARCHAR(10), @num_returned) + '
			c.customer_id,
				SUM(d.extended_amt) total
			FROM
				BILLING b (nolock)
				INNER JOIN BILLINGDETAIL d (nolock) ON b.billing_uid = d.billing_uid
			INNER JOIN CUSTOMER c (nolock) ON b.customer_id = c.customer_id 
		WHERE
			b.invoice_date BETWEEN ''' + @start_date + ' 00:00'' AND ''' + @end_date + ' 23:59:59''
			AND b.status_code = ''I''
			AND b.void_status = ''F''
			AND c.customer_type <> ''IC''
		GROUP BY c.customer_id,
			c.cust_name,
			c.customer_type
		HAVING sum(d.extended_amt) >= ' + CONVERT(VARCHAR(20), @minimum_dollars) + '
		ORDER BY Sum(d.extended_amt) DESC
	'

	
	--print @sql
	EXEC ( @sql )

	SET NOCOUNT OFF
	
	SELECT
		a.customer_id,
		c.cust_name,
		c.customer_type,
		a.total
	FROM
		#output a
		INNER JOIN CUSTOMER c (nolock) on a.customer_id = c.customer_id
	ORDER BY 
		a.total DESC
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_corporate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_corporate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_top_customers_corporate] TO [EQAI]
    AS [dbo];

