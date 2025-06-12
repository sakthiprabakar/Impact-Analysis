
CREATE PROCEDURE sp_extract_rpt_workorder
	@return_schema_only char(1) = 'F',
	@return_count_only char(1) = 'F',
	@filter_expression varchar(max) = '',
	@start  int = 1,
	@maxct  int = 15,
	@sort   nvarchar(200) = NULL
	,@user_code	varchar(20) 
	,@permission_id int
	AS
	
SET NOCOUNT ON	
IF @start is null
set @start = 1

--DECLARE @contact_id INT
--SET @contact_id = 101298 -- Contacts should use their contact_id
--SET @contact_id = 0 -- Associates should use 0

declare @stmt varchar(max)
declare @ubound int

IF @sort IS NULL
	set @sort = 'workorder_id desc'

IF @return_schema_only = 'T'
	set @sort = 'workorder_id desc'

IF @filter_expression IS NULL OR LEN(@filter_expression) = 0
	set @filter_expression = '1=1'

-- replace single quote with escaped quote
set @filter_expression = REPLACE(@filter_expression, '''''', '''')

IF @start < 1 SET @start = 1
  IF @maxct < 1 SET @maxct = 1
  SET @ubound = @start + @maxct

	declare @main_sql varchar(max) = ''

	SET @main_sql = 'SELECT
					row_number() over(order by ' + @sort + ') as ROWID,
				    * FROM view_extract_rpt_workorder
			WHERE 1=1
				AND ' + @filter_expression


set @main_sql = @main_sql +
			' AND 1 = CASE
						WHEN ''' + @return_schema_only + ''' = ''T'' THEN 0
						ELSE 1
			 END'


--print @main_sql
IF @return_count_only = 'F'
BEGIN
  SET @STMT = ' SELECT *
                FROM (' + @main_sql +' ) AS tbl
                WHERE  ROWID >= ' + CONVERT(varchar(9), @start) + ' AND
                       ROWID <  ' + CONVERT(varchar(9), @ubound)
  --PRINT @stmt
	EXEC (@STMT) -- return slice
END

ELSE

BEGIN
SET @STMT = ' SELECT COUNT(*) record_count
                FROM (' + @main_sql +' ) AS tbl'
	EXEC (@STMT)
END






/*

DECLARE @contact_id INT
SET @contact_id = 101298 -- Contacts should use their contact_id
SET @contact_id = 0 -- Associates should use 0

declare @stmt varchar(max)
declare @ubound int

if @return_schema_only = 'T'
	set @sort = 'workorder_id'


IF @filter_expression IS NULL OR LEN(@filter_expression) = 0
	set @filter_expression = '1=1'

-- replace single quote with escaped quote
set @filter_expression = REPLACE(@filter_expression, '''''', '''')



SELECT * INTO #tbl FROM (
SELECT DISTINCT
    workorderheader.company_id,
    workorderheader.profit_ctr_id, -- AS profit_center_id,
    company.company_name,
    profitcenter.profit_ctr_name, -- AS profit_center_name,
    workorderheader.customer_id,
    customer.cust_name AS customer_name, -- AS customer_name,
    customerbilling.territory_code AS customer_territory, -- AS territory,
    customerbilling.billing_project_id AS customer_billing_project_id, -- as billing_project_id,
    customerbilling.project_name AS customer_billing_project_name, -- as billing_project_name,
        workorderheader.workorder_id,
    workorderheader.start_date,
    workorderheader.end_date,
    CASE workorderheader.workorder_status
        WHEN 'N' THEN 'New'
        WHEN 'H' THEN 'On Hold'
        WHEN 'D' THEN 'Dispatched'
        WHEN 'C' THEN 'Complete'
        WHEN 'P' THEN 'Priced'
        WHEN 'A' THEN 'Accepted'
        WHEN 'X' THEN 'Submitted'
        ELSE ''
    END AS workorder_status,
    CASE workorderheader.workorder_type
        WHEN 'D' THEN 'Disposal'
        WHEN 'E' THEN 'Emergency Response'
        WHEN 'O' THEN 'Other Services and Rentals'
        WHEN 'P' THEN 'Projects/Resource Management'
        WHEN 'R' THEN 'Rail'
        WHEN 'S' THEN 'Special Service'
        WHEN 'T' THEN 'Transportation'
        ELSE ''
    END AS workorder_type,
    workorderheader.project_code,
    workorderheader.project_name,
    workorderheader.project_location,
    workorderheader.quote_id,
    workorderheader.generator_id,
    generator.epa_id, -- AS generator_epa_id,
    generator.generator_name,
    workorderheader.station_id,
    workorderheader.fixed_price_flag,
    workorderheader.total_price,
    workorderheader.total_cost,
    gross_margin = isnull( workorderheader.total_price, 0 ) - isnull( workorderheader.total_cost, 0 ),
    CONVERT( FLOAT, CASE isnull(workorderheader.total_price, 0) WHEN 0 THEN 0 ELSE ((workorderheader.total_price - isnull(workorderheader.total_cost, 0)) / workorderheader.total_price ) * 100 END ) AS margin_percentage,
    CONVERT( money, workorderheader.cust_discount ) AS customer_discount,
    workorderheader.purchase_order,
    workorderheader.release_code,
    workorderproblem.problem_desc AS problem,
    CASE isnull(quoteheader.job_type, '')
        WHEN 'B' THEN 'Base'
        WHEN 'E' THEN 'Event'
        ELSE ''
    END AS job_type,
    nullif( b.gl_account_code, '' ) AS gl_account,
    nullif( b.gl_sr_account_code, '' ) AS mi_surcharge_gl_account,
    insurance_amount = ( SELECT
                             SUM( insr_extended_amt )
                         FROM   billing
                         WHERE  workorderheader.workorder_id = billing.receipt_id
                            AND workorderheader.profit_ctr_id = billing.profit_ctr_id
                            AND workorderheader.company_id = billing.company_id
                            AND billing.trans_source = 'W'
                            AND insr_extended_amt IS NOT NULL ),
    nullif( b.gl_insr_account_code, '' ) AS insurance_gl_account,
    nullif( b.invoice_code, '' ) AS invoice_code,
    invoice_date = ( SELECT
                         MIN( invoice_date )
                     FROM   billing
                     WHERE  workorderheader.workorder_id = billing.receipt_id
                        AND workorderheader.profit_ctr_id = billing.profit_ctr_id
                        AND workorderheader.company_id = billing.company_id
                        AND billing.trans_source = 'W'
                        AND invoice_date IS NOT NULL
                        AND invoice_date <> '' ),
    generator.generator_state,
    generator.site_code AS generator_site_code,
    nullif( b.invoice_id, '' ) AS invoice_id,
    revision_id = CASE
                      WHEN nullif( b.invoice_id, '' ) IS NULL THEN NULL
                      ELSE ( SELECT
                                 MAX( i.revision_id )
                             FROM   invoiceheader i
                             WHERE  i.invoice_id = b.invoice_id
                                AND b.invoice_id IS NOT NULL )
                  END,
    nullif( workorderheader.billing_project_id, '' ) AS billing_project_id,
    nullif( workorderheader.po_sequence_id, '' ) AS po_sequence_id,
    submitted_flag = CASE
                         WHEN workorderheader.submitted_flag = 'T' THEN 'Submitted'
                         ELSE 'Not Submitted'
                     END
,
			d.sequence_id,
			d.bill_unit_code,
			bu.bill_unit_desc,
			d.quantity_used,
			d.pounds,
			d.resource_class_code,
			d.DESCRIPTION, -- as service_desc_1,
			d.description_2 -- as service_desc_2
FROM   workorderheader
       INNER JOIN company
           ON company.company_id = workorderheader.company_id
       INNER JOIN profitcenter
           ON profitcenter.company_id = workorderheader.company_id
              AND profitcenter.profit_ctr_id = workorderheader.profit_ctr_id
       INNER JOIN workorderdetail d
			ON workorderheader.workorder_id = d.workorder_id
				AND workorderheader.profit_ctr_id = d.profit_ctr_id
				AND workorderheader.company_id = d.company_id
       LEFT OUTER JOIN workorderproblem
           ON workorderheader.problem_id = workorderproblem.problem_id
       LEFT OUTER JOIN customer
           ON workorderheader.customer_id = customer.customer_id
       LEFT OUTER JOIN generator
           ON workorderheader.generator_id = generator.generator_id
       LEFT OUTER JOIN workorderquoteheader quoteheader
           ON workorderheader.quote_id = quoteheader.quote_id
              AND workorderheader.company_id = quoteheader.company_id
              AND workorderheader.profit_ctr_id = quoteheader.profit_ctr_id
              AND quoteheader.curr_status_code = 'A'
       LEFT OUTER JOIN billing b
           ON workorderheader.workorder_id = b.receipt_id
              AND workorderheader.profit_ctr_id = b.profit_ctr_id
              AND workorderheader.company_id = b.company_id
              AND b.trans_source = 'W'
       LEFT OUTER JOIN customerbilling
           ON workorderheader.customer_id = customerbilling.customer_id
              AND isnull( workorderheader.billing_project_id, 0 ) = customerbilling.billing_project_id
		LEFT OUTER JOIN billunit bu ON d.bill_unit_code = bu.bill_unit_code
WHERE  
    1 = CASE 
			WHEN @return_schema_only = 'T' THEN 0
			ELSE 1
		END
	AND workorderheader.workorder_status IN ( 'A', 'C', 'D', 'N', 'P', 'X' )
	AND 1 = CASE
		WHEN @contact_id > 0 THEN
			CASE WHEN EXISTS (
				SELECT customer_id FROM contactxref WHERE contact_id = @contact_id AND workorderheader.customer_id = contactxref.customer_id
				UNION
				SELECT generator_id FROM contactxref WHERE contact_id = @contact_id AND workorderheader.generator_id = contactxref.generator_id
				UNION
				SELECT customergenerator.generator_id FROM customergenerator INNER JOIN contactxref ON customergenerator.customer_id = contactxref.customer_id WHERE contact_id = @contact_id AND workorderheader.generator_id = customergenerator.generator_id
			) THEN 1 ELSE 0	END
		ELSE 1
	END
	AND generator.site_code = '1') as tbl
	
	
IF @filter_expression IS NULL OR LEN(@filter_expression) = 0
	set @filter_expression = '1=1'


IF @start < 1 SET @start = 1
  IF @maxct < 1 SET @maxct = 1
  SET @ubound = @start + @maxct

IF @return_count_only = 'F'
BEGIN                         
  SET @STMT = ' SELECT *
                FROM (
                      SELECT  ROW_NUMBER() OVER(ORDER BY ' + @sort + ') AS ROWID, *
                      FROM    #tbl WHERE ' + @filter_expression + ' 
                     ) AS tbl
                WHERE  ROWID >= ' + CONVERT(varchar(9), @start) + ' AND
                       ROWID <  ' + CONVERT(varchar(9), @ubound) 
  --PRINT @stmt
  EXEC (@STMT)              -- return slice
END
ELSE
BEGIN
SET @STMT = ' SELECT COUNT(*) record_count
                FROM (
                      SELECT  ROW_NUMBER() OVER(ORDER BY ' + @sort + ') AS row
                      FROM    #tbl WHERE ' + @filter_expression + ' 
                     ) AS tbl'
                     
	EXEC (@STMT)        
END

*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_workorder] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_workorder] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_workorder] TO [EQAI]
    AS [dbo];

