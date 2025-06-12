
CREATE PROCEDURE sp_dash_eqweb_num_logins_eq
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_eqweb_num_logins_eq:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of distinct EQ Associates to log into EQ Online

examples:
	1: Corporate measurement:
	update dashboardmeasurement set 
		tier_id = 1 
		where measurement_id = 9
	sp_dash_eqweb_num_logins_eq 9, '2009-06-15 00:00:00', '2009-06-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-06-15' and measurement_id = 9
	delete DashboardResult 
		where report_period_end_date = '2009-06-15' and measurement_id = 9
	
	2: per Company/ProfitCenter (all) measurement:
	update dashboardmeasurement set 
		tier_id = 2, copc_all_flag = 'T' 
		where measurement_id = 9
	sp_dash_eqweb_num_logins_eq 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-01-15'
	delete DashboardResult 
		where report_period_end_date = '2009-01-15'

	3: per Company/ProfitCenter (specific) measurement:
	update dashboardmeasurement set 
		tier_id = 2, copc_all_flag = 'F' 
		where measurement_id = 9
	-- what to expect data for...
	select p.company_id, p.profit_ctr_id, p.status, p.waste_receipt_flag 
		from profitcenter p INNER JOIN DashboardMeasurementProfitCenter d 
		ON p.company_id = d.company_id AND p.profit_ctr_id = d.profit_ctr_id 
		where d.measurement_id = 9
	sp_dash_eqweb_num_logins_eq 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-01-15'
	delete DashboardResult 
		where report_period_end_date = '2009-01-15'

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/14/2009 RJG Verified date_added is correct
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
	convert(varchar(20), count(distinct logon)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	LEFT OUTER JOIN EQWeb..b2blog a ON a.date_added BETWEEN @start_date AND @end_date AND a.action like 'EQ Associate Logged In'
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
    ON OBJECT::[dbo].[sp_dash_eqweb_num_logins_eq] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_eqweb_num_logins_eq] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_eqweb_num_logins_eq] TO [EQAI]
    AS [dbo];

