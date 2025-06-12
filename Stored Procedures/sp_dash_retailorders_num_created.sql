
CREATE PROCEDURE sp_dash_retailorders_num_created
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_retailorders_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of retail orders created per day

select * from DashBoardMeasurement where description like '%retai%'
-- 33

	sp_dash_retailorders_num_created 33, '2009-09-25 00:00:00', '2009-09-25 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-25 00:00:00.000'
		and measurement_id = 33
	delete DashboardResult 
		where report_period_end_date = '2009-09-25 00:00:00.000'
		and measurement_id = 33
		
LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Added o.status <> 'V' check.
			Converted null as company/profitctr_id to 0 as...
			Removed Profitcenter join, as this is a corporate measurement.
10/13/2009 RJG Since this has been converted to a strictly corporate measurement
				removed join to OrderDetail (replaced with OrderHeader)
				changed date_added to order_date
				changed to ignore status of V
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
	convert(varchar(20), count(distinct oh.order_id)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	LEFT JOIN OrderHeader oh on 
		oh.order_date BETWEEN @start_date AND @end_date		
		AND oh.status <> 'V'
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
    ON OBJECT::[dbo].[sp_dash_retailorders_num_created] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retailorders_num_created] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_retailorders_num_created] TO [EQAI]
    AS [dbo];

