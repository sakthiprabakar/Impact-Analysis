/****** Object:  Stored Procedure dbo.sp_pbtext    Script Date: 9/24/2000 4:20:32 PM ******/
/*
**  7 - PB stored procedure that retrieves comments info
**     from the catalog
*/
create procedure sp_pbtext
@objid  int ,
@number smallint = NULL
as
if (@number = NULL)
select text  from dbo.syscomments where id = @objid
else
select text  from dbo.syscomments where
(id = @objid and number = @number)
return
