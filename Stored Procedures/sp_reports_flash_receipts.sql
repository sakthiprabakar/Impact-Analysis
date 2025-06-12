CREATE PROCEDURE sp_reports_flash_receipts
	@StartDate datetime,
	@EndDate datetime,
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers,
	@copc_list varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@invoiced_included varchar(1) = 'F',
	@permission_id int
	
	/*
	06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
	exec sp_reports_flash_receipts 
		@StartDate='2009-09-17 00:00:00',
		@EndDate='2009-09-30 00:00:00',
		@user_code=N'RICH_G',
		@contact_id=-1,
		@copc_list=N'2|21',
		@invoiced_included='T',
		@permission_id=66
	*/
AS

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL


declare @status_type table
(
	code char(1),
	name varchar(50)
)

INSERT INTO @status_type VALUES ('A', 'Accepted')
INSERT INTO @status_type VALUES ('N', 'New')
INSERT INTO @status_type VALUES ('I', 'I')
INSERT INTO @status_type VALUES ('L', 'In the Lab')
INSERT INTO @status_type VALUES ('M', 'Manual')
INSERT INTO @status_type VALUES ('R', 'Rejected')
INSERT INTO @status_type VALUES ('T', 'In-Transit')
INSERT INTO @status_type VALUES ('U', 'Unloading')
INSERT INTO @status_type VALUES ('V', 'Void')

declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)



	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id		
	
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

/*
NULL - New
A - Accepted
I - ?
L - In the Lab
M - Manual
N - New
R - Rejected
T - In-Transit
U - Unloading
V - Void
*/

SELECT  r.company_id, 
         r.profit_ctr_id, 
         (select TOP 1 name from @status_type where code = r.receipt_status) as receipt_status ,
         --r.receipt_status, 
         --r.submitted_flag, 
         case when r.submitted_flag = 'F' THEN 'False'
				WHEN r.submitted_flag = 'T' THEN 'True'
		END as submitted_flag,         
         r.receipt_date, 
         r.receipt_id, 
         r.customer_id, 
         c.cust_name, 
         g.epa_id, 
         g.generator_id,
         g.generator_name, 
         r.treatment_id, 
         r.billing_project_id, 
         r.gl_account_code, 
         Sum(Isnull(rp.waste_extended_amt,0))        AS 'waste_extended_amt', 
         rp.bundled_tran_gl_account_code, 
         Sum(Isnull(rp.bundled_tran_extended_amt,0)) AS 'bundled_tran_extended_amt',
         SUM(ISNULL(rp.sr_extended_amt,0)) AS 'sr_extended_amt',
         SUM(ISNULL(rp.total_extended_amt,0)) AS 'total_extended_amt',
         cb.project_name,
         cb.territory_code,
		 CASE 
			WHEN @invoiced_included = 'T' THEN dbo.fn_get_receipt_invoice_codes(r.receipt_id, r.company_id, r.profit_ctr_id) 
			ELSE NULL
		END as invoice_code,
		 CASE 
			WHEN @invoiced_included = 'T' THEN dbo.fn_get_receipt_invoice_dates(r.receipt_id, r.company_id, r.profit_ctr_id) 
			ELSE NULL
		END as invoice_date,
		r.manifest
				 --CASE WHEN @invoiced_included = 'T' THEN (SELECT DISTINCT ih.invoice_date
					--									  FROM   billing b
					--											 INNER JOIN InvoiceHeader ih
					--											   ON b.invoice_id = ih.invoice_id
					--									  WHERE  b.company_id = r.company_id
					--											 AND b.profit_ctr_id = r.profit_ctr_id
					--											 AND b.receipt_id = r.receipt_id
					--											 --AND b.line_id = r.line_id
					--											 AND b.trans_source = 'R'
					--											 AND b.status_code = 'I'
					--											 AND ih.status = 'I')
					--ELSE NULL                                                         
				 --END as invoice_date              
FROM     Receipt r 
		INNER JOIN @tbl_profit_center_filter secured_copc ON (r.company_id = secured_copc.company_id AND r.profit_ctr_id = secured_copc.profit_ctr_id)
         JOIN receiptprice rp 
           ON rp.company_id = r.company_id 
              AND rp.profit_ctr_id = r.profit_ctr_id 
              AND rp.receipt_id = r.receipt_id 
              AND rp.line_id = r.line_id 
              AND rp.print_on_invoice_flag = 'T' /* added from EQAI version */
         JOIN #Secured_Customer secured_customer ON (secured_customer.customer_id = r.customer_id)
         JOIN customer c 
           ON r.customer_id = c.customer_id
         LEFT OUTER JOIN generator g 
           ON g.generator_id = r.generator_id           
		 LEFT OUTER JOIN customerbilling cb ON cb.customer_id = r.customer_id AND cb.billing_project_id = r.billing_project_id           
	WHERE    
		 r.receipt_status NOT IN ('V','R','T') 
		 AND r.fingerpr_status IN ('W','H','A') /* Wait, Hold, Accepted */
         AND trans_mode = 'I' 
         AND receipt_date BETWEEN @StartDate AND @EndDate
         /*--and isnull(submitted_flag, 'F') = 'F' */
         AND 1 = CASE 
					WHEN @invoiced_included = 'T' THEN 1 /* include everything */
					WHEN 
						@invoiced_included  = 'F' AND 
				  (0 = (SELECT Count(*) 
                  FROM   billing b 
                  WHERE  b.company_id = r.company_id 
                         AND b.profit_ctr_id = r.profit_ctr_id 
                         AND b.receipt_id = r.receipt_id 
                         AND b.trans_source = 'r' 
                         AND b.status_code = 'I'))  THEN 1
                    ELSE 0
                   END                         
         
GROUP BY r.company_id, 
         r.profit_ctr_id, 
         r.receipt_status, 
         r.submitted_flag, 
         r.receipt_date, 
         r.receipt_id, 
         r.customer_id, 
         c.cust_name, 
         g.epa_id, 
         g.generator_name, 
         r.treatment_id, 
         r.billing_project_id, 
         r.gl_account_code, 
         rp.bundled_tran_gl_account_code,
         cb.project_name,
         g.generator_id,
         cb.territory_code,
         r.manifest
ORDER BY r.company_id, 
         r.profit_ctr_id, 
         r.receipt_id 





GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_receipts] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_receipts] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_flash_receipts] TO [EQAI]
    AS [dbo];

