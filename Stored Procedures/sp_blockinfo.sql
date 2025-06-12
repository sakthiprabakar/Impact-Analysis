
Create Procedure sp_blockinfo 
/************************************************************
Procedure    : sp_blockinfo
Database     : plt_ai* 
Created      : Tue Jan 09 12:30:40 EST 2007 - Jonathan Broome
Filename     : L:\Apps\SQL\
Description  : Retrieves information on current blocking.

Should also store that info, would be nice.

************************************************************/
AS

	set nocount on
	set ansi_warnings off
	declare @checktime datetime
	set @checktime = getdate()
	
	-- drop table #temp
	create table #temp (
		spid		int,
		status		nchar(30),
		login		nchar(128),
		hostname	nchar(128),
		BlkBy		nchar(128),
		DBName		nchar(128),
		Command		nchar(128),
		CPUTime		int,
		DiskIO		int,
		LastBatch	nchar(128),
		ProgramName nchar(128),
		spid_2		int
	)
	
	-- drop table #sp_who
	create table #sp_who (
		spid		int,
		status		char(30),
		login		char(128),
		hostname	char(128),
		BlkBy		int,
		DBName		char(128),
		Command		char(128),
		CPUTime		int,
		DiskIO		int,
		LastBatch	char(128),
		ProgramName char(128),
		lastbatch_dt	datetime,
		blocked_spids	int,
		sql_command	varchar(255),
		SQL_CurrentLine varchar(4000)
	)

--	select 'loading #temp ' + convert(varchar(30), datediff(ms, @checktime, getdate()))

	insert #temp exec sp_who2

--	select '#temp loaded ' + convert(varchar(30), datediff(ms, @checktime, getdate()))

	if (select count(*) from #temp where BlkBy <> '  .') = 0 return

	insert #sp_who (
		spid,
		status,
		login,
		hostname,
		BlkBy,
		DBName,
		Command,
		CPUTime,
		DiskIO,
		LastBatch,
		ProgramName,
		Blocked_spids
	)
	select
		spid,
		status,
		login,
		hostname,
		case when BlkBy = '  .' then null else convert(int, BlkBy) end as BlkBy,
		DBName,
		Command,
		CPUTime,
		DiskIO,
		LastBatch,
		ProgramName,
		(select count(distinct w2.spid) from #temp w2 where case when w2.BlkBy = '  .' then null else convert(int, w2.BlkBy) end = x.spid) as Blocked_spids
	from #temp x
	where BlkBy <> '  .'

	insert #sp_who (
		spid,
		status,
		login,
		hostname,
		BlkBy,
		DBName,
		Command,
		CPUTime,
		DiskIO,
		LastBatch,
		ProgramName,
		Blocked_spids
	)
	select
		spid,
		status,
		login,
		hostname,
		case when BlkBy = '  .' then null else convert(int, BlkBy) end as BlkBy,
		DBName,
		Command,
		CPUTime,
		DiskIO,
		LastBatch,
		ProgramName,
		(select count(distinct w2.spid) from #temp w2 where case when w2.BlkBy = '  .' then null else convert(int, w2.BlkBy) end = x.spid) as Blocked_spids
	from #temp x
	where spid in (select distinct BlkBy from #sp_who)
	and spid not in (select distinct spid from #sp_who)

--	select '#sp_who loaded ' + convert(varchar(30), datediff(ms, @checktime, getdate()))

	update #sp_who set blocked_spids = (
		select count(distinct w2.spid) from #sp_who w2 
		where w2.BlkBy = #sp_who.spid)

	update #sp_who set blocked_spids = blocked_spids + isnull((
		select sum(blocked_spids) from #sp_who w2 
		where w2.BlkBy = #sp_who.spid), 0)
	where BlkBy is null
	
	delete from #sp_who where blocked_spids = 0 or BlkBy is not null
	-- select * from #sp_who

	if (select count(*) from #sp_who) > 0 begin

--	select 'processing #sp_who ' + convert(varchar(30), datediff(ms, @checktime, getdate()))
		-- drop table #dbcc_inputbuffer
		create table #dbcc_inputbuffer (
			EventType	nvarchar(30),
			Parameters	int,
			EventInfo	nvarchar(255)
		)
		
		Create Table #BlockInfoDetail (
			dbid				int,
			dbname			nchar(128),
			objid			int,
			indid			int,
			type				nchar(128),
			resource			nchar(128),
			mode				nchar(8),
			status			nchar(8)
		)
		
		Create Table #line (
			line nvarchar(4000)
		)
		
		declare @sql varchar(200), @spid int, @ident int
		
		DECLARE spid_cursor CURSOR
		   FOR select spid from #sp_who
		OPEN spid_cursor
		FETCH NEXT FROM spid_cursor INTO @spid
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @sql = 'dbcc inputbuffer (' + convert(varchar(20), @spid) +')'
			insert #dbcc_inputbuffer exec(@sql)
			set @sql = 'sp_lock ' + convert(varchar(20), @spid)
			insert #BlockInfoDetail exec(@sql)
			set @sql = 'sp_ShowCodeLine ' + convert(varchar(20), @spid) + ', 0, 1, ''S'''
			insert #line exec(@sql)
			update #sp_who set 
				sql_command = (select top 1 EventInfo from #dbcc_inputbuffer),
				lastbatch_dt = convert(datetime, (left(lastBatch, charindex(' ', lastBatch)-1) + 
					'/' + convert(varchar(4), datepart(yyyy, getdate())) + ' ' +
					replace(lastBatch, left(lastBatch, charindex(' ', lastBatch)), ' '))),
				SQL_CurrentLine = (select top 1 line from #line)
			where spid = @spid
			truncate table #dbcc_inputbuffer
			truncate table #line
			
			insert BlockInfo (
				Spid,
				Hostname,		
				DBName,		
				Login,		
				ProgramName, 	
				Command,	
				CPUTime,	
				DiskIO,	
				Elapsed_Seconds,	
				Blocked_Spids,
				SQL_Command,
				SQL_CurrentLine,
				time_stamp	
			)
			select 
				spid,
				hostname, 
				dbname, 
				login, 
				programname, 
				command, 
				cputime, 
				diskio, 
				datediff(s, lastbatch_dt, @checktime) as elapsed_seconds, 
				blocked_spids, 
				sql_command, 
				SQL_CurrentLine,
				@checktime as time_stamp 
			from #sp_who
			where spid = @spid
			
			select @ident = @@identity
			
			insert BlockInfoDetail
			select @ident,
				dbid	,
				db_name(convert(int, dbname)) as dbname,
				objid,
				object_name(convert(int, objid)) as objname,
				indid,
				type	,
				resource,
				mode	,
				status
			from #BlockInfoDetail
			truncate table #BlockInfoDetail
			
			FETCH NEXT FROM spid_cursor INTO @spid
		END
		
		CLOSE spid_cursor
		DEALLOCATE spid_cursor
		
	end

	set nocount off

	select 
		spid,
		hostname, 
		dbname, 
		login, 
		programname, 
		command, 
		cputime, 
		diskio, 
		datediff(s, lastbatch_dt, @checktime) as elapsed_seconds, 
		blocked_spids, 
		sql_command, 
		SQL_CurrentLine,
		@checktime as time_stamp 
	from #sp_who
	
	set ansi_warnings on

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_blockinfo] TO [EQAI]
    AS [dbo];

