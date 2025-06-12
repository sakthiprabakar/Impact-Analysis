
CREATE PROCEDURE sp_rpt_workorder_YTD_supplies_utilization
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
AS
/**************************************************************************************
This procedure runs for Waste Received from Generators Report
PB Object(s):	r_ytd_supplies_utilization

08/10/2011 AM	Created

sp_rpt_workorder_YTD_supplies_utilization 22,0,'2015-01-01', '2016-01-01'
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT
 woh.company_id, 
 woh.profit_ctr_id, 
 woh.workorder_id, 
 woh.workorder_type_id, 
 woth.account_desc, 
 woh.workorder_status, 
 woh.start_date, 
 woh.end_date, 
 woh.submitted_flag, 
 woh.date_submitted, 
 ProfitCenter.profit_ctr_name,
 company.company_name,
 wod.sequence_id, 
 wod.resource_class_code, 
 wod.description, 
 wod.description_2, 
 wod.bill_unit_code, 
 wod.price, 
 wod.cost, 
 wod.quantity, 
 wod.quantity_used, 
 wod.bill_rate
FROM workorderdetail wod
JOIN workorderheader woh ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_id = woh.workorder_id
JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
JOIN Company ON Company.company_id = wod.company_id
JOIN ProfitCenter ON ProfitCenter.company_id = wod.company_id
	AND ProfitCenter.profit_ctr_id = wod.profit_ctr_id
WHERE wod.resource_type = 'S'
AND woh.submitted_flag = 'T'
AND wod.company_id = @company_id
AND wod.profit_ctr_id = @profit_ctr_id
AND woh.start_date Between @date_from AND @date_to
ORDER BY woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.sequence_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_workorder_YTD_supplies_utilization] TO [EQAI]
    AS [dbo];

