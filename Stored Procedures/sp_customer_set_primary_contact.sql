
/************************************************************
Procedure    : sp_customer_set_primary_contact
Database     : plt_ai*
Created      : Fri Jun 02 16:08:01 EDT 2006 - Jonathan Broome
Description  : sets the primary_contact field in contactxref
	as specified, and resets the other contacts associated with
	the same customer_id.  Adds notes for the contacts set and
	unset to note when they were changed, who did it, etc.

sp_customer_set_primary_contact 888888, 10001, 'JONATHAN', 1
sp_customer_set_primary_contact 888888, 10913, 'JONATHAN', 1

select * from contactxref where customer_id = 888888

select * from note where customer_id = 888888 order by date_added desc

************************************************************/
Create Procedure sp_customer_set_primary_contact (
	@customer_id	int,
	@contact_id		int,
	@added_by		char(10),
	@debug			int = 0
)
AS

	declare @old int, @note_id int

	if @debug <> 0 print 'Logging existing primary_contact'

	-- Log the existing primary_contact
	select @old = contact_id
	from contactxref
	where customer_id = @customer_id and primary_contact = 'T'

	if @debug <> 0 print 'Old Primary Contact: ' + isnull(convert(varchar(10),@old), '-1')
	if @debug <> 0 print 'New Primary Contact: ' + isnull(convert(varchar(10),@contact_id), '-1')

	if isnull(@old, -1) <> isnull(@contact_id, -1)
		begin
			if @debug <> 0 print 'Old Primary Contact <> New Primary Contact'

			exec @note_id = sp_sequence_next 'Note.Note_ID'

			if @debug <> 0 print 'Old Primary Contact <> New Primary Contact'

			if @debug <> 0 print 'Inserting changelog note (' + convert(varchar(10), @note_id) + ') on old primary contact'

			Insert Note (
				note_id,
				note_source,
				note_date,
				subject,
				status,
				note_type,
				note,
				customer_id,
				contact_id,
				added_by,
				date_added,
				modified_by,
				date_modified,
				app_source,
				rowguid
			) values (
				@note_id,
				'Contact',
				getdate(),
				'AUDIT',
				'O',
				'AUDIT',
				'un-selected as primary contact for customer ' + convert(varchar(10), @customer_id),
				@customer_id,
				@old,
				@added_by,
				getdate(),
				@added_by,
				getdate(),
				'WEB',
				newid()
			)

			exec @note_id = sp_sequence_next 'Note.Note_ID'

			if @debug <> 0 print 'Inserting changelog note (' + convert(varchar(10), @note_id) + ') on new contact'

			Insert Note (
				note_id,
				note_source,
				note_date,
				subject,
				status,
				note_type,
				note,
				customer_id,
				contact_id,
				added_by,
				date_added,
				modified_by,
				date_modified,
				app_source,
				rowguid
			) values (
				@note_id,
				'Contact',
				getdate(),
				'AUDIT',
				'O',
				'AUDIT',
				'selected as primary contact for customer ' + convert(varchar(10), @customer_id),
				@customer_id,
				@contact_id,
				@added_by,
				getdate(),
				@added_by,
				getdate(),
				'WEB',
				newid()
			)

			update contactxref set
			primary_contact = case when contact_id = @contact_id then 'T' else 'F' end
			where customer_id = @customer_id

		end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_set_primary_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_set_primary_contact] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_set_primary_contact] TO [EQAI]
    AS [dbo];

