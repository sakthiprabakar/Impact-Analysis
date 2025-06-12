
CREATE PROCEDURE sp_resource_history_report
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@customer_from	int
,	@customer_to	int
AS
/***************************************************************************************
This SP returns times a resource has been used on workorders for resources BOXDROP,
	FRACDROP, BOXPICK and FRACPICK.

PB Object:	r_resource_history

03/11/2003 NJE Created
				Note: take out temp table if no more changes
11/02/2010 SK Added Company_ID & Profit_Ctr_ID as input args, added joins to company-profit center
			  wherever required, took off the temp table
			  Moved to Plt_AI

sp_resource_history_report 14, -1, '1/1/2010','4/14/2010',1,99999 

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	wod.resource_assigned
,	woh.customer_id
,	woh.workorder_id
,	woh.company_id
,	woh.profit_ctr_id
,	woh.start_date
,	woh.end_date
,	wod.resource_class_code
,	wod.resource_type
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM WorkorderHeader woh
JOIN Company
	ON Company.company_id = woh.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = woh.company_id
	AND ProfitCenter.profit_ctr_id = woh.profit_ctr_id
JOIN WorkorderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP', 'BOXPICK', 'FRACPICK') 
	AND wod.resource_assigned IS NOT NULL
WHERE	(@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND woh.customer_id BETWEEN @customer_from AND @customer_to
	AND woh.end_date between @date_from and @date_to
ORDER BY wod.resource_assigned, woh.end_date

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_resource_history_report] TO [EQAI]
    AS [dbo];

