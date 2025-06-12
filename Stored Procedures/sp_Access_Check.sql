
create procedure sp_Access_Check
	@user_id int = NULL,
	@user_code varchar(10) = NULL,
	@contact_id int = NULL,
	@permission_id int,
	@action_id int = NULL
	
	/*
		exec sp_Access_Check 1206, null, null, 122, 4
		exec sp_Access_Check 1206, null, null, 123, 4
	*/
AS
BEGIN

	if @user_id is null
		select @user_id = user_id from users where user_code = @user_code
		
	if @user_code is null
		select @user_code = user_code from users where user_id = @user_id
		

	SELECT DISTINCT apg.permission_id,
                    apg.action_id,
                    ag.group_id,
                    ag.group_description
    FROM   AccessPermissionGroup apg
           INNER JOIN AccessGroup ag
             ON apg.group_id = ag.group_id
           INNER JOIN AccessGroupSecurity ags
             ON ags.user_id = @user_id
                AND ags.group_id = apg.group_id
    WHERE  1 = 1
           AND apg.permission_id = @permission_id
           AND apg.action_id = COALESCE(@action_id, apg.action_id)
           AND ag.status = 'A' 
    ORDER BY apg.action_id DESC
    
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_Check] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_Check] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_Check] TO [EQAI]
    AS [dbo];

