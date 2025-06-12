/****** Object:  Stored Procedure dbo.sp_pbtable    Script Date: 9/24/2000 4:20:31 PM ******/
/*
**  6 - PB stored procedure that retrieves table info
**     from the catalog
*/
create procedure sp_pbtable
@tblname varchar(60) = NULL as
declare @objid int
if @tblname = null
select name, id, type, uid, user_name(uid) from sysobjects where
(type = 'S' or type = 'U' or type = 'V')
else
begin
select @objid = object_id(@tblname)
select name, id, type, uid, user_name(uid) from sysobjects
where id = @objid
end
return
