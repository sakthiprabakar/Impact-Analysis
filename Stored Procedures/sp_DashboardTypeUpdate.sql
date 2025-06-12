CREATE PROCEDURE [dbo].[sp_DashboardTypeUpdate] 
    @dashboard_type_id int,
    @description varchar(500),
    @status char(1),
	@modified_by varchar(50)
/*	
	Description: 
	Updates DashboardType information

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/		
AS 

	UPDATE [dbo].[DashboardType]
	SET    [description] = @description,
	       [status] = @status,
		   [modified_by] = @modified_by,
		   [date_modified] = GETDATE()
	WHERE  [dashboard_type_id] = @dashboard_type_id 

	EXEC sp_dashboardtypeselect @dashboard_type_id 	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeUpdate] TO [EQAI]
    AS [dbo];

