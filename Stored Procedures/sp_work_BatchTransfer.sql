DROP PROCEDURE IF EXISTS sp_work_BatchTransfer 
GO

CREATE PROCEDURE sp_work_BatchTransfer 
	@location_in		varchar(15), 
	@tracking_num_in	varchar(max), 
	@company_id			int,
	@profit_ctr_id		int,
	@cycle_in			int,
	@user_id			varchar(8),
	@debug				int
AS
/****************
This SP recalculates the distinct set of waste codes and constituents from transfers

Test Cmd Line:  sp_work_BatchTransfer 'PASS-THRU', '03/01/2005', 21, 0, 3, 'SA', 1
sp_work_BatchTransfer '701', 'ALL', 21, 0, 1, 'ANITHA_M', 1
sp_work_BatchTransfer '701', '13888', 21, 0, 1, 'ANITHA_M', 1 
sp_work_BatchTransfer '701', '16286,18221,16286,13888', 21, 0, 1, 'ANITHA_M', 1 
sp_work_BatchTransfer '705', '25474', 21, 0, 2, 'MARTHA_M', 1 

08/24/2004 SCC	Created
03/14/2005 SCC	Modified for new table names. Now called from sp_work_batch.
03/23/2005 MK	Added profit_ctr_id to work table selects.
11/30/2010 SK	Added @company_id as input arg and joins to company-profit center
				moved to Plt_AI
04/16/2013 RB   Added waste_code_uid to waste code related tables
08/01/2016 AM   Added #tmp_tracking_num temp table and necessary joins.
08/20/2021 MPM	DevOps 18527 - Corrected the inserts into work_BatchWasteCode, 
				work_BatchConstituent and work_BatchTransfer.

select * from tracking
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@location				varchar(15),
	@tracking_num			varchar(max),
	@cycle					int,
	@process_count			int,
	@sort_count				int,
	@sort_waste_code		varchar(2000),
	@sort_const				varchar(2000),
	@transfer_waste_code	varchar(4),
	@transfer_const_id		int

IF @debug = 1 select 'called with @location_in: ' + @location_in + ' @tracking_num_in: ' + @tracking_num_in + ' @cycle_in: ' + Convert(varchar(10), @cycle_in)

-- Anitha 
	CREATE TABLE #tmp_tracking_num (
		tracking_num		varchar (15)
	)
	INSERT #tmp_tracking_num
	SELECT row
	from dbo.fn_SplitXsvText(',', 1, @tracking_num_in)
	WHERE isnull(row,'') <> ''
-- Anitha END

-- Remove any previous transfer records
DELETE FROM work_BatchTransfer WHERE user_id = @user_id

-- Get all the transfers and on-site waste events that went into this batch
SELECT DISTINCT 
	location, 
	BatchEvent.tracking_num, 
	cycle, 
	dest_location, 
	dest_tracking_num, 
	dest_cycle, 
	event_type, 
	0 as process_flag
INTO #tmp_transfer
FROM BatchEvent
JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = BatchEvent.dest_tracking_num OR
	 #tmp_tracking_num.tracking_num = 'ALL'
WHERE event_type = 'T'
AND dest_location = @location_in
AND (@tracking_num_in = 'ALL' OR BatchEvent.dest_tracking_num = #tmp_tracking_num.tracking_num  )
AND dest_cycle <= @cycle_in
AND profit_ctr_id = @profit_ctr_id
AND company_id = @company_id
UNION ALL
SELECT DISTINCT 
	location, 
	BatchEvent.tracking_num, 
	cycle, 
	dest_location, 
	dest_tracking_num, 
	dest_cycle, 
	event_type, 
	0 as process_flag
FROM BatchEvent
JOIN #tmp_tracking_num ON #tmp_tracking_num.tracking_num = BatchEvent.tracking_num OR
	 #tmp_tracking_num.tracking_num = 'ALL'
WHERE event_type = 'W'
AND location = @location_in
AND (@tracking_num_in = 'ALL' OR BatchEvent.tracking_num = #tmp_tracking_num.tracking_num  )
AND cycle <= @cycle_in
AND profit_ctr_id = @profit_ctr_id
AND company_id = @company_id

IF @debug = 1 select 'selecting from #tmp_transfer'
IF @debug = 1 select * from #tmp_transfer

-- Get the selected waste codes from Transfers
SELECT DISTINCT
	#tmp_transfer.dest_location as location,
	#tmp_transfer.dest_tracking_num as tracking_num,
	#tmp_transfer.dest_cycle as cycle,
	#tmp_transfer.event_type,
	BatchWasteCode.waste_code,
	BatchWasteCode.waste_code_uid
INTO #tmp_waste
FROM #tmp_transfer
JOIN BatchWasteCode
	ON #tmp_transfer.location = BatchWasteCode.location
	AND #tmp_transfer.tracking_num = BatchWasteCode.tracking_num
	AND #tmp_transfer.cycle = BatchWasteCode.cycle
	AND #tmp_transfer.event_type = BatchWasteCode.event_type
	AND BatchWasteCode.profit_ctr_id = @profit_ctr_id
	AND BatchWasteCode.company_id = @company_id
	AND BatchWasteCode.status in ('O', 'A')

IF @debug = 1 select 'selecting from #tmp_waste'
IF @debug = 1 select * from #tmp_waste

-- Get the selected constituents from Transfers
SELECT DISTINCT
	#tmp_transfer.dest_location as location,
	#tmp_transfer.dest_tracking_num as tracking_num,
	#tmp_transfer.dest_cycle as cycle,
	#tmp_transfer.event_type,
	BatchConstituent.const_id,
	BatchConstituent.UHC
INTO #tmp_const
FROM #tmp_transfer
JOIN BatchConstituent
	ON #tmp_transfer.location = BatchConstituent.location
	AND #tmp_transfer.tracking_num = BatchConstituent.tracking_num
	AND #tmp_transfer.cycle = BatchConstituent.cycle
	AND #tmp_transfer.event_type = BatchConstituent.event_type
	AND BatchConstituent.profit_ctr_id = @profit_ctr_id
	AND BatchConstituent.company_id = @company_id
	AND BatchConstituent.status in ('O', 'A')

IF @debug = 1 select 'selecting from #tmp_const'
IF @debug = 1 select * from #tmp_const

-- Insert waste codes to batch waste code table
INSERT work_BatchWasteCode(
	location, 
	tracking_num,
	company_id,
	profit_ctr_id, 
	waste_code, 
	container, 
	container_id, 
	user_id,
	waste_code_uid)
SELECT DISTINCT 
	#tmp_waste.location, 
	#tmp_waste.tracking_num, 
	@company_id,
	@profit_ctr_id,
	waste_code, 
	CASE WHEN event_type = 'T' THEN 'Transfer' ELSE 'On-Site Waste' END, 
	0, 
	@user_id,
	waste_code_uid
FROM #tmp_waste 
--JOIN #tmp_tracking_num
--ON #tmp_tracking_num.tracking_num = #tmp_waste.tracking_num
where waste_code_uid is not null

-- Insert constituents to batch const table
INSERT work_BatchConstituent (
	location, 
	tracking_num,
	company_id,
	profit_ctr_id,
	const_id, 
	const_desc, 
	LDR_ID, 
	container, 
	container_id, 
	user_id,
	UHC)
SELECT DISTINCT 
	#tmp_const.location,  
	#tmp_const.tracking_num, 
	@company_id,
	@profit_ctr_id,
	#tmp_const.const_id, 
	constituents.const_desc, 
	constituents.ldr_id, 
	CASE WHEN event_type = 'T' THEN 'Transfer' ELSE 'On-Site Waste' END, 
	0, 
	@user_id,
	#tmp_const.UHC
FROM #tmp_const 
JOIN Constituents
ON Constituents.const_id = #tmp_const.const_id 
--JOIN #tmp_tracking_num
--ON #tmp_tracking_num.tracking_num = #tmp_const.tracking_num

SELECT @process_count = count(*) FROM #tmp_transfer
WHILE @process_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @location = dest_location, @tracking_num = dest_tracking_num, @cycle = dest_cycle FROM #tmp_transfer WHERE process_flag = 0
	SET ROWCOUNT 0
	IF @debug = 1 select 'location: ' + @location + ' tracking_num: ' + @tracking_num + ' cycle: ' + convert(varchar(10), @cycle)

	-- Build the waste code sort
	SELECT DISTINCT 
		waste_code, 
		0 as process_flag 
	INTO #waste_code_sort 
	FROM #tmp_waste 
	WHERE location = @location 
		AND tracking_num = @tracking_num 
		AND cycle = @cycle 
	ORDER BY waste_code

	SELECT @sort_count = @@rowcount
	SET @sort_waste_code = ''
	SET ROWCOUNT 1
	WHILE @sort_count > 0
	BEGIN
		SELECT @transfer_waste_code = waste_code FROM #waste_code_sort WHERE process_flag = 0
		IF @sort_waste_code = ''
			SET @sort_waste_code = @transfer_waste_code
		ELSE
			SET @sort_waste_code = @sort_waste_code + ', ' + @transfer_waste_code
		UPDATE #waste_code_sort SET process_flag = 1 WHERE process_flag = 0
		SET @sort_count = @sort_count - 1
	END
	SET ROWCOUNT 0
	DROP TABLE #waste_code_sort
	IF @debug = 1 select 'Waste Code Sort: ' + @sort_waste_code

	-- Build the constituents sort
	SELECT DISTINCT 
		const_id, 
		0 as process_flag 
	INTO #const_sort 
	FROM #tmp_const 
	WHERE location = @location 
		AND tracking_num = @tracking_num 
		AND cycle = @cycle 
	ORDER BY const_id

	SELECT @sort_count = @@rowcount
	SET @sort_const = ''
	SET ROWCOUNT 1
	WHILE @sort_count > 0
	BEGIN
		SELECT @transfer_const_id = const_id FROM #const_sort WHERE process_flag = 0
		IF @sort_const = ''
			SET @sort_const = convert(varchar(10), @transfer_const_id)
		ELSE
			SET @sort_const = @sort_const + ', ' + convert(varchar(10), @transfer_const_id)
		UPDATE #const_sort SET process_flag = 1 WHERE process_flag = 0
		SET @sort_count = @sort_count - 1
	END
	SET ROWCOUNT 0
	DROP TABLE #const_sort
	IF @debug = 1 select 'Const Sort: ' + @sort_const
		
	INSERT work_BatchTransfer (
		location, 
		tracking_num, 
		company_id,
		profit_ctr_id, 
		cycle, 
		transfer_location, 
		transfer_tracking_num, 
		transfer_cycle, 
		transfer_waste_code, 
		transfer_const_id, 
		user_id)
	SELECT 
		#tmp_transfer.dest_location, --@location_in, 
		#tmp_transfer.dest_tracking_num, 
		@company_id,
		@profit_ctr_id, 
		@cycle_in, 
		@location, 
		@tracking_num, 
		@cycle, 
		@sort_waste_code, 
		@sort_const, 
		@user_id
	FROM #tmp_transfer

	-- Go on to the next
	SET ROWCOUNT 1
	UPDATE #tmp_transfer SET process_flag = 1 WHERE process_flag = 0
	SET @process_count = @process_count - 1
	SET ROWCOUNT 0
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_work_BatchTransfer] TO [EQAI]
    AS [dbo];

