CREATE PROCEDURE [dbo].[sp_sequence_next]
	@name	varchar(50),
	@select int = 1
AS
/***************************************************************************************
Returns the next item in a sequence, and increments the sequence
Exists on:
	plt_ai

Notes:
	This SP will take an optional 2nd parameter, to force no SELECT @result, so...
	WHEN THE WCR PROCESS IS REBUILT, GET RID OF (DROP) SP_SEQUENCE_SILENT_NEXT
	and use this one instead.
	This SP does not create the sequence if it doesn't exist.  That helps avoid typos.

09/15/2003 JPB	Created
08/29/2005 JPB  Altered a LOT (added mode checking, proper trans usage, silent mode)
11/03/2006 JPB	Modified to remove mode-checking (now it's mode specific - dev/test/prod)
		Also added retry system to try and avoid 'sequence was not updated' errors
		(error occured when 2 users simultaneously hit the table, both updated,
		and the nextvalue+1 check afterward failed for 1)
10/01/2007 WAC	Removed references to a database server since the procedure will be executed on the 
		server that it resides on.
12/14/2012	JPB	Revised update logic so the update is in a single statement to try and avoid
	cases where nearby executions can hit the same number during the time between a retrieve
	and an increment
08/29/2018 GSO Added grant statements used by OnBase application to send messages
08/30/2018 GSO Added grant statements used by AESOP_IMAGE_SERVICE application to get sequences	

select * from sequence where name = 'ScanImage.image_id'
sp_sequence_next 'form.form_id'
select * from sequence
sp_sequence_next 'Note.note_id', 0 -- zero = silent
****************************************************************************************/
set nocount on
set xact_abort on

declare @nextvalue int, 
	@error varchar(255), 
	@tries int
	
set @error = ''
set @tries = 1

increment:
begin transaction sequence_next
select @nextvalue = next_value from sequence where name = @name
if @nextvalue is null
	set @error = 'SEQUENCE ''' + @name + ''' DOES NOT EXIST.'
else
begin

	-- update sequence set next_value = next_value + 1 where name = @name
	update sequence set @nextvalue = next_value, next_value = next_value + 1 where name = @name
		
	if (@nextvalue + 1) <> (select next_value from sequence where name = @name)
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
		goto increment
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
    ON OBJECT::[dbo].[sp_sequence_next] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_next] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_next] TO [AESOP_IMAGE_SERVICE]
    AS [dbo];


GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_next] TO [Svc_OnBase_SQL]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_next] TO [EQAI]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sequence_next] TO [eqlogin]
    AS [dbo];

