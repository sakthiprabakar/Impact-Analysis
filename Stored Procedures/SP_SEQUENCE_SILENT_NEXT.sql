
/***************************************************************************************
Returns the next item in a sequence, and increments the sequence.
Does so silently - no output, just a return code.

09/15/2003 JPB	Created
12/14/2012	JPB	Revised update logic so the update is in a single statement to try and avoid
	cases where nearby executions can hit the same number during the time between a retrieve
	and an increment

Test Cmd Line: sp_sequence_silent_next 'customer.customer_id'
****************************************************************************************/
CREATE PROCEDURE SP_SEQUENCE_SILENT_NEXT
	@name	varchar(50)
as
	declare @nextvalue int
	start:
	set nocount on
	
	if not exists(select 1 from sequence where name = @name)
		insert into sequence (name, next_value) values (@name, 0)
		
	-- update sequence set next_value = next_value + 1 where name = @name
	update sequence set @nextvalue = next_value, next_value = next_value + 1 where name = @name
	
	set nocount off
	return @nextvalue

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_SEQUENCE_SILENT_NEXT] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_SEQUENCE_SILENT_NEXT] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_SEQUENCE_SILENT_NEXT] TO [EQAI]
    AS [dbo];

