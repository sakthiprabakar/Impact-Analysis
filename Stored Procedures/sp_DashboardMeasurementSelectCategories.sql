CREATE PROCEDURE [dbo].[sp_DashboardMeasurementSelectCategories] 
    @measurement_id INT = NULL
/*	
	Description: 
	Selects measurement's categories

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	SELECT dc.* FROM DashboardCategory dc 
		INNER JOIN DashboardCategoryXMeasurement dcm ON dc.category_id = dcm.category_id
		INNER JOIN DashboardMeasurement dm ON dcm.measurement_id = dm.measurement_id AND
		dm.measurement_id = @measurement_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectCategories] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectCategories] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectCategories] TO [EQAI]
    AS [dbo];

