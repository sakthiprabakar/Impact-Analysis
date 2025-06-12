
CREATE PROCEDURE sp_rpt_manifest_count
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************
This procedure runs for Manifest Count Report
PB Object(s):	r_manifest_count

10/26/2010 SK	Created on Plt_AI

sp_rpt_manifest_count 12, 0, '7/16/04', '7/16/04', 1, 999999
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	r.manifest
,	r.company_id
,	r.profit_ctr_id
,	r.receipt_id
,	Customer.cust_name
,	g.epa_id
,	g.generator_name
,	r.receipt_date
,	r.hauler
,	r.truck_code
,	c.company_name
,	pc.profit_ctr_name
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_id = r.company_id
	AND pc.profit_ctr_id = r.profit_ctr_id
JOIN Customer
	ON Customer.customer_ID = r.customer_id
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.receipt_status = 'A'
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.manifest_flag = 'M'
	AND r.fingerpr_status = 'A'
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_count] TO [EQAI]
    AS [dbo];

