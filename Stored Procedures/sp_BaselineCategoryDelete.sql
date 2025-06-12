CREATE PROCEDURE [dbo].[sp_BaselineCategoryDelete] 
    @baseline_category_id int
AS 
	DELETE
	FROM   [dbo].[BaselineCategory]
	WHERE  baseline_category_id = @baseline_category_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryDelete] TO [EQAI]
    AS [dbo];

