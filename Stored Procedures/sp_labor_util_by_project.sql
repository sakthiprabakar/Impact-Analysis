CREATE PROCEDURE sp_labor_util_by_project
	@company_id			int
,	@profit_ctr_id		int
,	@project_id_from	int
,	@project_id_to		int
AS
/***************************************************************************************
This SP lists projects and calculates the labor utilization by resource.

Filename:	F:\EQAI\SQL\EQAI\sp_labor_util_by_project.sql
PB Object(s):	d_rpt_labor_util_by_project

09/05/2003 PD	Created
03/23/2004 JDB	Added profit_ctr_id to join between WorkorderHeader and WorkorderDetail
04/07/2010 RJG	Changed join criteria:
				1) 	Added: r.resource_class_profit_ctr_id = RC.profit_ctr_id
				2)  Added: wod.profit_ctr_ID = RC.profit_ctr_id
04/09/2010 RJG	Removed references to ResourceClass and ResourceXResourceClass
01/13/2010 SK	Used Company_id & Profit_ctr_ID, removed unused parms debug, company_name
				Moved to Plt_AI

sp_labor_util_by_project 14, 1, 1, 10
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


CREATE TABLE #project_summary (
	project_id		int				null
,	project_name	varchar(100)	null
)

CREATE TABLE #labor (
	company_id			int				null
,	profit_ctr_id		int				null
,	project_id			int 			null
,	project_name		varchar(100)	null
,	record_id			int 			null
,	resource_assigned	varchar(10)		null
,	wo_billed_hrs		float 			null
,	wo_nocharge_hrs		float 			null
,	payroll_hrs			float 			null
,	expected_start_date	datetime 		null
,	expected_end_date	datetime 		null
,	level_1				int 			null
,	level_2				int 			null
,	level_3				int 			null
,	level_4				int 			null
,	level_5				int 			null
)

/* Insert records for billable hours */
INSERT #labor
SELECT DISTINCT
	pd.company_id,
	pd.profit_ctr_ID,
	pd.project_id,
	pd.name,
	pd.record_id,
	wod.resource_assigned,
	wod.quantity_used,
	0 AS wo_nocharge_hrs,
	0 AS payroll_hrs,
	pd.estimated_start_date,
	pd.estimated_end_date,
	pd.level_1,
	pd.level_2,
	pd.level_3,
	pd.level_4,
	pd.level_5
FROM workorderheader woh
JOIN workorderdetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type = 'L'
	AND wod.bill_unit_code = 'HOUR'
	AND wod.bill_rate > 0
JOIN projectdetail pd
	ON pd.company_ID = woh.company_id
	AND pd.profit_ctr_ID = woh.profit_ctr_ID
	AND pd.project_ID = woh.project_id
	AND pd.record_ID = woh.project_record_id
	AND pd.project_id BETWEEN @project_id_from AND @project_id_to
WHERE woh.company_id = @company_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.workorder_status NOT IN ('V', 'T', 'R')

/* Insert records for no charge hours*/
INSERT #labor
SELECT DISTINCT
	pd.company_id,
	pd.profit_ctr_ID,
	pd.project_id,
	pd.name,
	pd.record_id,
	wod.resource_assigned,
	0 AS wo_billed_hrs,
	quantity_used,
	0 AS payroll_hrs,
	pd.estimated_start_date,
	pd.estimated_end_date,
	pd.level_1,
	pd.level_2,
	pd.level_3,
	pd.level_4,
	pd.level_5
FROM workorderheader woh
JOIN workorderdetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type = 'L'
	AND wod.bill_unit_code = 'HOUR'
	AND wod.bill_rate <= 0
JOIN projectdetail pd
	ON pd.company_ID = woh.company_id
	AND pd.profit_ctr_ID = woh.profit_ctr_ID
	AND pd.project_ID = woh.project_id
	AND pd.record_ID = woh.project_record_id
	AND pd.project_id BETWEEN @project_id_from AND @project_id_to
WHERE woh.company_id = @company_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.workorder_status NOT IN ('V', 'T', 'R')	

/* Insert records for payroll*/
INSERT #labor
SELECT DISTINCT
	pd.company_id,
	pd.profit_ctr_ID,
	pd.project_id,
	pd.name,
	pd.record_id,
	rp.resource_code,
	0 AS wo_billed_hrs,
	0 AS wo_nocharge_hrs,
	rp.hours,
	pd.estimated_start_date,
	pd.estimated_end_date,
	pd.level_1,
	pd.level_2,
	pd.level_3,
	pd.level_4,
	pd.level_5
FROM projectdetail pd
JOIN ResourcePayroll rp
	ON rp.project_id = pd.project_id
	AND rp.project_record_id = pd.record_id
	AND rp.company_id = pd.company_ID
WHERE pd.company_ID = @company_id
	AND pd.profit_ctr_ID = @profit_ctr_id
	AND pd.project_id BETWEEN @project_id_from AND @project_id_to

--Create Summary Table 
INSERT #project_summary
SELECT DISTINCT
	#labor.project_id,
	project.name
FROM #labor, Project
WHERE #labor.project_id = Project.project_id
	AND #labor.company_id = Project.company_ID
	AND #labor.profit_ctr_id = Project.profit_ctr_ID

--final select
SELECT DISTINCT
	ps.project_id,
	ps.project_name, 
	lbr.record_id,
	lbr.project_name AS pname,
	lbr.expected_start_date,
	lbr.expected_end_date,
	lbr.resource_assigned,
	lbr.wo_billed_hrs,
	lbr.wo_nocharge_hrs,
	lbr.payroll_hrs,
	lbr.level_1,
	lbr.level_2,
	lbr.level_3,
	lbr.level_4,
	lbr.level_5,
	lbr.company_id,
	lbr.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM #labor lbr
JOIN #project_summary ps
	ON lbr.project_id = ps.project_id
JOIN Company
	ON Company.company_id = lbr.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = lbr.company_id
	AND ProfitCenter.profit_ctr_ID = lbr.profit_ctr_id

DROP TABLE #labor
DROP TABLE #project_summary

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_labor_util_by_project] TO [EQAI]
    AS [dbo];

