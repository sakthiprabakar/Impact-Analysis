	CREATE PROCEDURE [dbo].[sp_DashboardResultSelect] 
	    @result_id INT = NULL,
	    @measurement_id INT = NULL,
	    @report_period_end_date DATETIME = NULL,
	    @company_id int = NULL,
	    @profit_ctr_id int = NULL
/*	
	Description: 
	Selects a particular dashboard result

	Revision History:
	??/01/2009	RJG 	Created
*/	
	AS 
	
	SET NOCOUNT ON
	
	declare @related_measurement_id int
	SET @related_measurement_id = NULL
	
	IF @result_id IS NOT NULL
	BEGIN
		SELECT
			   dr.[result_id],
			   dr.[report_period_end_date],
			   dr.[answer],
			   dr.[company_id],
			   dr.[profit_ctr_id],
			   dr.[compliance_flag],
			   dr.[date_added],
			   dr.[date_modified],
			   dr.[measurement_id],
			   dm.[description] as measurement_description,
			   dr.[modified_by],
			   dr.[note],
			   dr.[added_by],
			   pc.profit_ctr_name,
			   dm.time_period,
			   dr.threshold_value,
			   dr.threshold_operator,
			   dr.threshold_pass
		FROM   [dbo].[DashboardResult] dr
			INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
			LEFT OUTER JOIN ProfitCenter pc ON pc.profit_ctr_id = dr.profit_ctr_id AND pc.company_id = dr.company_id
		WHERE  ([result_id] = @result_id
				 OR @result_id IS NULL) 
		ORDER BY report_period_end_date DESC

		SELECT @related_measurement_id = dr.measurement_id
		FROM   [dbo].[DashboardResult] dr

		WHERE  ([result_id] = @result_id
				 OR @result_id IS NULL) 
		
	END
	
	IF @measurement_id IS NOT NULL
	BEGIN
		SET @related_measurement_id = @measurement_id
		
		-- results for corporate tier
		if @company_id IS NULL AND @profit_ctr_id IS NULL
		BEGIN		
			SELECT
				   dr.[result_id],
				   dr.[report_period_end_date],
				   dr.[answer],
				   dr.[company_id],
				   dr.[profit_ctr_id],
				   dr.[compliance_flag],
				   dr.[date_added],
				   dr.[date_modified],
				   dr.[measurement_id],
				   dm.[description] as measurement_description,
				   dr.[modified_by],
				   dr.[note],
				   dr.[added_by],
				   pc.profit_ctr_name,
				   dm.time_period,
				   dr.threshold_value,
				   dr.threshold_operator,
				   dr.threshold_pass
			FROM   [dbo].[DashboardResult] dr
				INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
				LEFT OUTER JOIN ProfitCenter pc ON pc.profit_ctr_id = dr.profit_ctr_id AND pc.company_id = dr.company_id
			WHERE  (dm.measurement_id = @measurement_id AND dr.report_period_end_date = @report_period_end_date) 
			ORDER BY report_period_end_date DESC
		END
		
		if @company_id IS NOT NULL and @profit_ctr_id IS NOT NULL
		BEGIN		
			SELECT
				   dr.[result_id],
				   dr.[report_period_end_date],
				   dr.[answer],
				   dr.[company_id],
				   dr.[profit_ctr_id],
				   dr.[compliance_flag],
				   dr.[date_added],
				   dr.[date_modified],
				   dr.[measurement_id],
				   dm.[description] as measurement_description,
				   dr.[modified_by],
				   dr.[note],
				   dr.[added_by],
				   pc.profit_ctr_name,
				   dm.time_period
			FROM   [dbo].[DashboardResult] dr
				INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
				LEFT OUTER JOIN ProfitCenter pc ON pc.profit_ctr_id = dr.profit_ctr_id AND pc.company_id = dr.company_id
			WHERE  (dm.measurement_id = @measurement_id AND dr.report_period_end_date = @report_period_end_date AND dr.company_id = @company_id AND dr.profit_ctr_id = @profit_ctr_id) 
			ORDER BY report_period_end_date DESC
		
		END
			
	END
	
	
	exec sp_DashboardMeasurementSelect @related_measurement_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelect] TO [EQAI]
    AS [dbo];

