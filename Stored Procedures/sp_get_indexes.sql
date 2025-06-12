--drop procedure sp_get_indexes



-- sp_get_indexes 'all',0
create procedure sp_get_indexes ( @type varchar(6), @debug int = 0) as

--****************************************************************************************
-- List index information for the current database
--****************************************************************************************
-- Version: 	1.0
-- Author:	Theo Ekelmans 
-- Email:	theo@ekelmans.com
-- Date:	2005-10-07
--****************************************************************************************
declare @carriage char(1), @linefeed char(1)

declare @tablename varchar(255) ,
        @indexname varchar(255) ,
	@indexid  int ,
	@status   int ,
	@isprimary tinyint ,
	@isclustered tinyint ,
	@isunique tinyint ,
	@isignoredupes tinyint ,
	@isignoreduperow tinyint ,
	@isnorecompute tinyint ,
	@fillfactor int ,
	@estrowcount int ,
	@reserved int ,
	@used int ,
	@keynumber int,
	@columnname varchar(255),
	@command varchar(4000),
	@holdtablename varchar(255),
	@holdindexid int,
        @holdindexname varchar(255),
	@more_columns tinyint,
        @more_indexes tinyint
     


set nocount on 

create table #indexes ( tablename varchar(255) null,
                        indexname varchar(255) null,
						indexid  int null,
						status   int null,
						isprimary tinyint null,
						isclustered tinyint null,
						isunique tinyint null,
						isignoredupes tinyint null,
						isignoreduperow tinyint null,
						isnorecompute tinyint null,
						fillamount int null,
						estrowcount int null,
						reserved int null,
						used int null,
						keynumber int null,
						columnname varchar(255) null,
						datatype varchar(255) null,
						precise int null,
						scale int null,
						iscomputed int null,
						isnullable int null,
						collation varchar(255) null )
						
create table #commands ( tablename varchar(255),
                         indexid int null,
			 cmdtype int null,
                         cmdsubtype int null,
			 indexcmd varchar(4000) )
						


select @carriage = CHAR(13), @linefeed = CHAR(10)

insert #indexes				
select 	o.name as 'TableName',
	i.name as 'IndexName',
	i.indid as 'index_id',
	i.status as 'index_type',
	CASE WHEN (i.status & 0x800)     = 0 THEN 0 ELSE 1 END AS 'Primary', 
	CASE WHEN (i.status & 0x10)      = 0 THEN 0 ELSE 1 END AS 'Clustered', 
	CASE WHEN (i.status & 0x2)       = 0 THEN 0 ELSE 1 END AS 'Unique', 
	CASE WHEN (i.status & 0x1)       = 0 THEN 0 ELSE 1 END AS 'IgnoreDupKey', 
	CASE WHEN (i.status & 0x4)       = 0 THEN 0 ELSE 1 END AS 'IgnoreDupRow', 
	CASE WHEN (i.status & 0x1000000) = 0 THEN 0 ELSE 1 END AS 'NoRecompute', 
	i.OrigFillFactor AS 'FillFactor', 
	i.rowcnt as 'Est.RowCount',
	i.reserved * cast(8 as bigint) as ReservedKB,  
	i.used * cast(8 as bigint) as UsedKB,  
	k.keyno as 'KeyNumber',
	c.name as 'ColumnName',
	t.name as 'DataType', 
	c.xprec as 'Precision',
	c.xscale as 'Scale', 
	c.iscomputed as 'IsComputed', 
	c.isnullable as 'IsNullable', 
	c.collation as 'Collation'
--into #indexes
from 	           sysobjects   o with(nolock)
	inner join sysindexes   i with(nolock) on o.id    =  i.id
	inner join sysindexkeys k with(nolock) on i.id    =  k.id    and    i.indid =  k.indid
	inner join syscolumns   c with(nolock) on k.id    =  c.id    and    k.colid =  c.colid 
	inner join systypes     t with(nolock) on c.xtype =  t.xtype 

where 	o.xtype <> 'S' -- Ignore system objects
and 	i.name not like '_wa_sys_%' -- Ignore statistics

order by
	o.name, 
	k.indid,
	k.keyno


if @debug = 1 
begin
	select * from #indexes
end

-- declare cursor to process indexes

declare ind_list cursor for 
select 	tablename,
        indexname ,
	indexid ,
	status ,
	isprimary ,
	isclustered ,
	isunique ,
	isignoredupes ,
	isignoreduperow ,
	isnorecompute ,
	fillamount ,
	estrowcount ,
	reserved ,
	used ,
	keynumber ,
	columnname 
from #indexes
order by tablename, isclustered desc, indexid, keynumber


-- prime the cursor

open ind_list


fetch next from ind_list into
        @tablename,
        @indexname ,
	@indexid,
	@status  ,
	@isprimary  ,
	@isclustered  ,
	@isunique  ,
	@isignoredupes  ,
	@isignoreduperow  ,
	@isnorecompute  ,
	@fillfactor  ,
	@estrowcount ,
	@reserved  ,
	@used ,
	@keynumber ,
	@columnname 

	

	
	
select @holdtablename = @tablename, @holdindexid  = @indexid, @more_indexes = 0, @holdindexname = @indexname

while @@fetch_status = 0
begin

       select @command =  @carriage + @linefeed + @carriage + @linefeed
       select @command = @command + '-- ' + @tablename  + ' INDEXES ' + @carriage + @linefeed + @carriage + @linefeed
       insert #commands values (@tablename, 0, 0 ,0, @command)

     while @@fetch_status = 0 and @more_indexes = 0	
     begin
        
	if upper(@type) = 'DROP' or upper(@type) = 'ALL'
	begin
		select @command =  'if exists (select * from dbo.sysindexes where name = ''' + @indexname + ''' and id = object_id(''' + @tablename + '''))' + @carriage + @linefeed +
                 'drop index ' + @tablename + '.' + @indexname + @carriage + @linefeed +
                 'go' 
	   
	   insert #commands values (@holdtablename, @holdindexid, 1,1, @command)
	   select @command = ''

           select @command = 'if not exists (select * from dbo.sysindexes where name = ''' + @indexname + ''' and id = object_id(''' + @tablename + '''))' + @carriage + @linefeed +
                 'print ''<<<< ' + @tablename + '.' + @indexname +  '   Successfully Dropped  >>>> '' ' + @carriage + @linefeed +
                 'go' 
           insert #commands values (@holdtablename, @holdindexid, 1,2, @command)
	end
	
	select @command = '', @more_columns = 0
	if upper(@type) = 'CREATE' or upper(@type) = 'ALL'
	begin
		select @command = @command +  'CREATE '
		
		if @isunique = 1
		begin
			select @command = @command + 'UNIQUE '
		end
		
		if @isclustered = 1
		begin
			select @command = @command + 'CLUSTERED '
		end
		
		select @command = @command + 'INDEX ' + @indexname + ' on ' + @tablename + ' ( '  
		
		
		
                while @@fetch_status = 0  and @more_columns = 0
                begin
				select @command = @command + @columnname 

				fetch next from ind_list into
					@tablename,
					@indexname ,
					@indexid ,
					@status ,
					@isprimary ,
					@isclustered ,
					@isunique ,
					@isignoredupes ,
					@isignoreduperow ,
					@isnorecompute ,
					@fillfactor ,
					@estrowcount ,
					@reserved ,
					@used ,
					@keynumber ,
					@columnname 

				if @debug = 1 
				begin
				select  @tablename as 'tablename',
		    			@indexname as 'indename',
					@indexid as 'indexid',
					@status as 'status',
					@isprimary as 'primary',
					@isclustered as 'clustered',
					@isunique as 'unique',
					@isignoredupes as 'ingnorekeys',
					@isignoreduperow as 'ignorerows',
					@isnorecompute as 'recompute',
					@fillfactor as 'fillfactor',
					@estrowcount as 'estrows',
					@reserved as 'reserved',
					@used as 'used',
					@keynumber as 'keynumber',
					@columnname as 'column',
					@command as 'command',
					@holdtablename as 'holdtable' ,
					@holdindexid  as 'holdindex',
					@more_columns as 'more_columns'
				end
				
				if @@fetch_status <> 0 
				begin
					select @command = @command + ' )' + @carriage + @linefeed + ' GO'
					insert #commands values ( @holdtablename, @holdindexid,2,1, @command)
                                          select @command = ''
					 select @command = 'if exists (select * from dbo.sysindexes where name = ''' + @holdindexname + ''' and id = object_id(''' + @holdtablename + '''))' + @carriage + @linefeed +
                 				'print ''<<<< ' + @holdtablename + '.' + @holdindexname +  '   Successfully Created  >>>> '' ' + @carriage + @linefeed +
                				 'go' 
                                       	insert #commands values (@holdtablename, @holdindexid, 2,2, @command)
					select @more_columns = 1
				end
				
				else if @holdtablename <> @tablename or @holdindexid <> @indexid
				begin
					select @command = @command + ' )' + @carriage + @linefeed + ' GO'
					insert #commands values ( @holdtablename, @holdindexid,2,1, @command)
                                          select @command = ''
					 select @command =  'if exists (select * from dbo.sysindexes where name = ''' + @holdindexname + ''' and id = object_id(''' + @holdtablename + '''))' + @carriage + @linefeed +
                 				'print '' <<<< ' + @holdtablename + '.' + @holdindexname +  '   Successfully Created  >>>> '' ' + @carriage + @linefeed +
                				 'go' 
                                       
           				insert #commands values (@holdtablename, @holdindexid, 2,2, @command)
					select @more_columns = 1
                                        if @holdtablename <> @tablename
                                        begin
						select @more_indexes = 1
                                        end
				end
				
				else
				begin
					select @command = @command + ', '
				end
				
				select @holdtablename = @tablename, @holdindexid = @indexid, @holdindexname = @indexname
		end
		
	end
     end

     select @more_indexes = 0
	
end
		
close ind_list

deallocate ind_list

-- now format the output

select indexcmd from #commands
order by tablename, cmdtype, indexid, cmdsubtype



