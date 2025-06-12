CREATE PROCEDURE sp_rpt_receipt_list_outbound
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@receipt_id_from	int
,	@receipt_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@tsdf_approval_from	varchar(40)
,	@tsdf_approval_to	varchar(40)
AS
/***************************************************************************************
PB Object: r_receipt_list_outbound
11/01/2010 SK Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
07/16/2014 SM	Added container_count column
12/19/2022 Dipankar Added column secondary_waste_codes for #48934

sp_rpt_receipt_list_outbound 32, 0, '7/9/2014','7/21/2014', 1, 999999, 3845, 99999999, '0', 'ZZZZZZZZ', '0', 'ZZZ'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.generator_id
,	Generator.generator_name
,	Receipt.customer_id
,	Customer.cust_name
,	Receipt.tsdf_approval_code
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
,	Receipt.TSDF_code
,	Generator.epa_id
,	Profile.profile_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	Receipt.container_count
,	dbo.fn_receipt_secondary_waste_code_list (@company_id, @profit_ctr_id, Receipt.receipt_id, Receipt.line_id) as secondary_waste_codes
FROM Receipt
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.ob_profile_company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.ob_profile_profit_ctr_id
	AND ProfileQuoteApproval.approval_code = Receipt.tsdf_approval_code
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
	AND Receipt.receipt_id BETWEEN @receipt_id_from AND @receipt_id_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.manifest BETWEEN @manifest_from AND @manifest_to
	AND Receipt.TSDF_approval_code BETWEEN @tsdf_approval_from AND @tsdf_approval_to
	AND Receipt.trans_mode = 'O'

UNION ALL

SELECT
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.generator_id
,	Generator.generator_name
,	Receipt.customer_id
,	Customer.cust_name
,	Receipt.tsdf_approval_code
,	wastecode.display_name as waste_code
,	ReceiptPrice.price
,	Receipt.receipt_date
,	Receipt.receipt_status
,	Receipt.fingerpr_status
,	Receipt.company_id
,	TSDFApproval.comments
,	TSDFApproval.hand_instruct
,	TSDFApproval.tsdf_approval_code
,	Receipt.manifest
,	Receipt.profit_ctr_id
,	Receipt.TSDF_code
,	Generator.epa_id
,	TSDFApproval.tsdf_approval_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	Receipt.container_count
,	dbo.fn_receipt_secondary_waste_code_list (@company_id, @profit_ctr_id, Receipt.receipt_id, Receipt.line_id) as secondary_waste_codes
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN TSDFApproval
	ON TSDFApproval.tsdf_approval_code = Receipt.tsdf_approval_code
	AND TSDFApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND TSDFApproval.company_id = Receipt.company_id
JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN	wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.receipt_id BETWEEN @receipt_id_from AND @receipt_id_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.manifest BETWEEN @manifest_from AND @manifest_to
	AND Receipt.tsdf_approval_code BETWEEN @tsdf_approval_from AND @tsdf_approval_to
	AND Receipt.trans_mode = 'O'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_list_outbound] TO [EQAI]
    AS [dbo];

