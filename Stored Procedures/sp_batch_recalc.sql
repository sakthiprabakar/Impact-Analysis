CREATE PROCEDURE sp_batch_recalc 
	@batch_id			int,	
	@location_in		varchar(15), 
	@tracking_num_in	varchar(15), 
	@profit_ctr_id		int,
	@company_id			int,
	@cycle_in			int,
	@debug				int
AS
/****************
This SP recalculate the distinct set of waste codes and constituents from assigned receipts and transfers

06/06/2004 SCC Created
10/14/2004 SCC Modified to support storing selected waste codes and constituents for transfer and on-site waste events
03/23/2005 MK  Fixed waste code and constituents recalc - was adding to existing rather than recalculating
05/02/2005 SCC Fixed a prob where the Transfer Batch cycle was being inserted in the BatchWasteCode and BatchConstituent instead
		of the Transfer Batch destination cycle.
03/13/2006 MK  Fixed problem where a UHC that was 'U' in a transfer also came in as 'T' from bulk. Final insert took
		the 'U' instead of the 'T' based on the Max() function in the insert. Now, all 'U's in the temp
		const list are replace with a blank ' ' so the Max function will work. Then, the records that were
		inserted into BatchConstituent with a blank UHC are updated to 'U'.
01/13/2010 KAM Add the use of company_id and batch_id for the inserts	
11/30/2010 SK Modified to use company_id in joins and run on Plt_AI
			  moved to Plt_AI	
04/25/2013 RB Added waste_code_uid for Waste Code conversion

sp_batch_recalc 2432, '701', '12417', 0, 21, 1, 1
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@location		varchar(15),
	@tracking_num	varchar(15),
	@cycle			int,
	@process_count	int

IF @debug = 1 print 'called with @location_in: ' + @location_in + ' @tracking_num_in: ' + @tracking_num_in + ' @cycle_in: ' + Convert(varchar(10), @cycle_in)

-- Get all the transfers and on-site waste events that went into this batch
SELECT DISTINCT location, tracking_num, cycle, dest_location, dest_tracking_num, dest_cycle, event_type, 0 as process_flag
INTO #tmp_transfer
FROM BatchEvent
WHERE event_type = 'T'
AND dest_location = @location_in
AND dest_tracking_num = @tracking_num_in
AND dest_cycle <= @cycle_in
AND profit_ctr_id = @profit_ctr_id
AND company_id = @company_id
UNION ALL
SELECT DISTINCT location, tracking_num, cycle, dest_location, dest_tracking_num, dest_cycle, event_type, 0 as process_flag
FROM BatchEvent
WHERE event_type = 'W'
AND location = @location_in
AND tracking_num = @tracking_num_in
AND cycle <= @cycle_in
AND profit_ctr_id = @profit_ctr_id
AND company_id = @company_id

-- Remove this section (pulls in the current list)
---- Insert a record for this batch
--INSERT #tmp_transfer VALUES(@location_in, @tracking_num_in, @cycle_in, @location_in, @tracking_num_in, @cycle_in, 'C', 0)
--

IF @debug = 1 print 'selecting from #tmp_transfer'
IF @debug = 1 select * from #tmp_transfer

-- Get the selected waste codes from Transfers
SELECT DISTINCT
#tmp_transfer.location,
#tmp_transfer.tracking_num,
#tmp_transfer.cycle,
BatchWasteCode.waste_code_uid,
BatchWasteCode.waste_code
INTO #tmp_waste
FROM #tmp_transfer, BatchWasteCode
WHERE #tmp_transfer.location = BatchWasteCode.location
AND #tmp_transfer.tracking_num = BatchWasteCode.tracking_num
AND #tmp_transfer.cycle = BatchWasteCode.cycle
AND #tmp_transfer.event_type = BatchWasteCode.event_type
AND BatchWasteCode.profit_ctr_id = @profit_ctr_id
AND BatchWasteCode.company_id = @company_id
AND BatchWasteCode.status in ('O', 'A')
IF @debug = 1 print 'selecting from #tmp_waste'
IF @debug = 1 select * from #tmp_waste

-- Get the selected constituents from Transfers
SELECT DISTINCT
#tmp_transfer.location,
#tmp_transfer.tracking_num,
#tmp_transfer.cycle,
BatchConstituent.const_id,
BatchConstituent.UHC
INTO #tmp_const
FROM #tmp_transfer, BatchConstituent
WHERE #tmp_transfer.location = BatchConstituent.location
AND #tmp_transfer.tracking_num = BatchConstituent.tracking_num
AND #tmp_transfer.cycle = BatchConstituent.cycle
AND #tmp_transfer.event_type = BatchConstituent.event_type
AND BatchConstituent.profit_ctr_id = @profit_ctr_id
AND BatchConstituent.company_id = @company_id
AND BatchConstituent.status in ('O', 'A')

-- Get the waste codes for this batch
EXEC sp_batch_waste @location_in, @tracking_num_in, @company_id, @profit_ctr_id, @cycle_in, @debug

-- Get these constituents
EXEC sp_batch_const @location_in, @tracking_num_in, @company_id, @profit_ctr_id, @cycle_in, @debug

IF @debug = 1 print 'Selecting from #tmp_waste'
IF @debug = 1 Select * from #tmp_waste

-- Delete any existing batch waste codes
DELETE FROM BatchWasteCode WHERE location = @location_in AND tracking_num = @tracking_num_in
AND profit_ctr_id = @profit_ctr_id AND company_id = @company_id AND cycle <= @cycle_in AND event_type = 'C'

-- IF a waste code came from a Transfer, the location and tracking num will match but the cycle will be the transfer
-- batch cycle, not the receiving batch cycle.  Update the tmp table before inserting the waste codes
UPDATE #tmp_waste SET cycle = #tmp_transfer.dest_cycle
FROM #tmp_transfer 
WHERE #tmp_waste.location = #tmp_transfer.location
AND #tmp_waste.tracking_num = #tmp_transfer.tracking_num
AND #tmp_transfer.dest_location = @location_in
AND #tmp_transfer.dest_tracking_num = @tracking_num_in

-- Insert set of recalculated waste codes
INSERT BatchWasteCode (batch_id,company_id,profit_ctr_id, location, tracking_num, cycle, waste_code_uid, waste_code, event_type, status, date_modified, modified_by)
SELECT DISTINCT @batch_id, @company_id, @profit_ctr_id, @location_in, @tracking_num_in, cycle, waste_code_uid, waste_code, 'C', 'A', getdate(), 'AUTOCALC'
FROM #tmp_waste

IF @debug = 1 print 'Selecting from #tmp_const'
IF @debug = 1 Select * from #tmp_const

-- IF a constituent came from a Transfer, the location and tracking num will match but the cycle will be the transfer
-- batch cycle, not the receiving batch cycle.  Update the tmp table before inserting the constituents
UPDATE #tmp_const SET cycle = #tmp_transfer.dest_cycle
FROM #tmp_transfer 
WHERE #tmp_const.location = #tmp_transfer.location
AND #tmp_const.tracking_num = #tmp_transfer.tracking_num
AND #tmp_transfer.dest_location = @location_in
AND #tmp_transfer.dest_tracking_num = @tracking_num_in

-- Set any UHC U's to blank so "T" will rise to the top when selecting Max(UHC)
UPDATE #tmp_const SET UHC = ' '
WHERE (UHC is null) or (UHC = 'U')

-- Delete any existing batch constituents
DELETE FROM BatchConstituent WHERE location = @location_in AND tracking_num = @tracking_num_in
AND profit_ctr_id = @profit_ctr_id AND company_id = @company_id AND cycle <= @cycle_in AND event_type = 'C'

-- Insert set of recalculated constituents
INSERT BatchConstituent (batch_id,company_id,profit_ctr_id, location, tracking_num, cycle, const_id, UHC, event_type, status, date_modified, modified_by)
SELECT DISTINCT @batch_id, @company_id, @profit_ctr_id, @location_in, @tracking_num_in, cycle, const_id, MAX(IsNull(UHC,' ')), 'C', 'A', getdate(), 'AUTOCALC'
FROM #tmp_const 
GROUP BY cycle, const_id

-- Set all blank UHC's for this batch to 'U'
UPDATE BatchConstituent
SET UHC = 'U' 
WHERE location = @location_in AND tracking_num = @tracking_num_in
AND profit_ctr_id = @profit_ctr_id AND company_id = @company_id AND cycle <= @cycle_in AND event_type = 'C'
AND UHC = ' '

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_recalc] TO [EQAI]
    AS [dbo];

