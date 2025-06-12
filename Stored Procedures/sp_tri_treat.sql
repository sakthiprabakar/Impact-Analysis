CREATE PROCEDURE sp_tri_treat 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@generator_from		varchar(40)
,	@generator_to		varchar(40)
,	@epa_id_from		varchar(12)
,	@epa_id_to			varchar(12)
AS
/****************
This SP runs for the Report-  TRI Treatment/Bill Unit Gallon Report

PB Object(s):	r_tri_appr_treat

12/07/2010 SK Created on Plt_AI

exec sp_tri_treat 21, 0, '2008-01-01', '2008-01-31', 0, 'CONST', '0', 'ZZZZZZZZZZZZ'
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Generator.generator_name
,	Receipt.approval_code
,	w.display_name as waste_code
,	sum(Receipt.quantity) quantity
,	Receipt.bill_unit_code
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv
,	Receipt.treatment_id
,	Treatment.Treatment_desc 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN Profile 
	ON Receipt.profile_id = Profile.profile_id
	AND Profile.curr_status_code = 'A' 
INNER JOIN BillUnit 
	ON Receipt.bill_unit_code = BillUnit.bill_unit_code
LEFT OUTER JOIN Generator
	ON Receipt.Generator_id = generator.generator_id
INNER JOIN Treatment
	ON Receipt.treatment_id = Treatment.treatment_id 
	AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
	AND Receipt.company_id = Treatment.company_id
LEFT OUTER  JOIN WasteCode w
	ON Receipt.waste_code_uid = w.waste_code_uid
WHERE Receipt.fingerpr_status = 'A'
	AND Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Generator.generator_name BETWEEN @generator_from AND @generator_to
	AND Generator.epa_id BETWEEN @epa_id_from AND @epa_id_to
	AND Receipt.receipt_status = 'A' 
	AND Receipt.trans_mode = 'I' 
GROUP BY 
	Generator.generator_name
,	Receipt.approval_code
,	w.display_name
,	Receipt.bill_unit_code
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv
,	receipt.treatment_id
,	treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_tri_treat] TO [EQAI]
    AS [dbo];

