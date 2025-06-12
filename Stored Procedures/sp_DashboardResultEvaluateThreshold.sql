
CREATE PROCEDURE sp_DashboardResultEvaluateThreshold
	@reset_threshold_data char(1) = 'F'
AS
/*	
	Description: 
	Evaluates whether or not a measurement is acceptable

	Revision History:
	??/01/2009	RJG 	Created
*/		
BEGIN

/* reset all */
if @reset_threshold_data = 'T'
BEGIN
	UPDATE DashboardResult SET  threshold_pass = NULL
END	

UPDATE DashboardResult SET 
	threshold_value = dm.threshold_value, 
	threshold_operator = dm.threshold_operator, 
	threshold_pass = 
		CASE 
			WHEN dm.threshold_operator = '>' THEN 
				CASE 
					WHEN cast(dr.answer as decimal) > dm.threshold_value THEN 'T'
				ELSE 'F'
				END
			WHEN dm.threshold_operator = '<' THEN
				CASE WHEN cast(dr.answer as decimal) < dm.threshold_value THEN 'T'
				ELSE 'F'
				END			
			WHEN dm.threshold_operator = '=' THEN
				CASE WHEN cast(dr.answer as decimal) = dm.threshold_value THEN 'T'
				ELSE 'F'
				END		
			WHEN dm.threshold_operator = '>=' THEN
				CASE WHEN cast(dr.answer as decimal) >= dm.threshold_value THEN 'T'
				ELSE 'F'
				END	
			WHEN dm.threshold_operator = '<=' THEN
				CASE WHEN cast(dr.answer as decimal) <= dm.threshold_value THEN 'T'
				ELSE 'F'
				END					
		END
	FROM DashboardMeasurement dm 
		INNER JOIN DashboardResult dr ON dm.measurement_id = dr.measurement_id
	WHERE 	
		dm.threshold_operator IS NOT NULL 
		AND LEN(dm.threshold_operator) > 0
		AND dm.threshold_value IS NOT NULL
		AND threshold_pass IS NULL
		
		
	/* update the null values to be 'False' */
	UPDATE DashboardResult SET  threshold_pass = 'F'
	FROM DashboardMeasurement dm 
		INNER JOIN DashboardResult dr ON dm.measurement_id = dr.measurement_id
	WHERE 	
		dm.threshold_operator IS NOT NULL 
		AND LEN(dm.threshold_operator) > 0
		AND dm.threshold_value IS NOT NULL
		AND dr.answer IS NULL
		
	/* reset all */
	-- UPDATE DashboardResult SET  threshold_pass = NULL
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultEvaluateThreshold] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultEvaluateThreshold] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultEvaluateThreshold] TO [EQAI]
    AS [dbo];

