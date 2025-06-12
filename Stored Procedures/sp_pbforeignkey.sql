/****** Object:  Stored Procedure dbo.sp_pbforeignkey    Script Date: 9/24/2000 4:20:31 PM ******/
/*
** 9 - PB stored procedure that retrieves foreign key info
**     from the catalog
*/
create procedure sp_pbforeignkey
@tabname varchar(92)                    /* the table to check for indexes */
as
declare @tabid int                      /* the object id of the table */
/*
**  Check to see the the table exists and initialize @objid.
*/
select @tabid = object_id(@tabname)
/*
**  Table doesn't exist so return.
*/
if @tabid is NULL
begin
return
end
else
/*
**  See if the object has any foreign keys
*/
begin
select k.keycnt, OBJECT_NAME(k.depid), 
(select USER_NAME(o.uid) from dbo.sysobjects o 
where o.id = @tabid),
objectkey1 = col_name(k.id, key1),
objectkey2 = col_name(k.id, key2),
objectkey3 = col_name(k.id, key3),
objectkey4 = col_name(k.id, key4),
objectkey5 = col_name(k.id, key5),
objectkey6 = col_name(k.id, key6),
objectkey7 = col_name(k.id, key7),
objectkey8 = col_name(k.id, key8)
from syskeys k, master.dbo.spt_values v
where  k.type = v.number and v.type =  'K'
and k.type = 2 and k.id = @tabid
return
end
