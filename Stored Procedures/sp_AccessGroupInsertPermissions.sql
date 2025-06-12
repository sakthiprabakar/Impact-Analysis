CREATE PROCEDURE [dbo].[sp_AccessGroupInsertPermissions] 
    @group_id int,
    @permission_id_list varchar(8000),
    @added_by varchar(50)
/*	
	Description: 
	Inserts the csv provided list of permission_ids for the given group_id

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/			
AS 
	
	declare @tblPermissions table (permission_id int)
	INSERT @tblPermissions 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @permission_id_list) 
		where isnull(row, '') <> ''	
	
	DELETE FROM @tblPermissions WHERE permission_id IN (SELECT permission_id FROM AccessPermissionGroup WHERE group_id = @group_id)

	declare @add_date datetime
	set @add_date = GETDATE()	
	
	INSERT INTO AccessPermissionGroup 
		(permission_id, group_id, action_id, added_by, date_added)
	SELECT tbl.permission_id, @group_id, 3, @added_by, @add_date
		FROM @tblPermissions tbl

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsertPermissions] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsertPermissions] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsertPermissions] TO [EQAI]
    AS [dbo];

