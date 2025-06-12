CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutInsert] 
    @user_id int,
    @permission_id int,
    @notification_frequency varchar(20),
    @added_by varchar(50)
AS 

	DELETE FROM DashboardReportSendOut WHERE
		user_id = @user_id
		AND permission_id = @permission_id
		AND notification_frequency = @notification_frequency
		
	INSERT INTO [dbo].[DashboardReportSendOut]
                ([user_id],
                 [permission_id],
                 [notification_frequency],
                 [added_by], date_added)
    SELECT @user_id,
           @permission_id,
           @notification_frequency,
           @added_by, GETDATE()
                 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutInsert] TO [EQAI]
    AS [dbo];

