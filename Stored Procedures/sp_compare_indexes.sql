
create procedure sp_compare_indexes @db_from varchar(30), @db_to varchar(30) as

--sp_compare_indexes 'plt_02_ai', 'plt_21_ai'
create table #from_indexes ( tableid int null,
                        tablename varchar(60) null,
                        indexname varchar(60) null )

create table #to_indexes ( tableid int null,
                        tablename varchar(60) null,
                        indexname varchar(60) null )


declare @sql varchar(2000)


select @sql = 'insert #from_indexes ' +               
' select o.id, o.name , i.name from ' + @db_from + '.dbo.sysindexes i ,' + @db_from + '.dbo.sysobjects o ' +
' where  o.id = i.id ' + 
' and i.status NOT IN ( 0,2, 8, 3, 18, 10485856, 8388704) ' 



execute (@sql)

-- now get the to


select @sql = 'insert #to_indexes ' +               
' select o.id, o.name , i.name from ' + @db_to + '.dbo.sysindexes i ,' + @db_to + '.dbo.sysobjects o ' +
' where  o.id = i.id ' + 
' and i.status NOT IN ( 0,2, 8, 3, 18, 10485856, 8388704) ' 




execute (@sql)

select  'Not in ' + @db_to as 'compared',
        f.tableid ,
        f.tablename,
        f.indexname
from #from_indexes f
where not exists ( select 1 from #to_indexes t where
                   f.tablename = t.tablename
                and f.indexname = t.indexname
                 )

union 


select  'Not in ' + @db_from as 'compared',
        f.tableid ,
        f.tablename,
        f.indexname
from #to_indexes f
where not exists ( select 1 from #from_indexes t where
                   f.tablename = t.tablename
                and f.indexname = t.indexname
                 )

order by f.tablename, f.indexname
       


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_compare_indexes] TO [EQAI]
    AS [dbo];

