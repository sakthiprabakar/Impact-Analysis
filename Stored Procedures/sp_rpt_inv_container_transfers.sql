DROP PROCEDURE IF EXISTS sp_rpt_inv_container_transfers
GO

CREATE PROCEDURE sp_rpt_inv_container_transfers
	@company_id					int
,	@profit_ctr_id				int
,	@location_in				varchar(15)
,	@staging_rows				varchar(max)
,	@treatment_id_list			varchar(max)
,	@waste_type_category_list	varchar(max)
,	@waste_type_list			varchar(max)
,	@treatment_process_list		varchar(max)
,	@disposal_service_list		varchar(max)
WITH RECOMPILE
AS
/***************************************************************************************
Filename:		L:\Apps\SQL\EQAI\sp_rpt_inv_container_transfers.sql
PB Object(s):	r_inv_container_transfers

11/08/2006 SCC	Created
12/20/2006 SCC	Added Unloading state to Transfer container selection and assigned/not shipped containers
01/29/2007 SCC	Changed to report manifest container code and hazmat class.
09/20/2007 JDB	Replaced the "OR" with "UNION ALL" in the ContainerDestination.status part of the selects.
09/30/2010 SK	Added Company_ID as input argument, removed the unused arguments @date_from & @date_to
				moved to Plt_AI. added joins for company_id whereever necessary.
				removed argument @db_type - not used on the datawindow.
09/30/2015 RB	Added WITH RECOMPILE to the create statement
02/28/2017 MPM	Replaced the staging row input parameter with a staging row list input parameter.
03/22/2017 MPM	Modified the joins between Container and Receipt tables in an effor to improve performance.
08/01/2019 MPM	Incident 13809 - Updated the "group by" order in the final selects.
05/11/2023 MPM  DevOps 41793 - Added input parameters for Treatment ID List, Waste Type Category 
			    List, Waste Type List, Treatment Process List, and Disposal Service List.
				Also simplified the logic for @location_in.

sp_rpt_inv_container_transfers '9/20/07', '9/20/07', 'ALL', 0, 'ALL', 'PROD'	-- EQ Detroit / Florida
sp_rpt_inv_container_transfers '9/20/07', '9/20/07', 'ALL', 21, 'ALL', 'PROD'	-- MDI
sp_rpt_inv_container_transfers 14, 0, 'ALL', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@as_of_date 	datetime
,	@debug 			int

-- Debugging?
SELECT @debug = 0

-- Set the date
SELECT @as_of_date = GETDATE()
IF @debug = 1 PRINT 'As of date: ' + CONVERT(varchar(30), @as_of_date)

if @staging_rows is null
	set @staging_rows = 'ALL'
	
CREATE TABLE #tmp_staging_rows (staging_row	varchar(5) NULL)

if datalength((@staging_rows)) > 0 and @staging_rows <> 'ALL'
	EXEC sp_list @debug, @staging_rows, 'STRING', '#tmp_staging_rows'

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

IF @location_in IS NULL
	SET @location_in = 'ALL'

-- These are the Outbound Receipts that are open, not Accepted
SELECT	dbo.fn_container_receipt(Receipt.receipt_id, Receipt.line_id) AS outbound_receipt,
	Receipt.receipt_date
INTO #outbounds
FROM Receipt
WHERE Receipt.trans_mode = 'O'
	AND Receipt.receipt_status = 'N'
	AND (@company_ID= 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND (@company_ID= 0 OR Receipt.company_id = @company_ID)

-- 1A -- Incomplete Receipt Transfer/ContainerDestination records
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	Container.manifest,
	Container.manifest_container,
	Container.manifest_hazmat_class,
	ContainerDestination.tsdf_approval_code AS approval_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	ContainerDestination.TSDF_approval_bill_unit_code AS bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	@as_of_date AS as_of_date,
	CONVERT(varchar(15), '') AS tracking_num,
	ISNULL(Container.staging_row, '') AS staging_row,
	Container.container_size,
	Container.container_weight,
	Receipt.company_id,
	ISNULL(TSDF.eq_company, 0) AS approval_company_id,
	ISNULL(TSDF.eq_profit_ctr, 0) AS approval_profit_ctr_id,
	NULL AS outbound_receipt,
	NULL AS outbound_receipt_date
INTO #tmp
FROM Receipt
INNER JOIN Container
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN TSDF 
	ON TSDF.tsdf_code = ContainerDestination.location
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('N', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@location_in = 'ALL' OR ContainerDestination.location = @location_in)
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'N'
GROUP BY
	Receipt.company_id,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id,
	Receipt.trans_type,
	ContainerDestination.container_type,
	Container.manifest,
	Container.manifest_container,
	Container.manifest_hazmat_class,
	ContainerDestination.tsdf_approval_code,
	ContainerDestination.TSDF_approval_bill_unit_code,
	Receipt.receipt_date,
	ContainerDestination.location,
	Container.staging_row,
	Receipt.location,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	Container.container_size,
	Container.container_weight,
	TSDF.eq_company,
	TSDF.eq_profit_ctr

UNION ALL

-- 1B -- Incomplete Receipt Transfer/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	Container.manifest,
	Container.manifest_container,
	Container.manifest_hazmat_class,
	ContainerDestination.tsdf_approval_code AS approval_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	ContainerDestination.TSDF_approval_bill_unit_code AS bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	@as_of_date AS as_of_date,
	CONVERT(varchar(15),'') AS tracking_num,
	ISNULL(Container.staging_row, '') AS staging_row,
	Container.container_size,
	Container.container_weight,
	Receipt.company_id,
	ISNULL(TSDF.eq_company,0) AS approval_company_id,
	ISNULL(TSDF.eq_profit_ctr,0) AS approval_profit_ctr_id,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date
FROM Receipt
INNER JOIN Container
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN #outbounds 
	ON #outbounds.outbound_receipt = ContainerDestination.tracking_num
LEFT OUTER JOIN TSDF 
	ON TSDF.tsdf_code = ContainerDestination.location
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('N', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@location_in = 'ALL' OR ContainerDestination.location = @location_in)
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N', 'C')
	AND Container.container_type = 'R'
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.tracking_num IN 
		(SELECT outbound_receipt FROM #outbounds)
GROUP BY
	Receipt.company_id,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.container_id,
	ContainerDestination.profit_ctr_id,
	Receipt.trans_type,
	ContainerDestination.container_type,
	Container.manifest,
	Container.manifest_container,
	Container.manifest_hazmat_class,
	ContainerDestination.tsdf_approval_code,
	ContainerDestination.TSDF_approval_bill_unit_code,
	Receipt.receipt_date,
	ContainerDestination.location,
	Container.staging_row,
	Receipt.location,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	Container.container_size,
	Container.container_weight,
	TSDF.eq_company,
	TSDF.eq_profit_ctr,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date

-- Return Results
SELECT DISTINCT 
	#tmp.receipt_id, 
	#tmp.line_id,
	#tmp.profit_ctr_id,
	#tmp.container_type,
	#tmp.manifest,
	#tmp.manifest_container,
	#tmp.manifest_hazmat_class,
	#tmp.approval_code,
	SUM(#tmp.containers_on_site) AS containers_on_site,
	#tmp.bill_unit_code,
	#tmp.receipt_date,
	#tmp.location, 
	#tmp.days_on_site,
	#tmp.as_of_date,
	#tmp.tracking_num,
	#tmp.staging_row,
	#tmp.container_size,
	#tmp.container_weight,
	#tmp.company_id,
	#tmp.approval_company_id,
	#tmp.approval_profit_ctr_id,
	#tmp.outbound_receipt,
	#tmp.outbound_receipt_date,
	Company.company_name,
	PC.profit_ctr_name
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter PC
	ON PC.company_ID = #tmp.company_id
	AND PC.profit_ctr_ID = #tmp.profit_ctr_id
GROUP BY
	#tmp.company_id,
	Company.company_name,
	#tmp.profit_ctr_id,
	PC.profit_ctr_name,
	#tmp.receipt_id, 
	#tmp.line_id,
	#tmp.container_type,
	#tmp.manifest,
	#tmp.manifest_container,
	#tmp.manifest_hazmat_class,
	#tmp.approval_code,
	#tmp.bill_unit_code,
	#tmp.receipt_date,
	#tmp.location, 
	#tmp.days_on_site,
	#tmp.as_of_date,
	#tmp.tracking_num,
	#tmp.staging_row,
	#tmp.container_size,
	#tmp.container_weight,
	#tmp.approval_company_id,
	#tmp.approval_profit_ctr_id,
	#tmp.outbound_receipt,
	#tmp.outbound_receipt_date
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inv_container_transfers] TO [EQAI];
GO


