
CREATE PROCEDURE sp_rpt_rejected_load
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_rejected_load.sql
PB Object(s):	r_rejectlog
	
10/19/2010 SK	Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_rejected_load 2, -1, '2008-08-01', '2008-08-31', 1, 999999
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT 
	Receipt.receipt_id
,	Generator.generator_name
,	Receipt.approval_code
,	wastecode.display_name as waste_code
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.gross_weight
,	Receipt.hauler
,	Receipt.manifest
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv 
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
INNER JOIN BillUnit 
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
LEFT OUTER JOIN Generator 
	ON Generator.generator_id = Receipt.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND receipt.trans_type = 'D'
	AND receipt.trans_mode = 'I'
	AND receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND ((( Receipt.fingerpr_status = 'R') AND receipt.receipt_status IN ('A','R')) OR ( receipt.receipt_status = 'R')) 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_rejected_load] TO [EQAI]
    AS [dbo];

