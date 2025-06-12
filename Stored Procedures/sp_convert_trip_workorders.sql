CREATE PROCEDURE sp_convert_trip_workorders
	@company_id		int,
	@profit_ctr_id	int,
	@trip_id		int,
	@debug			tinyint
AS
/************************************************************************************
The purpose of this SP is to convert the older negative-ID work orders from Trips
to have positive numbers (with a workorder_status = 'X')

Loaded to Plt_AI

09/14/2009 JDB	Created.

SELECT trip_id, * FROM workorderheader WHERE trip_id > 0 AND workorder_id < 0 ORDER BY workorder_id desc

sp_convert_trip_workorders 22, 0, 0, 1
************************************************************************************/
DECLARE	@next_wo_id		int,
		@intCounter		int


------------------------------------------------------------------------------------
-- Create #tmp_header
------------------------------------------------------------------------------------
CREATE TABLE #tmp_header (
	trip_id				int		NOT NULL,
	trip_sequence_id	int		NOT NULL,
	company_id			tinyint NOT NULL,
	profit_ctr_id		tinyint NOT NULL,
	workorder_id		int		NOT NULL,
	workorder_status	char(1)	NOT NULL,
	new_workorder_id	int		NULL	)

INSERT INTO #tmp_header
SELECT trip_id,
	trip_sequence_id,
	company_id,
	profit_ctr_id,
	workorder_id,
	workorder_status,
	0
FROM WorkOrderHeader
WHERE 1=1
AND (@trip_id = 0 OR trip_id = @trip_id)
AND company_id = @company_id
AND profit_ctr_id = @profit_ctr_id
AND workorder_id < 0
AND trip_id > 0
ORDER BY trip_id, trip_sequence_id

--IF @debug = 1
--BEGIN
--	PRINT '======================================================='
--	PRINT 'SELECT * FROM #tmp_header'
--	PRINT '======================================================='
--	SELECT * FROM #tmp_header
--END


-- Get next work order number from the ProfitCenter table
SELECT @next_wo_id = next_workorder_id
FROM ProfitCenter
WHERE company_ID = @company_id
AND profit_ctr_ID = @profit_ctr_id

IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'SELECT @next_wo_id'
	PRINT '======================================================='
	SELECT @next_wo_id
END


-- Set new_workorder_id on the #tmp_header table
SET @intCounter = @next_wo_id		-- use the max number retrieved above
UPDATE #tmp_header SET @intCounter = new_workorder_id = @intCounter + 1
WHERE 1=1

-- Also update the ProfitCenter table's next_workorder_id field
UPDATE ProfitCenter SET next_workorder_ID = @intCounter + 1
WHERE company_ID = @company_id AND profit_ctr_ID = @profit_ctr_id

-- Update new workorder on the #tmp_header to have the zeros at the end
UPDATE #tmp_header SET new_workorder_id = new_workorder_id * 100

IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'SELECT * FROM #tmp_header'
	PRINT '======================================================='
	SELECT * FROM #tmp_header
	
	PRINT '======================================================='
	PRINT 'SELECT next_workorder_ID, * FROM ProfitCenter'
	PRINT '======================================================='
	SELECT next_workorder_ID, * FROM ProfitCenter WHERE company_ID = @company_id AND profit_ctr_ID = @profit_ctr_id
END


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkOrderAudit'
	PRINT '======================================================='
END

UPDATE WorkOrderAudit SET workorder_id = new_workorder_id
FROM WorkOrderAudit wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkorderAuditComment'
	PRINT '======================================================='
END

UPDATE WorkorderAuditComment SET workorder_id = new_workorder_id
FROM WorkorderAuditComment wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkOrderManifest'
	PRINT '======================================================='
END

UPDATE WorkOrderManifest SET workorder_id = new_workorder_id
FROM WorkOrderManifest wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkorderHours'
	PRINT '======================================================='
END

UPDATE WorkorderHours SET workorder_id = new_workorder_id
FROM WorkorderHours wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkorderReminder'
	PRINT '======================================================='
END

UPDATE WorkorderReminder SET workorder_id = new_workorder_id
FROM WorkorderReminder wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkOrderDetail'
	PRINT '======================================================='
END

UPDATE WorkOrderDetail SET workorder_id = new_workorder_id
FROM WorkOrderDetail wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating WorkOrderHeader'
	PRINT '======================================================='
END

UPDATE WorkOrderHeader SET workorder_id = new_workorder_id
FROM WorkOrderHeader wo
INNER JOIN #tmp_header tmp ON wo.company_id = tmp.company_id
	AND wo.profit_ctr_id = tmp.profit_ctr_id
	AND wo.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating Note'
	PRINT '======================================================='
END

UPDATE Note SET workorder_id = new_workorder_id
FROM Note note
INNER JOIN #tmp_header tmp ON note.company_id = tmp.company_id
	AND note.profit_ctr_id = tmp.profit_ctr_id
	AND note.workorder_id = tmp.workorder_id
	


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'Updating Scan'
	PRINT '======================================================='
END

UPDATE Plt_Image..Scan SET workorder_id = new_workorder_id
FROM Plt_Image..Scan scan
INNER JOIN #tmp_header tmp ON scan.company_id = tmp.company_id
	AND scan.profit_ctr_id = tmp.profit_ctr_id
	AND scan.workorder_id = tmp.workorder_id


IF @debug = 1
BEGIN
	PRINT '======================================================='
	PRINT 'SELECT * FROM WorkOrderHeader WHERE trip_ID = ' + CONVERT(varchar(10), @trip_id)
	PRINT '======================================================='
	SELECT trip_ID, trip_sequence_id, * FROM WorkOrderHeader WHERE trip_ID = @trip_id ORDER BY workorder_id ASC
END





DROP TABLE #tmp_header
