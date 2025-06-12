CREATE PROCEDURE [dbo].[sp_DashboardReportSendOutHistorySelect] 
    @history_id INT
AS 
	
	SELECT * FROM   [dbo].[DashboardReportSendOutHistory] 
	WHERE  ([history_id] = @history_id)
	
	SELECT * FROM DashboardReportSendOutHistoryParams params
		WHERE params.history_id = @history_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistorySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistorySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutHistorySelect] TO [EQAI]
    AS [dbo];

