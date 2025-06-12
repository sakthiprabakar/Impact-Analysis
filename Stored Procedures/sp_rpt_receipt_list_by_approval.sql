CREATE PROCEDURE sp_rpt_receipt_list_by_approval
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@approval_code		varchar(15)
AS
/***************************************************************************************
PB Objects: r_container_receipt_list_by_approval
10/29/2010 SK	created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_receipt_list_by_approval 14, 4, '2-01-04', '2-20-04', 1, 999999, 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.approval_code
,	Receipt.product_code
,	Receipt.bill_unit_code
,	Receipt.customer_id
,	Receipt.fingerpr_status
,	Receipt.generator_id
,	Receipt.manifest
,	Receipt.manifest_flag
,	Receipt.quantity
,	Receipt.receipt_date
,	Receipt.receipt_status
,	wastecode.Display_name as waste_code
,	ReceiptWasteCode.waste_code
,	Profile.OTS_flag
,	Receipt.trans_mode
,	Receipt.TSDF_approval_code
,	Receipt.waste_stream
,	Generator.epa_id
,	Generator.generator_name
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt 
JOIN Company
	ON Company.company_id = Receipt.company_id
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
LEFT OUTER JOIN ProfileQuoteApproval
	ON receipt.approval_code = ProfileQuoteApproval.approval_code
	AND receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND receipt.company_id = ProfileQuoteApproval.company_id
INNER JOIN Profile
	ON ProfileQuoteApproval.profile_id = Profile.profile_id
	AND Profile.curr_status_code = 'A'
LEFT OUTER JOIN ReceiptWasteCode
	ON receipt.receipt_id = ReceiptWasteCode.receipt_id
	AND receipt.line_id = ReceiptWasteCode.line_id
	AND receipt.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
	AND Receipt.company_id = ReceiptWasteCode.company_id
	AND ReceiptWasteCode.primary_flag = 'T'
INNER JOIN Generator
	ON receipt.generator_id = Generator.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND receipt.receipt_status <> 'I' 
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND (@approval_code = 'ALL' OR receipt.approval_code = @approval_code)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_list_by_approval] TO [EQAI]
    AS [dbo];

