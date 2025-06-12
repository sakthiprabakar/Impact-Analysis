
CREATE PROCEDURE sp_DashboardResultsForUser_Corporate
	@user_id int,
	@StartDate datetime,
	@EndDate datetime = NULL,
	@category_id int = NULL,
	@only_failed_or_missing char(1) = NULL
/*	
	Description: 
	Returns dashboard results for a given user & time frame

	Revision History:
	??/01/2009	RJG 	Created
	01/12/2010	RJG		Added category filter
	
	
	--exec sp_DashboardResultsForUser_Corporate 1206, '1/1/2010', '1/1/2011', 10
*/		
AS
BEGIN
/* Get the measurements that this user has access to */


-- this report will return multiple rows per facility per day of data if it has more than 1 day range is selected
if @EndDate IS NULL
	SET @EndDate = cast(convert(varchar, @StartDate, 101) + ' 23:59:59' as datetime)


IF @only_failed_or_missing IS NULL
	SET @only_failed_or_missing = 'T'

--SELECT * FROM view_AccessByUser
	DECLARE @tblCustomAttributes TABLE
	(
		permission_id int,
		theKey varchar(100),
		theValue varchar(100)
	)
	
	DECLARE cur_Attributes CURSOR FOR
		SELECT 
			permission_id, report_custom_arguments
			FROM view_AccessByUser 
			where user_id = @user_id AND record_type = 'R' 
			AND report_custom_arguments IS NOT NULL	
			AND LEN(report_custom_arguments) > 0
			AND CHARINDEX('measurement_id=', report_custom_arguments, 0) > 0
			AND report_tier_id = 1 -- corporate tier
			
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
	
	DELETE FROM @tblCustomAttributes
		WHERE theValue IN (
			SELECT measurement_id from DashboardMeasurement WHERE tier_id = 2 -- delete co/pc tier
			)	
	
	DECLARE @data_expected_for_date table (
		the_date datetime,
		measurement_id int
	)
	
	INSERT INTO @data_expected_for_date (the_date, measurement_id) 
		SELECT @StartDate, measurement_id
			FROM DashboardMeasurement where status = 'A' 
			AND tier_id = 1 
			AND (dashboardmeasurement.time_period = 'Daily') 	
	
	--SELECT * FROM @tblCustomAttributes
	
SELECT DISTINCT dm.description,
		   dm.source,
		   dr.answer,
		   ISNULL(date_table.the_date, @StartDate) as report_period_end_date,
		   ISNULL(dr.threshold_value, dm.threshold_value) as threshold_value,
		   ISNULL(dr.threshold_operator, dm.threshold_operator) as threshold_operator,		   
		   dr.threshold_pass,
		   dm.threshold_type,
		   dm.measurement_id,
		   dm.time_period,
		   dm.copc_waste_receipt_flag,
		   dm.copc_workorder_flag,
		   dm.copc_all_flag,
		   dm.compliance_flag,
		   CASE 
			WHEN LEN(ISNULL(dm.threshold_value,'')) = 0 THEN 'F'
			ELSE 'T'
		   END as threshold_metric_flag,
	       dr.note,
	       dm.display_format,
	       CASE 
			WHEN dr.threshold_pass = 'F' AND LEN(ISNULL(dm.threshold_value,'')) <> 0 THEN 'T'
			ELSE 'F'
	       END as contains_failed_thresholds,
	       CASE 
			WHEN dr.answer IS NULL THEN 'T'
			ELSE 'F'
	       END as contains_empty_metrics	       
	FROM   @tblCustomAttributes user_measurements 
		   INNER JOIN DashboardMeasurement dm ON user_measurements.theValue = dm.measurement_id
		   LEFT OUTER JOIN dashboardresult dr
			 ON dm.measurement_id = dr.measurement_id
			 AND dr.report_period_end_date = @StartDate
		   INNER JOIN dashboardtier
			 ON dm.tier_id = dashboardtier.tier_id
			LEFT OUTER JOIN @data_expected_for_date date_table ON date_table.measurement_id = dr.measurement_id
				AND date_table.the_date = dr.report_period_end_date
	WHERE  
			(dm.tier_id = 1) -- corporate tier
			AND (dm.time_period = 'Daily') 
			AND dm.status = 'A'
			AND EXISTS( SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = dm.measurement_id)			
			AND 
			1 = CASE 
					WHEN (@only_failed_or_missing = 'T' AND (dr.threshold_pass = 'F' OR dr.answer IS NULL)) THEN 1
					WHEN @only_failed_or_missing = 'F' THEN 1
			END
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_Corporate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_Corporate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultsForUser_Corporate] TO [EQAI]
    AS [dbo];

