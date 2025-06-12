 
create procedure sp_ContactSelect
	@contact_id int
/*
Usage: sp_ContactSelect
*/
as
SELECT DISTINCT Isnull(last_name, '') + ', ' + Isnull(first_name, '') AS display_name,
                name,
                c.contact_id,
                last_name,
                first_name,
                email,
                phone,
                contact_company
FROM   contact c
       INNER JOIN contactxref x
         ON c.contact_id = x.contact_id
            --AND x.status = 'A'
            AND ((c.contact_status = 'A' AND x.status = 'A') OR (c.contact_status <> 'A'))
            AND x.contact_id = @contact_id 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ContactSelect] TO [EQAI]
    AS [dbo];

