
CREATE PROCEDURE sp_rpt_receipts_unbilled 
	@company_id			int
,	@profit_ctr_id		int
AS

/***********************************************************************
PB Object(s):	r_receipts_unbilled
	
11/02/2010 SK	Created on Plt_AI

sp_rpt_receipts_unbilled 21, 0
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	Receipt.receipt_id
,	Receipt.receipt_status
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	Customer.cust_name
,	MAX(Generator.EPA_ID) AS EPA_ID
,	MAX(Generator.generator_name) AS generator_name
,	SUM(IsNull(ReceiptPrice.waste_extended_amt,0)) AS waste_extended_amt
,	SUM(IsNull(ReceiptPrice.sr_extended_amt,0)) AS sr_extended_amt
,	SUM(IsNull(ReceiptPrice.total_extended_amt,0)) AS total_extended_amt
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN ReceiptPrice
	ON ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.company_id = Receipt.company_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status IN ('N', 'L', 'U','M')
GROUP BY 
	Receipt.receipt_id
,	Receipt.receipt_status
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	Customer.cust_name
,	Company.company_name
,	ProfitCenter.profit_ctr_name
ORDER BY Receipt.receipt_status, Receipt.customer_id, Receipt.receipt_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipts_unbilled] TO [EQAI]
    AS [dbo];

