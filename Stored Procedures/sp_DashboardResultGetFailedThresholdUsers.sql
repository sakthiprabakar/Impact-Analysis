
CREATE PROCEDURE sp_DashboardResultGetFailedThresholdUsers
AS
/*	
	Description: 
	Since the last notification date, returns any users that have notifications associated with measurements they are watching

	Revision History:
	??/01/2009	RJG 	Created
*/		
BEGIN

	-- update the threshold results
	--UPDATE DashboardResult SET Threshold_Pass = NULL
	exec sp_DashboardResultEvaluateThreshold
	

	declare @max_history_date datetime
	declare @last_thirty_days datetime
	declare @since_date datetime
	
	set @last_thirty_days = Dateadd(dd,-30,Getdate())
	select @max_history_date = MAX(run_date) FROM DashboardMeasurementNotificationHistory
	
	-- no entires in the History table yet
	if (@max_history_date IS NULL) 
	begin
		SET @since_date = @last_thirty_days
	end
	else
	begin
		SET @since_date = @max_history_date
	end	

	SELECT 
	  DISTINCT dnotify.user_id, 
	  email, ua.permission_id,
	  dr.measurement_id,
	  @since_date as criteria_date
FROM   dashboardresult dr
       INNER JOIN dashboardmeasurementnotification dnotify
         ON dr.measurement_id = dnotify.measurement_id
       INNER JOIN users u
         ON dnotify.user_id = u.user_id
       LEFT OUTER JOIN profitcenter p
         ON p.company_id = dr.company_id
            AND p.profit_ctr_id = dr.profit_ctr_id
       INNER JOIN view_AccessByUser ua ON  
       ua.report_custom_arguments = 'measurement_id=' + CAST(dr.measurement_id AS VARCHAR(20))			AND ua.user_id = dnotify.user_id            
WHERE  threshold_pass = 'F'
       AND dr.report_period_end_date >= @since_date
       
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdUsers] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdUsers] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdUsers] TO [EQAI]
    AS [dbo];

