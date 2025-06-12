
CREATE PROCEDURE sp_rpt_manifest_not_scanned
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************
This procedure runs for Manifest Not Scanned Report
PB Object(s):	r_manifest_not_scanned

10/26/2010 SK	Created
03/31/2011 RB	Performance issue, changed "r.manifest NOT IN (select...)"
                to "r.manifest not in (select 1 from ...)

sp_rpt_manifest_not_scanned 12, 0, '7/16/04', '7/16/04', 1, 999999
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
,	r.receipt_status
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
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
-- rb 03/31/2011 perfomance issue
--	AND r.manifest NOT IN ( SELECT DISTINCT s.document_name 
--							FROM plt_image.dbo.scan s
--							WHERE s.status = 'A' 
--								AND s.company_id = r.company_id
--								AND s.profit_ctr_id = r.profit_ctr_id
--								AND s.type_id in (1,2) )
	AND not exists (select 1 from plt_image.dbo.Scan s
					where s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and s.document_name = r.manifest
					and s.status = 'A'
					and s.type_id in (1,2))
	AND r.receipt_status in ('A','U')
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.customer_id <> 2226
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_not_scanned] TO [EQAI]
    AS [dbo];

