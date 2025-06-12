CREATE PROC sp_WOTYPE_ProgressLog_Add (
	@description	varchar(200),
	@rows_affected	int = null
)
AS
	/****************************************************************
	sp_WOTYPE_ProgressLog_Add - a temporary sp to ease updating progress of the WOTYPE script progress

	sp_WOTYPE_ProgressLog_Add 'SomeStatus', 1
	****************************************************************/
	declare @log_id int
	INSERT WOTYPE_ProgressLog (description, rows_affected) values (@description, @rows_affected)
	set @log_id = @@identity
	if @log_id > 1 AND @description <> 'Begin Script'
		update WOTYPE_ProgressLog 
		SET elapsed = datediff(s,
			(SELECT date_added from WOTYPE_ProgressLog where log_id = @log_id-1) ,
			(SELECT date_added from WOTYPE_ProgressLog where log_id = @log_id)
		) 
		where log_id = @log_id
	if @rows_affected is not null begin
		CHECKPOINT
		INSERT WOTYPE_ProgressLog (description, rows_affected) values ('CHECKPOINT: DONE', NULL)
	end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_WOTYPE_ProgressLog_Add] TO PUBLIC
    AS [dbo];

