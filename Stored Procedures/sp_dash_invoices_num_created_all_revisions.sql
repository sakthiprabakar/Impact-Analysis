
CREATE PROCEDURE sp_dash_invoices_num_created_all_revisions
	@measurement_id	int,
	@start_date		datetime,
	@end_date		datetime
AS
/* ************************************************
sp_dash_invoices_num_created_all_revisions:
	@measurement_id: 	The DashboardMeasurement record related to this test.
	@start_date: 		The start date to query for
	@end_date: 			The end date to query for

Number of invoices (all revisions) created per day

select * from DashBoardMeasurement where description like '%invo%'
-- 28

	sp_dash_invoices_num_created_all_revisions 28, '2009-09-10 00:00:00', '2009-09-10 23:59:59'
	select *
		from DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 28
	delete DashboardResult
		where report_period_end_date = '2009-09-10 00:00:00.000'
		and measurement_id = 28

LOAD TO PLT_AI*

08/11/2009 JPB Created
10/06/2009 JPB Removed Profitcenter join, it was unused and inflating numbers
				Added i.status check
10/13/2009 RJG Added V to the ignored statuses
10/13/2009 RJG Changed date_added to invoice_date
10/14/2009 RJG Verified date_added is correct & changed


************************************************ */

SET ansi_warnings OFF

/* InvoiceHeader Status Codes
H
I
O
P
Q
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
	0 AS company_id,
	0 AS profit_ctr_id,
	dm.measurement_id,
	CONVERT (VARCHAR, @end_date, 101) AS report_period_end_date,
	COUNT(i.invoice_id) AS answer,
	NULL AS note,
	dm.threshold_value,
	dm.threshold_operator,
	GETDATE() AS date_modified,
	SYSTEM_USER AS modified_by,
	SYSTEM_USER AS added_by,
	GETDATE() AS date_added
FROM DashboardMeasurement dm
	INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	LEFT OUTER JOIN invoiceheader i ON i.date_added BETWEEN @start_date AND @end_date
		AND i.status NOT IN('V','O')
WHERE
 	dm.measurement_id = @measurement_id
GROUP BY
	dm.measurement_id,
	dm.threshold_operator,
	dm.threshold_value,
	dm.compliance_flag,
	dt.tier_name
SET ansi_warnings ON


SELECT distinct status FROM invoiceheader W

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_invoices_num_created_all_revisions] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_invoices_num_created_all_revisions] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_invoices_num_created_all_revisions] TO [EQAI]
    AS [dbo];

