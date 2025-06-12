DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_inv_container_pcb]
GO

CREATE PROCEDURE [dbo].[sp_rpt_inv_container_pcb]
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
Filename:		L:\Apps\SQL\EQAI\sp_rpt_inv_container_pcb.sql
Loads to:		Plt_AI
PB Object(s):	r_inv_container_staging_pcb				

11/04/2019 MPM DevOps 12600 - Created - copied from sp_rpt_inv_container
04/10/2022 GDE DevOps 29879 - Report Center - Add column for Container Type to Inventory Reports
05/09/2023 MPM DevOps 41793 - Added input parameters for Treatment ID List, Waste Type Category 
			   List, Waste Type List, Treatment Process List, and Disposal Service List.
09/13/2204 Prakash Rally # US116925 - Added weight column.

sp_rpt_inv_container_pcb 3, 0, 1, 999999, 'ALL', 'ALL', '1288', 'ALL', 'ALL', 'ALL', 'ALL'	
	
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@as_of_date 	datetime
,	@debug 			int

DECLARE @tmp TABLE 
	(receipt_id						INT				NULL 
		, line_id					INT				NULL
		, profit_ctr_id				INT				NULL
		, container_type			CHAR(1)			NULL
		, container_id				INT				NULL
		, load_type					VARCHAR(5)		NULL
		, manifest					VARCHAR(15)		NULL
		, manifest_page_num			INT				NULL
		, manifest_line				INT				NULL
		, manifest_qty_in_gallons	DECIMAL(18, 4)	NULL
		, approval_code				VARCHAR(50)		NULL
		, waste_code				VARCHAR(10)		NULL
		, bill_unit_code			VARCHAR(4)		NULL
		, receipt_date				DATETIME		NULL
		, location					VARCHAR(15)		NULL 
		, days_on_site				INT				NULL
		, staging_row				VARCHAR(5)		NULL
		, fingerpr_status			CHAR(1)			NULL
		, treatment_id				INT				NULL
		, treatment_desc			VARCHAR(32)		NULL
		, container_size			VARCHAR(15)		NULL
		, container_weight			DECIMAL(18, 4)	NULL
		, tsdf_approval_code		VARCHAR(40)		NULL
		, company_id				INT				NULL
		, outbound_receipt			VARCHAR(15)		NULL
		, outbound_receipt_date		DATETIME		NULL
		, generator_id				INT				NULL
		, truck_code				VARCHAR(10)		NULL
		, tracking_number			VARCHAR(15)		NULL
		, manifest_container		VARCHAR(15)		NULL
	)

-- Debugging?
SELECT @debug = 0

-- Set the date
SELECT @as_of_date = GETDATE()
IF @debug = 1 PRINT 'AS of date: ' + CONVERT(varchar(30), @as_of_date)

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

-- These are the Outbound Receipts that are open, not Accepted
SELECT	dbo.fn_container_receipt(Receipt.receipt_id, Receipt.line_id) AS outbound_receipt,
	Receipt.receipt_date
INTO #outbounds
FROM Receipt
WHERE Receipt.trans_mode = 'O'
	AND Receipt.receipt_status = 'N'
	AND (@company_ID= 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND (@company_ID= 0 OR Receipt.company_id = @company_ID)
	
-- 1A -- Get Incomplete PCB Receipt/ContainerDestination records
--	ContainerDestination.status = 'N'
INSERT @tmp
SELECT --DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	convert(varchar(5),'DISP') AS load_type,
	Receipt.manifest,
	Receipt.manifest_page_num,
	Receipt.manifest_line,
	IsNull(Receipt.manifest_quantity, 0.0) * IsNull(bu.gal_conv, 0.0) AS manifest_qty_in_gallons,
	CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	w.display_name as waste_code,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	ISNULL(Container.staging_row, '') AS staging_row,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.treatment_desc,
	Container.container_size,
	dbo.fn_receipt_weight_container(ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.profit_ctr_id, ContainerDestination.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id) as container_weight,--Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	convert(varchar(15),NULL) AS outbound_receipt,
	convert(datetime,NULL) AS outbound_receipt_date,
	Receipt.generator_id,
	Receipt.truck_code,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container
FROM Receipt (NOLOCK)
JOIN BillUnit bu (NOLOCK)
	ON bu.manifest_unit = Receipt.manifest_unit
LEFT OUTER JOIN wastecode w on w.waste_code_uid = receipt.waste_code_uid
INNER JOIN Container (NOLOCK)
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination (NOLOCK)
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
	AND (@location_in = 'ALL' OR ISNULL(ContainerDestination.Location, '') = @location_in)
LEFT OUTER JOIN ProfileLab pl (NOLOCK)
	ON pl.profile_id = Receipt.profile_id
	AND pl.type = 'A'
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('L', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V','R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'N'
	AND (pl.pcb_concentration_50_499 = 'T' OR pl.pcb_concentration_500 = 'T' OR pl.pcb_source_concentration_gr_50 = 'T'
		OR EXISTS (SELECT 1
					FROM ReceiptWasteCode rwc
					JOIN WasteCode wc
						ON wc.waste_code_uid = rwc.waste_code_uid
					WHERE rwc.company_id = Receipt.company_id
					AND rwc.profit_ctr_id = Receipt.profit_ctr_id
					AND rwc.receipt_id = Receipt.receipt_id
					AND rwc.line_id = Receipt.line_id
					AND wc.pcb_flag = 'T')
		)

UNION ALL

-- 1B -- Get Incomplete Receipt/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT --DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	convert(varchar(5),'DISP') AS load_type,
	Receipt.manifest,
	Receipt.manifest_page_num,
	Receipt.manifest_line,
	IsNull(Receipt.manifest_quantity, 0.0) * IsNull(bu.gal_conv, 0.0) AS manifest_qty_in_gallons,
	CONVERT(varchar(50), Receipt.approval_code) AS approval_code,
	w.display_name as waste_code,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	ISNULL(Container.staging_row, '') AS staging_row,
	Receipt.fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.treatment_desc,
	Container.container_size,
	dbo.fn_receipt_weight_container(ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.profit_ctr_id, ContainerDestination.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id) as container_weight, --Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date,
	Receipt.generator_id,
	Receipt.truck_code,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container
FROM Receipt (NOLOCK)
JOIN BillUnit bu (NOLOCK)
	ON bu.manifest_unit = Receipt.manifest_unit
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = Receipt.waste_code_uid
INNER JOIN Container (NOLOCK)
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination (NOLOCK)
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
	AND (@location_in = 'ALL' OR ISNULL(ContainerDestination.Location, '') = @location_in)
INNER JOIN #outbounds 
	ON #outbounds.outbound_receipt = ContainerDestination.tracking_num
LEFT OUTER JOIN ProfileLab pl (NOLOCK)
	ON pl.profile_id = Receipt.profile_id
	AND pl.type = 'A'
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('L', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status NOT IN ('V', 'R')
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N', 'C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'C' 
	AND (pl.pcb_concentration_50_499 = 'T' OR pl.pcb_concentration_500 = 'T' OR pl.pcb_source_concentration_gr_50 = 'T'
		OR EXISTS (SELECT 1
					FROM ReceiptWasteCode rwc
					JOIN WasteCode wc
						ON wc.waste_code_uid = rwc.waste_code_uid
					WHERE rwc.company_id = Receipt.company_id
					AND rwc.profit_ctr_id = Receipt.profit_ctr_id
					AND rwc.receipt_id = Receipt.receipt_id
					AND rwc.line_id = Receipt.line_id
					AND wc.pcb_flag = 'T')
		)

UNION ALL

-- 2A -- Get Incomplete Receipt Transfer/ContainerDestination records 
--	ContainerDestination.status = 'N'
SELECT --DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	convert(varchar(5),'TFER') AS load_type,
	Receipt.manifest,
	Receipt.manifest_page_num,
	Receipt.manifest_line,
	IsNull(Receipt.manifest_quantity, 0.0) * IsNull(bu.gal_conv, 0.0) AS manifest_qty_in_gallons,
	ContainerDestination.tsdf_approval_code,
	convert(varchar(10),NULL) AS waste_code,
	ContainerDestination.TSDF_approval_bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	ISNULL(Container.staging_row, '') AS staging_row,
	'A' AS fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.treatment_desc,
	Container.container_size,
	dbo.fn_receipt_weight_container(ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.profit_ctr_id, ContainerDestination.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id) as container_weight, --Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	convert(varchar(15),NULL) AS outbound_receipt,
	convert(datetime,NULL) AS outbound_receipt_date,
	Receipt.generator_id,
	Receipt.truck_code,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container
FROM Receipt (NOLOCK)
JOIN BillUnit bu (NOLOCK)
	ON bu.manifest_unit = Receipt.manifest_unit
INNER JOIN Container (NOLOCK)
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination (NOLOCK)
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id =Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
	AND (@location_in = 'ALL' OR ISNULL(ContainerDestination.Location, '') = @location_in)
LEFT OUTER JOIN ProfileLab pl (NOLOCK)
	ON pl.profile_id = Receipt.profile_id
	AND pl.type = 'A'
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('N', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status IS NULL
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'N'
	AND (pl.pcb_concentration_50_499 = 'T' OR pl.pcb_concentration_500 = 'T' OR pl.pcb_source_concentration_gr_50 = 'T'
		OR EXISTS (SELECT 1
					FROM ReceiptWasteCode rwc
					JOIN WasteCode wc
						ON wc.waste_code_uid = rwc.waste_code_uid
					WHERE rwc.company_id = Receipt.company_id
					AND rwc.profit_ctr_id = Receipt.profit_ctr_id
					AND rwc.receipt_id = Receipt.receipt_id
					AND rwc.line_id = Receipt.line_id
					AND wc.pcb_flag = 'T')
		)

UNION ALL

-- 2B -- Get Incomplete Receipt Transfer/ContainerDestination records
--	ContainerDestination.status = 'C' but outbound not accepted
SELECT --DISTINCT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	convert(varchar(5),'TFER') AS load_type,
	Receipt.manifest,
	Receipt.manifest_page_num,
	Receipt.manifest_line,
	IsNull(Receipt.manifest_quantity, 0.0) * IsNull(bu.gal_conv, 0.0) AS manifest_qty_in_gallons,
	ContainerDestination.tsdf_approval_code,
	convert(varchar(10),NULL) AS waste_code,
	ContainerDestination.TSDF_approval_bill_unit_code,
	Receipt.receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	ISNULL(Container.staging_row, '') AS staging_row,
	'A' AS fingerpr_status,
	COALESCE(ContainerDestination.treatment_id, Receipt.treatment_id) AS treatment_id,
	t.treatment_desc,
	Container.container_size,
	dbo.fn_receipt_weight_container(ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.profit_ctr_id, ContainerDestination.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id) as container_weight, --Container.container_weight,
	ISNULL(ContainerDestination.tsdf_approval_code, '') AS tsdf_approval_code,
	Receipt.company_id,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date,
	Receipt.generator_id,
	Receipt.truck_code,
	ContainerDestination.tracking_num as tracking_number,
	Container.manifest_container
FROM Receipt (NOLOCK)
JOIN BillUnit bu (NOLOCK)
	ON bu.manifest_unit = Receipt.manifest_unit
INNER JOIN Container (NOLOCK)
       ON Container.company_id = Receipt.company_id
       AND Container.profit_ctr_id = Receipt.profit_ctr_id
       AND Container.receipt_id = Receipt.receipt_id
       AND Container.line_id = Receipt.line_id
       AND Container.container_id is not null
INNER JOIN ContainerDestination (NOLOCK)
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id =Container.profit_ctr_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
	AND (@location_in = 'ALL' OR ISNULL(ContainerDestination.Location, '') = @location_in)
INNER JOIN #outbounds 
	ON #outbounds.outbound_receipt = ContainerDestination.tracking_num
LEFT OUTER JOIN ProfileLab pl (NOLOCK)
	ON pl.profile_id = Receipt.profile_id
	AND pl.type = 'A'
LEFT OUTER JOIN Treatment t WITH (NOLOCK)
	ON t.treatment_id = ContainerDestination.treatment_id
	AND t.company_id = ContainerDestination.company_id
	AND t.profit_ctr_id = ContainerDestination.profit_ctr_id
WHERE Receipt.receipt_status IN ('N', 'U', 'A')
	AND ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.trans_type = 'X'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status IS NULL
	AND Receipt.receipt_date > '7-31-99'
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND (@treatment_id_list = 'ALL' OR ISNULL(t.treatment_id, -1) IN (SELECT treatment_id FROM #tmp_treatment_id))
	AND (@waste_type_category_list = 'ALL' OR ISNULL(t.wastetype_category, '') IN (SELECT waste_type_category FROM #tmp_waste_type_category))
	AND (@waste_type_list = 'ALL' OR ISNULL(t.wastetype_id, -1) IN (SELECT waste_type_id FROM #tmp_waste_type_id))
	AND (@treatment_process_list = 'ALL' OR ISNULL(t.treatment_process_id, -1) IN (SELECT treatment_process_id FROM #tmp_treatment_process_id))
	AND (@disposal_service_list = 'ALL' OR ISNULL(t.disposal_service_id, -1) IN (SELECT disposal_service_id FROM #tmp_disposal_service_id))
	AND ContainerDestination.status = 'C' 
	AND (pl.pcb_concentration_50_499 = 'T' OR pl.pcb_concentration_500 = 'T' OR pl.pcb_source_concentration_gr_50 = 'T'
		OR EXISTS (SELECT 1
					FROM ReceiptWasteCode rwc
					JOIN WasteCode wc
						ON wc.waste_code_uid = rwc.waste_code_uid
					WHERE rwc.company_id = Receipt.company_id
					AND rwc.profit_ctr_id = Receipt.profit_ctr_id
					AND rwc.receipt_id = Receipt.receipt_id
					AND rwc.line_id = Receipt.line_id
					AND wc.pcb_flag = 'T')
		)
		
-- Return Results
SELECT --DISTINCT 
	t.receipt_id, 
	t.line_id,
	t.profit_ctr_id,
	t.container_type,
	t.container_id,
	t.load_type,
	t.manifest,
	t.manifest_page_num,
	t.manifest_line,
	t.approval_code,
	t.waste_code,
	COUNT(DISTINCT t.container_id) AS containers_on_site,
	t.bill_unit_code,
	t.receipt_date,
	t.location, 
	t.days_on_site,
	@as_of_date AS as_of_date,
	t.staging_row,
	t.fingerpr_status,
	t.treatment_id,
	t.treatment_desc,
	t.container_size,
	t.container_weight,
	t.tsdf_approval_code,
	t.company_id,
	t.outbound_receipt,
	t.outbound_receipt_date,
	t.generator_id,
	Generator.generator_name,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	t.truck_code,
    t.tracking_number,
	t.manifest_qty_in_gallons,
	ProfitCenter.PCB_restricted_volume,
	ProfitCenter.PCB_restricted_volume_UOM,
	rp.storage_start_date as date_of_removal_for_disposal,
	DATEADD(month, 9, rp.storage_start_date) as removal_plus_9_mos,
	t.manifest_container,
	rp.weight
FROM @tmp t
JOIN Company (NOLOCK)
	ON Company.company_id = t.company_id
JOIN ProfitCenter (NOLOCK)
	ON ProfitCenter.company_ID = t.company_id
	AND ProfitCenter.profit_ctr_ID = t.profit_ctr_id
LEFT OUTER JOIN Generator (NOLOCK)
	ON Generator.generator_id = t.generator_id
LEFT OUTER JOIN ReceiptPCB rp (NOLOCK)
	ON rp.company_id = t.company_id
	AND rp.profit_ctr_id = t.profit_ctr_id
	AND rp.receipt_id = t.receipt_id
	AND rp.line_id = t.line_id
	AND rp.sequence_id = t.container_id
GROUP BY
	t.company_id,
	t.receipt_id, 
	t.line_id,
	t.profit_ctr_id,
	t.container_type,
	t.container_id,
	t.load_type,
	t.manifest,
	t.manifest_page_num,
	t.manifest_line,
	t.approval_code,
	t.waste_code,
	t.bill_unit_code,
	t.receipt_date,
	t.location, 
	t.days_on_site,
	t.staging_row,
	t.fingerpr_status,
	t.treatment_id,
	t.treatment_desc,
	t.container_size,
	t.container_weight,
	t.tsdf_approval_code,
	t.outbound_receipt,
	t.outbound_receipt_date,
	t.generator_id,
	Generator.generator_name,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	t.truck_code,
	t.tracking_number,
	t.manifest_qty_in_gallons,
	ProfitCenter.PCB_restricted_volume,
	ProfitCenter.PCB_restricted_volume_UOM,
	rp.storage_start_date,
	t.manifest_container,
	rp.weight
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inv_container_pcb] TO [CRM_SERVICE];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inv_container_pcb] TO [EQAI];
GO