CREATE PROCEDURE sp_rpt_transit_receipts
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_transit_receipts

11/12/2010 SK Created on Plt_AI

sp_rpt_transit_receipts 21, -1, '2010-11-01','2010-11-30', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.receipt_date
,	Receipt.approval_code
,	Receipt.manifest
,	Receipt.hauler
,	IsNull(Transporter_name, '') AS transporter_name
,	ReceiptPrice.bill_unit_code
,	ReceiptPrice.bill_quantity
,	Generator.epa_id
,	Generator.generator_name
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt 
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
LEFT OUTER JOIN Transporter
	ON Transporter.Transporter_code = Receipt.hauler
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'T'
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transit_receipts] TO [EQAI]
    AS [dbo];

