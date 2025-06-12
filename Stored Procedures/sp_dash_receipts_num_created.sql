
CREATE PROCEDURE sp_dash_receipts_num_created
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_receipts_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of receipts created per day

select * from DashBoardMeasurement where description like '%rece%'
-- 27

	sp_dash_receipts_num_created 27, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 27
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 27

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Removed Join to DashboardMeasurementProfitCenter
			Added receipt_status check
10/12/2009 RJG Added filter out of 'R' statuses
10/13/2009 RJG Changed date_added to r.receipt_date 
10/14/2009 RJG Changed back to date_added
************************************************ */

SET ansi_warnings OFF

/*
Receipt Status Types
NULL
A 
I 
L
M
N
R
T
U
V
*/

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
	COUNT(DISTINCT r.receipt_id) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A'--	AND p.waste_receipt_flag = 'T'
	LEFT OUTER JOIN receipt r ON r.company_id = p.company_id 
		AND r.profit_ctr_id = p.profit_ctr_id
		AND r.date_added BETWEEN @start_date AND @end_date
		AND r.receipt_status NOT IN ('V','R')
		AND	r.trans_type = 'D'
		AND r.trans_mode = 'I'
		AND r.fingerpr_status NOT IN('V','R')
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
    ON OBJECT::[dbo].[sp_dash_receipts_num_created] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_num_created] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_num_created] TO [EQAI]
    AS [dbo];

