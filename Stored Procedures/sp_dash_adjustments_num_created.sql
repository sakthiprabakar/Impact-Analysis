
CREATE PROCEDURE sp_dash_adjustments_num_created
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_adjustments_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of Adjustments created per day

examples:
	1: Corporate measurement:
	update dashboardmeasurement set 
		tier_id = 1 
		where measurement_id = 9
	sp_dash_adjustments_num_created 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-01-15'
	delete DashboardResult 
		where report_period_end_date = '2009-01-15'
	
	2: per Company/ProfitCenter (all) measurement:
	update dashboardmeasurement set 
		tier_id = 2, copc_all_flag = 'T' 
		where measurement_id = 9
	sp_dash_adjustments_num_created 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
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
	sp_dash_adjustments_num_created 9, '2009-01-15 00:00:00', '2009-01-15 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-01-15'
	delete DashboardResult 
		where report_period_end_date = '2009-01-15'

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/09/2009 RJG Modified to convert this to a co/pc metric (added Adjustment Detail and ProfitCenter join)
10/14/2009 RJG - Verified date_added should be used
10/14/2009 RJG - Changed adjustment to be: trans_source, co/pc, and receipt_id
10/19/2009 RJG - Changed AdjustmentHeader to LEFT OUTER against ProfitCenter so that it returns records even when there is no data (zeros)
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
	COUNT(
		DISTINCT trans_source + '-' 
		+ cast(ad.company_id as varchar(20))
		+ CAST(ad.profit_ctr_id as varchar(20))
		+ CAST(ad.receipt_id as varchar(20))
	) as answer,
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
	LEFT OUTER JOIN AdjustmentHeader a ON a.date_added BETWEEN @start_date AND @end_date
	LEFT OUTER JOIN AdjustmentDetail ad
		ON ad.company_id = p.company_ID 
		AND ad.profit_ctr_id = p.profit_ctr_ID		
		AND ad.adjustment_id = a.adjustment_id	
WHERE 
 	dm.measurement_id = @measurement_id
GROUP BY 
	p.company_id,
	p.profit_ctr_id,
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value

	
SET ansi_warnings ON


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_adjustments_num_created] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_adjustments_num_created] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_adjustments_num_created] TO [EQAI]
    AS [dbo];

