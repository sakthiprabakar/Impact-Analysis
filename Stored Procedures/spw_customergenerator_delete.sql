
/***************************************************************************************
Removes a Customer-Generator relationship

09/15/2003 JPB	Created
01/07/2005 JPB Altered to handle generator_id
Test Cmd Line: spw_customergenerator_delete '123456789012', 2222, 'jonathan'
****************************************************************************************/
create procedure spw_customergenerator_delete
	@generator_id int,
	@customer_ID	int,
	@by	varchar(10)
as
	declare @num int

	select @num = count(*) from customergenerator where generator_id = @generator_id and customer_ID = @customer_ID
	if 1 <= @num
	begin
		delete from customergenerator where generator_id = @generator_id and customer_ID = @customer_ID
		declare @noteID int
		declare @Changes varchar(1000)
		set @Changes = 'Generator_ID: ' + @generator_id + ' removed from Customer_ID: ' + convert(varchar(10), @Customer_ID)
		exec @noteID = sp_sequence_next 'CustomerNote.Note_ID'
		insert into customernote (customer_id, note_id, note, contact_date, note_type, contact_type, added_from_company, modified_by, date_added, date_modified, contact_id, status, added_by, subject, action_type, recipient, send_email_date, cc_list, note_group_id)
		values (@customer_id, @noteID, @Changes, GETDATE(), 'AUDIT', 'AUDIT', 2, @By, GETDATE(), GETDATE(), NULL, 'O', @By, NULL, 'None', NULL, NULL, NULL, NULL)
	end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customergenerator_delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customergenerator_delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customergenerator_delete] TO [EQAI]
    AS [dbo];

