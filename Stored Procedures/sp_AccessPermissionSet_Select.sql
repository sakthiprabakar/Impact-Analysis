CREATE PROCEDURE [dbo].[sp_AccessPermissionSet_Select] 
    @set_id INT = NULL,
    @set_name varchar(255) = NULL
/*	
	Description: 
	Selects or searches for PermissionSet (passing the id or set name criteria)

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	IF (@set_id IS NULL and @set_name IS NULL) OR @set_id IS NOT NULL
	BEGIN	
		SELECT 
			[set_id], 
			[display_order], 
			[set_name],
			[status]
		FROM   
			[dbo].[AccessPermissionSet] 
		WHERE  ([set_id] = @set_id OR @set_id IS NULL) 
		AND status = 'A'
		ORDER BY set_name ASC		
	END


	IF @set_name IS NOT NULL
	BEGIN
		SELECT 
			[set_id], 
			[display_order], 
			[set_name] 
		FROM   
			[dbo].[AccessPermissionSet] 
		WHERE  set_name LIKE '%' + @set_name + '%'		
		ORDER BY set_name ASC			
	END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Select] TO [EQAI]
    AS [dbo];

