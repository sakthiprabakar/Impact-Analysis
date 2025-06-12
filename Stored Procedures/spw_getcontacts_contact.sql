/***************************************************************************************
Retrieves contact Info for a contact

09/15/2003 JPB	Created
11/15/2004 JPB  Changed Customercontact -> contact
07/07/2005	JPB	Added first_name/last_name changes

Test Cmd Line: spw_getcontacts_contact 1, 10, 1243, 'data'
****************************************************************************************/
create procedure spw_getcontacts_contact
	@Page int,
	@RecsPerPage int,
	@contact_ID	int,
	@Mode	varchar(15)
As

	IF @mode = 'data'
	BEGIN
		SELECT
		contact.contact_ID, contact.contact_status, contact.contact_type, contact.contact_company, contact.name, contact.salutation, contact.first_name, contact.middle_name, contact.last_name, contact.suffix, contact.title, contact.phone, contact.fax, contact.pager, contact.mobile, contact.comments, contact.email, contact.email_flag, contact.added_from_company, contact.modified_by, contact.date_added, contact.date_modified, contact.web_access_flag, contact.web_password, contact.contact_addr1, contact.contact_addr2, contact.contact_addr3, contact.contact_addr4, contact.contact_city, contact.contact_state, contact.contact_zip_code, contact.contact_country, contact.contact_personal_info, contact.contact_directions
		from contact
		where contact.contact_id = @contact_ID
		for xml auto
	END
	IF @mode = 'date-added'
	BEGIN
		SELECT max(contact.date_added)
		from contact
		where contact.contact_id = @contact_ID
	END
	IF @mode = 'count'
	BEGIN
		SELECT count(*) from contact where contact_id = @contact_ID
	END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_contact] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_contact] TO [EQAI]
    AS [dbo];

