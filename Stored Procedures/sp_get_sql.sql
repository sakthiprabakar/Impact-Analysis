
create proc sp_get_sql (
	@spid		int
) as
/* *************************
Wrapper for fn_get_sql
7/25/2011 - JPB

sp_get_sql 932
go
sp_dbcc_inputbuffer 932, 0

************************** */

	declare @spid_str varchar(20)
	set @spid_str = convert(varchar(20), @spid)
	
	if object_id('tempdb..#A') is not null drop table #a
	CREATE TABLE #A(eventtype nvarchar(30), parameters int, eventinfo nvarchar(4000))
	INSERT INTO #A(EventType, Parameters, EventInfo)
	EXEC ('dbcc inputbuffer (' + @spid_str + ') with no_infomsgs')
	
	declare @sql_handle varbinary(64)
	select @sql_handle = sql_handle from sys.dm_exec_requests where session_id=@spid and request_id = 0
	
	-- select * from sys.fn_get_sql(@sql_handle)
	
	select 
		@spid as spid, 
		dbid, 
		db.name, 
		objectid, 
		EventInfo, 
		text as exact_sql_statement 
	from #a
	LEFT outer join sys.fn_get_sql(@sql_handle) on 1=1
	LEFT outer join sys.databases db on dbid = db.database_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_sql] TO [EQAI]
    AS [dbo];

