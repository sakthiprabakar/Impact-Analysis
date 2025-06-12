create procedure sp_sequence_neg
	@name	varchar(50),
	@select int = 1
as
/***************************************************************************************
Copied and modified from sp_sequence_next
Returns the next negative item in a sequence, and decrements the sequence
Exists on:
	plt_ai

Notes:	This SP will take an optional 2nd parameter, to force no SELECT @result, so...
	WHEN THE WCR PROCESS IS REBUILT, GET RID OF (DROP) SP_SEQUENCE_SILENT_NEXT
	and use this one instead.
	This SP does not create the sequence if it doesn't exist.  That helps avoid typos.

04/25/2006 MK	Created
11/03/2006	JPB	Modified to remove mode-checking (now it's mode specific - dev/test/prod)
				Also added retry system to try and avoid 'sequence was not updated' errors
				(error occured when 2 users simultaneously hit the table, both updated,
				and the nextvalue-1 check afterward failed for 1)
10/01/2007 WAC	Removed references to a database server since the procedure will be executed on the 
		server that it resides on.

sp_sequence_neg 'form.temp_form_id'
****************************************************************************************/
set nocount on
set xact_abort on

declare @nextvalue int, 
	@error varchar(255), 
	@tries int
	
set @error = ''
set @tries = 1

decrement:
begin transaction sequence_next

if not exists (select 1 from sequence where name = @name)
	set @error = 'SEQUENCE ''' + @name + ''' DOES NOT EXIST.'
else
begin

	update sequence set @nextvalue = next_value, next_value = next_value - 1 where name = @name

	if (@nextvalue - 1) <> (select next_value from sequence where name = @name)
		set @error = 'SEQUENCE WAS NOT UPDATED IN DATABASE.'
end

if @error = ''
	commit transaction sequence_next
else
begin
	rollback transaction sequence_next
	if @tries <= 5
	begin
		set @error = ''
		set @tries = @tries + 1
		goto decrement
	end
end

set xact_abort off

if @error = ''
	select @nextvalue as next where @select <> 0
else
begin
	set @nextvalue = null
	select @error as next where @select <> 0
end
set nocount off

return @nextvalue

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_neg] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_neg] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_neg] TO [EQAI]
    AS [dbo];

