CREATE PROCEDURE [dbo].[sp_AccessPermissionSet_Update] 
    @set_id int,
    @display_order int,
    @set_name varchar(255),
    @status char(1),
	@modified_by varchar(50)
/*	
	Description: 
	Updates PermissionSet

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	UPDATE [dbo].[AccessPermissionSet]
	SET    
		[display_order] = @display_order,
		[set_name] = @set_name,
		[status] = @status,
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()   
	WHERE  
	[set_id] = @set_id 
	
	exec sp_AccessPermissionSet_Select @set_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Update] TO [EQAI]
    AS [dbo];

