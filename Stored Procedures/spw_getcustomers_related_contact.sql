/***************************************************************************************
Retrieves all Customers related to a single Contact

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_getcustomers_related_contact 1243
****************************************************************************************/
create procedure spw_getcustomers_related_contact
	@contact_ID	int
As

	select contact.contact_ID, customer.customer_ID, customer.cust_name, customerxcontact.status
	from contact
	left join customerxcontact 
		on contact.contact_id = customerxcontact.contact_id
	left join customer
		on customerxcontact.customer_id = customer.customer_id
	where contact.contact_id = @contact_ID
	for xml auto



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related_contact] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related_contact] TO [EQAI]
    AS [dbo];

