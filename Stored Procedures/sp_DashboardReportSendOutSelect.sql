
CREATE PROCEDURE sp_DashboardReportSendOutSelect
	@user_id INT = null,
	@permission_id INT = null,
	@notification_frequency VARCHAR(20) = 'daily' -- 'daily', 'monthly', 'weekly'

AS

IF @notification_frequency = 'all'
	SET @notification_frequency = NULL

-- search for a specific type of notification
IF @notification_frequency IS NOT NULL
	OR (@notification_frequency IS NULL
	AND @user_id IS NULL
	AND @permission_id IS NULL)
BEGIN	
	SELECT so.*, 
		'A' as user_type, 
		u.user_code, 
		u.user_id as id, 
		u.user_name as username, 
		u.email 
	FROM DashboardReportSendOut so
	INNER JOIN USERS u ON so.user_id = u.user_id
		WHERE so.notification_frequency = COALESCE(@notification_frequency, so.notification_frequency)
		
	SELECT sop.* FROM DashboardReportSendOut so
		INNER JOIN DashboardReportSendOutParams sop ON so.USER_ID = sop.USER_ID
		AND so.permission_id = sop.permission_id
		WHERE so.notification_frequency = COALESCE(@notification_frequency, so.notification_frequency)
		
	SELECT DISTINCT p.*, s.* FROM AccessPermission p
		INNER JOIN DashboardReportSendOut so 
			ON p.permission_id = so.permission_id
		INNER JOIN AccessPermissionSet s ON p.set_id = s.set_id
		WHERE so.notification_frequency = COALESCE(@notification_frequency, so.notification_frequency)
		AND so.user_id = COALESCE(@user_id, so.user_id)
		AND so.permission_id = COALESCE(@permission_id, so.permission_id)			
		
END

-- search for a single PK
IF @notification_frequency IS NOT NULL
	AND @user_id IS NOT NULL
	AND @permission_id IS NOT NULL
BEGIN

	SELECT so.*, 
		'A' as user_type, 
		u.user_code, 
		u.user_id as id, 
		u.user_name as username, 
		u.email 
	FROM DashboardReportSendOut so
		INNER JOIN USERS u ON so.user_id = u.user_id
		WHERE so.notification_frequency = COALESCE(@notification_frequency, so.notification_frequency)
		AND so.user_id = COALESCE(@user_id, so.user_id)
		AND so.permission_id = COALESCE(@permission_id, so.permission_id)
		
	SELECT sop.* FROM DashboardReportSendOut so
		INNER JOIN DashboardReportSendOutParams sop ON so.USER_ID = sop.USER_ID
		AND so.permission_id = sop.permission_id
		WHERE sop.user_id = COALESCE(@user_id, sop.user_id)
		AND sop.permission_id = COALESCE(@permission_id, sop.permission_id)
		
	SELECT DISTINCT p.*, s.* FROM AccessPermission p
		INNER JOIN DashboardReportSendOut so 
			ON p.permission_id = so.permission_id
		INNER JOIN AccessPermissionSet s ON p.set_id = s.set_id
		WHERE so.notification_frequency = COALESCE(@notification_frequency, so.notification_frequency)
		AND so.user_id = COALESCE(@user_id, so.user_id)
		AND so.permission_id = COALESCE(@permission_id, so.permission_id)			
			
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardReportSendOutSelect] TO [EQAI]
    AS [dbo];

