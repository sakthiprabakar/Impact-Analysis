CREATE PROCEDURE sp_receipts_w_workorders 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS
/****************
This SP runs for the Report-  Waste Receipt Workorders by Receipt Date

PB Object(s):	r_receipts_w_workorders

12/08/2010 SK Created on Plt_AI
01/12/2012 SK	Changed to use the new WorkOrderTypeHeader.workorder_type_id (GL standardization project)

exec sp_receipts_w_workorders 0, -1, '2006-01-01', '2006-12-31'
******************/
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
,	Receipt.source_id
,	WorkorderHeader.workorder_type_id
,	WorkorderTypeHeader.account_desc
,	CASE WHEN Receipt.receipt_status in ('N', 'L', 'U') THEN 'U' ELSE 'B' END AS billed
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN ReceiptPrice
	ON ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.company_id = Receipt.company_id
JOIN WorkorderHeader
	ON WorkorderHeader.workorder_id = Receipt.source_id
	AND WorkorderHeader.profit_ctr_id = Receipt.profit_ctr_id
	AND WorkorderHeader.company_id = Receipt.company_id
JOIN WorkorderTypeHeader
	ON WorkorderTypeHeader.workorder_type_id = WorkorderHeader.workorder_type_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Customer
	ON Customer.customer_id = Receipt.customer_id
WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.source_type = 'W'
	AND Receipt.receipt_date between @date_from and @date_to
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status in ('N', 'L', 'U', 'A')
GROUP BY 
	Receipt.receipt_id
,	Receipt.receipt_status
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	WorkorderHeader.workorder_type_id
,	WorkorderTypeHeader.account_desc
,	Receipt.source_id
,	Customer.cust_name
,	Company.company_name
,	ProfitCenter.profit_ctr_name
ORDER BY Receipt.receipt_status, Receipt.customer_id, Receipt.receipt_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipts_w_workorders] TO [EQAI]
    AS [dbo];

