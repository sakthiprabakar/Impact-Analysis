CREATE PROCEDURE sp_work_container_inventory
	@company_id			tinyint,
	@profit_ctr_id		int,
	@customer_id_from	int,
	@customer_id_to		int,
	@location_in		varchar(15),
	@staging_rows		varchar(max),
	@user_id			varchar(8),
	@debug				int
WITH RECOMPILE
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_work_container_inventory.sql

Loads to:		Plt_AI
PB Object(s):	w_report_child_1
				w_report_master_container, w_report_master_stock_container
SQL Object(s):	None

09/XX/2002 SCC	Created
12/11/2002 JDB	Modified to get the receipt.location if the Container.location is NULL
03/08/2004 SCC	Added lab status
03/11/2004 SCC	Added treatment and container size
05/05/2004 MK	Select actual container_id in first select and added container weight for all
06/03/2004 SCC	Added Container.status = 'N' to omit reporting on completely consolidated containers
06/15/2004 SCC	Retrieves into work tables
10/28/2004 JDB	Updated @container_list calc to store ranges as 1-4 instead of 1, 2, 3, 4.
				It was taking up way too much space.  We then had to create another table
				work_container_inventory_container_2 to store the containers separately because
				they wanted to see each container number individually.
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
01/05/2005 SCC	Modified for Container Tracking
03/14/2005 SCC	Modified to use sp_work_report, shared with Batch reports
03/24/2005 LJT  Added receipt.fingerprint <> 'v'
03/29/2005 MK	Limited size of group_report concatenated data to 2000 to fit into work_container
08/29/2005 MK	Added tsdf_approval_code to work_container select
12/21/2006 SCC  Changed to include containers assigned but not yet shipped
06/09/2009 KAM  Update the status of a stock container calculation to distinguish between empty and accepted.
07/21/2009 JDB	Added new index on ContainerDestination.base_container_id to speed up the calculation
				of a stock container's fingerprint status (the change made on 6/9/09 above).
				Added join on company_id between ContainerDestination and Container tables.  This
				is not necessary right now because this report runs on Plt_XX_AI, but will be needed when
				we move it to Plt_AI. 
03/25/2010 JDB	Added @company_id as input parameter.
12/01/2010 SK	Modified to run on Plt_AI, Moved to Plt_AI
04/17/2013 RB   Added waste_code_uid to waste code related tables
02/28/2017 MPM	Replaced the staging row input parameter with a staging row list input parameter.
01/19/2018 AM   Added WITH RECOMPILE to sp to run report faster.

sp_work_container_inventory 14, 12, 1, 99999, 'STABLEX',  'BAY4', 'SMITA_K', 1
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if @staging_rows is null
	set @staging_rows = 'ALL'
	
CREATE TABLE #tmp_staging_rows (staging_row	varchar(5) NULL)

if datalength((@staging_rows)) > 0 and @staging_rows <> 'ALL'
	EXEC sp_list 0, @staging_rows, 'STRING', '#tmp_staging_rows'

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

-- These are the Outbound Receipts that are open, not Accepted
SELECT dbo.fn_container_receipt(Receipt.receipt_id, Receipt.line_id) AS outbound_receipt,
	Receipt.receipt_date
INTO #outbounds
FROM Receipt
WHERE Receipt.trans_mode = 'O'
AND Receipt.receipt_status IN ('N')
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id

-- Get Incomplete Receipt containers
SELECT DISTINCT 
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.company_id,
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
	AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))
JOIN ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
	AND (@location_in = 'ALL' OR IsNull(ContainerDestination.location, '') = @location_in)
	AND (ContainerDestination.status = 'N' OR 
		(ContainerDestination.status = 'C' AND ContainerDestination.tracking_num IN 
												(SELECT outbound_receipt FROM #outbounds)))
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
WHERE Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND Receipt.fingerpr_status <> 'V'
AND Receipt.receipt_date > '7-31-99'

UNION ALL

-- Include Incomplete Stock Containers
SELECT DISTINCT 
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container,
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id,
	ContainerDestination.profit_ctr_id,
	ContainerDestination.company_id,
	ContainerDestination.container_type,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	'' AS manifest,
	'' AS approval_code,
	'' AS waste_code,
	1 AS containers_on_site,
	'' AS bill_unit_code,
	ContainerDestination.date_added AS receipt_date,
	ISNULL(ContainerDestination.Location, '') AS location, 
	DATEDIFF(dd, ContainerDestination.date_added, @as_of_date) AS days_on_site,
	@as_of_date AS AS_OF_DATE,
	ISNULL(ContainerDestination.tracking_num, '') AS tracking_num,
	ISNULL(Container.staging_row, '') AS staging_row,
	CASE (SELECT COUNT(*) 
			FROM ContainerDestination 
			WHERE ContainerDestination.base_container_id = Container.container_id)
		WHEN 0 THEN ''
		ELSE 
		CASE (SELECT COUNT(*) 
				FROM receipt 
				JOIN containerDestination ON receipt.receipt_id = containerDestination.receipt_id 
					AND	receipt.line_id = containerDestination.line_id 
				WHERE containerDestination.base_container_id = container.container_id 
				AND fingerpr_status NOT IN ('A','V'))
			WHEN 0 THEN 'A'
			ELSE ''
		END
	END	AS fingerpr_status,
	ContainerDestination.treatment_id,
	Container.container_size,
	Container.container_weight,
	'F' AS waste_flag,
	'F' AS const_flag,
	CONVERT(varchar(2000),'') AS group_waste,
	CONVERT(varchar(2000),'') AS group_const,
	CONVERT(varchar(2000),'') AS group_container,
	1 AS base_container,
	ContainerDestination.tsdf_approval_code,
	#outbounds.outbound_receipt,
	#outbounds.receipt_date AS outbound_receipt_date,
	convert(int,null) as waste_code_uid
FROM Container
JOIN ContainerDestination 
	ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.container_type = ContainerDestination.container_type
	AND (@location_in = 'ALL' OR IsNull(ContainerDestination.location, '') = @location_in)
	AND (ContainerDestination.status = 'N' OR 
		(ContainerDestination.status = 'C' AND ContainerDestination.tracking_num IN 
												(SELECT outbound_receipt FROM #outbounds)))
LEFT OUTER JOIN #outbounds 
	ON ContainerDestination.tracking_num = #outbounds.outbound_receipt
WHERE Container.container_type = 'S'
AND Container.status IN ('N','C')
AND Container.profit_ctr_id = @profit_ctr_id
AND Container.company_id = @company_id 
AND (@staging_rows = 'ALL' OR ISNULL(Container.staging_row, '') in (select staging_row from #tmp_staging_rows))

-- Create tables to be populated by sp_work_report
CREATE TABLE #tmp_waste (
	receipt_id		int			NULL,
	line_id			int			NULL,
	container_type	char(1)		NULL,
	container_id	int			NULL,
	sequence_id		int			NULL,
	waste_code		varchar(4)	NULL,
	process_flag	int			NULL,
	waste_code_uid		int		NULL
)
CREATE CLUSTERED INDEX tmp_waste_1 ON #tmp_waste
	(receipt_id		ASC, 
	line_id			ASC, 
	container_type	ASC, 
	container_id	ASC, 
	sequence_id		ASC, 
	waste_code_uid		ASC		)


CREATE TABLE #tmp_const (
	receipt_id		int			NULL,
	line_id			int			NULL,
	container_type	char(1)		NULL,
	container_id	int			NULL,
	sequence_id		int			NULL,
	const_id		int			NULL,
	UHC				char(1)		NULL,
	process_flag	int			NULL
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
EXEC sp_work_report @report_source, @company_id, @profit_ctr_id, @user_id, @debug

-- Populate work table
INSERT work_Container (
	receipt_id,
	line_id, 
	company_id,
	profit_ctr_id,
	container_type,
	container,
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
SELECT DISTINCT #tmp.receipt_id, 
	#tmp.line_id,
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.container_type,
	#tmp.container,
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
	SUBSTRING(#tmp.container + '-' + ISNULL(#tmp.group_waste,'') + '-' + ISNULL(#tmp.group_const,''),1,2000),
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
JOIN Constituents ON #tmp_const.const_id = Constituents.const_id
WHERE #tmp_const.const_id IS NOT NULL

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_work_container_inventory] TO [EQAI]
    AS [dbo];

