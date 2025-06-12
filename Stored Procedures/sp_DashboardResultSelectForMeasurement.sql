	CREATE PROCEDURE [dbo].[sp_DashboardResultSelectForMeasurement] 
	    @measurement_id int,
	    @copc_list varchar(3000) = NULL, -- accepts '14|0' for company/profit center key
	    @start_date datetime = NULL,
	    @end_date datetime = NULL
/*	
	Description: 
	Selects all of the results for a given measurement / time frame (and optionally co/pc)

	Revision History:
	??/01/2009	RJG 	Created
	
	Test Invocation:
	sp_DashboardResultSelectForMeasurement @measurement_id = 47 ,@start_date = '09/01/2009', @end_date = '09/13/2009'
*/			
	AS 
	
	declare @tblProfitCenters table ([company_id] int, profit_ctr_id int)
	INSERT @tblProfitCenters 
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> ''	
	
	DECLARE @measurement_tier int
	SELECT @measurement_tier = tier_id FROM DashboardMeasurement where measurement_id = @measurement_id
	
	-- for "Corporate" tier measurement resulits
	IF (@copc_list IS NULL OR LEN(RTRIM(LTRIM(@copc_list))) = 0)
	--IF @measurement_tier = 1
	BEGIN
	
		IF OBJECT_ID ('tempdb..#data_for_date_and_copc') IS NOT NULL DROP TABLE #data_for_date_and_copc
	
		CREATE TABLE #report_dates (
			the_date datetime,
			measurement_id int
		)
		
		INSERT INTO #report_dates (the_date, measurement_id) 
			SELECT DATE, @measurement_id FROM 
			dbo.fn_GetDays(@start_date, @end_date)
		
		--SELECT * FROM #data_for_date_and_copc
			

		SELECT
			   ISNULL(dr.result_id, -1) as result_id,
			   dates.the_date as report_period_end_date,
			   dr.answer,
			   0 as company_id,
			   0 as profit_ctr_id,
			   dr.[compliance_flag],
			   dr.[date_added],
			   dr.[date_modified],
			   dm.measurement_id,
			   dm.[description] as measurement_description,
			   dr.[modified_by],
			   dr.[note],
			   dr.[added_by],
			   '' as profit_ctr_name,
			   dm.time_period,
			   dm.threshold_value,
			   dm.threshold_operator,
			   dr.threshold_pass,
			   dm.threshold_type,
				CASE 
				WHEN LEN(ISNULL(dm.threshold_value,'')) = 0 THEN 'F'
				ELSE 'T'
				END as threshold_metric_flag,			   
			   dm.display_format,
				CASE 
				WHEN dr.threshold_pass = 'F' AND LEN(ISNULL(dm.threshold_value,'')) <> 0 THEN 'T'
				ELSE 'F'
			   END as is_failed,
			   CASE 
				WHEN dr.answer IS NULL THEN 'T'
				ELSE 'F'
			   END as is_empty
		FROM   #report_dates dates
			LEFT OUTER JOIN [dbo].[DashboardResult] dr ON dates.the_date = dr.report_period_end_date AND
				dates.measurement_id = dr.measurement_id
				AND dr.measurement_id = @measurement_id
				AND dr.report_period_end_date BETWEEN COALESCE(@start_date, dr.report_period_end_date) AND COALESCE(@end_date, dr.report_period_end_date)
			INNER JOIN DashboardMeasurement dm ON dates.measurement_id = dm.measurement_id
		ORDER BY dr.report_period_end_date desc
		
			
		
		
	
	END
	
	-- for "Company / Profit Center" tier measurement resulits
	IF (@copc_list IS NOT NULL AND LEN(RTRIM(LTRIM(@copc_list))) <> 0)
	--IF @measurement_tier = 2 -- co/pc
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
			   dr.threshold_pass,
			   dm.threshold_type,
			   dm.display_format
		FROM   [dbo].[DashboardResult] dr
			INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
			LEFT OUTER JOIN ProfitCenter pc ON pc.profit_ctr_id = dr.profit_ctr_id AND pc.company_id = dr.company_id 
			INNER JOIN @tblProfitCenters pc_list ON pc.profit_ctr_id = pc_list.profit_ctr_id
			AND pc.company_id = pc_list.company_id
		WHERE  dr.measurement_id = @measurement_id
		AND dr.report_period_end_date BETWEEN COALESCE(@start_date, dr.report_period_end_date) AND COALESCE(@end_date, dr.report_period_end_date)			
		ORDER BY dr.report_period_end_date desc
	END	

	--SELECT * FROM @tblProfitCenters
	exec sp_DashboardMeasurementSelect @measurement_id
			
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelectForMeasurement] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelectForMeasurement] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultSelectForMeasurement] TO [EQAI]
    AS [dbo];

