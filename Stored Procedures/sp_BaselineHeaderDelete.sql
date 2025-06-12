CREATE PROCEDURE [dbo].[sp_BaselineHeaderDelete] 
    @baseline_id int
AS 
	DELETE
	FROM   [dbo].[BaselineHeader]
	WHERE  [baseline_id] = @baseline_id
	
	DELETE FROM BaselineDetail WHERE baseline_id = @baseline_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderDelete] TO [EQAI]
    AS [dbo];

