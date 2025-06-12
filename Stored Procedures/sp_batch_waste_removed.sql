CREATE PROCEDURE sp_batch_waste_removed
	@company_id			int
,	@profit_ctr_id		int
,	@location_in		varchar(15)
,	@tracking_num_in	varchar(15)
,	@cycle_in			int
AS

-- select distinct location, tracking_num from work_Batch where user_id = 'SA' and report_source = 'BATCH'

/***************************************************************************************

sp_batch_waste_removed 21, 0, '101', '101-1', 0

03/14/2005 SCC	Created/Started
04/11/2005 SCC	Created/Finished
11/30/2010 SK	Added company_id as input arg, moved to Plt_AI

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@list varchar(2000),
	@waste_code varchar(4),
	@cycle int,
	@cycle_prev int,
	@count int

CREATE TABLE #tmp_results (
	cycle int NULL,
	results varchar(2000)
)

-- These are the waste removed records
SELECT DISTINCT
	cycle,
	waste_code,
	0 as process_flag
INTO #tmp_remove
FROM BatchWasteCode
WHERE profit_ctr_id = @profit_ctr_id
AND company_id = @company_id
AND location = @location_in
AND tracking_num = @tracking_num_in
AND (@cycle_in = 0 OR cycle <= @cycle_in)
AND event_type = 'X' 
AND status = 'R'
ORDER BY cycle, waste_code

SELECT @count = @@rowcount

SET @list = ''
SET @cycle_prev = -1

SET ROWCOUNT 1
WHILE @count > 0
BEGIN
	SELECT @cycle = cycle, @waste_code = waste_code FROM #tmp_remove where process_flag = 0
	IF @cycle <> @cycle_prev AND @cycle_prev <> -1
	BEGIN
		INSERT #tmp_results VALUES(@cycle_prev, @list)
		SET @list = ''
	END
	
	IF @list = ''
		SET @list = @waste_code
	ELSE
		SET @list = @list + ', ' + @waste_code
	SET @cycle_prev = @cycle
	SET @count = @count - 1
	UPDATE #tmp_remove SET process_flag = 1  where process_flag = 0
END
-- Get the last one
IF @cycle_prev <> -1
	INSERT #tmp_results VALUES(@cycle_prev, @list)

SET ROWCOUNT 0
SELECT * FROM #tmp_results	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_waste_removed] TO [EQAI]
    AS [dbo];

