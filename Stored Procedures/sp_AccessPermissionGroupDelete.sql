CREATE PROCEDURE [dbo].[sp_AccessPermissionGroupDelete] 
    @permission_id int,
    @group_id int,
    @action_id int
AS 
	DELETE
	FROM   [dbo].[AccessPermissionGroup]
	WHERE  [permission_id] = @permission_id
	       AND [group_id] = @group_id
	       AND [action_id] = @action_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupDelete] TO [EQAI]
    AS [dbo];

