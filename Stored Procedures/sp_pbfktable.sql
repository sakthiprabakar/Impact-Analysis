/****** Object:  Stored Procedure dbo.sp_pbfktable    Script Date: 9/24/2000 4:20:31 PM ******/
/*
**  10 - PB stored procedure that retrieves table info
**       from foreign keys referencing the current table
*/
create procedure sp_pbfktable
@tblname varchar(60) = NULL as
declare @objid int
if @tblname = null
return
else
begin
select @objid = object_id(@tblname)
select name, id, type, uid, user_name(uid) from sysobjects
where id in (select k.id from syskeys k where k.depid =
@objid) 
end
return
