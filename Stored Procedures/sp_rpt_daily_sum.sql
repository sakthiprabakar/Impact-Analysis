
CREATE PROCEDURE sp_rpt_daily_sum
	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/**************************************************************************************
This procedure runs for Disposal Summary to Bill Michigan - Sub Title C(by Waste Type)
Report is specific for company_id = 2 i.e Michigan Disposal Inc.

PB Object(s):	r_daily_sum

10/22/2010 SK	Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_daily_sum '7/1/2010', '7/31/2010', 1, 999999

***************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	wastecode.display_name as waste_code
,	gallons = (ReceiptPrice.bill_quantity * BillUnit.gal_conv)
,	Receipt.company_id
,	Customer.customer_type
,	Receipt.customer_id 
FROM Receipt
INNER JOIN ReceiptPrice 
	ON ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
INNER JOIN ProfileQuoteApproval 
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id 
	AND ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.disposal_service_id = 10	
INNER JOIN Profile 
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN BillUnit 
	ON BillUnit.bill_unit_code = ReceiptPrice.bill_unit_code
INNER JOIN WasteCode 
	ON  WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.haz_flag = 'T'
LEFT OUTER JOIN Customer 
	ON Customer.customer_id = Receipt.customer_id
WHERE Receipt.fingerpr_status = 'A'
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A'
	AND Receipt.company_id = 2
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_daily_sum] TO [EQAI]
    AS [dbo];

