DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_stock_container_treat_weight_inv]
GO

CREATE PROCEDURE [dbo].[sp_rpt_stock_container_treat_weight_inv]
	@company_id					int
,	@profit_ctr_id 				int
,	@location					varchar(15)
,	@staging_row				varchar(5)
,	@treatment_id_list			varchar(max)
,	@waste_type_category_list	varchar(max)
,	@waste_type_list			varchar(max)
,	@treatment_process_list		varchar(max)
,	@disposal_service_list		varchar(max)
AS
/***************************************************************************************
Filename:		sp_rpt_stock_container_treat_weight_inv.SQL
PB Objects:		r_stock_container_treat_weight_inv
08/19/2004 kam	Created from sp_rpt_stock_container_treat_weight
10/27/2010 SK	Moved to Plt_AI, took out unused input parms: date_from, date_to, base_container
				Added company_id as input arg, added joins to company_id
03/22/2017 MPM	Modified the joins between Container and ContainerDestination tables in an effort to improve performance.
04/10/2022 GDE  DevOps 29879 - Report Center - Add column for Container Type to Inventory Reports
05/11/2023 MPM  DevOps 41793 - Added input parameters for Treatment ID List, Waste Type Category 
			    List, Waste Type List, Treatment Process List, and Disposal Service List.

sp_rpt_stock_container_treat_weight_inv 21, 0, 'EQDTP', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	@stock_drum_count	int,
	@debug int = 0

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

SELECT DISTINCT
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS base_container
,	ContainerDestination.treatment_id AS base_container_treatment_id
,	Treatment.treatment_desc AS base_container_treatment_desc
,	ISNULL(Container.container_weight, 0) AS base_container_weight
,	ISNULL(Container.container_size, '') AS base_container_size
,	ContainerDestination.date_added AS date_created
,	ContainerDestination.status AS base_status
,	ContainerDestination.company_id AS company_id
,	ContainerDestination.profit_ctr_id AS profit_ctr_id
,	Container.manifest_container AS manifest_container
INTO #stock_container
FROM ContainerDestination
JOIN Container 
	ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id is not null
	AND Container.container_type = ContainerDestination.container_type
	AND Container.status in ('N','C')
	AND (@staging_row = 'ALL' OR Container.staging_row = @staging_row)
LEFT OUTER JOIN Treatment
	ON Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE	( @company_id = 0 OR ContainerDestination.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR ContainerDestination.profit_ctr_id = @profit_ctr_id )
	AND ContainerDestination.container_type = 'S'
	AND ContainerDestination.status = 'N' 
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
	AND (@treatment_id_list = 'ALL' OR ISNULL(Treatment.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(Treatment.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(Treatment.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(Treatment.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(Treatment.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND (ContainerDestination.disposal_date IS NULL OR ContainerDestination.disposal_date > DateAdd(DAY,DATEDIFF(DAY,'20000101',GetDate()),'20000101'))

SELECT @stock_drum_count = COUNT(*) FROM #stock_container

-- Retrieve the list of containers that were poured into these base containers and their treatments and weights
SELECT DISTINCT
	#stock_container.base_container
,	#stock_container.base_container_treatment_id
,	#stock_container.base_container_treatment_desc
,	#stock_container.base_container_weight
,	#stock_container.base_container_size
,	#stock_container.date_created
,	#stock_container.company_id AS company_id
,	#stock_container.profit_ctr_id AS profit_ctr_id
,	CASE WHEN ContainerDestination.container_type = 'R' THEN CONVERT(varchar(15), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(15), ContainerDestination.line_id)
		 ELSE dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
	END AS source_container
,	ContainerDestination.container_id AS source_container_id
,	ContainerDestination.treatment_id AS source_container_treatment_id
,	Container.container_weight AS source_container_weight
,	Container.container_size AS source_container_size
,	ContainerDestination.container_percent AS source_container_percent
,	ContainerDestination.status AS source_container_status
,	@stock_drum_count AS stock_drum_count
,	consolidation_count = ISNULL((SELECT COUNT(*) FROM ContainerDestination 
									WHERE ContainerDestination.base_tracking_num = #stock_container.base_container
										AND ContainerDestination.company_id = #stock_container.company_id
										AND ContainerDestination.profit_ctr_id = #stock_container.profit_ctr_id),0)
,	#stock_container.base_status
,	#stock_container.manifest_container
INTO #results
FROM #stock_container 
LEFT OUTER JOIN ContainerDestination
	ON  ContainerDestination.base_tracking_num  = #stock_container.base_container
	AND ContainerDestination.company_id = #stock_container.company_id
	AND ContainerDestination.profit_ctr_id = #stock_container.profit_ctr_id
LEFT OUTER JOIN Container
	ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND Container.container_id is not null
ORDER BY 
#stock_container.base_container,
#stock_container.date_created,
source_container,
source_container_id

SELECT 
	#results.*
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	#results.manifest_container
FROM #results
JOIN Company
	ON Company.company_id = #results.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #results.company_id
	AND ProfitCenter.profit_ctr_ID =  #results.profit_ctr_id 
LEFT OUTER JOIN Treatment
	ON Treatment.treatment_id = ISNULL(#results.source_container_treatment_id, 0)
	AND Treatment.company_id = #results.company_id
	AND Treatment.profit_ctr_id = #results.profit_ctr_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_stock_container_treat_weight_inv] TO [EQAI];
GO

