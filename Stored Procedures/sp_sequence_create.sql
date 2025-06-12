CREATE PROCEDURE sp_sequence_create
	@name	varchar(50),
	@seed	int
AS
/***************************************************************************************
Creates a sequence if it does not already exist
Exists on:
	plt_ai

Notes:
	This SP does not create the sequence if it already exists.  That helps avoid resets.

09/15/2003 JPB	Created
08/29/2005 JPB  Altered to change CURRENT_VALUE to NEXT_VALUE, and add mode detection.
11/03/2006 JPB	Modified so it's mode-specific, not switching.
10/01/2007 WAC	Removed references to a database server since the procedure will be executed on the 
		server that it resides on.

sp_sequence_create 'Jason.ID', 13
****************************************************************************************/
set nocount on
set xact_abort on

declare @nextvalue int, 
	@error varchar(255)
	
set @error = ''

begin transaction sequence_next
	select @nextvalue = next_value from sequence where name = @name
	if @nextvalue is not null
		set @error = 'sequence ''' + @name + ''' already exists.'
	else
	begin
		insert sequence (name, next_value) values (@name, @seed)
		if (@seed) <> (select next_value from sequence where name = @name)
			set @error = 'sequence was not inserted in database.'
	end
	
if @error = ''
	commit transaction sequence_next
else
	rollback transaction sequence_next
	
set xact_abort off

if @error = ''
	select @seed as next
else
begin
	set @seed = null
	select @error as next
end
set nocount off
return @seed

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_create] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_create] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_create] TO [EQAI]
    AS [dbo];

