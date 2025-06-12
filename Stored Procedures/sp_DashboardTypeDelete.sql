CREATE PROCEDURE [dbo].[sp_DashboardTypeDelete] 
    @dashboard_type_id int,
    @modified_by varchar(50)
/*	
	Description: 
	Deletes given DashboardType

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/		
AS 
	UPDATE DashboardType
		SET status = 'I',
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()
		WHERE dashboard_type_id = @dashboard_type_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeDelete] TO [EQAI]
    AS [dbo];

