/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.


CREATE PROCEDURE sp_project_costs_by_phase
	@date_from		datetime, 
	@date_to		datetime , 
	@cust_id_from		int, 
	@cust_id_to		int, 
	@project_id_from	int,
	@debug_flag		int = 0
AS
/-***************************************************************************************
This SP calculates the project costs by phase per workorder.

Filename:	F:\EQAI\SQL\EQAI\sp_project_costs_by_phase.sql
PB Object(s):	d_rpt_project_costs_by_phase

10/22/2003 PD	Created
03/23/2004 JDB	Added profit_ctr_id to join between WorkorderHeader and WorkorderDetail
		Added new companies 18, 21, 22, 23, 24
10/03/2007 rg  replaced ntsql5 references to alias server
05/04/2010 JDB	Added databases 25 through 28.
06/24/2014 AM  Moved to plt_ai

sp_project_costs_by_phase '1-1-2004 00:00:00', '3-31-2004 23:59:59', 0, 999999, 4, 0
****************************************************************************************-/
DECLARE @e_date_from 	int,
	@e_date_to 	int,
        @company_name   varchar(35),
        @pname          varchar(100)

CREATE TABLE #wo (
        project_id		int		null, 
        project_record_id	int		null,
        project_name		varchar(100)	null,         
        resource_type		char(1)		null,
        description		varchar(100)	null,
        cost			money		null,
        pname			varchar(100)	null,
        resource_class_code	varchar(10)	null,
        phase_code		varchar(10)	null	)

SELECT @pname = name FROM project WHERE project_id = @project_id_from

/-* Insert Equipment records *-/
INSERT #wo
SELECT	pd.project_id,
	pd.record_id,
	pd.name,
	'E',
	wod.resource_assigned,
	ROUND((wod.quantity_used * wod.cost),2),
	@pname,
	wod.resource_class_code,
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
FROM	workorderheader woh,
	workorderdetail wod,
	projectdetail pd
WHERE	woh.workorder_status NOT IN ('V','R','T')
	AND woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.project_id = @project_id_from
	AND pd.project_id = woh.project_id
	AND pd.record_id = woh.project_record_id
	AND wod.bill_rate > 0
	AND wod.resource_type = 'E'
	AND woh.end_date BETWEEN @date_from AND @date_to

/-* Insert Labor Records *-/
INSERT #wo
SELECT	pd.project_id,
	pd.record_id,
	pd.name,
	'L',
	rp.resource_code,
	ROUND((rp.hours * rp.cost),2),
	@pname,
	rxrc.resource_class_code,
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
FROM	workorderheader woh,
	projectdetail pd,
	ResourcePayroll rp,
	ResourceXResourceClass rxrc
WHERE	woh.workorder_status NOT IN ('V','R','T')
	AND woh.project_id = @project_id_from
	AND pd.project_id = woh.project_id
	AND pd.record_id = woh.project_record_id
	AND pd.project_id = rp.project_id
	AND pd.project_id = rp.project_record_id
	AND rp.resource_code = rxrc.resource_code
	AND woh.end_date BETWEEN @date_from AND @date_to

/-* Insert Supplies records *-/
INSERT #wo
SELECT	pd.project_id,
	pd.record_id,
	pd.name,
	'S',
	wod.description,
	ROUND((wod.quantity_used * wod.cost),2),
	@pname,
	wod.resource_class_code,
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
FROM	workorderheader woh,
	workorderdetail wod,
	projectdetail pd
WHERE	woh.workorder_status NOT IN ('V','R','T')
	AND woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.project_id = @project_id_from
	AND pd.project_id = woh.project_id
	AND pd.record_id = woh.project_record_id
	AND wod.bill_rate > 0
	AND wod.resource_type = 'S'
	AND woh.end_date BETWEEN @date_from AND @date_to

/-* Insert Disposal Records *-/
INSERT #wo
SELECT	pd.project_id,
	pd.record_id,
	pd.name,
	'D',
	wod.tsdf_code,
	ROUND((wod.quantity_used * wod.cost),2),
	@pname,
	wod.resource_class_code,
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	workorderheader woh,
	workorderdetail wod,
	projectdetail pd
WHERE	woh.workorder_status NOT IN ('V','R','T')
	AND woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.project_id = @project_id_from
	AND pd.project_id = woh.project_id
	AND pd.record_id = woh.project_record_id
	AND wod.bill_rate > 0
	AND wod.resource_type = 'D'
	AND woh.end_date BETWEEN @date_from AND @date_to

SELECT 	@e_date_from = DATEDIFF(day, '1980-01-01', @date_from) + 722815
SELECT 	@e_date_to   = DATEDIFF(day, '1980-01-01', @date_to) + 722815
SELECT  @company_name = company_name FROM company

/-* Insert A/P records *-/

/-* company 2 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
FROM 	NTSQLFINANCE.e02.dbo.apvohdr vh,
	NTSQLFINANCE.e02.dbo.pur_list p,
	projectdetail pd
WHERE 	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 3 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM 	NTSQLFINANCE.e03.dbo.apvohdr vh,
	NTSQLFINANCE.e03.dbo.pur_list p,
	projectdetail pd 
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 12 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM 	NTSQLFINANCE.e12.dbo.apvohdr vh,
	NTSQLFINANCE.e12.dbo.pur_list p,
	projectdetail pd 
WHERE 	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 14 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM 	NTSQLFINANCE.e14.dbo.apvohdr vh,
	NTSQLFINANCE.e14.dbo.pur_list p,
	projectdetail pd 
WHERE 	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 15 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM 	NTSQLFINANCE.e15.dbo.apvohdr vh,
	NTSQLFINANCE.e15.dbo.pur_list p,
	projectdetail pd
WHERE 	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 17 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e17.dbo.apvohdr vh,
	NTSQLFINANCE.e17.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 18 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e18.dbo.apvohdr vh,
	NTSQLFINANCE.e18.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 21 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e21.dbo.apvohdr vh,
	NTSQLFINANCE.e21.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 22 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e22.dbo.apvohdr vh,
	NTSQLFINANCE.e22.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 23 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e23.dbo.apvohdr vh,
	NTSQLFINANCE.e23.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 24 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e24.dbo.apvohdr vh,
	NTSQLFINANCE.e24.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 25 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e25.dbo.apvohdr vh,
	NTSQLFINANCE.e25.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 26 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e26.dbo.apvohdr vh,
	NTSQLFINANCE.e26.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 27 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e27.dbo.apvohdr vh,
	NTSQLFINANCE.e27.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to

/-* company 28 *-/
INSERT #wo
SELECT 	pd.project_id,
	pd.record_id,
	pd.name,
	'A',
	vh.vendor_code + CAST('-' AS varchar(1)) + doc_ctrl_num,
	vh.amt_paid_to_date,
	@pname,
	'',
	RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id))) 
FROM	NTSQLFINANCE.e28.dbo.apvohdr vh,
	NTSQLFINANCE.e28.dbo.pur_list p,
	projectdetail pd
WHERE	vh.po_ctrl_num = p.po_no 
	AND p.reference_code = RTRIM(LTRIM(STR(pd.project_id))) + CAST('-' AS varchar(1)) + RTRIM(LTRIM(STR(pd.record_id)))
	AND pd.project_id = @project_id_from
	AND vh.date_doc BETWEEN @e_date_from AND @e_date_to


SELECT	project_id,
	project_record_id,
	project_name,
	resource_type,
	description,
	cost,
	@company_name,
	pname,
	resource_class_code,
	phase_code
FROM	#wo

DROP TABLE #wo

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_project_costs_by_phase] TO [EQAI]
    AS [dbo];

*/
