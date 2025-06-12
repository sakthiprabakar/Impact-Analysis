/****** Object:  Stored Procedure dbo.sp_pbcolumn    Script Date: 9/24/2000 4:20:31 PM ******/
/*
**  1 - PB stored procedure that retrieves column info
**     from the catalog
*/
create proc sp_pbcolumn @id int as
select colid, status, type, length, name, usertype
from dbo.syscolumns  where id = @id
