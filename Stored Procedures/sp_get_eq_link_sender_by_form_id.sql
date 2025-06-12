
create proc sp_get_eq_link_sender_by_form_id (
	@form_id int
)
as
/* *****************************************************************************
sp_get_eq_link_sender_by_form_id

	Retrives the EQ email address for the associate who created a link
	requested by form_id (intended to be used when a form is signed and we need
	to email a confirmation to whoever created the link to that form and is
	in the EQ Users table)

sp_get_eq_link_sender_by_form_id 209564

History:
	01/23/2013 - JPB - Created
	
***************************************************************************** */

select top 1 u.email --, l.*, f.*
from users u
inner join link l on (u.user_code = l.added_by or u.email = l.added_by)
inner join formheaderdistinct f on l.form_id = f.form_id and l.link_type = f.type
where f.locked = 'L'
and f.form_id = @form_id
order by l.date_added desc

