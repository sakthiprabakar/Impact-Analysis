/*
-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

create procedure spw_getcustomerxcompany_related
	@Customer_ID	int
As
/-***************************************************************************************
Retrieves all CustomerXCompany info for Customers related to Contacts of a single Customer

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
10/01/2007 WAC	Changed table EQAIConnect to EQConnect

Test Cmd Line: spw_getcustomerxcompany_related 2222
****************************************************************************************-/

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

	select customerxcompany.customer_ID, eqconnect.company_name, 
	contact.contact_ID, contact.name 
	from customerxcompany
	left join eqconnect
		on customerxcompany.company_id = eqconnect.company_id
		and eqconnect.visible_flag = 1
		and eqconnect.db_type = 'prod'
	left join contact
		on customerxcompany.primary_contact_id = contact.contact_id
	where customerxcompany.customer_ID in (
		select customer.customer_ID
		from contact
		left join customerxcontact 
			on contact.contact_id = customerxcontact.contact_id
		left join customer
			on customerxcontact.customer_id = customer.customer_id
		where contact.contact_id in (select contact_id from customerxcontact where customer_id in (
			select customer_id from #TempCompanies
			)
		)
	)
	for xml auto


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomerxcompany_related] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomerxcompany_related] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomerxcompany_related] TO [EQAI]
    AS [dbo];

*/
