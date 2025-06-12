CREATE PROCEDURE [dbo].[sp_AccessGroupDelete] 
    @group_id int,
    @modified_by varchar(50)
/*	
	Description: 
	Sets the group_id and all it's associated security to Inactive

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	UPDATE AccessGroup SET status = 'I',
		modified_by = @modified_by,
		date_modified = GETDATE()
	WHERE group_id = @group_id
	
	UPDATE AccessGroupSecurity SET status='I',
		modified_by = @modified_by,
		date_modified = GETDATE()
	WHERE group_id = @group_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupDelete] TO [EQAI]
    AS [dbo];

