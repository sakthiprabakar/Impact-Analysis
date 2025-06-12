
CREATE PROCEDURE sp_dash_containers_num_new_status
	@measurement_id	int,
	@until_date		datetime = NULL
AS
/* ************************************************
sp_dash_containers_num_new_status:
	@measurement_id: 	The DashboardMeasurement record related to this test.

Total Number of containers with a status of New

select * from DashBoardMeasurement where description like '%con%'
-- 36

	sp_dash_containers_num_new_status 36, '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 36
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 36

LOAD TO PLT_AI*

08/11/2009 JPB Created
08/25/2009 JPB Added @until_date parameter
10/06/2009 JPB Removed DashboardMeasureProfitcenter join

************************************************ */

SET ansi_warnings OFF

IF @until_date is null set @until_date = getdate()

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
	CONVERT (VARCHAR, @until_date, 101) AS report_period_end_date,
	convert(varchar(20), count(c.date_added)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'
	LEFT OUTER JOIN Container c ON c.company_id = p.company_id 
		AND c.profit_ctr_id = p.profit_ctr_id
WHERE 
 	dm.measurement_id = @measurement_id
	AND c.status = 'N'
	AND c.date_added <= @until_date
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
    ON OBJECT::[dbo].[sp_dash_containers_num_new_status] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_containers_num_new_status] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_containers_num_new_status] TO [EQAI]
    AS [dbo];

