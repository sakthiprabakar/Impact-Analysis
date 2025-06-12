CREATE PROCEDURE [dbo].[sp_AccessPermissionDelete] 
    @permission_id int,
    @modified_by varchar(50)
/*	
	Description: 
	Deactivates permission info

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	UPDATE AccessPermission 
		SET status='I',
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()
	WHERE permission_id = @permission_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionDelete] TO [EQAI]
    AS [dbo];

