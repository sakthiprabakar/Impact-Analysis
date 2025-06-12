
create procedure sp_AccessPermissionGroupSelect
	@group_id int,
	@permission_id int
as
begin
	SELECT * FROM AccessPermissionGroup apg
		where group_id = @group_id
		AND permission_id = @permission_id

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionGroupSelect] TO [EQAI]
    AS [dbo];

