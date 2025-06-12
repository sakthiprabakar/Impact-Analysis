CREATE PROCEDURE sp_equip_cust_sum
	@company_id		int
,	@year			int
,	@cust_id_from	int
,	@cust_id_to		int
AS
/****************
This SP summarizes the number of hours billed for equipment by month comparing the specified year
to the previous year's usage.

06/18/99 SCC Created
09/18/99 LJT Added join to Resourceclass table by unit to allow the multiple resources per unit
04/15/07 SCC Changed to use workorderheader.submitted_flag
04/06/2010 RJG	Added profit_ctr_id join to ResourceClass references because this table now points to a view that points to a table on PLT_AI
04/09/2010 RJG	Added fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, wod.company_id) call
				Removed references to ResourceClass, ResourceXResourceClass and Resource table
11/15/2010 SK	Added company_id as input arg, added joins to company ID
				moved to Plt_AI
6/11/2024 Prakash Passed profit_ctr_id argument to fn_get_assigned_resource_class_code for DevOps #86992
				
sp_equip_cust_sum 0, 2008, 5369, 6026
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


CREATE TABLE #ytd_sum (
	customer_id		int			null,
	month			int			null,
	year			int			null,
	bill_unit_code	varchar(4)	null,
	quantity_used	int			null,
	resource_item	varchar(10) null,
	resource_class	varchar(10) null,
	company_id		int			null
)

CREATE TABLE #ytd_crosstab (
	customer_id		int			null,
	customer_name	varchar(40) null,
	resource_item	varchar(10) null,
	resource_class	varchar(10) null,
	bill_unit_code	varchar(4)	null,
	company_id		int			null,
	January			float		NULL ,
	February		float		NULL ,
	March			float		NULL ,
	April			float		NULL ,
	May				float		NULL ,
	June			float		NULL ,
	July			float		NULL ,
	August			float		NULL ,
	September		float		NULL ,
	October			float		NULL ,
	November		float		NULL ,
	December		float		NULL
)

-- Select current year usage
INSERT INTO #ytd_sum
SELECT
	customer_id
,	month_number = datepart(month,woh.end_date)
,	year_number = datepart(year,woh.end_date)
,	wod.bill_unit_code
,	quantity_used = sum(wod.quantity_used)
,	wod.resource_assigned
,	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, woh.company_id, wod.profit_ctr_ID) as resource_class_code
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status = 'A'
	AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
GROUP BY woh.company_id, customer_id, wod.resource_assigned, wod.bill_unit_code, datepart(month,woh.end_date), datepart(year,woh.end_date), wod.profit_ctr_ID

--Create the result records
INSERT INTO #ytd_crosstab
SELECT DISTINCT
	#ytd_sum.customer_id
,	cust_name
,	resource_item
,	resource_class
,	bill_unit_code
,	#ytd_sum.company_id
,	0,0,0,0,0,0,0,0,0,0,0,0
FROM #ytd_sum, Customer
WHERE #ytd_sum.customer_id = Customer.customer_id

--Update the result records
UPDATE #ytd_crosstab
SET January = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 1 
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)

UPDATE #ytd_crosstab
SET February = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 2
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)

UPDATE #ytd_crosstab
SET March = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 3
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET April = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 4
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET May = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 5
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET June = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 6
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET July = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 7
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET August = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 8
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)

UPDATE #ytd_crosstab
SET September = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 9
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET October = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 10
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET November = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 11
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)
						
UPDATE #ytd_crosstab
SET December = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.customer_id = #ytd_crosstab.customer_id
						AND s.resource_item = #ytd_crosstab.resource_item AND year = @year AND month = 12
						AND #ytd_crosstab.company_id = s.company_id
						AND #ytd_crosstab.bill_unit_code = s.bill_unit_code), 0)

-- Select Results
SELECT 
	#ytd_crosstab.*
,	@year AS year
,	Company.company_name
FROM #ytd_crosstab
JOIN Company
	ON Company.company_id = #ytd_crosstab.company_id
ORDER BY #ytd_crosstab.company_id, #ytd_crosstab.customer_id

DROP TABLE #ytd_sum
DROP TABLE #ytd_crosstab

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equip_cust_sum] TO [EQAI]
    AS [dbo];

