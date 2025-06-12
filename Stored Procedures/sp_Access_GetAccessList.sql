CREATE PROCEDURE [dbo].[sp_Access_GetAccessList]
	@user_id int = NULL,
	@contact_id int = NULL,
	@contact_type char(1) = NULL
/*	
	Description: 
	Returns multiple recordsets.  
	parameters.  

	Revision History:
	??/01/2009	RJG 	Created
	
	
	exec sp_Access_GetAccessList 1206, null, 'A'
*/		
	
AS
BEGIN
	SET NOCOUNT ON;
	
	
	
	--SELECT * FROM ProfitCenter
	declare @user_code varchar(50)
	
	IF @user_id IS NOT NULL
	BEGIN
		SELECT @user_code = user_code FROM users where user_id = @user_id
	END
			
			SELECT access.* FROM view_AccessByUser access WHERE access.user_id = @user_id
			ORDER BY display_order, action_id desc, report_name, link_text
			
			SELECT apg.permission_id,
                   apg.action_id,
                   ag.group_id,
                   ag.group_description,
                   ag.permission_security_type,
                   ag.status
            FROM   AccessPermissionGroup apg
                   INNER JOIN view_AccessByUser ar
                     ON ar.permission_id = apg.permission_id
                   INNER JOIN AccessGroup ag
                     ON apg.group_id = ag.group_id
            WHERE  ar.user_id = @user_id
                   AND ag.status = 'A' 
            
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_GetAccessList] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_GetAccessList] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Access_GetAccessList] TO [EQAI]
    AS [dbo];

