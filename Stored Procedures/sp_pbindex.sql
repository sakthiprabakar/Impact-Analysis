/****** Object:  Stored Procedure dbo.sp_pbindex    Script Date: 9/24/2000 4:20:31 PM ******/
/*
**  3 - PB stored procedure that retrieves index info
**     from the catalog
*/
create procedure sp_pbindex
@objname varchar(92)                    /* the table to check for indexes */
as
declare @objid int                      /* the object id of the table */
declare @indid int                      /* the index id of an index */
declare @key1 varchar(30)               /* first key  */
declare @key2 varchar(30)               /* second key  */
declare @key3 varchar(30)               /* third key  */
declare @key4 varchar(30)               /* fourth key  */
declare @key5 varchar(30)               /* ...  */
declare @key6 varchar(30)
declare @key7 varchar(30)
declare @key8 varchar(30)
declare @key9 varchar(30)               /* ...  */
declare @key10 varchar(30)
declare @key11 varchar(30)
declare @key12 varchar(30)
declare @key13 varchar(30)               /* ...  */
declare @key14 varchar(30)
declare @key15 varchar(30)
declare @key16 varchar(30)
declare @unique smallint                /* index is unique */
declare @clustered  smallint            /* index is clustered */
/*
**  Check to see the the table exists and initialize @objid.
*/
select @objid = object_id(@objname)
/*
**  Table doesn't exist so return.
*/
if @objid is NULL
begin
return
end
/*
**  See if the object has any indexes.
**  Since there may be more than one entry in sysindexes for the object,
**  this select will set @indid to the index id of the first index.
*/
select @indid = min(indid)
from sysindexes
where id = @objid
and indid > 0
and indid < 255
/*
**  If no indexes, return.
*/
if @indid is NULL
begin
return
end
/*
**  Now check out each index, figure out it's type and keys and
**  save the info in a temporary table that we'll print out at the end.
*/
create table #spindtab
(
index_name      varchar(30),
index_num       int,
index_key1      varchar(30) NULL,
index_key2      varchar(30) NULL,
index_key3      varchar(30) NULL,
index_key4      varchar(30) NULL,
index_key5      varchar(30) NULL,
index_key6      varchar(30) NULL,
index_key7      varchar(30) NULL,
index_key8      varchar(30) NULL,
index_key9      varchar(30) NULL,
index_key10     varchar(30) NULL,
index_key11     varchar(30) NULL,
index_key12     varchar(30) NULL,
index_key13     varchar(30) NULL,
index_key14     varchar(30) NULL,
index_key15     varchar(30) NULL,
index_key16     varchar(30) NULL,
index_unique    smallint,
index_clustered smallint
)
while @indid != NULL
begin
/*
**  First we'll figure out what the keys are.
*/
declare @i int
declare @thiskey varchar(30)
declare @lastindid int
select @i = 1
set nocount on
while @i <= 16
begin
select @thiskey = index_col(@objname, @indid, @i)
if @thiskey = NULL
begin
goto keysdone
end
if @i = 1
begin
select @key1 = index_col(@objname, @indid, @i)
end
else
if @i = 2
begin
select @key2 = index_col(@objname, @indid, @i)
end
else
if @i = 3
begin
select @key3 = index_col(@objname, @indid, @i)
end
else
if @i = 4
begin
select @key4 = index_col(@objname, @indid, @i)
end
else
if @i = 5
begin
select @key5 = index_col(@objname, @indid, @i)
end
else
if @i = 6
begin
select @key6 = index_col(@objname, @indid, @i)
end
else
if @i = 7
begin
select @key7 = index_col(@objname, @indid, @i)
end
else
if @i = 8
begin
select @key8 = index_col(@objname, @indid, @i)
end
else
if @i = 9
begin
select @key9 = index_col(@objname, @indid, @i)
end
else
if @i = 10
begin
select @key10 = index_col(@objname, @indid, @i)
end
else
if @i = 11
begin
select @key11 = index_col(@objname, @indid, @i)
end
else
if @i = 12
begin
select @key12 = index_col(@objname, @indid, @i)
end
else
if @i = 13
begin
select @key13 = index_col(@objname, @indid, @i)
end
else
if @i = 14
begin
select @key14 = index_col(@objname, @indid, @i)
end
else
if @i = 15
begin
select @key15 = index_col(@objname, @indid, @i)
end
else
if @i = 16
begin
select @key16 = index_col(@objname, @indid, @i)
end
/*
**  Increment @i so it will check for the next key.
*/
select @i = @i + 1
end
/*
**  When we get here we now have all the keys.
*/
keysdone:
set nocount off
/*
**  Figure out if it's a  clustered or nonclustered index.
*/
if @indid = 1
select @clustered = 1
if @indid > 1
select @clustered = 0
/*
**  Now we'll check out the status bits for this index
*/
/*
**  See if the index is unique (0x02).
*/
if exists (select *
from master.dbo.spt_values v, sysindexes i
where i.status & v.number = v.number
and v.type = "I"
and v.number = 2
and i.id = @objid
and i.indid = @indid)
select @unique = 1
else
select @unique = 0
/*
**  Now we have all the needed info for the index so we'll add
**  the goods to the temporary table.
*/
insert into #spindtab
select name, @i - 1, @key1, @key2, @key3, @key4,
@key5, @key6, @key7, @key8, @key9,
@key10, @key11, @key12, @key13, @key14,
@key15, @key16, @unique, @clustered
from sysindexes
where id = @objid
and indid = @indid
/*
**  Now move @indid to the next index.
*/
select @lastindid = @indid
select @indid = NULL
select @indid = min(indid)
from sysindexes
where id = @objid
and indid > @lastindid
and indid < 255
end
/*
**  Now print out the contents of the temporary index table.
*/
select index_name, index_num, index_key1, index_key2,
index_key3, index_key4, index_key5, index_key6,
index_key7, index_key8, index_key9, index_key10,
index_key11, index_key12, index_key13, index_key14,
index_key15, index_key16, index_unique, index_clustered
from #spindtab
drop table #spindtab
