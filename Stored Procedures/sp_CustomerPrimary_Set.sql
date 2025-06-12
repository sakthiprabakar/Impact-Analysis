
/***************************************************************************************
Sets a Primary Contact for a Company

10/08/2003 JPB	Created
06/01/06   RG   revised for contactxref

Test Cmd Line: sp_CustomerPrimary_Set 1001, 2222, 2, 'Jonathan'
****************************************************************************************/
create procedure sp_CustomerPrimary_Set
	@Contact_ID	int,
	@Customer_ID	int,
	@Company_ID	int,
	@By	varchar(10)
AS

	declare @intCount	int
	
	select @intCount = count(*) from ContactXRef
	where customer_id = @Customer_ID
	and type = 'C'
	and primary_contact = 'T'
        and contact_id = @contact_id

	if @intCount = 0
	begin
		
		update ContactXRef 
		set primary_contact = 'F'
		where customer_id = @Customer_ID
		and type = 'C'
                and primary_contact = 'T'

		update ContactXRef 
		set primary_contact = 'T'
		where customer_id = @Customer_ID
		and type = 'C' 
		and contact_id = @contact_id
		
		set nocount on
		declare @noteID int
		declare @Changes varchar(1000)
		declare @contactname varchar(50)
		
		select @contactname = name from Contact where contact_id = @contact_id
		set @Changes = 'Primary Contact for ' + convert(varchar(10), @Customer_ID) + ' set to #' + convert(varchar(10), @Contact_ID) + ' (' + @contactname + ')'
		exec @noteID = sp_sequence_next 'Note.Note_ID'
		insert into Note (
		note_id, note_source, company_id, note_date, subject, status, note_type, note, customer_id, contact_id, contact_type,  date_added, added_by, modified_by, date_modified, app_source ) 
		values (
		@noteID, 'Customer', @company_id, GETDATE(), 'AUDIT','O', 'AUDIT', @changes, @customer_id, @contact_id, null,          GETDATE(), @by,       @by,        getdate(),      'EQAI')
	
		set nocount off
	end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerPrimary_Set] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerPrimary_Set] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerPrimary_Set] TO [EQAI]
    AS [dbo];

