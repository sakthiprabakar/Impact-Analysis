CREATE PROCEDURE [dbo].[sp_AccessUserGroup_Delete] 
    @group_id int,
    @user_id int,
    @modified_by varchar(50) /*placeholder for trace table */
/*	
	Description: 
	removes a user from a group

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	DELETE
	FROM   [dbo].[AccessUserXGroup]
	WHERE  [group_id] = @group_id
	       AND [user_id] = @user_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessUserGroup_Delete] TO [EQAI]
    AS [dbo];

