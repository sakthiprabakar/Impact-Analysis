CREATE PROCEDURE sp_rpt_shipments_by_cust_appr
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/***************************************************************************************
11/11/2010 SK	created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


PB Object : r_shipments_by_cust_appr

sp_rpt_shipments_by_cust_appr 14, 4, '2010-06-01', '2010-06-30', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.date_added
,	Customer.cust_name
,	Receipt.approval_code
,	wastecode.display_name as waste_code
,	Profile.approval_desc
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
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval 
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
   AND ProfileQuoteApproval.company_id = Receipt.company_id
   AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_shipments_by_cust_appr] TO [EQAI]
    AS [dbo];

