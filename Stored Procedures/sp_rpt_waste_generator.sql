CREATE PROCEDURE sp_rpt_waste_generator
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@customer_from 	int
,	@customer_to 	int
,	@epa_id			varchar(12)
AS
/***************************************************************************************
11/04/2010 SK	created on Plt_AI

PB Object : r_waste_generator

sp_rpt_waste_generator 14, 4, '2010-06-03', '2010-06-03', 1, 999999, 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	billing.receipt_id
,	billing.line_id
,	billing.billing_date
,	wastecode.display_name AS waste_code
,	Wastecode.waste_code_desc
,	billing.bill_unit_code
,	billing.generator_id
,	billing.generator_name
,	billing.quantity
,	billing.approval_code
,	Generator.EPA_ID
,	billing.company_id
,	billing.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Billing
JOIN Company
	ON Company.company_id = Billing.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Billing.company_id
	AND ProfitCenter.profit_ctr_id = Billing.profit_ctr_id
JOIN Customer
	ON Customer.customer_ID = Billing.customer_id
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = Billing.waste_code_uid
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Billing.generator_id
	AND (@epa_id = 'ALL' OR Generator.EPA_ID LIKE @epa_id)
WHERE	( @company_id = 0 OR Billing.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Billing.profit_ctr_id = @profit_ctr_id )
	AND billing.billing_date BETWEEN @date_from AND @date_to
	AND billing.customer_id BETWEEN @customer_from AND @customer_to
	AND billing.status_code = 'I'
	AND billing.void_status = 'F'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_generator] TO [EQAI]
    AS [dbo];

