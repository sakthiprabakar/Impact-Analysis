/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

CREATE PROCEDURE [dbo].[sp_reports_pricing]
	@StartDate datetime,
	@EndDate datetime,
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers
	@copc_list varchar(500) = NULL, -- ex: 21|1,14|0,14|1	
	@permission_id int
AS

--	select * from view_extract_rpt_receipt_price
	
	-- convert EndDate to 11:59:59 inclusive
	SET @EndDate = CONVERT(varchar(8), @EndDate, 112) + ' 23:59:59'

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL


declare @status_type table
(
	code char(1),
	name varchar(50)
)

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
		
		SELECT r.*
        FROM   view_extract_rpt_receipt_price r
               INNER JOIN @tbl_profit_center_filter secured_copc
                 ON ( r.company_id = secured_copc.company_id
                      AND r.profit_ctr_id = secured_copc.profit_ctr_id )
               INNER JOIN #Secured_Customer secured_customer
                 ON ( secured_customer.customer_id = r.customer_id )
        WHERE  r.receipt_date BETWEEN @StartDate AND @EndDate
        ORDER  BY r.receipt_date ASC 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pricing] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pricing] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_pricing] TO [EQAI]
    AS [dbo];

*/
