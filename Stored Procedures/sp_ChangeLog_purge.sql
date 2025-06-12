/***********************************************************************************
The purpose of this stored procedure is remove processed records from the ChangeLog table

Load to NTSQL1..Plt_AI,
	NTSQL3..Plt_AI

04/20/2006 SCC	Created
04/21/2006 JDB	Modified to use hours instead of days, write to ChangeLogPurgeLog

sp_ChangeLog_purge NULL, 72, 1
***********************************************************************************/
CREATE PROCEDURE sp_ChangeLog_purge
	@as_of_date	datetime = NULL, 
	@hours		int,
	@debug		int 
AS

DECLARE	@count_to_be_deleted	int,
	@count_deleted		int,
	@delete_records_before	datetime,
	@start_date		datetime
	
SET NOCOUNT ON
SET @start_date = GETDATE()

IF @as_of_date IS NULL SET @as_of_date = GETDATE()
SET @delete_records_before = DATEADD(hh, -@hours, @as_of_date)

IF @debug = 1 PRINT '@as_of_date:           ' + CONVERT(varchar(30), @as_of_date)
IF @debug = 1 PRINT 'Delete records before: ' + CONVERT(varchar(30), @delete_records_before)
IF @debug = 1 PRINT ''

IF @as_of_date <= GETDATE() AND @hours > 0
BEGIN
	-- This is how many records will be deleted
	SELECT @count_to_be_deleted = COUNT(*) FROM Changelog WHERE process_flag = 1 AND change_date < DATEADD(hh, -@hours, @as_of_date)
	IF @debug = 1 PRINT 'Records To Be Deleted:  ' + CONVERT(varchar(20), @count_to_be_deleted)
	
	DELETE FROM Changelog WHERE process_flag = 1 AND change_date < DATEADD(hh, -@hours, @as_of_date)

	SET @count_deleted = @@ROWCOUNT
	IF @debug = 1 PRINT 'Records Deleted:  ' + CONVERT(varchar(20), @count_deleted)

	INSERT INTO ChangeLogPurgeLog VALUES (@as_of_date, @hours, @delete_records_before, @count_to_be_deleted, @count_deleted, @start_date, GETDATE())
END
