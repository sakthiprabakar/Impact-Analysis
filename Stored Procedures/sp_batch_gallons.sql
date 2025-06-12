
CREATE PROCEDURE sp_batch_gallons
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location_in		varchar(15)
,	@tracking_num_in	varchar(15)
,	@user_id			varchar(10)
,	@debug				int
,	@cycle_in			int
AS
/***************************************************************************************

sp_batch_gallons 21, 0, '10-1-05','10-5-05', 'ALL', '1180', 'marilyn', 1, 1
sp_batch_gallons 0, '1-1-2006','4-22-2006', 'rainwater', '1', 'SA', 1, 2
sp_batch_gallons 21, 0, '1-1-1980', '6-4-2019', '703', '22956', 'martha_m', 0, 4
sp_batch_gallons 21, 0, '1-1-1980', '6-13-2019', '104', '80482', 'martha_m', 0, 0

03/14/2005 SCC	Created/Started
04/11/2005 SCC	Created/Finished
09/27/2005 MK	Added batch_date to #tmp and removed disposal dates from input args and from call to sp_work_batch_container
10/05/2005 MK	Modified transfer-in select to use BatchEvent.dest_cycle as cycle. On the final select, we were filtering 
		for the current batch cycle = incoming batch cycle instead of its destination cycle and losing all incoming 
		batch events for this or previous cycles that had cycles higher than the current cycle.
04/10/2006 SCC	Added on-site gallons to report
06/15/2010 KAM  Added outbound receipt gallons to this report
11/30/2010 SK	Added company_id as input arg, moved to Plt_AI
10/23/2015 AM   Added manifest_line.
05/29/2019 MPM	DevOps task 11193/10969 - Modified to use fn_calculated_gallons to determine gallons instead of multiplying quantity 
				by gal_conv if the profit center has calculated_gallons_flag = 'T' (Winnie).
06/12/2019 MPM	DevOps task 11207 - Modified to include washout receipts.

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
@cycle varchar(15),
@calculated_gallons_flag	char(1)

-- Create a table to receive the container list
CREATE TABLE #tmp (
	Container 			varchar(15) NULL,
	receipt_id 			int NULL, 
	line_id 			int NULL, 
	container_type 		varchar(1) NULL, 
	container_id 		int NULL, 
	sequence_id 		int NULL, 
	company_id			int NULL,
	profit_ctr_id 		int NULL,
	location 			varchar(15) NULL, 
	tracking_num 		varchar(15) NULL, 
	cycle				int NULL,
	receipt_date 		datetime NULL, 
	disposal_date 		datetime NULL, 
	generator_name 		varchar(40), 
	quantity 			decimal(10,4) NULL, 
	bill_unit_code 		varchar(4) NULL,
	gal_conv 			decimal(10,4) NULL, 
	manifest 			varchar(15) NULL, 
	manifest_line_id 	varchar(1) NULL, 
	approval_code 		varchar(15) NULL, 
	treatment_id 		int NULL, 
	bulk_flag 			varchar(1) NULL, 
	benzene 			float NULL, 
	generic_flag 		varchar(1) NULL,
	approval_comments 	varchar(1700) NULL, 
	waste_flag 			varchar(1) NULL, 
	const_flag 			varchar(1) NULL, 
	group_waste 		varchar(2000) NULL, 
	group_const 		varchar(2000) NULL, 
	group_container 	varchar(2000) NULL, 
	base_container 		varchar(15) NULL, 
	user_id 			varchar(8) NULL,
	batch_date			datetime NULL,
	manifest_line       int null
)

-- Create a table for on-site gallons
CREATE TABLE #tmp_on_site (
	container		varchar(40),
	container_id	int,
	sequence_id		int,
	source			varchar(15),
	gallons			float,
	cycle			int
)

IF @cycle_in = 0 
	SET @cycle = 'ALL' 
ELSE
	SET @cycle = CONVERT(varchar(15), @cycle_in)

IF @date_from IS NULL
	SET @date_from = '1-1-1980'
IF @date_to IS NULL
	SET @date_to = getdate()

SELECT @calculated_gallons_flag = ISNULL(calculated_gallons_flag, 'F')
FROM ProfitCenter
WHERE company_ID = @company_id
AND profit_ctr_ID = @profit_ctr_id

---------------------------------------------
-- Get the gallons
---------------------------------------------
-- These are receipt gallons
EXEC sp_work_batch_container @company_id, @profit_ctr_id, @date_from, @date_to, @location_in, @tracking_num_in, @user_id, @debug

-- These are the On-Site gallons
INSERT INTO #tmp_on_site (container, container_id, sequence_id, source, gallons, cycle)
SELECT	BatchEvent.location + '-' + BatchEvent.tracking_num + '-' + CONVERT(varchar(5), BatchEvent.cycle) AS Container,
	1 as container_id,
	1 as sequence_id,
	Convert(varchar(15),'On-Site') as source,
	IsNull(BatchEvent.quantity,0) * BillUnit.gal_conv AS gallons,
	BatchEvent.dest_cycle as cycle 
FROM BatchEvent, BillUnit
WHERE BatchEvent.unit = BillUnit.bill_unit_code
	AND BatchEvent.event_type = 'W'
	AND (@tracking_num_in = 'ALL' OR BatchEvent.dest_tracking_num = @tracking_num_in)
	AND (@location_in = 'ALL' OR BatchEvent.dest_location = @location_in)
	AND (@cycle_in = 0 OR BatchEvent.dest_cycle <= @cycle_in)
	AND BatchEvent.company_id = @company_id
	AND BatchEvent.profit_ctr_id = @profit_ctr_id

-- DevOps task 11207 - Need to include any washout receipt lines in On-Site gallons
INSERT INTO #tmp_on_site (container, container_id, sequence_id, source, gallons, cycle)
SELECT	Batch.location + '-' + Batch.tracking_num + '-' + CONVERT(varchar(5), Batch.cycle),
	1,
	1,
	Convert(varchar(15),'On-Site'),
	Receipt.quantity,
	Batch.cycle
from Batch
INNER JOIN  ContainerDestination
	ON ContainerDestination.location = Batch.location 
	AND ContainerDestination.tracking_num = Batch.tracking_num 
	AND ContainerDestination.profit_ctr_id = Batch.profit_ctr_id 
	AND ContainerDestination.company_id = Batch.company_id 
INNER JOIN Receipt 
	ON Receipt.receipt_id = ContainerDestination.receipt_id 
	AND Receipt.line_id = ContainerDestination.line_id  
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id  
	AND Receipt.company_id = ContainerDestination.company_id  
WHERE Receipt.receipt_status IN ('N', 'L', 'U', 'A')
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'W'
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.container_type = 'R'
	AND Batch.company_id = @company_id
	AND Batch.profit_ctr_id = @profit_ctr_id
	AND (Batch.location = @location_in OR @location_in = 'ALL')
	AND (Batch.tracking_num = @tracking_num_in OR @tracking_num_in = 'ALL')
	AND (Batch.cycle <= @cycle_in OR @cycle_in = 0)
	
-- These are the transfers IN
SELECT	BatchEvent.location + '-' + BatchEvent.tracking_num + '-' + CONVERT(varchar(5), BatchEvent.cycle) AS Container,
	1 as container_id,
	1 as sequence_id,
	Convert(varchar(15),'Transfer') as source,
	IsNull(BatchEvent.quantity,0) * BillUnit.gal_conv AS gallons,
	BatchEvent.dest_cycle as cycle 
INTO #tmp_transfer_in
FROM BatchEvent, BillUnit
WHERE BatchEvent.unit = BillUnit.bill_unit_code
	AND BatchEvent.event_type = 'T'
	AND (@tracking_num_in = 'ALL' OR BatchEvent.dest_tracking_num = @tracking_num_in)
	AND (@location_in = 'ALL' OR BatchEvent.dest_location = @location_in)
	AND (@cycle_in = 0 OR BatchEvent.dest_cycle <= @cycle_in)
	AND BatchEvent.company_id = @company_id
	AND BatchEvent.profit_ctr_id = @profit_ctr_id

-- These are the transfers OUT
SELECT	BatchEvent.location + '-' + BatchEvent.tracking_num + '-' + CONVERT(varchar(5), BatchEvent.cycle) as Container,
	1 as container_id,
	1 as sequence_id,
	Convert(varchar(15),'Transfer') as source,
	IsNull(BatchEvent.quantity,0) * BillUnit.gal_conv AS gallons,
	BatchEvent.cycle
INTO #tmp_transfer_out
FROM BatchEvent, BillUnit
WHERE BatchEvent.unit = BillUnit.bill_unit_code
	AND BatchEvent.event_type = 'T'
	AND (@tracking_num_in = 'ALL' OR BatchEvent.tracking_num = @tracking_num_in)
	AND (@location_in = 'ALL' OR BatchEvent.location = @location_in)
	AND (@cycle_in = 0 OR BatchEvent.cycle <= @cycle_in)
	AND BatchEvent.company_id = @company_id
	AND BatchEvent.profit_ctr_id = @profit_ctr_id
	
-- select * from #tmp ORDER BY Container
SET @debug = 0
IF @debug = 1 print 'SELECTING FROM #tmp'
IF @debug = 1 SELECT * FROM #tmp WHERE (@cycle = 'ALL' OR #tmp.cycle <= @cycle_in) ORDER BY Container, container_id, sequence_id
IF @debug = 1 print 'SELECTING FROM #tmp_transfer_in'
IF @debug = 1 SELECT * FROM #tmp_transfer_in WHERE (@cycle = 'ALL' OR #tmp_transfer_in.cycle <= @cycle_in) ORDER BY Container, container_id, sequence_id
IF @debug = 1 print 'SELECTING FROM #tmp_transfer_out'
IF @debug = 1 SELECT * FROM #tmp_transfer_out WHERE (@cycle = 'ALL' OR #tmp_transfer_out.cycle <= @cycle_in) ORDER BY Container, container_id, sequence_id

-- MPM - DevOps task 93111/10969 - Modified to use fn_calculated_gallons to determine container gallons instead of multiplying quantity 
-- by gal_conv if the profit center has calculated_gallons_flag = 'T' (Winnie).
IF @calculated_gallons_flag = 'T'
BEGIN
	select @location_in AS location, 
	@tracking_num_in AS tracking_num, 
	@cycle AS cycle,
	on_site_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_on_site WHERE (@cycle = 'ALL' OR #tmp_on_site.cycle <= @cycle_in)), 0), 
	container_gallons = IsNull((SELECT SUM(dbo.fn_calculated_gallons(company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id)) FROM #tmp WHERE (@cycle = 'ALL' OR #tmp.cycle <= @cycle_in) ), 0),
	transfer_in_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_transfer_in WHERE (@cycle = 'ALL' OR #tmp_transfer_in.cycle <= @cycle_in)), 0), 
	transfer_out_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_transfer_out WHERE (@cycle = 'ALL' OR #tmp_transfer_out.cycle <= @cycle_in)), 0),
	outbound_gallons = ISNULL((Select Sum(BillUnit.gal_conv * receipt.quantity)
								from receipt 
								join BillUnit on receipt.bill_unit_code = BillUnit.bill_unit_code 
								where profit_ctr_id = @profit_ctr_id
									AND company_id = @company_id
									and location_type = 'O' 
									and location = @location_in 
									and tracking_num = @tracking_num_in 
									and (cycle <= @cycle_in or @cycle = 'ALL' )),0)
END
ELSE
BEGIN
select @location_in AS location, 
@tracking_num_in AS tracking_num, 
@cycle AS cycle,
on_site_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_on_site WHERE (@cycle = 'ALL' OR #tmp_on_site.cycle <= @cycle_in)), 0), 
container_gallons = IsNull((SELECT SUM(quantity * gal_conv) FROM #tmp WHERE (@cycle = 'ALL' OR #tmp.cycle <= @cycle_in) ), 0),
transfer_in_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_transfer_in WHERE (@cycle = 'ALL' OR #tmp_transfer_in.cycle <= @cycle_in)), 0), 
transfer_out_gallons = IsNull((SELECT SUM(gallons) FROM #tmp_transfer_out WHERE (@cycle = 'ALL' OR #tmp_transfer_out.cycle <= @cycle_in)), 0),
outbound_gallons = ISNULL((Select Sum(BillUnit.gal_conv * receipt.quantity)
							from receipt 
							join BillUnit on receipt.bill_unit_code = BillUnit.bill_unit_code 
							where profit_ctr_id = @profit_ctr_id
								AND company_id = @company_id
								and location_type = 'O' 
								and location = @location_in 
								and tracking_num = @tracking_num_in 
								and (cycle <= @cycle_in or @cycle = 'ALL' )),0)
END
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_gallons] TO [EQAI]
    AS [dbo];

