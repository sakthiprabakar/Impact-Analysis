
CREATE PROCEDURE sp_rpt_manifest_scanned
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************
This procedure runs for Manifests Scanned Report
PB Object(s):	r_manifest_scanned

10/26/2010 SK	Created on Plt_AI

sp_rpt_manifest_scanned 12, 0, '7/16/04', '7/16/04', 1, 999999
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	r.manifest
,	r.receipt_id
,	r.receipt_date
,	r.customer_id
,	r.generator_id
,	g.epa_id
,	g.generator_name
,	r.company_id
,	r.profit_ctr_id
,	c.company_name
,	pc.profit_ctr_name
FROM Receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_id = r.company_id
	AND pc.profit_ctr_id = r.profit_ctr_id
JOIN Generator g
	ON g.generator_id = r.generator_id
JOIN plt_image.dbo.scan s
	ON s.manifest = r.manifest
	AND s.receipt_id = r.receipt_id
	AND s.company_id = r.company_id
	AND s.profit_ctr_id = r.profit_ctr_id
	AND s.status = 'A' 
	AND s.type_id = 1
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_mode = 'I'
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_scanned] TO [EQAI]
    AS [dbo];

