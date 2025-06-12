
create procedure sp_TerritorySelect
	@user_code_search varchar(10) = NULL,
	@user_id_search varchar(10) = NULL,
	@territory_code varchar(10) = NULL
	
/*
Usage: sp_TerritorySelect

exec sp_TerritorySelect null, null, '01'
exec sp_TerritorySelect null, 29, NULL
exec sp_TerritorySelect 'ROB_W', null, null
*/
as

SELECT t.territory_code,
       t.territory_desc,
       user_name,
       t.territory_code AS compare,
       u.user_code,
       u.user_id
FROM   territory t
       LEFT OUTER JOIN UsersXEQContact x
         ON t.territory_code = x.territory_code
            AND x.EQcontact_type = 'AE'
       LEFT OUTER JOIN users u
         ON x.user_code = u.user_code
            AND u.group_id <> 0
WHERE t.territory_code = COALESCE(@territory_code, t.territory_code)
AND ISNULL(u.user_code, '') = COALESCE(@user_code_search, ISNULL(u.user_code, ''))
AND ISNULL(u.user_id, '') = COALESCE(@user_id_search, ISNULL(u.user_id, ''))
ORDER  BY t.territory_code


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerritorySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerritorySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerritorySelect] TO [EQAI]
    AS [dbo];

