CREATE PROCEDURE [dbo].[sp_DashboardMeasurementSelectNotificationUsers] 
    @measurement_id INT = NULL
/*	
	Description: 
	Selects the users that are associated to the given measurement as 'notification users'

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	 SELECT   
	  u.user_id as id,   
	  u.user_name as username,   
	  u.email,   
	  'A' as user_type   
	 FROM DashboardMeasurementNotification dmn
	 INNER JOIN Users u ON dmn.user_id = u.user_id  
	 WHERE dmn.measurement_id = @measurement_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectNotificationUsers] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectNotificationUsers] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectNotificationUsers] TO [EQAI]
    AS [dbo];

