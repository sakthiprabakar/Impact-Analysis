CREATE PROCEDURE sp_rpt_approval_const_missing 
	@company_id		int
,	@profit_ctr_id	int
,	@approval_from	varchar(15)
,	@approval_to	varchar(15)
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************************
PB Object : r_approval_const_missing

Modifications:
11/12/2010 SK	Added company_id as input arg, added joins to company
				created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name

sp_rpt_approval_const_missing 14, -1, '0', 'ZZ', 1, 999999
***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT DISTINCT 
	Profile.profile_id
,	ProfileQuoteApproval.approval_code
,	Profile.approval_desc
,	ProfileQuoteApproval.company_id
,	ProfileQuoteApproval.profit_ctr_id
,	wastecode.display_name AS waste_code
,	Generator.generator_name
,	Profile.bill_unit_code
,	ProfileQuoteApproval.treatment_id
,	Profile.customer_id
,	Customer.cust_name
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM ProfileQuoteApproval
JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id 
	AND Profile.curr_status_code = 'A'
	AND Profile.ap_expiration_date > GetDate()
	AND Profile.customer_id BETWEEN @customer_id_from AND @customer_id_to
JOIN Company
	ON Company.company_id = ProfileQuoteApproval.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = ProfileQuoteApproval.company_id
	AND ProfitCenter.profit_ctr_ID = ProfileQuoteApproval.profit_ctr_id
JOIN Generator
	ON Generator.generator_id = Profile.generator_id
JOIN Customer
	ON Customer.customer_ID = Profile.customer_id
LEFT OUTER JOIN dbo.WasteCode
	ON wastecode.waste_code_uid = profile.waste_code_uid
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ProfileQuoteApproval.company_id
	AND Treatment.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND Treatment.treatment_id = ProfileQuoteApproval.treatment_id
WHERE	(@company_id = 0 OR ProfileQuoteApproval.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR ProfileQuoteApproval.profit_ctr_id = @profit_ctr_id)
	AND ProfileQuoteApproval.approval_code BETWEEN @approval_from AND @approval_to
GROUP BY 
	Profile.profile_id
,	ProfileQuoteApproval.approval_code
,	Profile.approval_desc
,	ProfileQuoteApproval.company_id
,	ProfileQuoteApproval.profit_ctr_id
,	wastecode.display_name
,	generator.generator_name
,	Profile.bill_unit_code
,	ProfileQuoteApproval.treatment_id
,	Profile.customer_id
,	Customer.cust_name
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
HAVING (SELECT COUNT(*) FROM ProfileConstituent 
		WHERE Profile.profile_id = ProfileConstituent.profile_id
		AND (IsNull(ProfileConstituent.unit,'') = '' OR IsNull(ProfileConstituent.concentration, -1) < 0)) > 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_approval_const_missing] TO [EQAI]
    AS [dbo];

