﻿DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_inv_container_disposal]
GO

CREATE PROCEDURE [dbo].[sp_rpt_inv_container_disposal]
	@company_id					int
,	@profit_ctr_id				int
,	@customer_id_from			int
,	@customer_id_to				int
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
Filename:	L:\Apps\SQL\EQAI\sp_rpt_inv_container_disposal.sql
Loads to:		Plt_XX_AI
PB Object(s):	d_rpt_inv_container_disposal

09/XX/2002 SCC Created
12/11/2002 JDB Modified to get the receipt.location if the drumdetail.location is NULL
03/08/2004 SCC Added lab status
03/11/2004 SCC Added treatment and container size
05/05/2004 MK  select actual sequence_id in first select and added container weight for all
06/03/2004 SCC Added DrumDetail.status = 'N' to omit reporting on completely consolidated containers
12/13/2004 MK  Modified ticket_id, drum references, DrumHeader, and DrumDetail
03/24/2005 LJT Added receipt.fingerprint <> 'V'
09/27/2005 MK  Modified to receipt.fingerprint NOT IN ('V','R')
10/24/2005 MK  Added company_id to resultset to fix display of stock containers in report
11/08/2006 SCC Added Transfer containers
12/20/2006 SCC Added Unloading state to Transfer container selection and assigned/not shipped containers
09/20/2007 JDB Replaced the "OR" with "UNION ALL" in the ContainerDestination.status part of the selects.
06/09/2009 KAM  Update the status of a stock container calculation to distinguish between empty and accepted.
07/21/2009 JDB	Added new index on ContainerDestination.base_container_id to speed up the calculation
				of a stock container's fingerprint status (the change made on 6/9/09 above).
				Also removed join to ProfitCenter table because it's no longer needed.
				Added join on company_id between ContainerDestination and Container tables.  This
				is not necessary right now because this report runs on Plt_XX_AI, but will be needed when
				we move it to Plt_AI. 
09/21/2010 SK	Modified to run on Plt_AI, takes CompanyID as input arg
				Removed unused arguments: @date_from & @date_to
				Report N/A for All Companies..only run for user selected company
				Replaced *= with standard ANSI joins
				moved to plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
09/30/2015 RB	Added WITH RECOMPILE to the create statement
02/28/2017 MPM	Replaced the staging row input parameter with a staging row list input parameter.
03/22/2017 MPM	Modified the joins between Container and Receipt tables in an effor to improve performance.
02/05/2018 AM   Addede ContainerDestination.tracking_number.
04/10/2022 GDE  DevOps 29879 - Report Center - Add column for Container Type to Inventory Reports
05/11/2023 MPM  DevOps 41793 - Added input parameters for Treatment ID List, Waste Type Category 
			    List, Waste Type List, Treatment Process List, and Disposal Service List.
				Also simplified the logic for @location_in.

sp_rpt_inv_container_disposal 14, 12, 1, 999999, 'ALL', 'BAY4', 'ALL', 'ALL', 'ALL', 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@as_of_date 	datetime,
	@debug 			int

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

-- 1A -- Get Incomplete Receipt/ContainerDestination records
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	'DISP' AS load_type,
	Receipt.manifest,
	CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	w.display_name as waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	@as_of_date AS as_of_date,
	CONVERT(varchar(15),'') AS tracking_num,
	ISNULL(Container.staging_row, '') AS staging_row,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	NULL AS outbound_receipt,
	NULL AS outbound_receipt_date,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container AS manifest_container
INTO #tmp
FROM Receipt
INNER JOIN Container
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = Receipt.waste_code_uid
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('L', 'U', 'A') 
	AND (@company_id = 0 OR Receipt.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V','R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N', 'C')
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
	Receipt.manifest,
	Receipt.approval_code,
	w.display_name,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ContainerDestination.location,
	Container.staging_row,
	Receipt.location,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ContainerDestination.tsdf_approval_code,
	ContainerDestination.tracking_num,
	Container.manifest_container

UNION ALL

-- 1B -- Get Incomplete Receipt/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	'DISP' AS load_type,
	Receipt.manifest,
	CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	w.display_name as waste_code,
	COUNT(ContainerDestination.container_id) AS containers_on_site,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	@as_of_date AS as_of_date,
	CONVERT(varchar(15),'') AS tracking_num,
	ISNULL(Container.staging_row, '') AS staging_row,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container AS manifest_container
FROM Receipt
INNER JOIN Container (NOLOCK)
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = Receipt.waste_code_uid
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN #outbounds 
	ON #outbounds.outbound_receipt = ContainerDestination.tracking_num
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('L', 'U', 'A') 
	AND (@company_id = 0 OR Receipt.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V','R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N', 'C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@location_in = 'ALL' OR ContainerDestination.location = @location_in)
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
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
	Receipt.manifest,
	Receipt.approval_code,
	w.display_name,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ContainerDestination.location,
	Container.staging_row,
	Receipt.location,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id),
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ContainerDestination.tsdf_approval_code,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date,
	ContainerDestination.tracking_num,
	Container.manifest_container

UNION ALL

-- 2A -- Include Incomplete Stock Label Drum records without a tracking number
--	ContainerDestination.status = 'N'
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id AS container_id,
	'STOCK' AS load_type,
	'' AS manifest,
	'' AS approval_code,
	'' AS waste_code,
	1 AS containers_on_site,
	'' AS bill_unit_code,
	ContainerDestination.date_added AS receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, ContainerDestination.date_added, @as_of_date) AS days_on_site,
	@as_of_date AS AS_OF_DATE,
	tracking_num = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id),
	ISNULL(Container.staging_row, '') AS staging_row,
	Case
			(Select count(*) from containerDestination 
			where containerDestination.base_container_id = container.container_id)
	
			When 0 then ''
				Else
				 CASE
					(Select count(*) from receipt join containerDestination on
					receipt.receipt_id = containerDestination.receipt_id and
					receipt.line_id = containerDestination.line_id 
					where containerDestination.base_container_id = container.container_id and
					fingerpr_status not in ('A','V'))
				 When 0 then 'A'
				 Else ''
				End
			End
			AS fingerpr_status,
	ContainerDestination.treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Container.company_id,
	NULL AS outbound_receipt,
	NULL AS outbound_receipt_date,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container AS manifest_container
FROM Container
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id =Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Container.container_type = 'S'
	AND Container.status IN ('N', 'C')
	AND ( @company_id = 0 OR Container.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Container.profit_ctr_id = @profit_ctr_id)
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@location_in = 'ALL' OR ContainerDestination.location = @location_in)
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'N'
GROUP BY
	Container.company_id,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.container_id,
	Container.container_id,
	ContainerDestination.company_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.Date_added,
	ContainerDestination.location,
	Container.staging_row,
	ContainerDestination.treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ContainerDestination.tsdf_approval_code,
	ContainerDestination.tracking_num,
	Container.manifest_container
UNION ALL

-- 2B -- Include Incomplete Stock Label Drum records without a tracking number
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id AS container_id,
	'STOCK' AS load_type,
	'' AS manifest,
	'' AS approval_code,
	'' AS waste_code,
	1 AS containers_on_site,
	'' AS bill_unit_code,
	ContainerDestination.date_added AS receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, ContainerDestination.date_added, @as_of_date) AS days_on_site,
	@as_of_date AS AS_OF_DATE,
	tracking_num = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id),
	ISNULL(Container.staging_row, '') AS staging_row,
	Case
			(Select count(*) from containerDestination 
			where containerDestination.base_container_id = container.container_id)
	
			When 0 then ''
				Else
				 CASE
					(Select count(*) from receipt join containerDestination on
					receipt.receipt_id = containerDestination.receipt_id and
					receipt.line_id = containerDestination.line_id 
					where containerDestination.base_container_id = container.container_id and
					fingerpr_status not in ('A','V'))
				 When 0 then 'A'
				 Else ''
				End
			End
			AS fingerpr_status,
	ContainerDestination.treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Container.company_id,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container AS manifest_container
FROM Container
INNER JOIN ContainerDestination 
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id =Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
LEFT OUTER JOIN #outbounds 
	ON #outbounds.outbound_receipt = ContainerDestination.tracking_num
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Container.container_type = 'S'
	AND Container.status IN ('N', 'C')
	AND ( @company_id = 0 OR Container.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Container.profit_ctr_id = @profit_ctr_id)
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@location_in = 'ALL' OR ContainerDestination.location = @location_in)
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.tracking_num IN 
		(SELECT outbound_receipt FROM #outbounds)
GROUP BY
	Container.company_id,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.container_id,
	Container.container_id,
	ContainerDestination.company_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.Date_added,
	ContainerDestination.location,
	Container.staging_row,
	ContainerDestination.treatment_id,
	t.Treatment_desc,
	Container.container_size,
	Container.container_weight,
	ContainerDestination.tsdf_approval_code,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date,
	ContainerDestination.tracking_num,
	Container.manifest_container

-- Return Results
SELECT DISTINCT 
	#tmp.receipt_id, 
	#tmp.line_id,
	#tmp.profit_ctr_id,
	#tmp.container_type,
	#tmp.container_id,
	#tmp.load_type,
	#tmp.manifest,
	#tmp.approval_code,
	waste_code,
	SUM(#tmp.containers_on_site),
	#tmp.bill_unit_code,
	#tmp.receipt_date,
	#tmp.location, 
	#tmp.days_on_site,
	#tmp.as_of_date,
	#tmp.tracking_num,
	#tmp.staging_row,
	#tmp.fingerpr_status,
	#tmp.treatment_id,
	#tmp.treatment_desc,
	#tmp.container_size,
	#tmp.container_weight,
	#tmp.tsdf_approval_code,
	#tmp.company_id,
	#tmp.outbound_receipt,
	#tmp.outbound_receipt_date,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	#tmp.tracking_number,
	#tmp.manifest_container
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #tmp.company_id
	AND ProfitCenter.profit_ctr_ID = #tmp.profit_ctr_id
GROUP BY
	#tmp.company_id,
	#tmp.receipt_id, 
	#tmp.line_id,
	#tmp.profit_ctr_id,
	#tmp.container_type,
	#tmp.container_id,
	#tmp.load_type,
	#tmp.manifest,
	#tmp.approval_code,
	waste_code,
	#tmp.bill_unit_code,
	#tmp.receipt_date,
	#tmp.location, 
	#tmp.days_on_site,
	#tmp.as_of_date,
	#tmp.tracking_num,
	#tmp.staging_row,
	#tmp.fingerpr_status,
	#tmp.treatment_id,
	#tmp.treatment_desc,
	#tmp.container_size,
	#tmp.container_weight,
	#tmp.tsdf_approval_code,
	#tmp.outbound_receipt,
	#tmp.outbound_receipt_date,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	#tmp.tracking_number,
	#tmp.manifest_container
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inv_container_disposal] TO [EQAI];
GO


