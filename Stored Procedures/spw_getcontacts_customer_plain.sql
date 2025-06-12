/***************************************************************************************
Lists Contacts for a specific Customer (non XML output)

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_getcontacts_customer_plain 2222
****************************************************************************************/
create procedure spw_getcontacts_customer_plain
	@customer_id int
as

	select customer.cust_name, Contact.contact_id, Contact.name
	from customer
	inner join customerxContact x
		on (customer.customer_id = x.customer_id and x.status = 'A')
	inner join Contact
		on (x.contact_id = Contact.contact_id and Contact.contact_status = 'A')
	where customer.customer_id = @customer_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer_plain] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer_plain] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_customer_plain] TO [EQAI]
    AS [dbo];

