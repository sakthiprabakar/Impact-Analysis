CREATE PROCEDURE [dbo].[sp_AccessPermissionSet_Delete] 
    @set_id int,
    @modified_by varchar(50)
/*	
	Description: 
	Deletes an AccessPermissionSet

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	UPDATE AccessPermissionSet 
		SET status = 'I',
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()
		WHERE set_id = @set_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Delete] TO [EQAI]
    AS [dbo];

