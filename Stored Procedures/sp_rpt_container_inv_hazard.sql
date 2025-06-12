DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_container_inv_hazard]
GO

CREATE PROCEDURE [dbo].[sp_rpt_container_inv_hazard]
    @company_id					int
,   @profit_cntr_id				int
,	@treatment_id_list			varchar(max)
,	@waste_type_category_list	varchar(max)
,	@waste_type_list			varchar(max)
,	@treatment_process_list		varchar(max)
,	@disposal_service_list		varchar(max)
WITH RECOMPILE
AS
/***************************************************************************************
Filename:		L:\Apps\SQL\EQAI\sp_rpt_inv_hazard.sql
Loads to:		Plt_AI
PB Object(s):	r_containter_inv_hazard
				

03/04/2022 GDE  Created
04/10/2022 GDE  DevOps 29879 - Report Center - Add column for Container Type to Inventory Reports
05/11/2023 MPM  DevOps 41793 - Added input parameters for Treatment ID List, Waste Type Category 
			    List, Waste Type List, Treatment Process List, and Disposal Service List.

sp_rpt_container_inv_hazard 3, 0, 'ALL', 'ALL', 'ALL', 'ALL', 'ALL'	  
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@as_of_date 	datetime
,	@debug 			int

-- Debugging?
SELECT @debug = 0

-- Set the date
SELECT @as_of_date = GETDATE()

IF OBJECT_ID(N'tempdb..#temp ') IS NOT NULL
	drop table #temp
;

-- DevOps 41793
CREATE TABLE #tmp_treatment_id (treatment_id INT NULL)

IF @treatment_id_list IS NULL
	SET @treatment_id_list = 'ALL'

IF DATALENGTH((@treatment_id_list)) > 0 AND @treatment_id_list <> 'ALL'
	EXEC sp_list @debug, @treatment_id_list, 'NUMBER', '#tmp_treatment_id'

CREATE TABLE #tmp_waste_type_category (waste_type_category VARCHAR(40) NULL)

IF @waste_type_category_list IS NULL
	SET @waste_type_category_list = 'ALL'

IF DATALENGTH((@waste_type_category_list)) > 0 AND @waste_type_category_list <> 'ALL'
	EXEC sp_list @debug, @waste_type_category_list, 'STRING', '#tmp_waste_type_category'

CREATE TABLE #tmp_waste_type_id (waste_type_id INT NULL)

IF @waste_type_list IS NULL
	SET @waste_type_list = 'ALL'

IF DATALENGTH((@waste_type_list)) > 0 AND @waste_type_list <> 'ALL'
	EXEC sp_list @debug, @waste_type_list, 'NUMBER', '#tmp_waste_type_id'

CREATE TABLE #tmp_treatment_process_id (treatment_process_id INT NULL)

IF @treatment_process_list IS NULL
	SET @treatment_process_list = 'ALL'

IF DATALENGTH((@treatment_process_list)) > 0 AND @treatment_process_list <> 'ALL'
	EXEC sp_list @debug, @treatment_process_list, 'NUMBER', '#tmp_treatment_process_id'

CREATE TABLE #tmp_disposal_service_id (disposal_service_id INT NULL)

IF @disposal_service_list IS NULL
	SET @disposal_service_list = 'ALL'
	
IF DATALENGTH((@disposal_service_list)) > 0 AND @disposal_service_list <> 'ALL'
	EXEC sp_list @debug, @disposal_service_list, 'NUMBER', '#tmp_disposal_service_id'

-- These are the Outbound Receipts that are open, not Accepted
SELECT c.company_id
		, c.profit_ctr_id
		, isnull(nullif(c.manifest_hazmat_class,''),'<none>') AS 'manifest_hazmat_class'
		, isnull(nullif(c.staging_row,''),'<none>') AS staging_row
		, c.container_type
		, c.receipt_id
		, c.line_id
		, c.container_id
		, c.status
		, cd.sequence_id
		, c.manifest_container AS manifest_container
INTO #temp
FROM Container c
JOIN ContainerDestination cd
	ON c.company_id = cd.company_id
		AND c.profit_ctr_id = cd.profit_ctr_id
		AND c.receipt_id = cd.receipt_id
		AND c.line_id = cd.line_id
		AND c.container_id = cd.container_id
		AND c.container_type = cd.container_type
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = cd.treatment_id
	AND t.company_id = cd.company_id
	AND t.profit_ctr_id = cd.profit_ctr_id
WHERE   c.container_type = 'S'
	AND cd.status not in ('V', 'R', 'C')
	AND c.company_id=@company_id 
	AND c.profit_ctr_id=@profit_cntr_id 
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))

UNION

SELECT c.company_id, c.profit_ctr_id, isnull(nullif(r.manifest_hazmat_class,''),'<none>'), isnull(nullif(c.staging_row,''),'<none>') AS staging_row, 
	c.container_type, c.receipt_id, c.line_id, c.container_id, c.status, cd.sequence_id, c.manifest_container AS manifest_container
FROM container c
	JOIN ContainerDestination cd
	ON c.company_id = cd.company_id
		AND c.profit_ctr_id = cd.profit_ctr_id
		AND c.receipt_id = cd.receipt_id
		AND c.line_id = cd.line_id
		AND c.container_id = cd.container_id
		AND c.container_type = cd.container_type
JOIN receipt r
	ON c.company_id = r.company_id
		AND c.profit_ctr_id = r.profit_ctr_id
		AND c.receipt_id = r.receipt_id
		AND c.line_id = r.line_id
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = cd.treatment_id
	AND t.company_id = cd.company_id
	AND t.profit_ctr_id = cd.profit_ctr_id
WHERE 
	 c.container_type = 'R'
	AND cd.status NOT IN ('V', 'R', 'C')
	AND c.company_id=@company_id 
	AND c.profit_ctr_id=@profit_cntr_id 
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))

SELECT 
	t.company_id, t.profit_ctr_id,isnull(nullif(t.staging_row,''),'<none>') AS 'Staging Row'
, isnull(nullif(t.manifest_hazmat_class,''),'<none>') AS 'Hazard Class'
, COUNT(*) AS 'Number of Containers'
, @as_of_date AS 'AS OF DATE'
, t.manifest_container
FROM #temp t
GROUP BY t.company_id, t.profit_ctr_id, t.staging_row, t.manifest_hazmat_class, t.manifest_container
ORDER BY t.company_id, t.profit_ctr_id, t.staging_row, t.manifest_hazmat_class, t.manifest_container
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inv_hazard] TO [EQAI];
GO
   