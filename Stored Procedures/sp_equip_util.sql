CREATE PROCEDURE sp_equip_util 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@territory_code char(2)
,	@debug_flag		int = 0
AS
/**************************************************************************
PB Object(s):	r_equip_util_detail
				r_equip_util_summary

11/21/2000 SCC	Created
12/06/2000 SCC	Added bill unit
04/16/2007 SCC	Changed to use workorderheader.submitted_flag and CustomerBilling.territory_code
04/07/2010 RJG	Added fields to joins:
					1) wod.profit_ctr_id = RC.profit_ctr_id
					2) rxrc.resource_class_profit_ctr_id = RC.profit_ctr_id
04/08/2010	RJG	Changed procedure to use fn_get_assigned_resource_class_code
				Removed references to ResourceClass and ResourceXResourceClass		
11/08/2010 SK	Added company-profitctr as input args
				Moved to Plt_AI
07/31/2012 JDB	Changed SP to retrieve work orders that are either Completed
				or Accepted, and not to require them to be Submitted.
6/11/2024 Prakash Passed profit_ctr_id argument to fn_get_assigned_resource_class_code and included the resource uid in Resource Join for DevOps #86992
					
sp_equip_util 14, -1, '01/01/2010', '01/31/2010 23:59:59', '99', 0
***************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

BEGIN

	CREATE TABLE #equip (
		equip_class				varchar(10)		null,
		equip					varchar(10)		null,
		equip_name				varchar(100)	null,
		quantity_used_billed	float			null,
		quantity_used_nc		float			null,
		quantity_hours			float			null,
		bill_unit				varchar(4)		null,
		company_id				int				null,
		profit_ctr_id			int				null 
	)

	/* Store equip use amounts */
	INSERT INTO #equip
	SELECT 
		dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as [resource_class_code],
		wod.resource_assigned,
		r.description,
		sum(quantity_used),
		0 as quantity_used_nc,
		0 as quantity_hours,
		wod.bill_unit_code,
		woh.company_id,
		woh.profit_ctr_ID
	FROM WorkOrderHeader woh
	JOIN WorkOrderDetail wod
		ON woh.workorder_id = wod.workorder_id
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND	woh.company_id = wod.company_id
		AND wod.resource_type = 'E'
		AND wod.bill_rate > 0
	JOIN Resource r
		ON r.resource_uid = wod.resource_uid
		--AND r.company_id = wod.company_id
	JOIN CustomerBilling
		ON woh.customer_id = CustomerBilling.customer_id
		AND IsNull(woh.billing_project_id,0) = CustomerBilling.billing_project_id
		AND CustomerBilling.status = 'A'
		AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
	WHERE	(@company_id = 0 OR woh.company_id = @company_id)	
		AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
		AND woh.workorder_status IN ('C', 'A')
		--AND woh.submitted_flag = 'T'
		AND woh.end_date BETWEEN @date_from and @date_to
	GROUP BY woh.company_id, woh.profit_ctr_id, wod.bill_unit_code, resource_assigned, r.description, r.company_id, r.default_profit_ctr_id

	/* Add in no charge resources */
	INSERT INTO #equip
	SELECT 
		dbo.fn_get_assigned_resource_class_code(wod.resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id) as [resource_class_code],
		wod.resource_assigned,
		r.description,
		0 as quantity_used_billed,
		sum(quantity_used),
		0 as quantity_hours,
		wod.bill_unit_code,
		woh.company_id,
		woh.profit_ctr_ID
	FROM WorkOrderHeader woh
	JOIN WorkOrderDetail wod
		ON woh.workorder_id = wod.workorder_id
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND	woh.company_id = wod.company_id
		AND wod.resource_type = 'E'
		AND wod.bill_rate <= 0
	JOIN Resource r
		ON r.resource_uid = wod.resource_uid
		--AND r.company_id = wod.company_id
	JOIN CustomerBilling	
		ON woh.customer_id = CustomerBilling.customer_id
		AND IsNull(woh.billing_project_id,0) = CustomerBilling.billing_project_id
		AND CustomerBilling.status = 'A'
		AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
	WHERE	(@company_id = 0 OR woh.company_id = @company_id)	
		AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)	
		AND woh.workorder_status IN ('C', 'A')
		--AND woh.submitted_flag = 'T'
		AND woh.end_date BETWEEN @date_from and @date_to
	GROUP BY woh.company_id, woh.profit_ctr_id, wod.bill_unit_code, resource_assigned, r.description, r.company_id, r.default_profit_ctr_id

	/* Add in resources total hours */
	INSERT INTO #equip
	SELECT 
		dbo.fn_get_assigned_resource_class_code(resource_item_code, 'HOUR', r.company_id, r.default_profit_ctr_id) as [resource_class_code],
		resource_item_code,
		r.description,
		0 as quantity_used_billed,
		0 as quantity_used,
		Sum(time_amount),
		'HOUR',
		r.company_id,
		NULL AS profit_ctr_id
	FROM Resource r
	JOIN WorkOrderSchedule
		ON WorkOrderSchedule.resource_item_code = r.resource_code
		AND WorkOrderSchedule.start_date BETWEEN @date_from AND @date_to
		AND WorkOrderSchedule.resource_item_type = 'R'
		AND WorkOrderSchedule.time_unit = 'H'
		AND	WorkOrderSchedule.company_id = r.company_id
	WHERE (@company_id = 0 OR r.company_id = @company_id)
		AND r.resource_type = 'E'
	GROUP BY r.company_id, resource_item_code, r.description, r.default_profit_ctr_id	

	UNION ALL

	SELECT 
		dbo.fn_get_assigned_resource_class_code(resource_item_code, 'DAY', r.company_id, r.default_profit_ctr_id) as [resource_class_code],
		resource_item_code,
		r.description,
		0 as quantity_used_billed,
		0 as quantity_used,
		Sum(time_amount),
		'DAY',
		r.company_id,
		NULL AS profit_ctr_id
	FROM Resource r
	JOIN WorkOrderSchedule
		ON WorkOrderSchedule.resource_item_code = r.resource_code
		AND WorkOrderSchedule.start_date BETWEEN @date_from AND @date_to
		AND WorkOrderSchedule.resource_item_type = 'R'
		AND WorkOrderSchedule.time_unit = 'D'
		AND	WorkOrderSchedule.company_id = r.company_id
	WHERE (@company_id = 0 OR r.company_id = @company_id)
		AND r.resource_type = 'E'
	GROUP BY r.company_id, resource_item_code, r.description, r.default_profit_ctr_id

	/* Return */
	SELECT 
		equip_class,
		equip,
		equip_name,
		SUM(quantity_used_billed) AS quantity_billed,
		SUM(quantity_used_nc) AS quantity_nc,
		SUM(quantity_hours) AS quantity_hours,
		bill_unit,
		#equip.company_id,
		#equip.profit_ctr_id,
		Company.company_name
	FROM #equip
	JOIN Company
		ON Company.company_id = #equip.company_id
	GROUP BY equip_class, bill_unit, equip, equip_name, #equip.company_id, #equip.profit_ctr_id, company_name

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equip_util] TO [EQAI]
GO

