/****** Object:  Stored Procedure dbo.sp_pbprimarykey    Script Date: 9/24/2000 4:20:31 PM ******/
/*
** 8 - PB stored procedure that retrieves primary key info
**     from the catalog
*/
create procedure sp_pbprimarykey
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
**  See if the object has a primary key
*/
begin
select k.keycnt,
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
and k.type = 1 and k.id = @tabid
return
end
