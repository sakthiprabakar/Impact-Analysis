/***************************************************************************************
Retrieves all Customers related to Contacts of a single Customer

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_getcustomers_related 2222
****************************************************************************************/
create procedure spw_getcustomers_related
	@Customer_ID	int
As

	SET NOCOUNT ON
	--Create a temporary table for companies
	CREATE TABLE #TempCompanies
	(
		Customer_ID	int
	)
	
	-- Fill it with this company's children id's (includes self)
	INSERT #TempCompanies (customer_ID) 
		EXEC spw_parent_getchildren_ids @Customer_ID, 0

	SET NOCOUNT OFF
	
	select contact.contact_ID, customer.customer_ID, customer.cust_name, customerxcontact.status
	from contact
	left join customerxcontact 
		on contact.contact_id = customerxcontact.contact_id
	left join customer
		on customerxcontact.customer_id = customer.customer_id
	where contact.contact_id in (
		select contact_id from customerxcontact where customer_id in (
			select customer_id from #TempCompanies
			)
		)
	for xml auto



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_related] TO [EQAI]
    AS [dbo];

