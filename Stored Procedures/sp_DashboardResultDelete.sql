CREATE PROCEDURE [dbo].[sp_DashboardResultDelete] 
    @result_id int
/*	
	Description: 
	Deletes DashboardResult record

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN

	DELETE
	FROM   [dbo].[DashboardResult]
	WHERE  [result_id] = @result_id

	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultDelete] TO [EQAI]
    AS [dbo];

