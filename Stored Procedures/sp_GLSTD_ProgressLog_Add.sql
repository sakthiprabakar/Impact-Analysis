CREATE PROC sp_GLSTD_ProgressLog_Add (
	@description	varchar(200),
	@rows_affected	int = null,
	@script_type	varchar(40) = null
)
AS
	/****************************************************************
	sp_GLSTD_ProgressLog_Add - a temporary sp to ease updating progress of the GLSTD script progress

		sp_GLSTD_ProgressLog_Add 'SomeStatus', 1
	****************************************************************/
	declare @log_id int
	INSERT GLSTD_ProgressLog (description, rows_affected, script_type) values (@description, @rows_affected, @script_type)
	set @log_id = @@identity
	if @log_id > 1 AND @description <> 'Begin Script'
		update GLSTD_ProgressLog 
		SET elapsed = datediff(s,
			(SELECT top 1 date_added from GLSTD_ProgressLog where log_id < @log_id and script_type = @script_type order by date_added desc) ,
			(SELECT date_added from GLSTD_ProgressLog where log_id = @log_id)
		) 
		where log_id = @log_id
	if @rows_affected is not null begin
		CHECKPOINT
		INSERT GLSTD_ProgressLog (description, rows_affected) values ('CHECKPOINT: DONE', NULL)
	end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_GLSTD_ProgressLog_Add] TO PUBLIC
    AS [dbo];

