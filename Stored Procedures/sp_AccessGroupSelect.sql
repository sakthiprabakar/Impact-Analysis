CREATE PROCEDURE [dbo].[sp_AccessGroupSelect] 
    @group_id INT = NULL,
    @description varchar(500) = NULL,
    @permission_security_type varchar(10) = NULL
/*	
	Description: 
	Selects single (given id) or searches (given criteria) for AccessGroup

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	BEGIN TRAN

	-- select all or a single record
	IF (@group_id IS NULL and @description IS NULL) Or @group_id IS NOT NULL
	BEGIN
		SELECT *
		FROM   [dbo].[AccessGroup] 
		WHERE  (@group_id IS NULL OR [group_id] = @group_id) 
		AND status = 'A'
		AND COALESCE(permission_security_type,'') = COALESCE(@permission_security_type, COALESCE(permission_security_type,''))
		ORDER BY group_description
	END
	
	-- do a search
	IF @description IS NOT NULL
	BEGIN
		SELECT *
		FROM   [dbo].[AccessGroup] 
		WHERE  group_description LIKE '%' + @description + '%'
		AND status = 'A'
		AND COALESCE(permission_security_type,'') = COALESCE(@permission_security_type, COALESCE(permission_security_type,''))
		ORDER BY group_description
	END

	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelect] TO [EQAI]
    AS [dbo];

