CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutUpdate] 
    @user_id int,
    @permission_id int,
    @notification_frequency varchar(20),
    @modified_by varchar(50)
AS 
	SET NOCOUNT ON 
	UPDATE [dbo].[DashboardReportSendOut]
    SET    [user_id] = @user_id,
           [permission_id] = @permission_id,
           [notification_frequency] = @notification_frequency,
           [date_modified] = GETDATE(),
           [modified_by] = @modified_by
    WHERE  [user_id] = @user_id
           AND [permission_id] = @permission_id
           AND [notification_frequency] = @notification_frequency 
    

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutUpdate] TO [EQAI]
    AS [dbo];

