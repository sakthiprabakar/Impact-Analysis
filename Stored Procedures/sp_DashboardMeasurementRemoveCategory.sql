CREATE PROCEDURE [dbo].[sp_DashboardMeasurementRemoveCategory] 
	@category_id int = NULL,
    @measurement_id INT = NULL
/*	
	Description: 
	Remove a category from a measurement

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	DELETE FROM DashboardCategoryXMeasurement WHERE category_id = @category_id
	AND measurement_id = @measurement_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementRemoveCategory] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementRemoveCategory] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementRemoveCategory] TO [EQAI]
    AS [dbo];

