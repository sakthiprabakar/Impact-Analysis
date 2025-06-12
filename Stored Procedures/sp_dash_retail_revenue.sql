
CREATE PROCEDURE sp_dash_retail_revenue
	@StartDate 	datetime,
	@EndDate 	datetime,
	@user_code 	varchar(100) = NULL, -- for associates
	@contact_id	int = NULL, -- for customers,
	@copc_list 	varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@permission_id int
AS
/* ************************************************
sp_dash_retail_revenue:
	@StartDate 			The start date to query for
	@EndDate 			The end date to query for
	@user_code 			for associates
	@contact_id			for customers,
	@copc_list 			The list of company|profitcenter combinations to restrict by

Total amount of retail orders received per company/profitcenter

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Removed ProfitCenter join, it was inflating results, and unused.
				Added o.status <> 'V' check
10/19/2009 JPB Converted to Analysis type
06/16/2023 Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

sp_dash_retail_revenue 
	@StartDate='2009-01-01 00:00:00',
	@EndDate='2009-09-30 23:59:59',
	@user_code='JONATHAN',
	@contact_id=-1,
	@copc_list='2|21,3|1,21|0,14|9'

************************************************ */

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL

declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)
	

	INSERT @tbl_profit_center_filter
		SELECT secured_copc.company_id, secured_copc.profit_ctr_id
			FROM SecuredProfitCenter secured_copc
			INNER JOIN (
				SELECT
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
					RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
				from dbo.fn_SplitXsvText(',', 0, @copc_list)
				where isnull(row, '') <> '') selected_copc 
				ON secured_copc.company_id = selected_copc.company_id 
				AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
				AND secured_copc.user_code = @user_code
				AND secured_copc.permission_id = @permission_id
				
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id						

SELECT od.company_id,
	od.profit_ctr_id,
	pr.profit_ctr_name,
	DATEPART(YYYY, oh.order_date) AS invoice_year, 
	DATEPART(M, oh.order_date) AS invoice_month, 
	p.short_description,
	SUM(od.quantity) AS total_quantity,	
	SUM(od.extended_amt) AS total_extended_amt	
FROM orderheader oh
INNER JOIN orderdetail od ON oh.order_id = od.order_id
INNER JOIN @tbl_profit_center_filter secured_copc 
	ON od.company_id = secured_copc.company_id 
	AND od.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN ProfitCenter pr ON od.company_id = pr.company_ID AND od.profit_ctr_id = pr.profit_ctr_ID
INNER JOIN Product p ON od.product_id = p.product_ID AND od.company_id = p.company_ID AND od.profit_ctr_id = p.profit_ctr_ID
INNER JOIN #Secured_Customer secured_customer ON (secured_customer.customer_id = oh.customer_id)
		 
WHERE oh.order_date BETWEEN @StartDate AND @EndDate
GROUP BY 
	od.company_id, 
	od.profit_ctr_id, 
	pr.profit_ctr_name, 
	DATEPART(YYYY, oh.order_date), 
	DATEPART(M, oh.order_date),
	p.short_description
ORDER BY 
	DATEPART(YYYY, oh.order_date), 
	DATEPART(M, oh.order_date),
	od.company_id, 
	od.profit_ctr_id, 
	SUM(od.extended_amt) desc,
	SUM(od.quantity) desc,
	p.short_description


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retail_revenue] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retail_revenue] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retail_revenue] TO [EQAI]
    AS [dbo];

