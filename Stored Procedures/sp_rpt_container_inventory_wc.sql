DROP PROCEDURE IF EXISTS sp_rpt_container_inventory_wc
GO

CREATE PROCEDURE sp_rpt_container_inventory_wc
	@company_id					int
,	@profit_ctr_id				int
,	@user_id					varchar(10)
,	@location					varchar(15)
,	@staging_rows				varchar(max)
,	@treatment_id_list			varchar(max)
,	@waste_type_category_list	varchar(max)
,	@waste_type_list			varchar(max)
,	@treatment_process_list		varchar(max)
,	@disposal_service_list		varchar(max)
AS
/*************************************************************************************************
PB Object(s):	r_inv_container_staging_wc

05/25/2023 MPM	DevOps 65607 - Created. This is an existing report. The datawindow formerly had a 
				SQL Select statement as its data source, but I rewrote that to use a CTE. However,
				PowerBuilder wouldn't allow that in the SQL Select, so I put that in this stored 
				procedure.
09/27/2023 Kamendra Singh DevOps 42708 - Added DISTINCT to the final select so that we get the unique records.
				This SP is used in the nested datawindow so this change enhances the performance.
12/14/2024 Krishna G K - US134993 - Added Container Weight column in the SELECT, and CTE sections
sp_rpt_container_inventory_wc 21, 0, 'MARTHA_M','ALL', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL'
**************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH work_cte (
	company_id, 
	profit_ctr_id, 
	as_of_date, 
	group_report, 
	outbound_receipt, 
	user_id, 
	company_name, 
	profit_ctr_name, 
	treatment_id, 
	wastetype_category, 
	wastetype_id, 
	treatment_process_id, 
	disposal_service_id, 
	location, 
	staging_row, 
	container_id,
	--US134993 - Add Container Weight to the SELECT query -- Start  
	container_weight  
	--US134993 - End 
	)
AS
(
-- Stock containers
SELECT 
	w.company_id, 
	w.profit_ctr_id, 
	w.as_of_date, 
	w.group_report, 
	w.outbound_receipt, 
	w.user_id, 
	c.company_name, 
	p.profit_ctr_name, 
	w.treatment_id, 
	t.wastetype_category, 
	t.wastetype_id, 
	t.treatment_process_id, 
	t.disposal_service_id, 
	w.location, 
	w.staging_row, 
	w.container_id,
	--US134993 - Add Container Weight to the SELECT query -- Start  
	w.container_weight  
	--US134993 - End
FROM work_Container w 
JOIN Company c 
	ON w.company_id = c.company_id
JOIN ProfitCenter p
	ON p.company_id = w.company_id
	AND p.profit_ctr_id = w.profit_ctr_id
JOIN Container c2 
	ON w.profit_ctr_id = c2.profit_ctr_id
	AND  w.company_id = c2.company_id
	AND w.container_id = c2.container_id
LEFT OUTER JOIN Treatment t 
	ON t.treatment_id = w.treatment_id
	AND t.company_id = w.company_id
	AND t.profit_ctr_id = w.profit_ctr_id
  WHERE w.container_type = 'S'
	AND w.user_id = @user_id 
	AND w.company_id = @company_id
	AND w.profit_ctr_id = @profit_ctr_id
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@treatment_id_list, ',')))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@waste_type_category_list, ',')))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@waste_type_list, ',')))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@treatment_process_list, ',')))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@disposal_service_list, ',')))
	AND (@location = 'ALL' OR w.location = @location)
	AND (@staging_rows = 'ALL' OR w.staging_row IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@staging_rows, ',')))
UNION
-- Receipt containers
SELECT 
	w.company_id, 
	w.profit_ctr_id, 
	w.as_of_date, 
	w.group_report, 
	w.outbound_receipt, 
	w.user_id, 
	c.company_name, 
	p.profit_ctr_name, 
	w.treatment_id, 
	t.wastetype_category, 
	t.wastetype_id, 
	t.treatment_process_id, 
	t.disposal_service_id, 
	w.location, 
	w.staging_row, 
	w.container_id,
	--US134993 - Add Container Weight to the SELECT query -- Start  
	w.container_weight  
	--US134993 - End 
FROM work_Container w 
JOIN Company c 
	ON w.company_id = c.company_id
JOIN ProfitCenter p
	ON p.company_id = w.company_id
	AND p.profit_ctr_id = w.profit_ctr_id
JOIN Container c2 
	ON w.receipt_id = c2.receipt_id
	AND w.line_id = c2.line_id
	AND w.profit_ctr_id = c2.profit_ctr_id
	AND  w.company_id = c2.company_id
	AND w.container_id = c2.container_id
LEFT OUTER JOIN Treatment t 
	ON t.treatment_id = w.treatment_id
	AND t.company_id = w.company_id
	AND t.profit_ctr_id = w.profit_ctr_id
  WHERE w.container_type = 'R'
	AND w.user_id = @user_id 
	AND w.company_id = @company_id
	AND w.profit_ctr_id = @profit_ctr_id
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@treatment_id_list, ',')))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@waste_type_category_list, ',')))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@waste_type_list, ',')))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@treatment_process_list, ',')))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@disposal_service_list, ',')))
	AND (@location = 'ALL' OR w.location = @location)
	AND (@staging_rows = 'ALL' OR w.staging_row IN (SELECT LTRIM(value) FROM dbo.fn_StringSplit(@staging_rows, ','))))
SELECT DISTINCT
	work_cte.profit_ctr_id, 
	work_cte.company_id,  
	work_cte.as_of_date,   
	work_cte.group_report,   
	work_cte.outbound_receipt,
	work_cte.user_id,
	(SELECT COUNT(*) FROM work_cte) AS total_container_count,
	work_cte.company_name,
	work_cte.profit_ctr_name,
	--US134993 - Add Sum of Container Weight to Select Query - Start  
	(SELECT SUM(CONTAINER_WEIGHT) FROM work_cte) AS total_container_weight  
	--US134993 - End
FROM work_cte WITH (NOLOCK)
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inventory_wc] TO [EQAI];
GO


