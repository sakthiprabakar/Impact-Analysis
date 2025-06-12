CREATE PROCEDURE [dbo].[sp_BaselineDetailDelete] 
    @baseline_id int,
    @baseline_category_id int,
    @generator_id int
AS 
	DELETE
	FROM   [dbo].[BaselineDetail]
	WHERE  [baseline_id] = @baseline_id
	       AND [baseline_category_id] = @baseline_category_id
	       AND [generator_id] = @generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailDelete] TO [EQAI]
    AS [dbo];

