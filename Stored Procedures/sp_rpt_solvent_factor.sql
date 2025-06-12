CREATE PROCEDURE sp_rpt_solvent_factor 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/*****************************************************************************************
This sp runs for the Inbound Receiving report 'Solvent Factor'

PB Object(s):	r_solvent_factor

12/17/2010 SK Created new on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_solvent_factor 2, -1, '01-01-2006','01-31-2006', 1, 999999
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	receipt.approval_code
,	wastecode.display_name as waste_code
,	generator.generator_name
,	receipt.quantity
,	ProfileLab.solvent_factor
,	receipt.receipt_date
,	receipt.company_id
,	Receipt.profit_ctr_id
,	billunit.gal_conv
,	Receipt.bill_unit_code 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = Receipt.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN BillUnit 
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
INNER JOIN Profile 
	ON Receipt.profile_id = Profile.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN ProfileLab 
	ON Profile.profile_id = ProfileLab.profile_id
	AND ProfileLab.type = 'A'
LEFT OUTER JOIN Generator
	ON Receipt.generator_id = generator.generator_id
WHERE Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND ( @company_id = 0 OR Receipt.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.receipt_status <> 'V' 
	AND (receipt.waste_code in ( 'D001', 'F001', 'F002','F003','F005')) 
	AND receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND receipt.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_solvent_factor] TO [EQAI]
    AS [dbo];

