CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutHistoryInsert] 
    @date_added datetime,
    @notification_frequency varchar(20),
    @permission_id int,
    @user_id int
AS 
	
	INSERT INTO [dbo].[DashboardReportSendOutHistory] (
		[date_added], 
		[notification_frequency], 
		[permission_id], 
		[user_id]
	)
	SELECT 
		@date_added, 
		@notification_frequency, 
		@permission_id, 
		@user_id
	
	
	DECLARE @newid INT
	SET @newid = SCOPE_IDENTITY()
	SELECT @newid
	--EXEC sp_DashboardReportSendOutHistorySelect @newid

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryInsert] TO [EQAI]
    AS [dbo];

