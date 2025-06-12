
CREATE PROCEDURE sp_dash_eqai_num_logins
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_eqai_num_logins:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of Distinct users to log into EQAI per day

examples:
	1: Corporate measurement:
	update dashboardmeasurement set 
		tier_id = 1 
		where measurement_id = 9
	sp_dash_eqai_num_logins 9, '2009-06-15 00:00:00', '2009-06-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-06-15' and measurement_id = 9
	delete DashboardResult 
		where report_period_end_date = '2009-06-15' and measurement_id = 9
	
	2: per Company/ProfitCenter (all) measurement:
	update dashboardmeasurement set 
		tier_id = 2, copc_all_flag = 'T' 
		where measurement_id = 9
	sp_dash_eqai_num_logins 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
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
	sp_dash_eqai_num_logins 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-01-15'
	delete DashboardResult 
		where report_period_end_date = '2009-01-15'

LOAD TO PLT_AI*

08/11/2009 JPB Created

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
	convert(varchar(20), count(distinct user_code)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	LEFT OUTER JOIN userlogin a ON a.login_date BETWEEN @start_date AND @end_date
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
    ON OBJECT::[dbo].[sp_dash_eqai_num_logins] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_eqai_num_logins] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_eqai_num_logins] TO [EQAI]
    AS [dbo];

