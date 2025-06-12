
create procedure sp_CustomerCategory_Select
@category_id int = null
as
begin

SELECT Category_ID,
       Category,
       DESCRIPTION
FROM   CustomerCategory
WHERE category_id = coalesce(@category_id, category_id)
ORDER  BY Category_ID 

end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerCategory_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerCategory_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerCategory_Select] TO [EQAI]
    AS [dbo];

