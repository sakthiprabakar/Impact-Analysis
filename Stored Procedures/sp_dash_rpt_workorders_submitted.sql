CREATE PROCEDURE [dbo].[sp_dash_rpt_workorders_submitted]
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(20) = NULL,
	@contact_id		int = NULL,
	@copc_list		varchar(2000),
	@permission_id int
AS
/* ************************************************
sp_dash_rpt_workorders_submitted:
 
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for
	@user_id:			Ther user_id of the person calling
	@copc_list:			A csv list of co/pc info (i.e. 14|0,12|1)

--Tests 
--Tests normal use
exec sp_dash_rpt_workorders_submitted '01/01/2009', '01/30/2009', 'rich_g', null, '14|0'

--Tests  bad user
exec sp_dash_rpt_workorders_submitted '01/01/2009', '01/30/2009', 'foo_bar', null, '14|0'

--Tests large date range
exec sp_dash_rpt_workorders_submitted '01/01/2009', '10/30/2009', 'rich_g', null, '14|0'

10/07/2009 RJG Created
10/12/2009 RJG Fixed bug when summing the total for each billing line item -- now only uses total_price
************************************************ */

/* filter out both what the user has access to and which co/pc list items they want to see */

IF @user_code = ''
	set @user_code = NULL

IF @user_code IS NOT NULL
	SET @contact_id = NULL

IF @contact_id IS NOT NULL
	SET @user_code = NULL



declare @workorder_status_type table
(
	code char(1),
	name varchar(50)
)


	/*
A - Accepted
C - Complete
D - Dispatched
N - New
P - Priced
T - Submitted
V - Void
X - Transfer
	*/


INSERT INTO @workorder_status_type VALUES ('A', 'Accepted')
INSERT INTO @workorder_status_type VALUES ('C', 'Complete')
INSERT INTO @workorder_status_type VALUES ('D', 'Dispatched')
INSERT INTO @workorder_status_type VALUES ('N', 'New')
INSERT INTO @workorder_status_type VALUES ('P', 'Priced')
INSERT INTO @workorder_status_type VALUES ('T', 'Submitted')
INSERT INTO @workorder_status_type VALUES ('V', 'Void')
INSERT INTO @workorder_status_type VALUES ('X', 'Trip')


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
		
	SELECT DISTINCT generator_id, generator_name INTO #Secured_Generator
		FROM SecuredGenerator sg WHERE sg.user_code = @user_code
		and sg.permission_id = @permission_id		


	SELECT
		 --Sum(Isnull(w.total_price, 0)) AS 'total_price',
		 w.total_price,
		 w.workorder_id,
		 w.company_id,
         w.profit_ctr_id,
         (select top 1 name from @workorder_status_type where code = w.workorder_status) as workorder_status,
         --w.workorder_status,
         case when w.submitted_flag = 'F' THEN 'False'
				WHEN w.submitted_flag = 'T' THEN 'True'
		END as submitted_flag,
--         w.submitted_flag,
         w.end_date,
         w.workorder_id,
         c.customer_id,
         c.cust_name,
         g.epa_id,
         g.generator_name,
         g.generator_id,
         w.workorder_type,
         w.billing_project_id,
         cb.project_name,
         t.account_desc,
         gl.account_code,
         gl.account_desc as 'gl_account_desc',
         b.invoice_id,
         b.invoice_date,
         b.invoice_code
FROM     workorderheader w

		 INNER JOIN @tbl_profit_center_filter secured_copc
			ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
		 INNER JOIN #Secured_Customer secured_customers ON (secured_customers.customer_id = w.customer_id)
		 INNER JOIN #Secured_Generator secured_generator ON (secured_generator.generator_id = w.generator_id)
         INNER JOIN workordertype t
           ON t.account_type = w.workorder_type
              AND t.company_id = w.company_id
         INNER JOIN glaccount gl
           ON gl.company_id = w.company_id
              AND gl.profit_ctr_id = w.profit_ctr_id
              AND gl.account_type = w.workorder_type
         INNER JOIN customer c
           ON w.customer_id = c.customer_id
         INNER JOIN generator g
           ON g.generator_id = w.generator_id
         LEFT OUTER JOIN customerbilling cb
			ON cb.customer_id = w.customer_id
			AND cb.billing_project_id = w.billing_project_id
         LEFT OUTER JOIN Billing b
			ON b.receipt_id = w.workorder_ID
			AND b.trans_source = 'W'
			AND b.company_id = w.company_id
			AND b.profit_ctr_id = b.profit_ctr_id
			AND b.status_code = 'I'
WHERE
		w.workorder_status NOT IN ('V','X','T')
         AND end_date BETWEEN @start_date AND @end_date
GROUP BY
		w.total_price,
		b.invoice_date,
		b.invoice_id,
		b.invoice_code,
		w.company_id,
		w.profit_ctr_id,
		w.workorder_status,
		w.workorder_id,
		w.submitted_flag,
		w.end_date,
		c.customer_id,
		c.cust_name,
		g.epa_id,
		g.generator_name,
		g.generator_id,
		w.workorder_type,
		w.billing_project_id,
		t.account_desc,
		gl.account_code,
		cb.project_name,
		gl.account_desc

ORDER BY w.company_id,
         w.profit_ctr_id,
         w.workorder_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_rpt_workorders_submitted] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_rpt_workorders_submitted] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_rpt_workorders_submitted] TO [EQAI]
    AS [dbo];

