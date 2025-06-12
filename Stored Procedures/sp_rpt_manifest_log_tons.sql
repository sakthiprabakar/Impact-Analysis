CREATE PROCEDURE sp_rpt_manifest_log_tons
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@haz_flag			char(1)
AS
/***********************************************************************
This procedure runs for all the Manifest Log by tons reports.

Filename:	L:\Apps\SQL\EQAI\sp_rpt_manifest_log_tons.sql

Note:	Send @haz_flag = 'U' for ALL of the Tons reports.
	Send @haz_flag = 'T' for the Hazardous (Tons) report.
	Send @haz_flag = 'F' for the Non-Hazardous (Tons) report.

05/27/2010 KAM  Copied from sp_rpt_manifest_log.sql to make changes for Tons
11/04/2010 SK	added company_id as input arg, added joins to company_id whereever necessary
				moved to Plt_AI

sp_rpt_manifest_log_tons 21, 0, '7/16/04', '7/16/04', 1, 999999, 'U'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	r.receipt_id
,	r.line_id
,	r.generator_id
,	g.generator_name
,	r.approval_code
,	r.quantity
,	r.manifest
,	r.location
,	r.receipt_date
,	r.time_in
,	r.time_out
,	r.company_id
,	r.profit_ctr_id
,	IsNull(b.pound_conv,0)
,	w.haz_flag
,	r.treatment_id
,	r.bulk_flag
,	IsNull(p.waste_water_flag,'N')
,	c.company_name
,	pc.profit_ctr_name
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = r.company_id
	AND pc.profit_ctr_ID = r.profit_ctr_id
JOIN BillUnit b
	ON b.bill_unit_code = r.bill_unit_code
JOIN Treatment t
	ON t.treatment_id = r.treatment_id
	AND t.company_id = r.company_id
	AND t.profit_ctr_id = r.profit_ctr_id
JOIN WasteCode w
	ON w.waste_code_uid = r.waste_code_uid
	AND (@haz_flag = 'U' OR w.haz_flag = @haz_flag)
JOIN Profile p
	ON p.profile_id = r.profile_id
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE (@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.receipt_status NOT IN ('T','V','R')
	AND r.fingerpr_status NOT IN ('V', 'R')
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_log_tons] TO [EQAI]
    AS [dbo];

