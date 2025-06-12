CREATE PROCEDURE sp_equip_type_sum
	@company_id	int
,	@year		int
AS
/****************
This SP summarizes the number of hours billed for equipment by location comparing the actual
to the budget forecast.

05/29/99 SCC Created
09/18/99 LJT Added join to Resourceclass table by unit to allow the multiple resources per unit
04/16/07 SCC Changed to use submitted flag
04/06/2010 RJG	Added profit_ctr_id join to ResourceClass references because this table now points to a view that points to a table on PLT_AI
04/07/2010 RJG	Changed joins on Resource table & added ProfitCenter join, Resource.location was dropped and replaced by default profit ctr
04/09/2010 RJG	Added fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, wod.company_id) call
				Removed references to ResourceClass, ResourceXResourceClass and Resource table
11/12/2010 SK	Added company_id as input arg, added joins to company ID
				moved to Plt_AI
6/11/2024 Prakash Passed profit_ctr_id argument to fn_get_assigned_resource_class_code for DevOps #86992

sp_equip_type_sum 0, 2008
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


CREATE TABLE #type_sum (
	resource_class		varchar(10) null,
	equipment			varchar(10) null,
	location			varchar(50) null,
	bill_unit_code		varchar(4)	null,
	quantity_used		float		null,
	quantity_forecast	float		null,
	quantity_last_year	float		null,
	company_id			int			null
)

INSERT INTO #type_sum
SELECT DISTINCT
	dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, woh.company_id, wod.profit_ctr_ID)
,	wod.resource_assigned
,	pc.profit_ctr_name
,	wod.bill_unit_code
,	sum(wod.quantity_used)
,	0
,	0
,	woh.company_id
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
	AND wod.resource_type = 'E'
JOIN ProfitCenter pc
	ON pc.company_ID = woh.company_id
	AND pc.profit_ctr_ID = woh.profit_ctr_ID
WHERE (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status = 'A'
	AND woh.submitted_flag = 'T'
	AND datepart(year,woh.end_date) = @year
GROUP BY woh.company_id, wod.resource_assigned, pc.profit_ctr_name, wod.bill_unit_code, wod.profit_ctr_ID

--update the temp table with forecast values
UPDATE #type_sum 
SET quantity_forecast = ( SELECT sum(budget_amount) 
							FROM ResourceBudget rb
							WHERE rb.resource_item_code = #type_sum.resource_class
								AND rb.resource_item_type = 'C'
								AND rb.year = @year
						)

-- update the temp table with last year's values
UPDATE #type_sum 
SET quantity_last_year = ( SELECT sum(wod.quantity_used) 
							FROM WorkOrderHeader woh
							JOIN WorkOrderDetail wod
								ON wod.company_id = woh.company_id
								AND wod.profit_ctr_id = woh.profit_ctr_id
								AND	wod.workorder_ID = woh.workorder_ID
								AND wod.resource_type = 'E'
							JOIN #type_sum t
								ON t.equipment = wod.resource_assigned
							WHERE woh.workorder_status = 'A'
								AND woh.submitted_flag = 'T'
								AND datepart(year,woh.end_date) = @year - 1
								AND (@company_id = 0 OR woh.company_id = @company_id)
							)

-- Select Results
SELECT DISTINCT
	resource_class
,	equipment
,	location
,	bill_unit_code
,	quantity_used
,	quantity_forecast
,	ISNULL(quantity_last_year,0) as quantity_last_year
,	#type_sum.company_id
,	Company.company_name
FROM #type_sum
JOIN Company
	ON Company.company_id = #type_sum.company_id

DROP TABLE #type_sum

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equip_type_sum] TO [EQAI]
    AS [dbo];

