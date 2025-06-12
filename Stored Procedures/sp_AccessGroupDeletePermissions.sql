CREATE PROCEDURE [dbo].[sp_AccessGroupDeletePermissions] 
    @group_id INT = NULL,
    @modified_by varchar(50)
/*	
	Description: 
	Deletes the AccessPermissionGroup record for the group_id

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	DELETE FROM AccessPermissionGroup WHERE group_id = @group_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDeletePermissions] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDeletePermissions] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDeletePermissions] TO [EQAI]
    AS [dbo];

