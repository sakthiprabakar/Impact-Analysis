
CREATE PROCEDURE sp_dash_workorders_num_generators_serviced_corporate
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_workorders_num_generators_serviced_corporate:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of generators serviced per workorder per day

select * from DashBoardMeasurement where description like '%gener%'
-- 47

	sp_dash_workorders_num_generators_serviced_corporate 47, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select *
		from DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 47
	delete DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 47

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Removed DashboardMeasurementProfitCenter join
10/13/2009 RJG Changed date_added to start_date
		Changed to ignore workorder_status ('V','X','T')
10/14/2009 RJG Verified start_date is correct		
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
	0 as company_id,
	0 as profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	count(distinct convert(varchar(40), w.workorder_id) + '-' + convert(varchar(40), w.generator_id)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'	AND p.workorder_flag = 'T'
	LEFT OUTER JOIN workorderheader w ON w.company_id = p.company_id
		AND w.profit_ctr_id = p.profit_ctr_id
		AND w.start_date BETWEEN @start_date AND @end_date
		AND w.workorder_status NOT IN ('V','X','T')
WHERE
 	dm.measurement_id = @measurement_id
GROUP BY
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value,
	dm.compliance_flag,
	dt.tier_name

SET ansi_warnings ON


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_num_generators_serviced_corporate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_num_generators_serviced_corporate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_num_generators_serviced_corporate] TO [EQAI]
    AS [dbo];

