/***************************************************************************************
Retrieves Contact Info for a Customer Hierarchy, non-xml

09/15/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_getcontacts_related_customer_plain 2222
****************************************************************************************/
create procedure spw_getcontacts_related_customer_plain
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
	
	-- Turn NOCOUNT back OFF
	SET NOCOUNT OFF

	select customerxContact.contact_ID, 
	case when customer.customer_id <= 999999 then
	right('000000' + convert(varchar(8), customer.customer_id),6) + ' - ' + Contact.name
	else
	convert(varchar(8), customer.customer_id) + ' - ' + Contact.name
	end
	from customer 
	left outer join CustomerXContact 
		on customer.customer_ID = CustomerXContact.customer_ID
	left join Contact 
		on CustomerXContact.contact_ID = Contact.contact_ID
	where customer.customer_id in (select customer_ID from #TempCompanies)
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_related_customer_plain] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_related_customer_plain] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcontacts_related_customer_plain] TO [EQAI]
    AS [dbo];

