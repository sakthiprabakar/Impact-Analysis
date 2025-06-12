DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_wcvoc_avg_conc_west]
GO
CREATE PROCEDURE sp_rpt_wcvoc_avg_conc_west
	@company_id			int
,	@receipt_date_from 	datetime
,	@receipt_date_to 	datetime
,	@cust_id_from 		int
,	@cust_id_to 		int
AS
/**************************************************************************
FILENAME:  sp_rpt_wcvoc_avg_conc_west.sql

PB Object:	r_wcvoc_avg_concentration_west

12/10/1999 JDB	Created stored procedure from wcvoc.sql to calculate the 
		average wcvoc for the west side.
		Used with d_rpt_wcvoc_avg_conc_west
08/05/2002 SCC	Added trans_mode to Receipt join
09/30/2002 JDB	Modified to use new container tables
03/20/2003 JDB	Modified to use receipt.DDVOC field.  This must be divided by 1,000,000
		to produce the correct values.
06/11/2003 SCC	Changed references to location table to ProcessLocation table
07/14/2006 MK	Modified to use ProfileQuoteApproval and Profile instead of Approval
12/10/2010 SK	Added company_id as input arg, added joins to company_id
				Replaced *= joins with standard ANSI joins, re-formatted
				Moved to Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
06/29/2022 GDE  DevOps 42727 - CAA VOC Worksheet - Report update
sp_rpt_wcvoc_avg_conc_west 2, '1/1/2006','1/30/2006',1000,10000
**************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE		@msg	varchar(50)

SELECT 
	r.approval_code
,	w.display_name as waste_code
,	g.generator_name
,	r.quantity
,	r.ddvoc/1000000 AS VOC
,	r.receipt_date
,	r.company_id
,	b.pound_conv
,	r.bill_unit_code
,	r.location
,	r.net_weight
,	NULL AS container_location
,	NULL AS container_container_count
,	pl.location_report_flag
,	r.manifest
,	r.bulk_flag
,	NULL AS disposal_date
,	c.company_name
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN BillUnit b
	ON b.bill_unit_code = r.bill_unit_code
JOIN ProcessLocation pl
	ON pl.location = r.location
	AND pl.location_report_flag = 'W'
JOIN ProfileQuoteApproval a
	ON a.company_id = r.company_id
	AND a.profit_ctr_id = r.profit_ctr_id
	AND a.approval_code = r.approval_code
JOIN Profile p
	ON p.profile_id = a.profile_id
	AND p.curr_status_code IN ('A','H')
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = r.waste_code_uid
WHERE r.receipt_date > '06-05-1997' 
	AND r.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
	AND r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND r.fingerpr_status = 'A'  
	AND r.receipt_status not in ('R', 'V') 
	AND (r.trans_type = 'D' AND r.trans_mode = 'I')
	AND (r.bulk_flag = 'T' OR (r.bulk_flag = 'F' AND r.receipt_date < '08-01-1999'))
	AND r.company_id = @company_id
	
UNION

SELECT 
	r.approval_code
,	w.display_name as waste_code
,	g.generator_name
,	r.quantity
,	r.ddvoc/1000000 AS VOC
,	r.receipt_date
,	r.company_id
,	b.pound_conv
,	r.bill_unit_code
,	r.location
,	r.net_weight
,	cd.location
,	container_count = ISNULL((SELECT COUNT(C2.container_ID) FROM Container C2
								WHERE cd.receipt_id = C2.receipt_id
									AND cd.line_id = C2.line_id
									AND cd.container_id = C2.container_id
									AND cd.profit_ctr_id = C2.profit_ctr_id
									AND cd.company_id = C2.company_id
									AND cd.container_type = C2.container_type), 0)
,	pl.location_report_flag
,	r.manifest
,	r.bulk_flag
,	cd.disposal_date
,	c.company_name
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN BillUnit b
	ON b.bill_unit_code = r.bill_unit_code
JOIN ProfileQuoteApproval a
	ON a.company_id = r.company_id
	AND a.profit_ctr_id = r.profit_ctr_id
	AND a.approval_code = r.approval_code
JOIN Profile p
	ON p.profile_id = a.profile_id
	AND p.curr_status_code IN ('A','H')
JOIN ContainerDestination cd
	ON cd.company_id = r.company_id
	AND cd.profit_ctr_id = r.profit_ctr_id
	AND cd.receipt_id = r.receipt_id
	AND cd.line_id = r.line_id
	AND cd.disposal_date > '06-05-1997' 
	AND cd.disposal_date BETWEEN @receipt_date_from AND @receipt_date_to
JOIN ProcessLocation pl
	ON pl.location = cd.location
	AND pl.location_report_flag = 'W'
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = r.waste_code_uid
WHERE r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND r.fingerpr_status = 'A'  
	AND r.receipt_status not in ('R', 'V')
	AND (r.trans_type = 'D' AND r.trans_mode = 'I')
	AND (r.bulk_flag = 'F' AND r.receipt_date > '07-31-1999')
	AND r.company_id = @company_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_wcvoc_avg_conc_west] TO [EQAI]
    AS [dbo];

