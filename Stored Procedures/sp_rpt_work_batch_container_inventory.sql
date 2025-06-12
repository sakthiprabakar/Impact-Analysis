CREATE PROCEDURE sp_rpt_work_batch_container_inventory
	@company_id		tinyint,
	@profit_ctr_id	int,
	@location_in	varchar(15),
	@tracking_num	varchar(5),
	@user_id		varchar(8),
	@debug			int
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_rpt_work_batch_container_inventory.sql
Loads to:		Plt_XX_AI
PB Object(s):	w_report_master_batch
SQL Object(s):	None

03/16/2009 KAM	Created
03/25/2010 JDB	Added @company_id as input parameter.
11/30/2010 SK	Added joins to @company_id, moved to Plt_AI
04/17/2013 RB   Added waste_code_uid to waste code related tables

SELECT * FROM work_Container where user_id = 'KEITH_MI'
SELECT * FROM work_ContainerOverflow where user_id = 'KEITH_MI'
SELECT * FROM work_ContainerWasteCode where user_id = 'KEITH_MI'
SELECT * FROM work_ContainerConstituent where user_id = 'KEITH_MI'

sp_rpt_work_batch_container_inventory 21, 0,'01/01/2009', '03/31/2009', 'HAZBOX','2', 'KEITH_MI', 1
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @as_of_date 		datetime,
	@container 				varchar(15),
	@base_container_count 	int,
	@container_type 		char(1),
	@insert_results 		char(1),
	@receipt_id 			int,
	@container_id 			int,
	@line_id 				int,
	@sequence_id 			int,
	@report_source			varchar(10)

SET NOCOUNT ON
IF @debug = 1 SET NOCOUNT OFF

-- Initialize
SET @report_source = 'INVENTORY'
SELECT @as_of_date = GETDATE()
IF @debug = 1 PRINT 'As of date: ' + CONVERT(varchar(30), @as_of_date)

DELETE FROM work_Container where user_id = @user_id
DELETE FROM work_ContainerOverflow where user_id = @user_id
DELETE FROM work_ContainerWasteCode where user_id = @user_id
DELETE FROM work_ContainerConstituent where user_id = @user_id

-- These are the Outbound Receipts that are open, not Accepted
SELECT dbo.fn_container_receipt(Receipt.receipt_id, Receipt.line_id) as outbound_receipt,
	Receipt.receipt_date
INTO #outbounds
FROM Receipt
WHERE Receipt.trans_mode = 'O'
AND Receipt.receipt_status IN ('N')
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id

-- Get Not complete Receipt containers
SELECT DISTINCT 
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.company_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	Receipt.manifest,
	Receipt.approval_code,
	Receipt.waste_code,
	1 AS containers_on_site,
	Receipt.bill_unit_code,
	Receipt.receipt_date,
	IsNull(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site,
	@as_of_date as as_of_date,
	IsNull(ContainerDestination.tracking_num,'') as tracking_num,
	IsNull(Container.staging_row, '') as staging_row,
	Receipt.fingerpr_status,
	ContainerDestination.treatment_id,
	Container.container_size,
	Container.container_weight,
	ContainerDestination.waste_flag,
	ContainerDestination.const_flag,
	CONVERT(varchar(2000),'') AS group_waste,
	CONVERT(varchar(2000),'') AS group_const,
	CONVERT(varchar(2000),'') AS group_container,
	0 AS base_container,
	ContainerDestination.tsdf_approval_code,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date as outbound_receipt_date,
	Receipt.waste_code_uid
INTO #tmp
FROM Receipt
JOIN Container 
	ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
	AND Container.status IN ('N','C')
	AND Container.container_type = 'R'
JOIN ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
WHERE Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND Receipt.fingerpr_status <> 'V'
AND Receipt.receipt_date > '7-31-99'
AND (@location_in = 'ALL' OR IsNull(ContainerDestination.location, '') = @location_in)
AND (@tracking_num = 'ALL' or IsNull(ContainerDestination.tracking_num, '') = @tracking_num)
AND ContainerDestination.status in ('N','C')

UNION ALL

-- Include Incomplete Stock Containers
SELECT DISTINCT 
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.company_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	'' AS manifest,
	'' AS approval_code,
	'' AS waste_code,
	1 AS containers_on_site,
	'' AS bill_unit_code,
	ContainerDestination.date_added AS receipt_date,
	IsNull(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, ContainerDestination.date_added, @as_of_date) AS days_on_site,
	@as_of_date AS AS_OF_DATE,
	IsNull(ContainerDestination.tracking_num, '') as tracking_num,
	IsNull(Container.staging_row, '') as staging_row,
	'' as fingerpr_status,
	ContainerDestination.treatment_id,
	Container.container_size,
	Container.container_weight,
	'F' as waste_flag,
	'F' as const_flag,
	CONVERT(varchar(2000),'') AS group_waste,
	CONVERT(varchar(2000),'') AS group_const,
	CONVERT(varchar(2000),'') AS group_container,
	1 as base_container,
	ContainerDestination.tsdf_approval_code,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date as outbound_receipt_date,
	convert(int,null) as waste_code_uid
FROM Container
JOIN ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
WHERE Container.container_type = 'S'
AND Container.status IN ('N','C')
AND Container.profit_ctr_id = @profit_ctr_id
AND Container.company_id = @company_id
AND (@location_in = 'ALL' OR ISNULL(ContainerDestination.location, '') = @location_in)
AND (@tracking_num = 'ALL' OR ISNULL(ContainerDestination.tracking_num, '') = @tracking_num)
AND ContainerDestination.status IN ('N','C')

-- Create tables to be populated by by sp_rpt_work_batch_report
CREATE TABLE #tmp_waste (
	receipt_id		int NULL,
	line_id			int NULL,
	container_type	char(1) NULL,
	container_id	int NULL,
	sequence_id		int NULL,
	treatment_id	int NULL,
	waste_code		varchar(4) NULL,
	process_flag	int NULL,
	waste_code_uid		int NULL
)
CREATE CLUSTERED INDEX tmp_waste_1 ON #tmp_waste
	(receipt_id		ASC, 
	line_id			ASC, 
	container_type	ASC, 
	container_id	ASC, 
	sequence_id		ASC, 
	waste_code_uid		ASC		)
	
	
CREATE TABLE #tmp_const (
	receipt_id		int NULL,
	line_id			int NULL,
	container_type	char(1) NULL,
	container_id	int NULL,
	sequence_id		int NULL,
	treatment_id	int NULL,
	const_id		int NULL,
	UHC				char(1) NULL,
	process_flag	int NULL
)
CREATE CLUSTERED INDEX tmp_const_1 ON #tmp_const
	(receipt_id		ASC, 
	line_id			ASC, 
	container_type	ASC, 
	container_id	ASC, 
	sequence_id		ASC, 
	const_id		ASC, 
	UHC				ASC		)

-- Call the SP that does all the waste code and constituent collection and grouping
EXEC sp_rpt_work_batch_report @report_source, @company_id, @profit_ctr_id, @user_id, @debug

-- Populate work table
INSERT work_Container (
	company_id,
	profit_ctr_id,
	container_type,
	container,
	receipt_id,
	line_id, 
	container_id,
	sequence_id,
	manifest,
	approval_code,
	waste_code,
	containers_on_site,
	bill_unit_code,
	receipt_date,
	location,
	days_on_site,
	as_of_date,
	tracking_num,
	staging_row,
	fingerpr_status,
	treatment_id,
	treatment_desc,
	container_size,
	container_weight,
	group_report,
	group_container,
	user_id,
	tsdf_approval_code,
	outbound_receipt,
	outbound_receipt_date )
SELECT DISTINCT 
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.container_type,
	#tmp.container,
	#tmp.receipt_id, 
	#tmp.line_id,
	#tmp.container_id,
	#tmp.sequence_id,
	#tmp.manifest,
	#tmp.approval_code,
	#tmp.waste_code,
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
	Treatment.treatment_desc,
	#tmp.container_size,
	#tmp.container_weight,
	substring(#tmp.container + '-' + IsNull(#tmp.group_waste,'') + '-' + IsNull(#tmp.group_const,''),1,2000),
	#tmp.group_container,
	@user_id,
	#tmp.tsdf_approval_code,
	#tmp.outbound_receipt,
	#tmp.outbound_receipt_date
FROM #tmp
LEFT OUTER JOIN Treatment 
	ON #tmp.treatment_id = Treatment.treatment_id
	AND #tmp.profit_ctr_id = Treatment.profit_ctr_id
	AND #tmp.company_id = Treatment.company_id
GROUP BY
#tmp.group_waste,
#tmp.group_const,
#tmp.group_container,
#tmp.container,
#tmp.receipt_id, 
#tmp.line_id,
#tmp.company_id,
#tmp.profit_ctr_id,
#tmp.container_type,
#tmp.container_id,
#tmp.sequence_id,
#tmp.manifest,
#tmp.approval_code,
#tmp.waste_code,
#tmp.bill_unit_code,
#tmp.receipt_date,
#tmp.location, 
#tmp.days_on_site,
#tmp.as_of_date,
#tmp.tracking_num,
#tmp.staging_row,
#tmp.fingerpr_status,
#tmp.treatment_id,
Treatment.treatment_desc,
#tmp.container_size,
#tmp.container_weight,
#tmp.tsdf_approval_code,
#tmp.outbound_receipt,
#tmp.outbound_receipt_date

-- Populate the waste code work table
INSERT work_ContainerWasteCode (
	receipt_id,
	line_id,
	company_id,
	profit_ctr_id,
	container_type,
	container_id, 
	sequence_id,
	waste_code,
	user_id,
	waste_code_uid )
SELECT DISTINCT
	#tmp_waste.receipt_id,
	#tmp_waste.line_id,
	@company_id,
	@profit_ctr_id,
	#tmp_waste.container_type, 
	#tmp_waste.container_id,
	#tmp_waste.sequence_id,
	waste_code,
	@user_id,
	#tmp_waste.waste_code_uid
FROM #tmp_waste
WHERE #tmp_waste.waste_code_uid IS NOT NULL

-- Populate the constituents work table
INSERT work_ContainerConstituent (
	receipt_id,
	line_id,
	company_id,
	profit_ctr_id,
	container_type,
	container_id, 
	sequence_id,
	const_id,
	UHC,
	const_desc,
	LDR_ID,
	user_id )
SELECT DISTINCT
	receipt_id,
	line_id,
	@company_id,
	@profit_ctr_id,
	container_type,
	container_id, 
	#tmp_const.sequence_id,
	#tmp_const.const_id,
	#tmp_const.UHC,
	Constituents.const_desc,
	Constituents.LDR_ID,
	@user_id
FROM #tmp_const
INNER JOIN Constituents ON #tmp_const.const_id = Constituents.const_id
WHERE #tmp_const.const_id IS NOT NULL

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_work_batch_container_inventory] TO [EQAI]
    AS [dbo];

