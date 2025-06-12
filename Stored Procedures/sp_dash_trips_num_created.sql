
CREATE PROCEDURE sp_dash_trips_num_created
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_trips_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of Trips created per day

select * from DashBoardMeasurement where description like '%trip%'
-- 35

	sp_dash_trips_num_created 35, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 35
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 35

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Removed DashboardMeasurementProfitcenter join
				Added trip_status <> 'V' check
				Refined ProfitCenter join to limit to PC's with workorder_flag = 'T'
10/14/2009 RJG Verified order_date is correct date field to use
************************************************ */

SET ansi_warnings OFF

INSERT DashboardResult (
	company_id,
	profit_ctr_id,
	measurement_id,
	report_period_end_date,
	answer,
	note,
	threshold_value,
	threshold_operator,
	date_modified,
	modified_by,
	added_by,
	date_added
)	
SELECT
	p.company_id,
	p.profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	convert(varchar(20), count(t.trip_id)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'-- and workorder_flag = 'T'
	LEFT OUTER JOIN tripheader t ON t.company_id = p.company_id 
		AND t.profit_ctr_id = p.profit_ctr_id
		AND t.date_added BETWEEN @start_date AND @end_date
		AND t.trip_status <> 'V'
WHERE 
 	dm.measurement_id = @measurement_id
GROUP BY 
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value,
	dm.compliance_flag,
	dt.tier_name,
	p.company_id,
	p.profit_ctr_id 
ORDER BY 
	p.company_id,
	p.profit_ctr_id 

SET ansi_warnings ON


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_trips_num_created] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_trips_num_created] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_trips_num_created] TO [EQAI]
    AS [dbo];

