CREATE PROCEDURE sp_rpt_receipt_list_inbound
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_receipt_list_inbound
11/01/2010 SK Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
07/16/2014 SM	Added container_count column
01/20/2023 Dipankar Added column secondary_waste_codes for #60789

sp_rpt_receipt_list_inbound 21, 0, '1/4/2017','4/4/2017', 1, 999999
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
,	ReceiptPrice.price
,	Receipt.receipt_date
,	Receipt.receipt_status
,	Receipt.fingerpr_status
,	Receipt.company_id
,	Profile.approval_comments
,	Profile.hand_instruct
,	ProfileQuoteApproval.approval_code
,	Receipt.manifest
,	Receipt.profit_ctr_id
,	Generator.epa_id
,	Profile.profile_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	Receipt.container_count
,   Receipt.created_by
,	dbo.fn_profile_secondary_waste_code_list (Profile.profile_id) as secondary_waste_codes 
FROM Receipt
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
LEFT OUTER JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_list_inbound] TO [EQAI]
    AS [dbo];

