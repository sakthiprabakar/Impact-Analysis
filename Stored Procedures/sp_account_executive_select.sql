
create procedure sp_account_executive_select
	@user_code varchar(20) = NULL
as
begin

	SELECT usr.user_name, usr.user_code, usr.user_id, ux.territory_code FROM Users usr
		INNER JOIN UsersXEQContact ux ON usr.user_code = ux.user_code
		WHERE ux.EQcontact_type = 'AE'
		and usr.group_id > 0
		and usr.user_code = coalesce(@user_code, usr.user_code)
	order by user_name
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_account_executive_select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_account_executive_select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_account_executive_select] TO [EQAI]
    AS [dbo];

