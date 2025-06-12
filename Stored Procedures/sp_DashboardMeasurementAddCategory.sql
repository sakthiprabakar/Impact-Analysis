CREATE PROCEDURE [dbo].[sp_DashboardMeasurementAddCategory] 
	@category_id int = NULL,
    @measurement_id INT = NULL,
    @added_by varchar(50) = NULL
/*	
	Description: 
	Associates a category to a measurement

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	IF NOT EXISTS(SELECT * FROM DashboardCategoryXMeasurement WHERE category_id = @category_id AND measurement_id = @measurement_id)
	BEGIN
	
		INSERT INTO DashboardCategoryXMeasurement (category_id, measurement_id, date_added, added_by)
		VALUES (@category_id, @measurement_id, getdate(), @added_by)	
	
	END	

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementAddCategory] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementAddCategory] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementAddCategory] TO [EQAI]
    AS [dbo];

