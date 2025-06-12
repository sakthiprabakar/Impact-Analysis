
create procedure sp_DashboardMeasurement_SelectAccessPermissionID
	@measurement_id int
as
begin
	select permission_id from AccessPermission where 
		status = 'A'
		and report_custom_arguments = 'measurement_id='+ CAST(@measurement_id as varchar(20))
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurement_SelectAccessPermissionID] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurement_SelectAccessPermissionID] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurement_SelectAccessPermissionID] TO [EQAI]
    AS [dbo];

