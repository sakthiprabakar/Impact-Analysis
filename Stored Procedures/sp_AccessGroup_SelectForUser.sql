CREATE PROCEDURE [dbo].[sp_AccessGroup_SelectForUser] 
    @user_id INT,
    @group_id int = NULL -- if specified, it will return a record if the user is in this group
    
/*	
	Description: 
	Selects all of the group access for the specified user_id

	Revision History:
	??/01/2009	RJG 	Created
	sp_Access_GetAccessList
	exec sp_AccessGroup_SelectForUser 1206
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	BEGIN TRAN

	SELECT	DISTINCT ag.*
	FROM   [dbo].[AccessGroup] ag
	INNER JOIN [AccessGroupSecurity] ags ON ag.group_id = ags.group_id
	WHERE  (ags.user_id = @user_id ) 
	and ags.group_id = COALESCE(@group_id, ags.group_id)
	AND ag.status = 'A'
	AND ags.status = 'A'
	ORDER BY group_description

	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectForUser] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectForUser] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectForUser] TO [EQAI]
    AS [dbo];

