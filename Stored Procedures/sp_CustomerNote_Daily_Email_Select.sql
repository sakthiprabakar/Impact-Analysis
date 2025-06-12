
/***************************************************************************************
Returns the notes & information necessary for sending daily note-based emails
Loads on PLT_AI

10/16/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: sp_CustomerNote_Daily_Email_Select
****************************************************************************************/
create procedure sp_CustomerNote_Daily_Email_Select
AS
	select customer.customer_id, customer.cust_name, customer.cust_phone, customer.cust_fax,
	contact.name, contact.title, contact.phone, contact.fax, contact.pager, contact.mobile, contact.email,
	customernote.*, 
	customernotedetail.*
	from customernote inner join customer on customernote.customer_id = customer.customer_id
	left outer join contact on customernote.contact_id = contact.contact_id
	left outer join customernotedetail on customernote.note_id = customernotedetail.note_id
		and customernotedetail.audit = 'F'
	where customernote.status = 'O' 
	and (customernote.send_email_date = getdate() or customernote.contact_date <= getdate())
	and customernote.note_type in ('reminder', 'actionitem', 'scheduledcall')
	order by customernote.note_id, customernotedetail.detail_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerNote_Daily_Email_Select] TO [EQAI]
    AS [dbo];

