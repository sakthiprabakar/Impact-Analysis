CREATE PROCEDURE sp_trans_audit
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS 

/***************************************************************************************
This SP calculates transportation prices for receipts.

Filename:	F:\EQAI\SQL\EQAI\sp_trans_audit.sql
PB Object(s):	r_trans_audit (Report Center | Audit | Transportation Audit)

04/05/2004 JDB	Added bill_quantity_flag to select to properly calculate the quantity.
		It now uses quantity of 1 when bill_quantity_flag = 'L' (for Load).
09/21/2004 JDB	Added UNION "ALL" because the approval comments changed to texb.
07/18/2006 rg   revised for quoteheader quotedetail
08/13/2007 SCC	Changed to reference service_desc_1 in Billing table
10/14/2010 SK	Added input arguments : company_id, profit_ctr_id
				returns company_name, profit_ctr_name
				Modified the report to run for:
				1. All Companies- all profit centers
				2. selected company- all profit centers
				3. a facility : selected company-selected profit center	
				Moved to Plt_AI

sp_trans_audit 12, 0, '2003-06-01', '2003-06-30'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	qd.bill_method BM
,	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id
,	b.billing_date
,	b.quantity
,	b.approval_code
,	qd.price
,	qd.min_quantity
,	b.hauler
,	p.comments_3
,	b.manifest
,	w.display_name as waste_code
,	b.ref_line_id
,	qd.bill_quantity_flag
,	c.company_name
,	pc.profit_ctr_name
FROM	billing b
JOIN Company c
	ON c.company_id = b.company_id
JOIN ProfitCenter pc
	ON pc.company_id = b.company_id
	AND pc.profit_ctr_id = b.profit_ctr_id
JOIN profileQuoteapproval pqa
	ON pqa.company_id = b.company_id
	AND pqa.profit_ctr_id = b.profit_ctr_id
	AND pqa.approval_code = b.approval_code
JOIN profile p
	ON p.profile_id = pqa.profile_id
	AND p.curr_status_code = 'A'
JOIN profilequotedetail qd 
	ON qd.company_id = pqa.company_id
	AND qd.profit_ctr_id = pqa.profit_ctr_id
	AND qd.quote_id = pqa.quote_id
	AND  qd.record_type = 'T'
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = b.waste_code_uid
WHERE	(@company_id = 0 OR b.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id)
	AND b.billing_date BETWEEN @date_from AND @date_to
	AND b.status_code <> 'V'
	AND b.trans_type = 'D' 
	
UNION ALL

SELECT	
	'Z' BM
,	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id
,	b.billing_date
,	b.quantity
,	b.approval_code
,	rp.price
,	NULL
,	b.hauler
,	b.service_desc_1
,	b.manifest
,	w.display_name as waste_code
,	b.ref_line_id
,	NULL
,	c.company_name
,	pc.profit_ctr_name
FROM billing b
JOIN Company c
	ON c.company_id = b.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = b.company_id
	AND pc.profit_ctr_ID = b.profit_ctr_id
JOIN receiptprice rp
	ON rp.company_id = b.company_id
	AND rp.profit_ctr_id = b.profit_ctr_id
	AND rp.receipt_id = b.receipt_id
	AND rp.line_id = b.line_id
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = b.waste_code_uid
WHERE	(@company_id = 0 OR b.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id)
	AND b.billing_date BETWEEN @date_from AND @date_to
	AND b.status_code <> 'V'
	AND b.waste_code IN ('TRAN', 'TSRV', 'EQSS')
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trans_audit] TO [EQAI]
    AS [dbo];

