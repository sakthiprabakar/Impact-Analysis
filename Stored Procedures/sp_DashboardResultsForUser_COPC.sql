
CREATE PROCEDURE sp_DashboardResultsForUser_COPC
	@user_id int = NULL,
	@StartDate datetime,
	@EndDate datetime = NULL,
	@copc_list varchar(2000),
	@measurement_id int = NULL,
	@category_id int = NULL,
	@only_failed_or_missing char(1) = NULL,
	@condense_acceptable_values char(1) = NULL
/*	
	Description: 
	Selects DashboardResult entries for a user, timeframe, measurement id, and copc_list
		-- the copc list is also filtered against what the user has access to

	Revision History:
	??/01/2009	RJG 	Created
	02/08/2010	RJG		Modified to "condense" acceptable values into one row
*/		

/*

exec sp_DashboardResultsForUser_COPC 1206, '08/23/2011','08/23/2011 11:59:59', '12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21', NULL, 10, 'F', 'T'

-- SELECT company_id, profit_Ctr_id from ProfitCenter Where status = 'a'
-- exec sp_DashboardResultsForUser_COPC 925, '01/01/2009', '06/01/2009', '14|0', 26
-- exec sp_DashboardResultsForUser_COPC 1206, '01/01/2009', '10/01/2009', '12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21', 26
-- exec sp_DashboardResultsForUser_COPC 1206, '09/01/2009', '10/01/2009', '12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21', 46
-- exec sp_DashboardResultsForUser_COPC @StartDate='2009-09-29 00:00:00',@EndDate='2009-09-29 23:59:59',@user_id=1206,@copc_list=N'12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21',@measurement_id=NULL
-- exec sp_DashboardResultsForUser_Corporate @StartDate='2009-09-29 00:00:00',@EndDate='2009-09-29 23:59:59',@user_id=1206

--exec sp_DashboardResultsForUser_COPC 
--	@StartDate='2010-01-12 00:00:00',
--	@EndDate='2010-01-13 00:00:00',
--	@user_id=1206,
--	@copc_list=N'12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21',
--	@measurement_id=15,
--	@category_id=NULL,
--	@only_failed_or_missing = 'F'


*/

/*
sp_DashboardResultsForUser_COPC 1206, '10/01/2009', '10/01/2009 23:59:59', '12|0,14|0,17|0,18|0,21|0,22|0,23|0,24|0,3|1,12|1,14|1,15|1,21|1,12|2,14|2,15|2,21|2,12|3,14|3,15|3,21|3,12|4,14|4,15|4,12|5,14|5,14|6,14|9,14|10,14|11,14|12,2|21', 46
*/

AS
BEGIN

-- this report will return multiple rows per facility per day of data if it has more than 1 day range is selected
if @EndDate IS NULL
	SET @EndDate = cast(convert(varchar, @StartDate, 101) + ' 23:59:59' as datetime)


IF @only_failed_or_missing IS NULL
	SET @only_failed_or_missing = 'T'

/* Get the measurements that this user has access to */
	DECLARE @tblCustomAttributes TABLE
	(
		permission_id int,
		theKey varchar(100),
		theValue varchar(100)
	)
	
	declare @tblProfitCenters table ([company_id] int, profit_ctr_id int)
	INSERT @tblProfitCenters 
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> ''		
	
	DECLARE cur_Attributes CURSOR FOR
		SELECT 
			permission_id, report_custom_arguments
			FROM view_AccessByUser 
			where user_id = @user_id AND record_type = 'R' 
			AND report_custom_arguments IS NOT NULL	
			AND LEN(report_custom_arguments) > 0
			AND CHARINDEX('measurement_id=', report_custom_arguments, 0) > 0
			
	OPEN cur_Attributes
	
			DECLARE @tmp_permission_id int, @tmp_arguments varchar(500)

			FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
			WHILE (@@FETCH_STATUS = 0) 
			BEGIN
				--print cast(@tmp_permission_id as varchar(20)) + ' ' + @tmp_arguments
				
				INSERT INTO @tblCustomAttributes (permission_id, theKey, theValue)
					SELECT @tmp_permission_id, 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) theKey,
					RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('=',row) + 1, LEN(row) - (CHARINDEX('=',row)-1)))) theValue
					from dbo.fn_SplitXsvText(',', 0, @tmp_arguments) 
					where isnull(row, '') <> '' AND 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) = 'measurement_id'		
				
				FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
			END
		
	CLOSE cur_Attributes
	DEALLOCATE cur_Attributes	
	
	DECLARE @user_code varchar(50)
	SELECT @user_code = user_code FROM users where user_id = @user_id
	
	DELETE FROM @tblCustomAttributes
		WHERE theValue IN (
			SELECT measurement_id from DashboardMeasurement WHERE tier_id = 1
			)
	--RETURN
	 
	DECLARE @measurement_copc TABLE
	(
		measurement_id int,
		company_id int,
		profit_ctr_id int
	)
	
	--SELECT @measurement_id
	--SELECT @user_code
	
	DECLARE @measurement_tier int	
	SELECT @measurement_tier = tier_id FROM DashboardMeasurement dm WHERE
	measurement_id = @measurement_id	
	
		-- co/pc tier
		INSERT INTO @measurement_copc (measurement_id, company_id, profit_ctr_id) 
		SELECT DISTINCT dm.measurement_id, dpc.company_id, dpc.profit_ctr_id FROM DashboardMeasurement dm
			INNER JOIN DashboardMeasurementProfitCenter dpc ON dm.measurement_id = dm.measurement_id	
			INNER JOIN ProfitCenter p ON p.status = 'A'
			where dm.status = 'A' AND dm.copc_all_flag ='F' 
			AND dm.measurement_id = COALESCE(@measurement_id, dm.measurement_id)	
			AND dm.tier_id = 2
    		AND EXISTS( 
    			SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat 
    			WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = dm.measurement_id)
    		AND EXISTS(
				SELECT TOP 1 * FROM 
					SecuredProfitCenter pc 
					INNER JOIN @tblCustomAttributes secured_measures
						ON pc.permission_id = secured_measures.permission_id
				WHERE dpc.company_id = pc.company_id 
				AND dpc.profit_ctr_id = pc.profit_ctr_id				    		
				AND dpc.measurement_id = dm.measurement_id
    		)	
			
		UNION ALL 
		
		SELECT DISTINCT dm.measurement_id, dpc.company_id, dpc.profit_ctr_id 
		FROM DashboardMeasurement dm
			INNER JOIN DashboardMeasurementProfitCenter dpc ON dm.measurement_id = dm.measurement_id
			INNER JOIN @tblCustomAttributes secured_measures
						ON secured_measures.theValue = COALESCE(@measurement_id, secured_measures.theValue)	
			INNER JOIN SecuredProfitCenter user_pc ON
				dpc.company_id = user_pc.company_id 
				AND user_pc.profit_ctr_id = dpc.profit_ctr_id
			where dm.status = 'A' AND dm.copc_all_flag ='T' 
			AND dm.tier_id = 2
			AND dm.measurement_id = COALESCE(@measurement_id, dm.measurement_id)	
    		AND EXISTS( 
    			SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat 
    			WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = dm.measurement_id)
    			
		
	--SELECT 'measurement_copc', * FROM @measurement_copc
	--SELECT 'profit_ctrs', * FROM @tblProfitCenters
	--SELECT 'custom_attr', * FROM @tblCustomAttributes
	
	CREATE TABLE #data_for_date_and_copc (
		the_date datetime,
		measurement_id int,
		company_id int,
		profit_ctr_id int
	)
	
	INSERT INTO #data_for_date_and_copc (the_date, measurement_id, company_id, profit_ctr_id) 
		SELECT dates.DATE, measurement_id, company_id, profit_ctr_id
		FROM @measurement_copc mcopc
		INNER JOIN dbo.fn_GetDays(@StartDate, @EndDate) dates ON dates.DATE = dates.DATE




		SELECT DISTINCT dm.description,
		   dm.source,
		   pc.company_id,
		   pc.profit_ctr_id,
		   dr.answer,
		   ISNULL(date_table.the_date, @StartDate) as report_period_end_date,
		   dt.tier_name,
		   ISNULL(dr.threshold_value, dm.threshold_value) as threshold_value,
		   ISNULL(dr.threshold_operator, dm.threshold_operator) as threshold_operator,		   
		   dr.threshold_pass,
		   dm.threshold_type,
		   dm.measurement_id,
		   dt.tier_id,
		   dm.time_period,
		   dm.copc_waste_receipt_flag,
		   dm.copc_workorder_flag,
		   dm.copc_all_flag,
		   pc.profit_ctr_name,
		   dm.compliance_flag,
		   CASE 
			WHEN LEN(ISNULL(dm.threshold_value,'')) = 0 THEN 'F'
			ELSE 'T'
		   END as threshold_metric_flag,
	       RIGHT('00' + CONVERT(VARCHAR,pc.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,pc.profit_ctr_ID), 2) + ' ' + pc.profit_ctr_name as profit_ctr_name_with_key,
	       dr.note,
	       dm.display_format,
	       'F' as contains_failed_thresholds,
	       'F' as contains_empty_metrics,
	       'F' as is_condensed_value -- condensed values are "Acceptable" values that are condensed into one line
	       INTO #report_data
	FROM   dashboardmeasurement dm
			INNER JOIN @measurement_copc dpc ON dpc.measurement_id = dm.measurement_id
			INNER JOIN @tblCustomAttributes secured_measurements ON dpc.measurement_id = secured_measurements.theValue				
			INNER JOIN DashboardTier dt ON dt.tier_id = dm.tier_id
			INNER JOIN ProfitCenter pc ON 
				dpc.company_id = pc.company_id 
				AND dpc.profit_ctr_ID = pc.profit_ctr_id
			INNER JOIN @tblProfitCenters selected_copc ON 
				pc.company_id = selected_copc.company_id
				AND pc.profit_ctr_id = selected_copc.profit_ctr_id						
			LEFT OUTER JOIN #data_for_date_and_copc date_table ON date_table.measurement_id = dm.measurement_id
				AND date_table.company_id = dpc.company_id
				AND date_table.profit_ctr_id = dpc.profit_ctr_id				
			LEFT OUTER JOIN DashboardResult dr ON dpc.measurement_id = dr.measurement_id
				AND dpc.company_id = dr.company_id
				AND dpc.profit_ctr_id = dr.profit_ctr_id
				AND dr.report_period_end_date = date_table.the_date
		WHERE (dm.time_period = 'Daily') 
		   AND dm.measurement_id = COALESCE(@measurement_id, dm.measurement_id)
		   AND dm.status = 'A'	
		   AND dm.tier_id = 2
		   AND EXISTS( SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = dm.measurement_id)			
		   AND 
				1 = CASE 
						WHEN (@only_failed_or_missing = 'T' AND (dr.threshold_pass = 'F' OR dr.answer IS NULL)) THEN 1
						WHEN @only_failed_or_missing = 'F' THEN 1
				END
	ORDER BY dm.measurement_id, pc.company_id, pc.profit_ctr_id	
	
	--SELECT 'rdata', * FROM #data_for_date_and_copc
	--SELECT 'rd', * FROM #report_data
	
	-- update failed metric flag
	UPDATE #report_data SET contains_failed_thresholds = 'T'
		WHERE EXISTS( 
			SELECT 1 FROM #report_data rd 
			WHERE #report_data.measurement_id = rd.measurement_id
			AND #report_data.report_period_end_date = rd.report_period_end_date
			AND rd.threshold_pass = 'F' AND threshold_metric_flag = 'T' 
		)
		
	-- update empty metric flag
	UPDATE #report_data SET contains_empty_metrics = 'T'
		WHERE EXISTS( 
			SELECT 1 FROM #report_data rd 
			WHERE #report_data.measurement_id = rd.measurement_id
			AND #report_data.report_period_end_date = rd.report_period_end_date
			AND rd.answer IS NULL
		)		
	
	--SELECT * FROM #report_data
	
	IF @condense_acceptable_values = 'T'
	BEGIN
		SELECT DISTINCT 
			measurement_id,
			contains_failed_thresholds,
			contains_empty_metrics,
			threshold_pass,
			note
		INTO #passing_data 
		FROM #report_data rd WHERE threshold_pass = 'T'
			AND ISNULL(note,'') = ''
		
		
		DELETE FROM #report_data WHERE threshold_pass = 'T'
			AND ISNULL(note,'') = ''
			
		
		
			INSERT INTO #report_data (
				[description],
				[source],
				company_id,
				profit_ctr_id,
				answer,
				report_period_end_date,
				tier_name,
				threshold_value,
				threshold_operator,
				threshold_pass,
				threshold_type,
				measurement_id,
				tier_id,
				time_period,
				copc_waste_receipt_flag,
				copc_workorder_flag,
				copc_all_flag,
				profit_ctr_name,
				compliance_flag,
				threshold_metric_flag,
				profit_ctr_name_with_key,
				note,
				display_format,
				contains_failed_thresholds,
				contains_empty_metrics,
				is_condensed_value
			)
			SELECT DISTINCT dm.description,
			   dm.source,
			   0 as company_id,
			   0 as profit_ctr_id,
			   0 as answer,
			   @StartDate as report_period_end_date,
			   dt.tier_name,
			   dm.threshold_value as threshold_value,
			   dm.threshold_operator as threshold_operator,		   
			   'T' as threshold_pass,
			   dm.threshold_type,
			   dm.measurement_id,
			   2 as tier_id,
			   dm.time_period,
			   dm.copc_waste_receipt_flag,
			   dm.copc_workorder_flag,
			   dm.copc_all_flag,
			   'All facilties had acceptable values' as profit_ctr_name,
			   dm.compliance_flag,
			   CASE 
				WHEN LEN(ISNULL(dm.threshold_value,'')) = 0 THEN 'F'
				ELSE 'T'
			   END as threshold_metric_flag,
			   'All facilties had acceptable values' as profit_ctr_name_with_key,
			   '',
			   dm.display_format,
			   pd.contains_failed_thresholds as contains_failed_thresholds,
			   pd.contains_empty_metrics as contains_empty_metrics,
			   'T' as is_condensed_value
		FROM   dashboardmeasurement dm
				INNER JOIN #passing_data pd ON dm.measurement_id = pd.measurement_id
				INNER JOIN DashboardTier dt ON dt.tier_id = dm.tier_id
		WHERE contains_empty_metrics = 'F'
		AND contains_failed_thresholds = 'F'
	
		
	END
	

	
	SELECT * FROM #report_data
	

	END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_COPC] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_COPC] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_COPC] TO [EQAI]
    AS [dbo];

