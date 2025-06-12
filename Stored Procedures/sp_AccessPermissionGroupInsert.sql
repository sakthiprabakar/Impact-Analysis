CREATE PROCEDURE [dbo].[sp_AccessPermissionGroupInsert] 
    @permission_id int,
    @group_id int,
    @action_id int,
    @added_by varchar(50)
AS 

exec sp_AccessPermissionGroupDelete @permission_id, @group_id, @action_id

INSERT INTO [dbo].[AccessPermissionGroup]
            ([permission_id],
             [group_id],
             [action_id],
             [date_modified],
             [modified_by],
             [date_added],
             [added_by])
SELECT @permission_id,
       @group_id,
       @action_id,
       GETDATE(),
       @added_by,
       GETDATE(),
       @added_by 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupInsert] TO [EQAI]
    AS [dbo];

