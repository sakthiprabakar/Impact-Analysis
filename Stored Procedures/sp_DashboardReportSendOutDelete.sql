CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutDelete] 
    @user_id int,
    @permission_id int,
    @notification_frequency varchar(20)
AS 
	DELETE
	FROM   [dbo].[DashboardReportSendOut]
	WHERE  [user_id] = @user_id
	       AND [permission_id] = @permission_id
	       AND [notification_frequency] = @notification_frequency

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutDelete] TO [EQAI]
    AS [dbo];

