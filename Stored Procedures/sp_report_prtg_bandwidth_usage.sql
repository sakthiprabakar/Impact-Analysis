create procedure sp_report_prtg_bandwidth_usage
	@start_date datetime,
	@end_date datetime
as
begin
	-- column id 20 is speed in (in BYTES)
	-- column id 24 is speed out (in BYTES)
	
	/*
		todo - if PTP T1 is present, use that
				if no PTP T1 (Augusta, Dallas) then use the T1 to Internet
	*/
	
	-- first, insert the rows that have a PTP T1
	SELECT 
	result.threshold_value,
	result.threshold_operator,
	result.threshold_result,
	sensor.sensor_location,
	col.column_name,
	CAST(reporting_start_interval AS Date) As reporting_date, datepart(hh, reporting_start_interval) AS reporting_hour,
    COUNT(result.threshold_result) as threshold_result_count
	,0 as DISTINCT_LOCATIONS,
	SUM(
		CASE WHEN result.threshold_result = 'T' THEN 1
		ELSE 0
		END
	) as threshold_exceeded_count
	,
	SUM(
		CASE WHEN result.threshold_result = 'F' THEN 1
		ELSE 0
		END
	) as threshold_ok_count	
	,
	SUM(
		CASE WHEN result.threshold_result IS NULL THEN 1
		ELSE 0
		END
	) as threshold_missing_count			
	 INTO #data FROM PRTG_SensorExtractResult result
	 JOIN PRTG_SensorExtract sensor ON result.sensor_id = sensor.sensor_id
	 JOIN PRTG_SensorExtractTypeColumn col ON result.column_id = col.column_id
		where result.reporting_start_interval BETWEEN @start_date and @end_date
	GROUP BY 
	sensor.sensor_location,
	result.threshold_value,
	result.threshold_operator,
	result.threshold_result,
	col.column_name,
	CAST(reporting_start_interval AS Date)
	,datepart(hh, reporting_start_interval)
       ,result.column_id
	,sensor.sensor_type_id
	--HAVING result.column_id IN (20,24)
	HAVING col.column_name IN('Traffic in (speed)(RAW)','Traffic out (speed)(RAW)')
	AND sensor.sensor_type_id = 2
	
	--SELECT * FROM PRTG_SensorExtract pg
	--	join PRTG_SensorExtractTypeColumn pc ON pg.sensor_type_id = pc.type_id
	--	where sensor_type_id = 2
	
	--SELECT * FROM PRTG_SensorExtractTypeColumn_tmp where type_id = 3
	-- next, insert all others (t1 to internet)
	INSERT INTO #data
	SELECT 
	result.threshold_value,
	result.threshold_operator,
	result.threshold_result,
	sensor.sensor_location,
	col.column_name,
	CAST(reporting_start_interval AS Date) As reporting_date, datepart(hh, reporting_start_interval) AS reporting_hour,
       
	COUNT(result.threshold_result) as threshold_result_count
	,0 as DISTINCT_LOCATIONS,
	SUM(
		CASE WHEN result.threshold_result = 'T' THEN 1
		ELSE 0
		END
	) as threshold_exceeded_count
	,
	SUM(
		CASE WHEN result.threshold_result = 'F' THEN 1
		ELSE 0
		END
	) as threshold_ok_count	
	,
	SUM(
		CASE WHEN result.threshold_result IS NULL THEN 1
		ELSE 0
		END
	) as threshold_missing_count		
	 FROM PRTG_SensorExtractResult result
	 JOIN PRTG_SensorExtract sensor ON result.sensor_id = sensor.sensor_id
	 JOIN PRTG_SensorExtractTypeColumn col ON result.column_id = col.column_id
		where result.reporting_start_interval BETWEEN @start_date and @end_date
	GROUP BY 
	sensor.sensor_location,
	result.threshold_value,
	result.threshold_operator,
	result.threshold_result,
	col.column_name,
	CAST(reporting_start_interval AS Date), datepart(hh, reporting_start_interval)
    ,result.column_id
	,sensor.sensor_type_id
	--HAVING result.column_id IN (39,43)
	HAVING col.column_name IN('Traffic in (speed)(RAW)','Traffic out (speed)(RAW)')
	AND sensor.sensor_type_id = 3
	AND sensor.sensor_location NOT IN (SELECT sensor_location from #data)
	--SELECT * FROM PRTG_SensorExtractTypeColumn
	
	
	
	
	declare @distinct_locations int 
	SELECT @distinct_locations = COUNT(DISTINCT sensor_location) FROM #data
	
	update #data set DISTINCT_LOCATIONS = @distinct_locations
	
	SELECT * FROM #data 
	order by reporting_date, reporting_hour
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_prtg_bandwidth_usage] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_prtg_bandwidth_usage] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_prtg_bandwidth_usage] TO [EQAI]
    AS [dbo];

