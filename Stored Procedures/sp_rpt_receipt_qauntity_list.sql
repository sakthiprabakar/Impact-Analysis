CREATE PROCEDURE sp_rpt_receipt_qauntity_list
	@company_id			int
,	@profit_ctr_id		int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
,	@cust_id_from		int
,	@cust_id_to		int
AS

/***************************************************************************************
PB Object(s):	r_receipt_list_quantity

11/08/2010 SK	Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
10/23/2015 AM   Modified sql to get multiple bill unit codes when receipt line has multiple units and select non void receipts.

sp_rpt_receipt_qauntity_list 2, -1, '11-01-2007', '11-01-2007', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.generator_id
,	Generator.generator_name
,	Receipt.customer_id
,	Customer.cust_name
,	Receipt.approval_code
,	wastecode.display_name as waste_code
,	Receipt.receipt_date
,	Receipt.receipt_status
,	Receipt.fingerpr_status
,	Receipt.company_id
,	Profile.approval_comments
,	Profile.hand_instruct
,	ProfileQuoteApproval.approval_code
,	Receipt.manifest
,	Receipt.profit_ctr_id
,	Receipt.trans_mode
,	Receipt.manifest_quantity
,	Receipt.manifest_unit
,	receipt.Quantity
,	receiptprice.bill_unit_code
,	CASE WHEN BillUnit.MDEQ_uom = 'CONV_G' THEN (BillUnit.gal_conv * Receipt.quantity) ELSE Receipt.quantity END as converted_quantity
,	CASE WHEN BillUnit.MDEQ_uom = 'CONV_G' THEN 'G' ELSE IsNull(LTrim(RTrim(BillUnit.MDEQ_uom)), '') END AS converted_unit
,	Generator.epa_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Customer
	ON Customer.customer_id = Receipt.customer_id
LEFT OUTER JOIN ProfileQuoteApproval 
	ON ProfileQuoteApproval.approval_code = Receipt.approval_code
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.company_id = Receipt.company_id
INNER JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Profile.curr_status_code = 'A'
LEFT OUTER JOIN receiptprice
    ON receiptprice.profit_ctr_id = Receipt.profit_ctr_id
	AND receiptprice.company_id = Receipt.company_id
	AND receiptprice.receipt_id = Receipt.receipt_id
	AND receiptprice.line_id = receipt.line_id 
LEFT OUTER JOIN BillUnit
	ON Billunit.bill_unit_code = receiptprice.bill_unit_code
WHERE	( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
        AND Receipt.receipt_status <> 'V'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_qauntity_list] TO [EQAI]
    AS [dbo];

