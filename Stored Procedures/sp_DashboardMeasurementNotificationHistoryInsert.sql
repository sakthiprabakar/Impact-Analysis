CREATE PROCEDURE [dbo].[sp_DashboardMeasurementNotificationHistoryInsert] 
    @run_date datetime,
    @user_id int,
    @execution_path varchar(500),
    @execution_result varchar(50),
    @execution_command varchar(50),
    @execution_parameters varchar(500) = NULL,
    @execution_error varchar(1000) = NULL
/*	
	Description: 
	Creates a record of when a certain user last received a notification report.  This is used
	as the baseline date for the next time the report is run.

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	DELETE FROM DashboardMeasurementNotificationHistory
		WHERE run_date = @run_date AND user_id = @user_id
		AND execution_path = @execution_path
		AND execution_result = @execution_result
		AND execution_command = @execution_command
	
	INSERT INTO 
		[dbo].[DashboardMeasurementNotificationHistory] (
	[run_date], 
	[user_id], 
	execution_path, 
	execution_result,	
	execution_error, 
	execution_command,
	execution_parameters
	)
	SELECT 
		@run_date, 
		@user_id, 
		@execution_path, 
		@execution_result, 
		@execution_error, 
		@execution_command,
		@execution_parameters
	
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[DashboardMeasurementNotificationHistory]
	WHERE  [run_date] = @run_date
	       AND [user_id] = @user_id
	       AND execution_path = @execution_path
	       AND execution_result = @execution_result
	       AND execution_command = @execution_command
	-- End Return Select <- do not remove

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementNotificationHistoryInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementNotificationHistoryInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementNotificationHistoryInsert] TO [EQAI]
    AS [dbo];

