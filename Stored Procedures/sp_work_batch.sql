CREATE PROCEDURE sp_work_batch
	@company_id		tinyint,
	@profit_ctr_id	int,
	@date_from		datetime, 
	@date_to		datetime , 
	@location_in	varchar(15), 
	@tracking_num_in varchar(255), 
	@user_id		varchar(10),
	@debug			int
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_work_batch.sql
Loads to:		Plt_XX_AI
PB Object(s):	w_report_master_batch
SQL Object(s):	None

06/18/2004 SCC	Created
09/22/2004 JDB	Convert approval_comments to varchar(1800) since they are now text
		datatype and you cannot select them as distinct.  Why 1800?  Because the
		table already had several varchar(2000) fields, and the table size was
		too big to make it 2000 or larger.
11/11/2004 MK  Changed generator_code to generator_id
12/30/2004 SCC	Changed Ticket references
03/11/2005 SCC	Updated to reference batch tables
03/14/2005 SCC	Modified to use sp_work_report, shared with INVENTORY reports to 
		build sort on waste codes and constituents
03/21/2005 LJT	Modified to sub - select size or one bill unit value for reporting. 
                Use first price_line in receiptprice.  
                Modified to only select completed containers  
                Modified to be able to select closed batches
03/29/2005 MK	Limited size of group_report concatenated data to 2000 to fit into work_container
05/12/2005 MK	Added disposal date range to parameters and included in initial select.
09/27/2005 MK	Added batch_date to #tmp. Removed disposal dates from parameters and from call to sp_work_batch_container
10/12/2005 MK	Added UHC to constituents tables
11/16/2007 RG   changed temp table to match work table ( decimal(10,4) to float)
03/25/2010 JDB	Added @company_id as input parameter.
11/30/2010 SK	Modified to use @company_id, Moved to Plt_AI
04/16/2013 RB   Added waste_code_uid to waste code related tables
10/23/2015 AM   Added manifest_line.
08/05/2016 SK	Increased the input parm @tracking_num_in field length. added more debug stmts
12/13/2017 MPM	Added receipt_id, line_id to work_BatchContainer

SELECT * FROM work_BatchWasteCode where user_id = 'SA'
SELECT * FROM work_BatchConstituent where user_id = 'SA'
DELETE FROM work_BatchWasteCode where user_id = 'SA'
DELETE FROM work_BatchConstituent where user_id = 'SA'

sp_work_batch 21, 0,  '9-1-05','2-28-06', '701', '12546', 'marilyn', 1
sp_work_batch 21, 0, '1-1-2005','10-28-2005', '701', '11956', 'MK', 1
sp_work_batch 21, 0, '04-01-2016','06-01-2016', '701', '21999,22070,22080,22112', 'Smita_K', 1
sp_work_batch 21, 0, '1-1-2015','12-13-2017', '101', '101-17', 'martha_m', 0
sp_work_batch 21, 0, '1-1-2015','12-13-2017', 'ALL', 'ALL', 'martha_m', 0
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@const_id				int,
	@container				varchar(15),
	@container_list			varchar(2000),
	@base_container_count	int,
	@container_type			char(1),
	@insert_results			char(1),
	@process_count			int,
	@receipt_id				int,
	@record_count			int,
	@group_sort				varchar(2000),
	@container_id			int,
	@container_id_prev		int,
	@line_id				int,
	@line_id_prev			int,
	@sequence_id			int,
	@UHC					char(1),
	@waste_code				varchar(4),
	@report_source			varchar(10)

-- Initialize
SET @report_source = 'BATCH'

CREATE TABLE #tmp (
	container 		varchar(15) NULL,
	receipt_id 		int NULL, 
	line_id 		int NULL, 
	container_type 	varchar(1) NULL, 
	container_id 	int NULL, 
	sequence_id 	int NULL, 
	profit_ctr_id 	int NULL,
	company_id		int NULL,
	location 		varchar(15) NULL, 
	tracking_num 	varchar(15) NULL, 
	cycle			int NULL,
	receipt_date 	datetime NULL, 
	disposal_date 	datetime NULL, 
	generator_name 	varchar(40), 
	quantity 		float NULL, 
	bill_unit_code 	varchar(4) NULL,
	gal_conv 		float NULL, 
	manifest 		varchar(15) NULL, 
	manifest_line_id  varchar(1) NULL,  
	approval_code 	varchar(15) NULL, 
	treatment_id 	int NULL, 
	bulk_flag 		varchar(1) NULL, 
	benzene 		float NULL, 
	generic_flag 	varchar(1) NULL,
	approval_comments varchar(1700) NULL, 
	waste_flag 		varchar(1) NULL, 
	const_flag 		varchar(1) NULL, 
	group_waste 	varchar(2000) NULL, 
	group_const 	varchar(2000) NULL, 
	group_container varchar(2000) NULL, 
	base_container 	varchar(15) NULL, 
	user_id 		varchar(8) NULL,
	batch_date		datetime NULL,
	manifest_line   int NULL 
)

---------------------------------------------
-- Get the batch containers
---------------------------------------------
-- These are receipt containers
EXEC sp_work_batch_container @company_id, @profit_ctr_id, @date_from, @date_to, @location_in, @tracking_num_in, @user_id, @debug


-- Create tables to be populated by sp_work_report
CREATE TABLE #tmp_waste (
	receipt_id		int NULL,
	line_id			int NULL,
	container_type	char(1) NULL,
	container_id	int NULL,
	sequence_id		int NULL,
	waste_code		varchar(4) NULL,
	process_flag	int NULL,
	waste_code_uid  int NULL
)
CREATE CLUSTERED INDEX tmp_waste_1 ON #tmp_waste
	(receipt_id		ASC, 
	line_id			ASC, 
	container_type	ASC, 
	container_id	ASC, 
	sequence_id		ASC, 
--	waste_code		ASC		)
	waste_code_uid	ASC		)
	
	
CREATE TABLE #tmp_const (
	receipt_id		int NULL,
	line_id			int NULL,
	container_type	char(1) NULL,
	container_id	int NULL,
	sequence_id		int NULL,
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
	

-- Process these records for reporting
EXEC sp_work_report @report_source, @company_id, @profit_ctr_id, @user_id, @debug

-- Populate the Overflow table with location and tracking_num
UPDATE work_BatchOverflow SET
	location = #tmp.location,
	tracking_num = #tmp.tracking_num
FROM #tmp
WHERE work_BatchOverflow.profit_ctr_id = #tmp.profit_ctr_id
AND work_BatchOverflow.company_id = #tmp.company_id
AND work_BatchOverflow.receipt_id = #tmp.receipt_id
AND work_BatchOverflow.line_id = #tmp.line_id
AND work_BatchOverflow.container_id = #tmp.container_id
AND work_BatchOverflow.sequence_id = #tmp.sequence_id
AND work_BatchOverflow.container_type = #tmp.container_type

-------------------------------------------------
-- Populate work table
-------------------------------------------------
INSERT work_BatchContainer (
	company_id,
	profit_ctr_id, 
	container, 
	container_type,
	container_id, 
	sequence_id, 
	location, 
	tracking_num, 
	receipt_date, 
	disposal_date,
	generator_name, 
	quantity, 
	bill_unit_code, 
	bill_unit_gal_conv, 
	manifest, 
	manifest_line_id,
	approval_code, 
	treatment_id, 
	treatment_desc, 
	bulk_flag, 
	benzene, 
	generic_flag, 
	approval_comments, 
	group_report, 
	group_container, 
	user_id,
	batch_date,
	manifest_line,
	receipt_id,
	line_id 
	)
SELECT 	
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.container,
	#tmp.container_type,
	#tmp.container_id,
	#tmp.sequence_id,
	#tmp.location,
	#tmp.tracking_num,
	#tmp.receipt_date,
	#tmp.disposal_date,
	#tmp.generator_name,
	#tmp.quantity,
	#tmp.bill_unit_code,
	#tmp.gal_conv,
	#tmp.manifest,
	#tmp.manifest_line_id,
	#tmp.approval_code,
	#tmp.treatment_id,
	Treatment.treatment_desc,
	#tmp.bulk_flag,
	#tmp.benzene,
	#tmp.generic_flag,
	#tmp.approval_comments,
	SUBSTRING(#tmp.container + '-' + ISNULL(#tmp.group_waste,'') + '-' + ISNULL(#tmp.group_const,''), 1, 2000),
	#tmp.group_container,
	@user_id,
	#tmp.batch_date,
	#tmp.manifest_line,
	#tmp.receipt_id,
	#tmp.line_id
FROM #tmp
LEFT OUTER JOIN Treatment ON #tmp.treatment_id = Treatment.treatment_id
	AND #tmp.profit_ctr_id = Treatment.profit_ctr_id
	AND #tmp.company_id = Treatment.company_id

IF @debug = 1 PRINT 'Selecting from #tmp'
IF @debug = 1 SELECT * FROM #tmp


IF @debug = 1 PRINT 'Populated work_BatchContainer'

-------------------------------------------------
-- Populate the waste code work table
-------------------------------------------------
INSERT work_BatchWasteCode (
	company_id,
	profit_ctr_id,
	tracking_num, 
	location, 
	waste_code, 
	container, 
	container_id, 
	sequence_id, 
	container_type,
	user_id,
	waste_code_uid)
SELECT DISTINCT 
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.tracking_num,
	#tmp.location,
	#tmp_waste.waste_code,
	#tmp.container,
	#tmp.container_id,
	#tmp.sequence_id,
	#tmp.container_type,
	@user_id,
	#tmp_waste.waste_code_uid
FROM #tmp
INNER JOIN #tmp_waste 
	ON #tmp.receipt_id = #tmp_waste.receipt_id
	AND #tmp.line_id = #tmp_waste.line_id
	AND #tmp.container_id = #tmp_waste.container_id
	AND #tmp.sequence_id = #tmp_waste.sequence_id
	AND #tmp.container_type = #tmp_waste.container_type
WHERE #tmp_waste.waste_code_uid IS NOT NULL

-------------------------------------------------
-- Populate the constituents work table
-------------------------------------------------
INSERT work_BatchConstituent (
	company_id,
	profit_ctr_id,
	tracking_num, 
	location, 
	const_id, 
	const_desc, 
	LDR_ID, 	
	container, 
	container_id, 
	sequence_id, 
	container_type,
	user_id,
	UHC)
SELECT DISTINCT
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.tracking_num,
	#tmp.location,
	#tmp_const.const_id,
	Constituents.const_desc, 
	Constituents.LDR_ID,
	#tmp.container,
	#tmp.container_id,
	#tmp.sequence_id,
	#tmp.container_type,
	@user_id,
	#tmp_const.UHC
FROM #tmp
INNER JOIN #tmp_const 
	ON #tmp.receipt_id = #tmp_const.receipt_id
	AND #tmp.line_id = #tmp_const.line_id
	AND #tmp.container_type = #tmp_const.container_type
	AND #tmp.container_id = #tmp_const.container_id
INNER JOIN Constituents 
	ON #tmp_const.const_id = Constituents.const_id
WHERE #tmp_const.const_id IS NOT NULL

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_work_batch] TO [EQAI]
    AS [dbo];

