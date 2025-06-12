
CREATE PROCEDURE sp_dash_receipts_manifests_num_received
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_receipts_manifests_num_received:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of unique manifests received per day

select * from DashBoardMeasurement where description like '%mani%'
-- 46

	sp_dash_receipts_manifests_num_received 46, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select *
		from DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 46
	delete DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 46
LOAD TO PLT_AI*

09/10/2009 JPB Created
10/06/2009 JPB Added receipt_status check
10/13/2009 RJG Changed date_added to receipt_date, changed to ignore V and R statuses
10/14/2009 RJG Verified receipt_date is correct date to use
10/14/2009 RJG Per Jonathan and Jason, added
		AND r.trans_type = 'D'
		AND r.trans_mode = 'I'
		AND r.fingerpr_status = 'A'		
10/15/2009 RJG Changed fingerpr_status to NOT IN(V,R)
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
	convert(varchar(20), count(distinct r.manifest)) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	INNER JOIN profitcenter p ON p.status = 'A' --and p.waste_receipt_flag = 'T'
	LEFT OUTER JOIN receipt r ON r.company_id = p.company_id
		AND r.profit_ctr_id = p.profit_ctr_id
		AND r.receipt_date BETWEEN @start_date AND @end_date
		AND r.receipt_status NOT IN ('V','R')
		AND r.trans_type = 'D'
		AND r.trans_mode = 'I'
		AND r.fingerpr_status NOT IN ('V','R')
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
    ON OBJECT::[dbo].[sp_dash_receipts_manifests_num_received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_manifests_num_received] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_receipts_manifests_num_received] TO [EQAI]
    AS [dbo];

