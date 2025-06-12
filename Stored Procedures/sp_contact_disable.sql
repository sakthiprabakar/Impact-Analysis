
/************************************************************
Procedure    : sp_contact_disable
Database     : plt_ai*
Created      : Mon Jun 05 10:01:29 EDT 2006 - Jonathan Broome
Description  : Sets a contact's contact_status to 'I'nactive,
		and cascades to other contact related tables to update
		their related status fields

sp_contact_disable 96245, 'JONATHAN'
************************************************************/
Create Procedure sp_contact_disable (
	@contact_id	int,
	@added_by	char(10),
	@debug		int = 0
)
AS

	if @contact_id is null return

	if (select count(*) from contactxref where status = 'A' and contact_id = @contact_id) = 0 return

	declare @note_id int, @changelog varchar(8000)

	-- Log the existing contactxref settings for this contact
	select @changelog = coalesce(@changelog + ', ', '') + 'Customer: ' + cast(customer_id as varchar(10)) + ', (FROM) Status=' + isnull(status, 'I') + ', Web_Access=' + isnull(web_access, 'I') + ', Primary_Contact=' + isnull(primary_contact, 'F') + ' (TO) Status=I, Web_Access=I, Primary_Contact=F; '
	from contactxref
	where contact_id = @contact_id
	and type = 'C'
	order by customer_id
	select @changelog = coalesce(@changelog + ', ', '') + 'Generator: ' + cast(generator_id as varchar(10)) + ', (FROM) Status=' + isnull(status, 'I') + ', Web_Access=' + isnull(web_access, 'I') + ', Primary_Contact=F (TO) Status=I, Web_Access=I, Primary_Contact=F; '
	from contactxref
	where contact_id = @contact_id
	and type = 'G'
	order by generator_id

	set @changelog = ltrim(rtrim(@changelog))

	update contact set
		contact_status = 'I'
	where
		contact_id = @contact_id

	update contactxref set
		status = 'I',
		web_access = 'I',
		primary_contact = 'F'
	where
		contact_id = @contact_id

	exec @note_id = sp_sequence_next 'Note.Note_ID'

	if @debug <> 0 print 'Inserting note (' + convert(varchar(10), @note_id) + ') to indicate contact being disabled.'

	Insert Note (
		note_id,
		note_source,
		note_date,
		subject,
		status,
		note_type,
		note,
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
		'C',
		'AUDIT',
		'Contact Disabled. contact.contact_status = ''I''.  ContactXref changes: ' + isnull(@changelog, '(none)'),
		@contact_id,
		@added_by,
		getdate(),
		@added_by,
		getdate(),
		'WEB',
		newid()
	)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_disable] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_disable] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_disable] TO [EQAI]
    AS [dbo];

