
/***************************************************************************************
Creates (set status = A) a customer/contact relationship

10/1/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_customerxContact_delete 2222, 1243
****************************************************************************************/
create procedure spw_customerxContact_add
	@Customer_ID	int,
	@Contact_ID	int
AS
	DECLARE @Num	int
	set nocount on
	Select @Num = count(*) from CustomerXContact where Customer_ID = @Customer_ID and Contact_ID = @Contact_ID
	if @Num = 0
		Insert into CustomerXContact (Customer_ID, Contact_ID, Status) values (@Customer_ID, @Contact_ID, 'A')
	else
		begin
			Delete from CustomerXContact where Customer_ID = @Customer_ID and Contact_ID = @Contact_ID
			Insert into CustomerXContact (Customer_ID, Contact_ID, Status) values (@Customer_ID, @Contact_ID, 'A')
		end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_add] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_add] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customerxContact_add] TO [EQAI]
    AS [dbo];

