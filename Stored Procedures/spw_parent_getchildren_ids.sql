/***************************************************************************************
Returns the customer_id's of the input's Hiearchical children

10/1/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_parent_getchildren_ids 25, 0
****************************************************************************************/
create procedure spw_parent_getchildren_ids
	@customer_ID	int,
	@contact_ID	int = 0
As

	if @customer_ID <= 0
		select top 1 @customer_ID = customer_ID from CustomerXcontact where contact_id = @contact_ID and status = 'A'

	select c1.customer_ID from CustomerTree as c1, CustomerTree as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_ID = @customer_ID



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_ids] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_ids] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_ids] TO [EQAI]
    AS [dbo];

