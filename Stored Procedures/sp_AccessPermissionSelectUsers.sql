
CREATE PROCEDURE sp_AccessPermissionSelectUsers
	@permission_id int
/*	
	Description: 
	Select users / contacts who have access to a given permission.
	Returns generic user/contact information that is common to both

	Revision History:
	??/01/2009	RJG 	Created
	06/27/2012  JPB		Updated to use AccessGroupSecurity table
	
	
	sp_AccessPermissionSelectUsers 195
	
*/			
AS
  
	SELECT 
		u.user_id as id, 
		u.user_name as username, 
		u.email, 
		'A' as user_type 
	FROM AccessPermissionGroup apg 
		INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
		INNER JOIN AccessGroupSecurity aug ON apg.group_id = aug.group_id
		INNER JOIN Users u ON aug.user_id = u.user_id and u.group_id <> 0
	WHERE apg.permission_id = @permission_id

	UNION -- ALL
		
	SELECT c.contact_id as id,   
		c.name as username,   
		c.email,   
		'C' as user_type    
	FROM AccessPermissionGroup apg 
		INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
		INNER JOIN AccessGroupSecurity aug ON apg.group_id = aug.group_id
		INNER JOIN Contact c ON aug.contact_id = c.contact_id
	WHERE apg.permission_id = @permission_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelectUsers] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelectUsers] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelectUsers] TO [EQAI]
    AS [dbo];

