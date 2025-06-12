
/***************************************************************************************
Retrieves the available Action Types

09/15/2003 JPB	Created
Test Cmd Line: spw_getactiontypes
****************************************************************************************/
create procedure spw_getactiontypes
AS
	select action_type, action_type from ActionType

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getactiontypes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getactiontypes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getactiontypes] TO [EQAI]
    AS [dbo];

