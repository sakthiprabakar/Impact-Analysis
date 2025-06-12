CREATE PROCEDURE sp_rpt_shipments_by_gen_appr
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@epa_id			varchar(12)
AS
/***************************************************************************************
11/10/2010 SK	created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


PB Object : r_shipments_by_gen_appr

sp_rpt_shipments_by_gen_appr 14, 4, '2010-06-01', '2010-06-30', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.generator_id
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.date_added
,	generator.generator_name
,	Receipt.approval_code
,	wastecode.display_name as waste_code
,	Profile.approval_desc
,	Generator.EPA_ID
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
	AND (@epa_id = 'ALL' OR Generator.EPA_ID LIKE @epa_id)
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval 
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
   AND ProfileQuoteApproval.company_id = Receipt.company_id
   AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
WHERE	( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_mode = 'I' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_shipments_by_gen_appr] TO [EQAI]
    AS [dbo];

