CREATE PROCEDURE sp_rpt_services 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/*****************************************************************************************
This sp runs for the Inbound Receiving report 'Services Rendered'

PB Object(s):	r_services

12/16/2010 SK Created new on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_services 2, -1, '01-01-2006','01-31-2006', 1, 999999
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.line_id
,	Generator.generator_name
,	Receipt.approval_code
,	Receipt.service_desc
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.gross_weight
,	Receipt.hauler
,	Receipt.manifest
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv
,	Receipt.receipt_id
,	wastecode.display_name as waste_code
,	SUM(IsNull(ReceiptPrice.price,0)) AS receipt_price
,	SUM(IsNull(ReceiptPrice.total_extended_amt,0)) as total_extended_amt
,	Transporter.transporter_name 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN BillUnit 
	ON Receipt.bill_unit_code = BillUnit.bill_unit_code
LEFT OUTER JOIN Generator 
	ON Receipt.generator_id = Generator.generator_id
LEFT OUTER JOIN Transporter 
	ON Receipt.hauler = Transporter.transporter_code
INNER JOIN ReceiptPrice 
	ON Receipt.receipt_id = ReceiptPrice.receipt_id
	AND Receipt.line_id = ReceiptPrice.line_id
	AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
	AND Receipt.company_id = ReceiptPrice.company_id
WHERE Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND ( @company_id = 0 OR Receipt.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.fingerpr_status = 'A'
	AND Receipt.trans_type = 'S' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.receipt_status = 'A' 
GROUP BY 
	Receipt.line_id
,	Generator.generator_name
,	Receipt.approval_code
,	Receipt.service_desc
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.gross_weight
,	Receipt.hauler
,	Receipt.manifest
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv
,	Receipt.receipt_id
,	wastecode.display_name
,	Transporter.transporter_name 
,	Company.company_name
,	ProfitCenter.profit_ctr_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_services] TO [EQAI]
    AS [dbo];

