
/***************************************************************************************
Deletes (set status = I) a customer/contact relationship

10/1/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_customerxContact_delete 2222, 1243
****************************************************************************************/
create procedure spw_customerxContact_delete
	@Customer_ID	int,
	@Contact_ID	int
AS
	update CustomerXContact set status = 'I' where Customer_ID = @Customer_ID and Contact_ID = @Contact_ID



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_delete] TO [EQAI]
    AS [dbo];

