--drop proc if exists sp_rpt_cumulative_sales
go

CREATE PROCEDURE sp_rpt_cumulative_sales
	@company_id		int
,	@profit_ctr_id  int
,	@year			int 
,	@report_type	int
,	@customer_type	varchar(20) = null
,	@customer_id_list	varchar(100) = null
AS
/**************************************************************************************************************
EQAI object(s): r_cumulative_sales_customer
				r_cumulative_sales_bu
				r_cumulative_sales_bu_customer
				r_cumulative_sales_bu_treatment
				r_cumulative_sales_treatment
				r_cumulative_sales_billing_type_desc
				r_cumulative_sales_bu_customer_Generator 
				r_cumulative_sales_dept
				r_cumulative_sales_dept_customer
				r_cumulative_sales_dept_treatment

@report_type = 1:	Group/sort by Company/Profit Center, then Customer
			 = 2:	Group/sort by Company/Profit Center, then Business Unit 
			 = 3:	Group/sort by Company/Profit Center, then Business Unit, then Customer
			 = 4:	Group/sort by Company/Profit Center, then Treatment
			 = 5:	Group/sort by Company/Profit Center, then Business Unit, then Treatment
			 = 6:   Group/sort by Company/Profit Center, then Billing Type Description
	         = 7:	Group/sort by Company/Profit Center, then Customer and Generator	 
	         
01/24/2012 JDB	Copied from sp_cum_sales.  Modified to use new work_CumulativeSales table.
				Modified to retrieve from BillingDetail table, and use the dist_company_id
				and dist_profit_ctr_id fields.
03/12/2014 SM	Added new report with option 6 for grouping by Billing Type.
				Updated Billing and BillingDetail table JOIN to billing_uid field.
				Changed (Epicor) GL department to JDE Business Unit for the reports 2, 3 & 5
				Added profit center to the retreival arguments
03/20/2014 JPB	Rewrote report_type 6 for better speed - 
					removed the fn_get_billing_type_description calls - they were slow
					Added left joins to the necessary tables, and case statements to recreate the fn output.
03/22/2016 AM   Added new report with option 7 for grouping by customer and generator_id.
11/08/2016 MPM	Added optional customer_type and customer_ID_list retrieval arguments.
08/03/2020 AM  DevOps:14451 - Modified #cum_sales.customer_name from 40 to 75

sp_rpt_cumulative_sales 2, 2011, 3
sp_rpt_cumulative_sales 21, 0, 2015, 7
sp_rpt_cumulative_sales 21, 0, 2015, 1
sp_rpt_cumulative_sales 21, 0, 2016, 4
sp_rpt_cumulative_sales 21, 0, 2016, 4, '3M'
sp_rpt_cumulative_sales 21, 0, 2016, 1, null, '17607,3562'
sp_rpt_cumulative_sales 21, 0, 2016, 5, '3M', '17607,3562'
***************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #cum_sales (
	month				int			NULL,
	revenue				money		NULL,
	company_id			int			NULL,		-- This is the dist_company_id from BillingDetail
	profit_ctr_id		int			NULL,		-- This is the dist_profit_ctr_id from BillingDetail
	business_unit				varchar(7)	NULL,
	business_unit_description	varchar(40)	NULL,
	customer_id			int			NULL,
	customer_name		varchar(75)	NULL,
	treatment_id		int			NULL,
	treatment_desc		varchar(40) NULL,
	wastetype_desc		varchar(60) NULL,
	treatment_process	varchar(30) NULL,
	disposal_service_desc varchar(20) NULL,
	billing_type_description VARCHAR(150) NULL,
	generator_id         int			NULL
	)

/*	
CREATE TABLE #BusinessUnit
( business_unit VARCHAR(7) NULL, business_unit_description VARCHAR(40) NULL )

	-- Store all JDE Business Units into the #BusinessUnit table:
	IF @report_type = 2 OR @report_type = 3 OR @report_type = 5
	BEGIN
	INSERT INTO #BusinessUNIT
		SELECT LTRIM(RTRIM(jdea.business_unit)) 
		, jdea.description_01 
		FROM JDE.EQFinance.dbo.JDEBusinessUnit_F0006 jdea
	END
*/
SET NOCOUNT ON

if @customer_type is null
	set @customer_type = 'ALL'
	
if @customer_id_list is null
	set @customer_id_list = 'ALL'
	
-- Customer IDs:
create table #customer_ids (customer_id int)
if datalength((@customer_id_list)) > 0 and @customer_id_list <> 'ALL'
begin
    Insert #customer_ids
    select convert(int, row)
    from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
    where isnull(row, '') <> ''
end

------------------------------------------------------------------------------------
-- @report_type = 1 indicates the report should be grouped by customer only.
------------------------------------------------------------------------------------
IF @report_type = 1
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		NULL,
		NULL,
		ISNULL(b.customer_id, -1),
		ISNULL(c.cust_name, '<unknown>'),
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		b.customer_id,
		c.cust_name
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, b.customer_id
END

------------------------------------------------------------------------------------
-- @report_type = 2 indicates the report should be grouped by Business Unit only.
------------------------------------------------------------------------------------
IF @report_type = 2
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU,
		-- ISNULL(#BusinessUnit.business_unit_description, '(Missing)') 
		NULL AS business_unit_description,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	-- LEFT OUTER JOIN #BusinessUnit ON #BusinessUnit.business_unit = bd.JDE_BU
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU
--		#BusinessUnit.business_unit_description
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, bd.JDE_BU
END

----------------------------------------------------------------------------------------------------
-- @report_type = 3 indicates the report should be grouped by Business Unit and customer.
----------------------------------------------------------------------------------------------------
IF @report_type = 3
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU,
--		ISNULL(#BusinessUnit.business_unit_description, '(Missing)') 
		NULL AS business_unit_description,
		ISNULL(b.customer_id, -1),
		ISNULL(c.cust_name, '<unknown>'),
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	-- LEFT OUTER JOIN #BusinessUnit ON #BusinessUnit.business_unit = bd.JDE_BU
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU,
--		#BusinessUnit.business_unit_description,
		b.customer_id,
		c.cust_name
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, bd.JDE_BU, b.customer_id
END

------------------------------------------------------------------------------------
-- @report_type = 4 indicates the report should be grouped by treatment only.
------------------------------------------------------------------------------------
IF @report_type = 4
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		NULL,
		NULL,
		NULL,
		NULL,
		r.treatment_id,
		tr.treatment_desc,
		tr.wastetype_description,
		tr.treatment_process_process,
		tr.disposal_service_desc,
		NULL,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
		AND bd.billing_type = 'Disposal'
	JOIN Receipt r ON r.company_id = b.company_id
		AND r.profit_ctr_id = b.profit_ctr_id
		AND r.receipt_id = b.receipt_id
		AND r.line_id = b.line_id
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
	JOIN Treatment tr ON tr.treatment_id = r.treatment_id
		AND tr.company_id = r.company_id
		AND tr.profit_ctr_id = r.profit_ctr_id
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		r.treatment_id,
		tr.treatment_desc,
		tr.wastetype_description,
		tr.treatment_process_process,
		tr.disposal_service_desc
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, tr.wastetype_description, tr.treatment_process_process, tr.disposal_service_desc, r.treatment_id
END

----------------------------------------------------------------------------------------------------
-- @report_type = 5 indicates the report should be grouped by Business Unit and treatment.
----------------------------------------------------------------------------------------------------
IF @report_type = 5
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU,
		--ISNULL(#BusinessUnit.business_unit_description, '(Missing)') 
		NULL AS business_unit_description,
		NULL,
		NULL,
		r.treatment_id,
		tr.treatment_desc,
		tr.wastetype_description,
		tr.treatment_process_process,
		tr.disposal_service_desc,
		NULL,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
		AND bd.billing_type = 'Disposal'
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	-- LEFT OUTER JOIN #BusinessUnit ON #BusinessUnit.business_unit = bd.JDE_BU
	JOIN Receipt r ON r.company_id = b.company_id
		AND r.profit_ctr_id = b.profit_ctr_id
		AND r.receipt_id = b.receipt_id
		AND r.line_id = b.line_id
		AND r.trans_mode = 'I'
		AND r.trans_type = 'D'
	JOIN Treatment tr ON tr.treatment_id = r.treatment_id
		AND tr.company_id = r.company_id
		AND tr.profit_ctr_id = r.profit_ctr_id
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.JDE_BU,
--		#BusinessUnit.business_unit_description,
		r.treatment_id,
		tr.treatment_desc,
		tr.wastetype_description,
		tr.treatment_process_process,
		tr.disposal_service_desc
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, tr.wastetype_description, tr.treatment_process_process, tr.disposal_service_desc, r.treatment_id
END

----------------------------------------------------------------------------------------------------
-- @report_type = 6 indicates the report should be grouped by Billing Type Description.
----------------------------------------------------------------------------------------------------

IF @report_type = 6
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		CASE bd.billing_type 
			WHEN 'Disposal' THEN
				bt.billing_type_desc + ':  ' + wt.category
			WHEN 'Workorder' THEN
				bt.billing_type_desc + ':  ' + ht.account_desc
			WHEN 'Product' THEN 
				bt.billing_type_desc + ':  ' + p.product_code
			ELSE
				coalesce(bt.billing_type_desc, '(Blank)')
		END,
		NULL
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	LEFT JOIN BillingType bt ON bt.billingtype_uid = bd.billingtype_uid
	LEFT JOIN Product p ON p.product_id = bd.product_id and bd.billing_type = 'Product'
	LEFT JOIN WorkOrderHeader h ON bd.receipt_id = h.workorder_id and bd.company_id = h.company_id and bd.profit_ctr_id = h.profit_ctr_id and bd.billing_type = 'Workorder' and bd.trans_source = 'W'
	LEFT JOIN WorkOrderTypeHeader ht ON h.workorder_type_id = ht.workorder_type_id and bd.billing_type = 'Workorder' and bd.trans_source = 'W'
	LEFT JOIN Receipt r ON bd.receipt_id = r.receipt_id AND bd.line_id = r.line_id AND bd.company_id = r.company_id AND r.profit_ctr_id = bd.profit_ctr_id and bd.billing_type = 'Disposal' and bd.trans_source = 'R'
	LEFT JOIN Treatment t ON r.treatment_id = t.treatment_id AND r.company_id = t.company_id AND r.profit_ctr_id = t.profit_ctr_id and bd.billing_type = 'Disposal' and bd.trans_source = 'R'
	LEFT JOIN WasteType wt ON t.wastetype_id = wt.wastetype_id and bd.billing_type = 'Disposal' and bd.trans_source = 'R'
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		b.customer_id,
		CASE bd.billing_type 
			WHEN 'Disposal' THEN
				bt.billing_type_desc + ':  ' + wt.category
			WHEN 'Workorder' THEN
				bt.billing_type_desc + ':  ' + ht.account_desc
			WHEN 'Product' THEN 
				bt.billing_type_desc + ':  ' + p.product_code
			ELSE
				coalesce(bt.billing_type_desc, '(Blank)')
		END
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, b.customer_id
END

------------------------------------------------------------------------------------
-- @report_type = 7 indicates the report should be grouped by customer and generator.
------------------------------------------------------------------------------------
IF @report_type = 7
BEGIN
	INSERT INTO #cum_sales
	SELECT 	
		MONTH(b.invoice_date),
		SUM(ISNULL(CONVERT(money, bd.extended_amt), 0.00)),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		NULL,
		NULL,
		ISNULL(b.customer_id, -1),
		ISNULL(c.cust_name, '<unknown>'),
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		b.generator_id
	FROM Billing b
	JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid
	JOIN Customer c	ON b.customer_id = c.customer_id
	                AND (c.customer_ID in (select customer_id from #customer_ids) OR @customer_id_list = 'ALL')
	                AND (c.customer_type = @customer_type OR @customer_type = 'ALL')
	LEFT OUTER JOIN Generator G ON g.generator_id = b.generator_id
	WHERE YEAR(b.invoice_date) = @year
	AND ( @company_id = 0 OR bd.dist_company_id = @company_id )
	AND ( @profit_Ctr_id = -1 OR bd.dist_profit_Ctr_id = @profit_Ctr_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	GROUP BY MONTH(b.invoice_date),
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		b.customer_id,
		c.cust_name,
		b.generator_id
	ORDER BY bd.dist_company_id, bd.dist_profit_ctr_id, b.customer_id, b.generator_id
END


DELETE FROM work_CumulativeSales
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description, January, generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue, generator_id FROM #cum_sales WHERE month = 
1
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,February, generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue, generator_id FROM #cum_sales WHERE month = 
2
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,March, generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue, generator_id FROM #cum_sales WHERE month = 
3
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description, April, generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
4
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,May,generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
5
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,June,generator_id		)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
6
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,July,generator_id		)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
7
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,August,generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
8
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,September,generator_id)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
9
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,October,generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
10

INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,November,generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
11
	
INSERT INTO work_CumulativeSales (company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,December,generator_id	)
SELECT company_id, profit_ctr_id, business_unit, business_unit_description, customer_id, customer_name, treatment_id, treatment_desc, wastetype_desc, treatment_process, disposal_service_desc, billing_type_description,revenue,generator_id FROM #cum_sales WHERE month = 
12
	

SET NOCOUNT OFF
SELECT	
	work.company_id,
	work.profit_ctr_id,
	c.company_name,
	pc.profit_ctr_name,
	work.business_unit,
	work.business_unit_description,
	work.customer_id,
	work.customer_name,
	work.treatment_id,
	work.treatment_desc,
	work.wastetype_desc,
	work.treatment_process,
	work.disposal_service_desc,
	work.billing_type_description,
	year = @year,
	January		= SUM(ISNULL(January, 0.00)),
	February	= SUM(ISNULL(February, 0.00)),
	March		= SUM(ISNULL(March, 0.00)),
	April		= SUM(ISNULL(April, 0.00)),
	May			= SUM(ISNULL(May, 0.00)),
	June		= SUM(ISNULL(June, 0.00)),
	July		= SUM(ISNULL(July, 0.00)),
	August		= SUM(ISNULL(August, 0.00)),
	September	= SUM(ISNULL(September, 0.00)),
	October		= SUM(ISNULL(October, 0.00)),
	November	= SUM(ISNULL(November, 0.00)),
	December	= SUM(ISNULL(December, 0.00)),
	work.generator_id,
	g.generator_name,
	g.epa_id
FROM work_CumulativeSales work
JOIN Company c ON c.company_id = work.company_id
JOIN ProfitCenter pc ON pc.company_ID = work.company_id
	AND pc.profit_ctr_ID = work.profit_ctr_id
LEFT OUTER JOIN Generator g ON g.generator_id = work.generator_id
GROUP BY 
	work.company_id,
	work.profit_ctr_id,
	c.company_name,
	pc.profit_ctr_name,
	work.business_unit,
	work.business_unit_description,
	work.customer_id,
	work.customer_name,
	work.treatment_id,
	work.treatment_desc,
	work.wastetype_desc,
	work.treatment_process,
	work.disposal_service_desc,
	work.billing_type_description,
	work.generator_id,
	g.generator_name,
	g.epa_id
ORDER BY work.company_id, work.profit_ctr_id, work.business_unit, work.customer_name, work.treatment_desc, work.billing_type_description

DROP TABLE #cum_sales
DROP TABLE #customer_ids
--IF @report_type = 2 OR @report_type = 3 OR @report_type = 5
	--DROP TABLE  #BusinessUnit

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_cumulative_sales] TO [EQAI]
    AS [dbo];

