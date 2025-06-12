
CREATE PROCEDURE sp_rpt_benzene_neshap_approval_list
	@company_id			int
,   @profit_ctr_id      int
,	@date_from			datetime
,	@date_to			datetime
,	@generator_from		varchar(40)
,	@generator_to		varchar(40)
,	@epa_id_from		varchar(12)
,	@epa_id_to			varchar(12)
AS
/***********************************************************************
This procedure runs for Benzene NESHAP Approval List

PB Object(s):	r_benzene_neshap_approval_list

11/18/2010 SK	Created on Plt_AI
02/28/2014 AM   Added profit_ctr_id to where clause
01/25/2023 Prakash   The Join Condition for Generator ID modified to use Receipt's Generator ID for DevOps #49273

sp_rpt_benzene_neshap_approval_list 21, '2008-01-01', '2008-03-31', 0, 'ZZZZZZZZ', '0', 'ZZZZZZZZZZZZ'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	ProfileQuoteApproval.approval_code
,	Profile.generator_id
,	Generator.generator_name
,	Profile.approval_desc
,	Receipt.company_id
,   receipt.profit_ctr_id
,	Generator.EPA_ID
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN ReceiptWasteCode
	ON ReceiptWasteCode.company_id = Receipt.company_id
	AND ReceiptWasteCode.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptWasteCode.receipt_id = Receipt.receipt_id
	AND ReceiptWasteCode.line_id = Receipt.line_id
	AND ReceiptWasteCode.waste_code IN ('D018', 'U019', 'F037', 'F038', 'K141', 'K142', 
         								'K143', 'K144', 'K145', 'K147', 'K159', 'K169', 'K171', 'K172')
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
--	AND Profile.curr_status_code = 'A'
JOIN Generator
--	ON Generator.generator_id = Profile.generator_id
    ON Generator.generator_id = Receipt.generator_id
	AND Generator.generator_name BETWEEN @generator_from AND @generator_to
	AND Generator.epa_id BETWEEN @epa_id_from AND @epa_id_to
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
WHERE (@company_id = 0 OR Receipt.company_id = @company_id)	
    AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_benzene_neshap_approval_list] TO [EQAI]
    AS [dbo];

