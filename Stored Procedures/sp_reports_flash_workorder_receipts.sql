CREATE PROCEDURE sp_reports_flash_workorder_receipts
	@StartDate datetime,
	@EndDate datetime,
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers
	@copc_list varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@invoiced_included varchar(1) = 'F',
	@permission_id int
AS
	
/* ******************************************************************************
	exec sp_reports_flash_workorder_receipts 
		@StartDate='2009-09-17 00:00:00',
		@EndDate='2010-12-31 00:00:00',
		@user_code=N'RICH_G',
		@contact_id=-1,
		@copc_list=N'14|0,21|0',
		@invoiced_included='T',
		@permission_id = 64
	
	2009-11-03, RJG - Added fields:
			@StartDate AS StartDate,
			@EndDate AS EndDate,
			w.date_modified,
			w.description,
			w.modified_by
			
	2010-03-05, JPB - Added HAVING clause to ignore 0-dollar amounts unless the
		print_on_invoice flag is set.
		06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
****************************************************************************** */

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL
	
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
	
	/*
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id		
		
	SELECT DISTINCT generator_id, generator_name INTO #Secured_Generator
		FROM SecuredGenerator sg WHERE sg.user_code = @user_code
		and sg.permission_id = @permission_id		
		
	create index cui_secured_customer_tmp on #Secured_Customer(customer_id)	
	create index cui_secured_generator_tmp on #Secured_Generator(generator_id)	
	*/
	
	DECLARE @user_id int
	SELECT @user_id = user_id FROM Users where user_code = @user_code
	
	SELECT ags.* INTO #user_access
		FROM AccessGroupSecurity ags 
		INNER JOIN AccessPermissionGroup apg ON ags.group_id = apg.group_id
		WHERE user_id = @user_id
		AND apg.permission_id = @permission_id
		and apg.action_id = 2 -- read
		AND ags.status = 'A'
		
/*		
SELECT b.invoice_code, ih.invoice_date
                                                  FROM   billing b
                                                  INNER JOIN workorderheader w ON
                                                  b.company_id = w.company_id
                                                         AND b.profit_ctr_id = w.profit_ctr_id
                                                         AND b.receipt_id = w.workorder_id
                                                         AND b.trans_source = 'W'
                                                         AND b.status_code = 'I'
                                                         INNER JOIN InvoiceHeader ih
                                                           ON b.invoice_id = ih.invoice_id
                                                  WHERE  ih.status = 'I'	
AND w.workorder_status NOT IN ('V','X','T') 
         AND end_date BETWEEN @StartDate AND @EndDate
         --and isnull(submitted_flag, 'F') = 'F' 
		AND 1 = CASE 
					WHEN @invoiced_included = 'T' THEN 1 /* include everything */
					WHEN 
						@invoiced_included  = 'F' AND 
				  (0 = (SELECT Count(*) FROM   billing b 
					WHERE  b.company_id = w.company_id 
                         AND b.profit_ctr_id = w.profit_ctr_id 
                         AND b.receipt_id = w.workorder_id 
                         AND b.trans_source = 'W' 
                         AND b.status_code = 'I'))  THEN 1
                    ELSE 0
                   END                                                       	
*/		
		
	
	INSERT @tbl_profit_center_filter 
		SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
			FROM 
				SecuredProfitCenter secured_copc
			INNER JOIN (
				SELECT 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
					RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
				from dbo.fn_SplitXsvText(',', 0, @copc_list) 
				where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
				and secured_copc.permission_id = @permission_id
				and secured_copc.user_code = @user_code

SELECT   w.company_id, 
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
         w.workorder_type, 
         w.billing_project_id, 
         cb.project_name,
         t.account_desc, 
         gl.account_code, 
         Sum(Isnull(w.total_price,0)) AS 'total_price',
         cb.territory_code,
         g.generator_id,
         g.EPA_ID,
         CASE WHEN @invoiced_included = 'T' THEN (SELECT DISTINCT b.invoice_code
                                                  FROM   billing b
                                                         INNER JOIN InvoiceHeader ih
                                                           ON b.invoice_id = ih.invoice_id
                                                  WHERE  b.company_id = w.company_id
                                                         AND b.profit_ctr_id = w.profit_ctr_id
                                                         AND b.receipt_id = w.workorder_id
                                                         AND b.trans_source = 'W'
                                                         AND b.status_code = 'I'
                                                         AND ih.status = 'I')
			ELSE NULL                                                         
		 END as invoice_code,
         CASE WHEN @invoiced_included = 'T' THEN (SELECT DISTINCT ih.invoice_date
                                                  FROM   billing b
                                                         INNER JOIN InvoiceHeader ih
                                                           ON b.invoice_id = ih.invoice_id
                                                  WHERE  b.company_id = w.company_id
                                                         AND b.profit_ctr_id = w.profit_ctr_id
                                                         AND b.receipt_id = w.workorder_id
                                                         AND b.trans_source = 'W'
                                                         AND b.status_code = 'I'
                                                         AND ih.status = 'I')
			ELSE NULL                                                         
		 END as invoice_date,         
         w.created_by,
         w.date_added,
         @StartDate AS StartDate,
         @EndDate AS EndDate,
         w.date_modified,
         w.description,
         w.modified_by
FROM     workorderheader w 
		 INNER JOIN @tbl_profit_center_filter secured_copc 
			ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
			JOIN #user_access secured_customers ON (secured_customers.customer_id = -9999 or secured_customers.customer_id = w.customer_id) and secured_customers.record_type = 'C'
			JOIN #user_access secured_generators ON (secured_generators.generator_id = -9999 or secured_generators.generator_id = w.generator_id) and secured_generators.record_type = 'G'
			--JOIN SecuredGenerator secured_generators ON (secured_generators.generator_id = w.generator_id)
         JOIN workordertype t 
           ON t.account_type = w.workorder_type 
              AND t.company_id = w.company_id 
         JOIN glaccount gl 
           ON gl.company_id = w.company_id 
              AND gl.profit_ctr_id = w.profit_ctr_id 
              AND gl.account_type = w.workorder_type 
         JOIN customer c 
           ON w.customer_id = c.customer_id 
         LEFT OUTER JOIN generator g 
           ON g.generator_id = w.generator_id 
         LEFT OUTER JOIN customerbilling cb ON cb.customer_id = w.customer_id AND cb.billing_project_id = w.billing_project_id
                                  
WHERE    w.workorder_status NOT IN ('V','X','T') 
         AND end_date BETWEEN @StartDate AND @EndDate
         --and isnull(submitted_flag, 'F') = 'F' 
		AND 1 = CASE 
					WHEN @invoiced_included = 'T' THEN 1 /* include everything */
					WHEN 
						@invoiced_included  = 'F' AND 
				  (0 = (SELECT Count(*) FROM   billing b 
					WHERE  b.company_id = w.company_id 
                         AND b.profit_ctr_id = w.profit_ctr_id 
                         AND b.receipt_id = w.workorder_id 
                         AND b.trans_source = 'W' 
                         AND b.status_code = 'I'))  THEN 1
                    ELSE 0
                   END     
GROUP BY w.company_id, 
         w.profit_ctr_id, 
         w.workorder_status, 
         w.submitted_flag, 
         w.end_date, 
         w.workorder_id, 
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
         w.date_added, 
         w.date_modified,
         w.description,
         w.modified_by,
         gl.account_desc,
         w.created_by,
         cb.territory_code
HAVING
		Sum(Isnull(w.total_price,0)) > 0
		OR
		(
			Sum(Isnull(w.total_price,0)) = 0
			AND EXISTS (
				select 1 from workorderdetail 
				where workorder_id = w.workorder_id
				and profit_ctr_id = w.profit_ctr_id
				and company_id = w.company_id
				and print_on_invoice_flag = 'T'
			)
		)
ORDER BY w.company_id, 
         w.profit_ctr_id, 
         w.workorder_id 
         
         
         
         
         
         


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_workorder_receipts] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_workorder_receipts] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_workorder_receipts] TO [EQAI]
    AS [dbo];

