CREATE PROCEDURE sp_equip_ytd_sum
	@company_id		int
,	@year			int
AS
/****************
This SP summarizes the number of hours billed for equipment by month comparing the specified year
to the previous year's usage.

05/29/99 SCC Created
09/18/99 LJT Added join to Resourceclass table by unit to allow the multiple resources per unit
04/16/07 SCC Changed to use submitted flag
04/07/2010 RJG Added criteria to joins:
				1) rxrc.resource_class_profit_ctr_id = RC.profit_ctr_id
				2) wod.profit_ctr_id = RC.profit_ctr_id
04/09/2010 RJG	Added reference to fn_get_assigned_resource_class_code and removed references to
				ResourceXResourceClass and ResourceClass
11/15/2010 SK	Added company_id as input arg, added joins to company ID
				moved to Plt_AI
07/31/2012 JDB	Changed SP to retrieve work orders that are either Completed
				or Accepted, and not to require them to be Submitted.
6/11/2024 Prakash Passed profit_ctr_id argument to fn_get_assigned_resource_class_code and included the resource uid in Resource Join for DevOps #86992
	
sp_equip_ytd_sum 21, 2008
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@lifetime_hours INT
,	@lifetime_days	INT

CREATE TABLE #ytd_sum (
	month			int				null,
	year			int				null,
	quantity_used	int				null,
	resource_item	varchar(10)		null,
	resource_class	varchar(10)		null,
	description		varchar(100)	null,
	company_id		int				null
)

CREATE TABLE #ytd_crosstab (
	resource_item	varchar(10)		null,
	resource_class	varchar(10)		null,
	description		varchar(100)	null,
	company_id		int				null,
	current_year_1	int				NULL,
	current_year_2	int				NULL,
	current_year_3	int				NULL,
	current_year_4	int				NULL,
	current_year_5	int				NULL,
	current_year_6	int				NULL,
	current_year_7	int				NULL,
	current_year_8	int				NULL,
	current_year_9	int				NULL,
	current_year_10 int				NULL,
	current_year_11 int				NULL,
	current_year_12 int				NULL,
	prior_year_1	int				NULL,
	prior_year_2	int				NULL,
	prior_year_3	int				NULL,
	prior_year_4	int				NULL,
	prior_year_5	int				NULL,
	prior_year_6	int				NULL,
	prior_year_7	int				NULL,
	prior_year_8	int				NULL,
	prior_year_9	int				NULL,
	prior_year_10	int				NULL,
	prior_year_11	int				NULL,
	prior_year_12	int				NULL,
	lifetime		int				NULL	
)

--Select current year usage by hour
INSERT INTO #ytd_sum
SELECT
	month_number = datepart(month,woh.end_date)
,	year_number = datepart(year,woh.end_date)
,	quantity_used = sum(wod.quantity_used)
,	wod.resource_assigned
,	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code
,	r.description
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
	AND wod.bill_unit_code = 'HOUR'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status IN ('C', 'A')
	--AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year
GROUP BY woh.company_id, r.description, wod.resource_assigned, datepart(month,woh.end_date), datepart(year,woh.end_date), wod.bill_unit_code, r.company_id, r.default_profit_ctr_id

--Select current year usage by day
INSERT INTO #ytd_sum
SELECT
	month_number = datepart(month,woh.end_date)
,	year_number = datepart(year,woh.end_date)
,	quantity_used = sum(wod.quantity_used * 8)
,	wod.resource_assigned
,	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code
,	r.description
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
	AND wod.bill_unit_code = 'DAY'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status IN ('C', 'A')
	--AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year
GROUP BY woh.company_id, r.description, wod.resource_assigned, datepart(month,woh.end_date), datepart(year,woh.end_date), wod.bill_unit_code, r.company_id, r.default_profit_ctr_id

--Select prior year usage by hour
INSERT INTO #ytd_sum
SELECT
	month_number = datepart(month,woh.end_date)
,	year_number = datepart(year,woh.end_date)
,	quantity_used = sum(wod.quantity_used)
,	wod.resource_assigned
,	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code
,	r.description
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
	AND wod.bill_unit_code = 'HOUR'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status IN ('C', 'A')
	--AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year - 1
GROUP BY woh.company_id, r.description, wod.resource_assigned, datepart(month,woh.end_date), datepart(year,woh.end_date), wod.bill_unit_code, r.company_id, r.default_profit_ctr_id

--Select prior year usage by day
INSERT INTO #ytd_sum
SELECT
	month_number = datepart(month,woh.end_date)
,	year_number = datepart(year,woh.end_date)
,	quantity_used = sum(wod.quantity_used * 8)
,	wod.resource_assigned
,	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code
,	r.description
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
	AND wod.bill_unit_code = 'DAY'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status IN ('C', 'A')
	--AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year - 1
GROUP BY woh.company_id, r.description, wod.resource_assigned, datepart(month,woh.end_date), datepart(year,woh.end_date), wod.bill_unit_code, r.company_id, r.default_profit_ctr_id

--Create the result records
INSERT INTO #ytd_crosstab
SELECT DISTINCT
	resource_item
,	resource_class
,	description
,	company_id
,	0,0,0,0,0,0,0,0,0,0,0,0
,	0,0,0,0,0,0,0,0,0,0,0,0
,	0
FROM #ytd_sum

--Update the result records for current year
UPDATE #ytd_crosstab
SET current_year_1 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 1), 0)

UPDATE #ytd_crosstab 
SET current_year_2 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 2), 0)

UPDATE #ytd_crosstab
SET current_year_3 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 3), 0)

UPDATE #ytd_crosstab
SET current_year_4 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 4), 0)

UPDATE #ytd_crosstab
SET current_year_5 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 5), 0)

UPDATE #ytd_crosstab
SET current_year_6 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 6), 0)

UPDATE #ytd_crosstab
SET current_year_7 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 7), 0)

UPDATE #ytd_crosstab
SET current_year_8 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 8), 0)

UPDATE #ytd_crosstab
SET current_year_9 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 9), 0)

UPDATE #ytd_crosstab
SET current_year_10 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 10), 0)

UPDATE #ytd_crosstab
SET current_year_11 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 11), 0)

UPDATE #ytd_crosstab
SET current_year_12 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year AND month = 12), 0)

--Update the result records for prior year
UPDATE #ytd_crosstab
SET prior_year_1 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 1), 0)

UPDATE #ytd_crosstab 
SET prior_year_2 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 2), 0)

UPDATE #ytd_crosstab
SET prior_year_3 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 3), 0)

UPDATE #ytd_crosstab
SET prior_year_4 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 4), 0)

UPDATE #ytd_crosstab
SET prior_year_5 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 5), 0)

UPDATE #ytd_crosstab
SET prior_year_6 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 6), 0)

UPDATE #ytd_crosstab
SET prior_year_7 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 7), 0)

UPDATE #ytd_crosstab
SET prior_year_8 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 8), 0)

UPDATE #ytd_crosstab
SET prior_year_9 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 9), 0)

UPDATE #ytd_crosstab
SET prior_year_10 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 10), 0)

UPDATE #ytd_crosstab
SET prior_year_11 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 11), 0)

UPDATE #ytd_crosstab
SET prior_year_12 = ISNULL((SELECT sum(s.quantity_used) FROM #ytd_sum s WHERE s.resource_item = #ytd_crosstab.resource_item 
								AND s.company_id = #ytd_crosstab.company_id AND year = @year - 1 AND month = 12), 0)

--get the lifetime values by hour
UPDATE #ytd_crosstab
SET lifetime = ISNULL((SELECT sum(wod.quantity_used) FROM WorkOrderHeader woh 
						JOIN WorkOrderDetail wod 
							ON wod.workorder_id = woh.workorder_id
							AND wod.profit_ctr_id =  woh.profit_ctr_id
							AND wod.company_id = woh.company_id
							AND wod.resource_type = 'E'
							AND wod.bill_unit_code = 'HOUR'
							AND wod.resource_assigned = #ytd_crosstab.resource_item
						WHERE woh.workorder_status IN ('C', 'A')
							--AND woh.submitted_flag = 'T'
							AND woh.company_id = #ytd_crosstab.company_id
						), 0)

--get the lifetime values by day
UPDATE #ytd_crosstab
SET lifetime = lifetime + ISNULL((SELECT sum(wod.quantity_used * 8) FROM WorkOrderHeader woh
									JOIN WorkOrderDetail wod 
										ON wod.workorder_id = woh.workorder_id
										AND wod.profit_ctr_id =  woh.profit_ctr_id
										AND wod.company_id = woh.company_id
										AND wod.resource_type = 'E'
										AND wod.bill_unit_code = 'DAY'
										AND wod.resource_assigned = #ytd_crosstab.resource_item
									WHERE woh.workorder_status IN ('C', 'A')
										--AND woh.submitted_flag = 'T'
										AND woh.company_id = #ytd_crosstab.company_id
								), 0)

--Select Results
SELECT
	#ytd_crosstab.*
,	@year AS year 
,	Company.company_name
FROM #ytd_crosstab
JOIN Company
	ON Company.company_id = #ytd_crosstab.company_id
ORDER BY #ytd_crosstab.company_id

DROP TABLE #ytd_sum
DROP TABLE #ytd_crosstab

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equip_ytd_sum] TO [EQAI]
    AS [dbo];

