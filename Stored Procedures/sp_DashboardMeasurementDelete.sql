CREATE PROCEDURE [dbo].[sp_DashboardMeasurementDelete] 
    @measurement_id int
/*	
	Description: 
	Deactivates a measurement

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	UPDATE [dbo].[DashboardMeasurement]
	SET status='I'
	WHERE  [measurement_id] = @measurement_id
/*	
	BEGIN TRAN

	DELETE
	FROM   [dbo].[DashboardMeasurement]
	WHERE  [measurement_id] = @measurement_id

	COMMIT
	*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementDelete] TO [EQAI]
    AS [dbo];

