--DROP PROCEDURE sp_labor_util_sum
--GO
CREATE PROCEDURE sp_labor_util_sum 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code char(2)
,	@debug_flag		int = 0
,	@reference_code varchar(32) null
AS
/****************************************************************************************************

PB Object(s):	r_labor_util

06/18/1999 SCC	Created
09/18/1999 LJT	Added join to Resourceclass table by unit to allow the multiple resources per unit
11/20/2000 SCC	Added territory code argument
04/17/2007 SCC	Changed to use WorkorderHeader.submitted_flag and CustomerBilling.territory_code
04/07/2010 RJG	Changed join criteria, added:
				1) RC.profit_ctr_id = rxrc.resource_class_profit_ctr_id
04/09/2010 RJG	Removed references to ResourceClass and ResourceXResourceClass
11/08/2010 SK	Added company-profitctr as input args
				Moved to Plt_AI
07/31/2012 JDB	Changed SP to retrieve work orders that are either Completed
				or Accepted, and not to require them to be Submitted.
10/30/2022 GDE Reports - Reference Code Usage	
04/05/2023 AM - DevOps:62859 - Added employee_ID
6/11/2024 Prakash - DevOps #86992 - Passed profit_ctr_id argument to fn_get_assigned_resource_class_code and included the resource uid in Resource Join.

sp_labor_util_sum 14, -1, '01/01/2010', '01/31/2010 23:59:59', 1, 99999, '99', 0
****************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #labor (
	labor_class				varchar(10)		null,
	labor					varchar(10)		null,
	labor_name				varchar(100)	null,
	quantity_used_billed	float			null,
	quantity_used_nc		float			null,
	quantity_hours			float			null,
	company_id				int				null,
	profit_ctr_id			int				null,
	reference_code			varchar(32)		null,
	employee_ID				varchar(20)		null
)

/* Store labor use amounts */
INSERT INTO #labor
SELECT 
	dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code,
	resource_assigned,
	r.description,
	sum(quantity_used),
	0 as quantity_used_nc,
	0 as quantity_hours,
	woh.company_id,
	woh.profit_ctr_ID,
	isNull(woh.reference_code,'') AS reference_code,
    U.employee_ID
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND	woh.company_id = wod.company_id
	AND wod.resource_type = 'L'
	AND wod.bill_rate > 0
	AND wod.bill_unit_code  = 'HOUR'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
	--AND r.company_id = wod.company_id
LEFT OUTER JOIN Users u on r.User_id = u.User_id
JOIN CustomerBilling
	ON woh.customer_id = CustomerBilling.customer_id
	AND IsNull(woh.billing_project_id,0) = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
WHERE woh.workorder_status IN ('C', 'A')
	AND woh.customer_id BETWEEN @cust_id_from and @cust_id_to
	AND woh.end_date BETWEEN @date_from and @date_to
	AND (@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	--AND IsNull(woh.submitted_flag, 'F') = 'T'
	AND (isnull(@reference_code, '') = '' or woh.reference_code = @reference_code )
GROUP BY woh.company_id, woh.profit_ctr_id, wod.bill_unit_code, resource_assigned, r.description,woh.reference_code, U.employee_ID, r.company_id, r.default_profit_ctr_id

/* Add in no charge resources */
INSERT INTO #labor
SELECT 
	dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as resource_class_code,
	resource_assigned,
	r.description,
	0 as quantity_used_billed,
	sum(quantity_used),
	0 as quantity_hours,
	woh.company_id,
	woh.profit_ctr_ID,
	isNull(woh.reference_code, '') AS reference_code,
	U.employee_ID
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND	woh.company_id = wod.company_id
	AND wod.resource_type = 'L'
	AND wod.bill_rate <= 0
	AND wod.bill_unit_code  = 'HOUR'
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
	--AND r.company_id = wod.company_id
LEFT OUTER JOIN Users u on r.User_id = u.User_id
JOIN CustomerBilling
	ON woh.customer_id = CustomerBilling.customer_id
	AND IsNull(woh.billing_project_id,0) = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
WHERE	woh.end_date BETWEEN @date_from and @date_to
	AND (@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND woh.workorder_status IN ('C', 'A')
	--AND IsNull(woh.submitted_flag, 'F') = 'T'
	AND woh.customer_id BETWEEN @cust_id_from and @cust_id_to
	AND (isnull(@reference_code, '') = '' or woh.reference_code = @reference_code)
GROUP BY woh.company_id, woh.profit_ctr_id, wod.bill_unit_code, resource_assigned, r.description,woh.reference_code, U.employee_ID, r.company_id, r.default_profit_ctr_id

/* Add in resources total hours */
INSERT INTO #labor
SELECT
	dbo.fn_get_assigned_resource_class_code(resource_item_code, 'HOUR', r.company_id, r.default_profit_ctr_id) as resource_class_code,
	resource_item_code,
	r.description,
	0 as quantity_used_billed,
	0 as quantity_used,
	Sum(time_amount),
	r.company_id,
	NULL AS profit_ctr_id,
	'' AS reference_code,
	U.employee_ID
FROM Resource r
JOIN WorkOrderSchedule
	ON WorkOrderSchedule.resource_item_code = r.resource_code
	AND WorkOrderSchedule.start_date BETWEEN @date_from AND @date_to
	AND WorkOrderSchedule.assignment_type = 'Hours'
	AND WorkOrderSchedule.resource_item_type = 'R'
	AND	WorkOrderSchedule.company_id = r.company_id
LEFT OUTER JOIN Users u on r.User_id = u.User_id
WHERE (@company_id = 0 OR r.company_id = @company_id)
GROUP BY r.company_id, resource_item_code, r.description, U.employee_ID, r.default_profit_ctr_id

/* Return */
SELECT 
	labor_class,
	labor,
	labor_name,
	sum(quantity_used_billed) as quantity_billed,
	sum(quantity_used_nc) as quantity_nc,
	sum(quantity_hours) as quantity_hours,
	#labor.company_id,
	#labor.profit_ctr_id,
	Company.company_name,
	#labor.reference_code,
	#labor.employee_ID
FROM #labor
JOIN Company
	ON Company.company_id = #labor.company_id
GROUP BY labor_class, labor, labor_name, #labor.company_id, #labor.profit_ctr_id, company_name,#labor.reference_code,#labor.employee_id
GO
GRANT EXECUTE
   ON OBJECT::[dbo].[sp_labor_util_sum] TO [EQAI];
       --AS dbo;
GO
