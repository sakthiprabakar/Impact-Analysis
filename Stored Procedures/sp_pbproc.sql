/****** Object:  Stored Procedure dbo.sp_pbproc    Script Date: 9/24/2000 4:20:31 PM ******/
/*
**  4 - PB stored procedure that retrieves proc info
**     from the catalog
*/
create proc sp_pbproc
@procid int = NULL ,
@procnumber smallint = NULL  as
if @procid = null
begin
select o.id, o.name, o.uid, user_name(o.uid),
p.number from dbo.sysobjects o, dbo.sysprocedures p
where o.type = 'P' and p.sequence = 0 and o.id = p.id
end
else
begin
select name, type, length, colid from dbo.syscolumns
where (id = @procid and number = @procnumber)
end
return
