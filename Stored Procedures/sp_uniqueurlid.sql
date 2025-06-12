/************************************************************
Procedure    : sp_uniqueurlid
Database     : plt_ai*
Created      : Tue Jul 05 13:21:43 EDT 2005 - Jonathan Broome
Description  : Returns a unique number for use in the Link table's URL_ID field
************************************************************/
Create Procedure sp_uniqueurlid (
	@output varchar(255) OUTPUT
)
AS

set nocount on

declare @NewID varchar(510),
		@count int,
		@unique int

set @unique = 1
set @output = ''
WHILE @unique > 0
BEGIN
	set @newID = convert(varchar(255), newid()) + convert(varchar(255), newid())
	set @Count = 1
	WHILE @count < len(@newid)
	BEGIN
		if isnumeric(substring(@newid, @count, 1)) = 1
			set @output = @output + substring(@newid, @count, 1)
		set @count = @count + 1
	END
	select @output = left(replace(@output, '-', ''),15)
	select @unique = count(*) from link where url_id = @output
END

set nocount off
-- select @output


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_uniqueurlid] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_uniqueurlid] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_uniqueurlid] TO [EQAI]
    AS [dbo];

