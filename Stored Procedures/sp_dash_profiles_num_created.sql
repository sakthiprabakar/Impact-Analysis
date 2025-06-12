
CREATE PROCEDURE sp_dash_profiles_num_created
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_profiles_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of Profiles created per day

select * from DashBoardMeasurement where description like '%pro%'
-- 40

	sp_dash_profiles_num_created 40, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 40
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 40

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB	Added check of curr_status_code <> 'V'

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
	0 AS company_id, 
	0 AS profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	convert(varchar(20), count(pro.profile_id)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	LEFT OUTER JOIN Profile pro ON pro.date_added BETWEEN @start_date AND @end_date
		AND pro.curr_status_code <> 'V'
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
    ON OBJECT::[dbo].[sp_dash_profiles_num_created] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_profiles_num_created] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_profiles_num_created] TO [EQAI]
    AS [dbo];

