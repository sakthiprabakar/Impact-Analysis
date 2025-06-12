
create procedure sp_note_contact_type_select
	@contact_type_id int = null
as
begin

	SELECT * FROM NoteContactType nt
		where nt.contact_type_id  = coalesce(@contact_type_id, nt.contact_type_id)

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_contact_type_select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_contact_type_select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_contact_type_select] TO [EQAI]
    AS [dbo];

