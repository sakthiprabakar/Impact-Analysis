
CREATE PROCEDURE [dbo].[sp_AccessPermissionSet_Insert] 
    @display_order int,
    @set_name varchar(255),
    @status char(1),
    @added_by varchar(50)
/*	
	Description: 
	Creates a new AccessPermissionSet

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/			
AS 

	INSERT INTO [dbo].[AccessPermissionSet]
           ([display_order],
            [set_name],
            [status],
            added_by,
            date_added)
	SELECT 
		@display_order,
		@set_name,
		@status,
		@added_by,
		GETDATE()
	
	declare @setid int
	set @setid = scope_identity()
	
	exec sp_AccessPermissionSet_Select @setid
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSet_Insert] TO [EQAI]
    AS [dbo];

