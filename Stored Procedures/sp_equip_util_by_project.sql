/***************************************************************************************
This SP lists projects and calculates the equipment utilization by resource.

Filename:	F:\EQAI\SQL\EQAI\sp_equip_util_by_project.sql
PB Object(s):	d_rpt_equip_util_by_project

09/05/2003 PD	Created
03/23/2004 JDB	Added profit_ctr_id to join between WorkorderHeader and WorkorderDetail
04/07/2010 RJG  Added criteria to joins:
				1) wod.profit_ctr_ID = RC.profit_ctr_id
				2) r.resource_class_profit_ctr_id = RC.profit_ctr_id
04/09/2010 RJG	Removed references to ResourceXResourceClass and Resourceclass
06/24/2014 AM   Moved to plt_ai 

select * from workorderheader where project_id = 5
select * from workorderdetail where workorder_id = 1119000 and profit_ctr_id = 1
sp_equip_util_by_project 14, 1, 1, 10, 0, 'EQ'
****************************************************************************************/
CREATE PROCEDURE sp_equip_util_by_project
	@company_id		int,
	@profit_ctr_id		int,
	@project_id_from	int, 
	@project_id_to		int,
	@debug_flag		int = 0, 
	@company_name		varchar(35)
AS

CREATE TABLE #project_summary (
	project_id	int		null,
	project_name	varchar(100)	null	)

CREATE TABLE #equip (
        project_id		int 		null, 
        project_name		varchar(100)	null, 
        record_id		int 		null,        
        equip_class		varchar(10) 	null,
        resource_assigned	varchar(10) 	null,
        quantity_used_billed	float 		null,
        quantity_used_nc	float 		null,
        expected_start_date	datetime 	null,
        expected_end_date	datetime 	null,
        bill_unit_code		varchar(4) 	null,
        level_1			int 		null,
        level_2 		int 		null,
        level_3 		int 		null,
        level_4 		int 		null,
        level_5 		int 		null	)

/* Insert records billable */
INSERT #equip
SELECT DISTINCT
	pd.project_id,
	pd.name,
	pd.record_id,
	wod.resource_class_code,
	wod.resource_assigned,
	wod.quantity_used,
	0 AS quantity_used_nc,
	expected_start_date = pd.estimated_start_date,
	expected_end_date = pd.estimated_end_date,
	wod.bill_unit_code,
	pd.level_1,
	pd.level_2,
	pd.level_3,
	pd.level_4,
	pd.level_5
FROM	workorderheader woh, 
	projectdetail pd, 
	workorderdetail wod 
WHERE	woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.workorder_status NOT IN ('T', 'V', 'R')
	AND wod.resource_type = 'E'
	AND wod.bill_rate > 0
	AND woh.project_id = pd.project_id
	AND woh.project_record_id = pd.record_id
	AND pd.project_id BETWEEN @project_id_from AND @project_id_to


/* Insert records no-charge */
INSERT #equip
SELECT DISTINCT
	pd.project_id,
	pd.name,
	pd.record_id,
	wod.resource_class_code,
	wod.resource_assigned,
	0 AS quantity_used,
	wod.quantity_used,
	expected_start_date = pd.estimated_start_date,
	expected_end_date = pd.estimated_end_date,
	wod.bill_unit_code,
	pd.level_1,
	pd.level_2,
	pd.level_3,
	pd.level_4,
	pd.level_5
FROM 	workorderheader woh, 
	projectdetail pd, 
	workorderdetail wod
WHERE 	woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.workorder_status NOT IN ('T', 'V', 'R')
	AND wod.resource_type = 'E'
	AND wod.bill_rate <= 0
	AND woh.project_id = pd.project_id
	AND woh.project_record_id = pd.record_id
	AND pd.project_id BETWEEN @project_id_from AND @project_id_to

--Create Summary Table 
INSERT #project_summary
SELECT DISTINCT
	#equip.project_id,
	project.name
FROM 	#equip, project
WHERE 	#equip.project_id = project.project_id

-- Final select
SELECT DISTINCT
	ps.project_id,
	ps.project_name, 
	eq.record_id,
	eq.project_name AS pname,
	eq.expected_start_date,
	eq.expected_end_date,
	eq.equip_class,
	eq.resource_assigned,
	eq.quantity_used_billed,
	eq.quantity_used_nc,
	eq.bill_unit_code,
	eq.level_1,
	eq.level_2,
	eq.level_3,
	eq.level_4,
	eq.level_5
FROM 	#equip eq, #project_summary ps
WHERE 	eq.project_id = ps.project_id

DROP TABLE #equip
DROP TABLE #project_summary

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equip_util_by_project] TO [EQAI]
    AS [dbo];

