CREATE PROCEDURE sp_rpt_monthly_invoicing_purchasing_ytd
	@year			int,
	@month			int,
	@customer_type	varchar(10),
	@customer_id	int,
	@user_code		varchar(100) = NULL, -- for associates
	@copc_list		varchar(max) = NULL, -- ex: 21|1,14|0,14|1
    @permission_id	int = NULL
AS
/****************
This SP summarizes the number of hours billed for equipment class by month for the specific year.

09/21/2012 DZ	Created
02/14/2013 JDB	Fixed a bug in the calculation of end date.  It wasn't working for the month of December.
02/14/2013 JDB	Also fixed another bug in the WHILE loop to update the monthly information.  It was
				starting at 1, but incrementing the month before the first iteration, so it never 
				calculated totals for January.
	
sp_rpt_monthly_invoicing_purchasing_ytd 2013, 1, 'USSTEEL', 0, 'JASON_B', '14|15', 1
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
******************/
set nocount on
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @SQLString	nvarchar(900),
		@I			int,
		@StartDate	datetime,
		@EndDate	datetime

declare @tbl_profit_center_filter table (
    [company_id] int, 
    profit_ctr_id int
)

-- Old Code:
--SET @StartDate = convert(datetime, '01/01/'+ Convert(varchar(4),@year), 101);
--SET @EndDate = convert(datetime, CONVERT(varchar(2), @month+1)+ '/01/'+ Convert(varchar(4),@year), 101);

-- New Code:
SET @StartDate = convert(datetime, '01/01/'+ Convert(varchar(4),@year), 101);
IF @month = 12 
BEGIN
	-- If the user runs the report for December, we need the end date to be January 1 of the next year.
	SET @month = 1
	SET @year = @year + 1
	SET @EndDate = convert(datetime, '01/01/'+ Convert(varchar(4),@year), 101);
END
ELSE
BEGIN
	SET @EndDate = convert(datetime, CONVERT(varchar(2), @month+1)+ '/01/'+ Convert(varchar(4),@year), 101);
END

IF @user_code = ''
    set @user_code = NULL
    
INSERT @tbl_profit_center_filter
    SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
        FROM SecuredProfitCenter secured_copc
        INNER JOIN (
            SELECT 
                RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
                RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
            from dbo.fn_SplitXsvText(',', 0, @copc_list) 
            where isnull(row, '') <> '') selected_copc ON 
                secured_copc.company_id = selected_copc.company_id 
                AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
                AND secured_copc.permission_id = @permission_id
                AND secured_copc.user_code = @user_code

SELECT sc.customer_id, c.cust_name
INTO #SecuredCustomer
FROM SecuredCustomer sc
JOIN customer c
ON sc.customer_ID = c.customer_ID
WHERE sc.user_code = @user_code
AND sc.permission_id = @permission_id
AND (@customer_type = '' OR c.customer_type = @customer_type)
AND (@customer_id IS NULL OR @customer_id = 0 OR c.customer_id = @customer_id)

CREATE INDEX cui_secured_customer_tmp ON #SecuredCustomer(customer_id)

CREATE TABLE #ytd_sum (
	customer_id		int				null,
	--cust_name		varchar(40)		null,
	company_id		int				null,
	profit_ctr_id	int				null,
	resource_type	varchar(4)		null,
	resource_class	varchar(10)		null,
	--description		varchar(100)	null,
	bill_unit_code	varchar(4)		null,
	bill_rate		float			null,
	price			money			null,
	month_number	int				null,
	quantity_used	int				null
)

CREATE TABLE #ytd_crosstab (
	customer_id		int				null,
	--cust_name		varchar(40)		null,
	company_id		int				null,
	profit_ctr_id	int				null,
	resource_type	varchar(4)		null,
	resource_class	varchar(10)		null,
	--description		varchar(100)	null,
	bill_unit_code	varchar(4)		null,
	bill_rate		float			null,
	price			money			null,
	month_1			int				NULL,
	month_2			int				NULL,
	month_3			int				NULL,
	month_4			int				NULL,
	month_5			int				NULL,
	month_6			int				NULL,
	month_7			int				NULL,
	month_8			int				NULL,
	month_9			int				NULL,
	month_10		int				NULL,
	month_11		int				NULL,
	month_12		int				NULL	
)

--Select current year usage by hour
INSERT INTO #ytd_sum
SELECT
	woh.customer_ID
,	woh.company_id
,	woh.profit_ctr_ID
,	wod.resource_type
,	wod.resource_class_code
--,	rc.description
,	wod.bill_unit_code
,	wod.bill_rate
,	wod.price
,	month_number = datepart(month,b.invoice_date)
,	quantity_used = SUM(wod.quantity_used)
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.workorder_id = woh.workorder_id
	AND wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
--JOIN Customer c
--	ON woh.customer_ID = c.customer_ID
--	AND (@customer_type = '' OR c.customer_type = @customer_type)
--	AND (@customer_id = 0 OR woh.customer_id = @customer_id)
JOIN Billing b
	ON b.receipt_id = woh.workorder_ID
	AND b.company_id = wod.company_id
	AND b.profit_ctr_id = wod.profit_ctr_ID
	AND b.workorder_resource_type = wod.resource_type
	AND b.workorder_sequence_id = wod.sequence_ID
	AND b.workorder_resource_item = wod.resource_class_code
	AND b.void_status = 'F'
	AND b.status_code = 'I'
INNER JOIN #SecuredCustomer secured_customer
    ON secured_customer.customer_id = woh.customer_id
JOIN @tbl_profit_center_filter secured_copc
    ON woh.company_id = secured_copc.company_id
    AND woh.profit_ctr_id = secured_copc.profit_ctr_id
WHERE woh.workorder_status IN ('C', 'A')
	AND wod.resource_type IN ('E', 'S', 'O', 'L')
	AND b.invoice_date >= @StartDate
	AND b.invoice_date < @EndDate
GROUP BY
	woh.customer_ID
,	woh.company_id
,	woh.profit_ctr_ID
,	wod.resource_type
,	wod.resource_class_code
--,	rc.description
,	wod.bill_unit_code
,	wod.bill_rate
,	wod.price
,	datepart(month,b.invoice_date)

--Create the result records
INSERT INTO #ytd_crosstab
SELECT DISTINCT
	customer_id,
	company_id,
	profit_ctr_id,
	resource_type,
	resource_class,
--	description,
	bill_unit_code,
	bill_rate,
	price,
	0,0,0,0,0,0,0,0,0,0,0,0
FROM #ytd_sum

--Update the result records for current year
SET @I= 0;
WHILE @I<12
BEGIN
	SET @I = @I + 1;
	SET @SQLString = N'
	UPDATE #ytd_crosstab
	SET month_' + cast(@I as varchar(2)) + N'= ISNULL((SELECT sum(s.quantity_used) 
							FROM #ytd_sum s 
						   WHERE s.customer_id = #ytd_crosstab.customer_id
							 AND s.company_id = #ytd_crosstab.company_id
							 AND s.profit_ctr_id = #ytd_crosstab.profit_ctr_id
							AND s.resource_type = #ytd_crosstab.resource_type
							AND s.resource_class = #ytd_crosstab.resource_class
							AND s.bill_unit_code = #ytd_crosstab.bill_unit_code
							AND s.price = #ytd_crosstab.price
							AND month_number = ' + CAST(@I AS varchar(2)) + '), 0)';
	EXECUTE sp_executesql @SQLString
END
set nocount off
--Select Results
SELECT t.*, pc.profit_ctr_name, sc.cust_name, bu.bill_unit_desc, rc.description
FROM #ytd_crosstab t
JOIN ProfitCenter pc
ON t.company_id = pc.company_ID
AND t.profit_ctr_id = pc.profit_ctr_ID
JOIN #SecuredCustomer sc
ON t.customer_id = sc.customer_id
JOIN BillUnit bu
ON t.bill_unit_code = bu.bill_unit_code
JOIN ResourceClass rc
ON t.resource_class = rc.resource_class_code
AND t.bill_unit_code = rc.bill_unit_code
AND t.company_id = rc.company_id
AND t.profit_ctr_ID = rc.profit_ctr_id
ORDER BY t.company_id, t.profit_ctr_id, sc.cust_name, t.customer_id

DROP TABLE #ytd_sum
DROP TABLE #ytd_crosstab

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_invoicing_purchasing_ytd] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_invoicing_purchasing_ytd] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_invoicing_purchasing_ytd] TO [EQAI]
    AS [dbo];

