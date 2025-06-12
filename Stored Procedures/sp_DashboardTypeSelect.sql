CREATE PROCEDURE [dbo].[sp_DashboardTypeSelect] 
    @dashboard_type_id INT = NULL,
    @description varchar(500) = NULL
/*	
	Description: 
	Searches for or selects a single DashboardType

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 

	SELECT [dashboard_type_id],
	       [date_added],
	       [date_modified],
	       [description],
	       [modified_by],
	       [status],
	       added_by
	FROM   [dbo].[DashboardType]
	WHERE  (([dashboard_type_id] = @dashboard_type_id
		 OR @dashboard_type_id IS NULL)
		OR (@description IS NULL OR [description] LIKE '%' + @description + '%'))
		AND status = 'A'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeSelect] TO [EQAI]
    AS [dbo];

