
create procedure sp_NAMSelect
	@user_code varchar(20) = NULL,
	@user_id int = NULL,
	@nam_type_id int = NULL
/*
Usage: sp_NAMSelect
*/

as

 SELECT type_id,
        user_name,
        u.user_code,
        u.user_id
 FROM   UsersXEQContact x
        INNER JOIN users u
          ON x.user_code = u.user_code
 WHERE  x.EQcontact_type = 'NAM' 
 and x.user_code = coalesce(@user_code, x.user_code)
 and u.user_id = coalesce(@user_id, u.user_id)
 and x.type_id = coalesce(@nam_type_id, x.type_id)
 order by user_name
 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_NAMSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_NAMSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_NAMSelect] TO [EQAI]
    AS [dbo];

