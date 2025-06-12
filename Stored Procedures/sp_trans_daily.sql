CREATE PROCEDURE sp_trans_daily
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS 

/***************************************************************************************
This SP calculates transportation prices for receipts.

Filename:	F:\EQAI\SQL\EQAI\sp_trans_daily.sql
PB Object(s):	r_trans_daily (Report Center | Audit | Daily Transportation Received)

04/01/2004 JDB	Added bill_quantity_flag to select to properly calculate the quantity.
		It now uses quantity of 1 when bill_quantity_flag = 'L' (for Load).
09/21/2004 JDB	Added UNION "ALL" because the approval comments changed to text.
12/06/2004 MK	Modified ticket_id to receipt_id and line_id
07/18/2006 rg	modifed for quote header quote detail
10/14/2010 SK	Added input arguments : company_id, profit_ctr_id
				returns company_name, profit_ctr_name
				Modified the report to run for:
				1. All Companies- all profit centers
				2. selected company- all profit centers
				3. a facility : selected company-selected profit center	
				Moved to Plt_AI
				
sp_trans_daily 21, 0, '2010-01-01', '2010-01-30'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	qd.bill_method BM
,	r.company_id
,	r.profit_ctr_id
,	r.receipt_id receipt_id
,	r.line_id line_id
,	r.receipt_date
,	r.quantity
,	pqa.approval_code
,	qd.price
,	qd.min_quantity
,	r.hauler
,	p.comments_3
,	r.manifest
,	w.display_name as waste_code
,	r.ref_line_id
,	r.bill_quantity_flag
,	c.company_name
,	pc.profit_ctr_name
FROM receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_id = r.company_id
	AND pc.profit_ctr_id = r.profit_ctr_id
JOIN profileQuoteapproval pqa
	ON pqa.company_id = r.company_id
	AND pqa.profit_ctr_id = r.profit_ctr_id
	AND pqa.approval_code = r.approval_code
JOIN profile p
	ON p.profile_id = pqa.profile_id
	AND p.curr_status_code = 'A'
JOIN profilequotedetail qd 
	ON qd.company_id = pqa.company_id
	AND qd.profit_ctr_id = pqa.profit_ctr_id
	AND qd.quote_id = pqa.quote_id
	AND  qd.record_type = 'T'
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = r.waste_code_uid
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.receipt_status NOT IN ('T', 'V')
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I' 
	
UNION ALL

SELECT 
	'Z' BM
,	r.company_id
,	r.profit_ctr_id
,	r.receipt_id receipt_id
,	r.line_id line_id
,	r.receipt_date
,	r.quantity
,	r.approval_code
,	rp.price
,	NULL
,	r.hauler
,	r.service_desc
,	r.manifest
,	w.display_name as waste_code
,	r.ref_line_id
,	NULL
,	c.company_name
,	pc.profit_ctr_name
FROM receipt r
JOIN Company c
	ON c.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = r.company_id
	AND pc.profit_ctr_ID = r.profit_ctr_id
JOIN receiptprice rp
	ON rp.company_id = r.company_id
	AND rp.profit_ctr_id = r.profit_ctr_id
	AND rp.receipt_id = r.receipt_id
	AND rp.line_id = r.line_id
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = r.waste_code_uid
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.receipt_status NOT IN ('T', 'V')
	AND r.trans_mode = 'I'
	AND r.waste_code IN ('TRAN', 'TSRV', 'EQSS')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trans_daily] TO [EQAI]
    AS [dbo];

