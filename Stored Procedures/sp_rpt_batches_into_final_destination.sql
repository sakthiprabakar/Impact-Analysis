
CREATE PROCEDURE sp_rpt_batches_into_final_destination
	@company_id							int
,	@profit_ctr_id						int
,	@user_code							varchar(10)
,	@source_location_list				varchar(8000) = null
,	@dest_location_list					varchar(8000) = null
,	@date_opened_from					datetime = null
,	@date_opened_to						datetime = null
,	@date_closed_from					datetime = null
,	@date_closed_to						datetime = null
,	@include_inbound_container_detail	char(1) = null
,	@include_waste_code_detail			char(1) = null
,	@debug								int = null
AS
/***************************************************************************************
This report displays batches disposed into a final destination process location over
a specified date range.

12/2/2017 MPM	Created

exec sp_rpt_batches_into_final_destination 21, 0, 'martha_m', '101','106', null, null, null, null, null, null, 0

****************************************************************************************/

DECLARE @no_date_opened char(1),
		@no_date_closed char(1),
		@location		varchar(15),
		@tracking_num	varchar(15)

IF @debug IS NULL
	SET @debug = 0
	
IF @date_opened_from IS NULL AND @date_opened_to IS NULL OR @date_opened_from = '1-1-1900' AND @date_opened_to = '1-1-3000'
	SET @no_date_opened = 'T'
	
IF @date_opened_from IS NULL
	SET @date_opened_from = '1-1-1900'

IF @date_opened_to IS NULL
	SET @date_opened_to = '1-1-3000'

IF @date_closed_from IS NULL AND @date_closed_to IS NULL OR @date_closed_from = '1-1-1900' AND @date_closed_to = '1-1-3000'
	SET @no_date_closed = 'T'
	
IF @date_closed_from IS NULL
	SET @date_closed_from = '1-1-1900'

IF @date_closed_to IS NULL
	SET @date_closed_to = '1-1-3000'
	
IF @source_location_list IS NULL
	SET @source_location_list = 'ALL'
	
IF @dest_location_list IS NULL
	SET @dest_location_list = 'ALL'

-- Source locations:
create table #source_locations (location varchar(15))
if datalength((@source_location_list)) > 0 and @source_location_list <> 'ALL'
begin
    Insert #source_locations
    select convert(varchar(15), row)
    from dbo.fn_SplitXsvText(',', 0, @source_location_list)
    where isnull(row, '') <> ''
end

-- Destination locations:
create table #destination_locations (location varchar(15))
if datalength((@dest_location_list)) > 0 and @dest_location_list <> 'ALL'
begin
    Insert #destination_locations
    select convert(varchar(15), row)
    from dbo.fn_SplitXsvText(',', 0, @dest_location_list)
    where isnull(row, '') <> ''
end

-- Get the "tranfer out" batches
SELECT DISTINCT 
		b.company_id
		, b.profit_ctr_id
		, b.location
		, b.tracking_num
		, be.cycle
		, be.event_date as 'transfer_out_date'
  INTO #tmp_batch
  FROM BatchEvent be
  JOIN ProcessLocation pl
	ON be.dest_location = pl.location
	AND be.company_id = pl.company_id
	AND be.profit_ctr_id = pl.profit_ctr_id
  JOIN Batch b
	ON b.company_id = be.company_id
	AND b.profit_ctr_id = be.profit_ctr_id
	AND b.location = be.location
	AND b.tracking_num = be.tracking_num
 WHERE be.event_type = 'T'
	AND be.company_id = @company_id
	AND be.profit_ctr_id = @profit_ctr_id
	AND (@source_location_list = 'ALL' OR be.location in (select location from #source_locations))
	AND (@dest_location_list = 'ALL' OR be.dest_location in (select location from #destination_locations))
	AND ((b.date_opened between @date_opened_from AND @date_opened_to) OR @no_date_opened = 'T')
	AND ((b.date_closed between @date_closed_from AND @date_closed_to) OR @no_date_closed = 'T')
	AND pl.final_destination_flag = 'T'
	ORDER BY b.location
		, b.tracking_num
		, be.cycle

IF @debug = 1
BEGIN
	SELECT 'SELECT * FROM #tmp_batch'
	SELECT * from #tmp_batch	
END

-- Cursor for getting location, tracking_num for "transfer out" batches.  
-- We need this to call sp_work_batch, which populates batch work tables for the given user.
-- Specifically, we need work_BatchContainer to be populated for this report.
DECLARE cursor_tmp cursor FOR
  SELECT DISTINCT location, tracking_num
    FROM #tmp_batch

OPEN cursor_tmp 
FETCH NEXT FROM cursor_tmp INTO @location, @tracking_num

IF @@FETCH_STATUS = 0
BEGIN
	-- Clear out batch work tables for this user
	delete from work_BatchContainer where work_BatchContainer.user_id = @user_code
	delete from work_BatchWasteCode where work_BatchWasteCode.user_id = @user_code
	delete from work_BatchConstituent where work_BatchConstituent.user_id = @user_code
	
	IF @debug = 1
	BEGIN
		SELECT 'Just deleted from batch work tables'
		SELECT 'SELECT @location, @tracking_num'
		SELECT @location, @tracking_num	
	END

END

WHILE @@FETCH_STATUS = 0 
BEGIN

	EXEC dbo.sp_work_batch @company_id, @profit_ctr_id, @date_opened_from, @date_opened_to, @location, @tracking_num, @user_code, 0

	IF @debug = 1
	BEGIN
		SELECT 'Just executed sp_work_batch'
		SELECT 'SELECT @location, @tracking_num'
		SELECT @location, @tracking_num	
	END
	
	FETCH NEXT FROM cursor_tmp INTO @location, @tracking_num

END 

CLOSE cursor_tmp
DEALLOCATE cursor_tmp

-- Final select
SELECT company_id
		, profit_ctr_id
		, location
		, tracking_num
		, cycle
		, transfer_out_date
FROM #tmp_batch
ORDER BY location, tracking_num, cycle


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batches_into_final_destination] TO [EQAI]
    AS [dbo];

