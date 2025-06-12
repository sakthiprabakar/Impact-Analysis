CREATE PROCEDURE [dbo].[sp_AccessGroupUpdate] 
    @group_id int,
    @group_description varchar(500),
    @status char(1),
    --@permission_security_type varchar(10),
    @modified_by varchar(50)
/*	
	Description: 
	Updates group information

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit fields
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	UPDATE [dbo].[AccessGroup]
	SET    [group_id] = @group_id, 
	[group_description] = @group_description, 
	[status] = @status,
	--[permission_security_type] = @permission_security_type,
	[modified_by] = @modified_by,
	[date_modified] = getdate()
	WHERE  [group_id] = @group_id
	
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[AccessGroup]
	WHERE  [group_id] = @group_id	
	-- End Return Select <- do not remove


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupUpdate] TO [EQAI]
    AS [dbo];

