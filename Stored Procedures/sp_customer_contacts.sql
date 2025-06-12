
/************************************************************
Procedure    : sp_customer_contacts
Database     : plt_ai*
Created      : Fri Jun 02 13:36:56 EDT 2006 - Jonathan Broome
Description  : Returns the contacts (active and inactive) for an input customer_id

************************************************************/
Create Procedure sp_customer_contacts (
	@customer_id	int
)
AS

	select
		c.*,
		x.status,
		x.web_access,
		x.primary_contact
	from contact c
		inner join contactxref x on c.contact_id = x.contact_id
	where
		x.customer_id = @customer_id
		order by x.status, c.name, c.last_name, c.first_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_contacts] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_contacts] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_contacts] TO [EQAI]
    AS [dbo];

