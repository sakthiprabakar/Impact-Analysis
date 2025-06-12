
CREATE PROCEDURE sp_dash_receipts_bulk_num_received
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_receipts_num_created:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of bulk receipts received per day

select * from DashBoardMeasurement where description like '%rece%'
-- 27

	exec sp_dash_receipts_bulk_num_received 64, '01/01/2011', '01/31/2011'
	sp_dash_receipts_bulk_num_received 27, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select * 
		from DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 27
	delete DashboardResult 
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 27

LOAD TO PLT_AI*

06/07/2011	- RJG	Created
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
	COUNT(r.receipt_id) AS answer,
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
		AND r.receipt_date >= @start_date and r.receipt_date <=@end_date
		AND r.receipt_status NOT IN ('V','R')
		AND	r.trans_type = 'D'
		AND r.trans_mode = 'I'
		AND r.fingerpr_status NOT IN('V','R')
		AND r.bulk_flag = 'T' -- bulk flag
WHERE 
 	dm.measurement_id = @measurement_id
-- 	AND
--r.company_id = 2	
--and r.profit_ctr_id = 21
--and r.receipt_id=	480842
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
    ON OBJECT::[dbo].[sp_dash_receipts_bulk_num_received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_bulk_num_received] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_bulk_num_received] TO [EQAI]
    AS [dbo];

