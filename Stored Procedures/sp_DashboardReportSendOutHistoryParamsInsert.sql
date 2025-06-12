CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutHistoryParamsInsert] 
    @history_id int,
    @user_id int,
    @permission_id int,
    @param_key varchar(100),
    @param_value varchar(MAX)
AS 
	
	INSERT INTO [dbo].[DashboardReportSendOutHistoryParams] (
		[history_id], 
		[user_id], 
		[permission_id], 
		[param_key], 
		[param_value]
	)
	SELECT 
		@history_id, 
		@user_id,
		@permission_id, 
		@param_key, 
		@param_value

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryParamsInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryParamsInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistoryParamsInsert] TO [EQAI]
    AS [dbo];

