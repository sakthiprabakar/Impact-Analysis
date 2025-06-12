
CREATE PROCEDURE sp_dash_workorders_total_submitted
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_workorders_total_submitted:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Total Price of work orders submitted per day

select * from DashBoardMeasurement where description like '%work%'
-- 38

	sp_dash_workorders_total_submitted 38, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 38
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 38
	
LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Exclude voided workorders
				Remove DashboardMeasurementProfitCenter join.

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
	convert(varchar(20), sum(w.total_price)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A' and p.workorder_flag = 'T'
	LEFT OUTER JOIN Workorderheader w ON w.company_id = p.company_id 
		AND w.profit_ctr_id = p.profit_ctr_id
		AND w.date_submitted BETWEEN @start_date AND @end_date
		AND w.workorder_status <> 'V'
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
ORDER BY p.company_id, p.profit_ctr_id

SET ansi_warnings ON


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_total_submitted] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_total_submitted] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_workorders_total_submitted] TO [EQAI]
    AS [dbo];

