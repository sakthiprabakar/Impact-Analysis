
CREATE PROCEDURE sp_rpt_manifest_audit_log
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************
This procedure runs for Manifest Audit Log
PB Object(s):	r_manifest_audit_log

10/26/2010 SK	Created on Plt_AI
08/21/2013 SM	joined wastecode table using uid and display name
sp_rpt_manifest_audit_log 12, 0, '7/16/04', '7/16/04', 1, 999999
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.receipt_id
,	Receipt.line_id
,	Generator.generator_name
,	Receipt.approval_code
,	Receipt.service_desc
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.gross_weight
,	Receipt.hauler
,	Receipt.manifest
,	Receipt.receipt_date
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	BillUnit.gal_conv
,	wastecode.display_name AS waste_code
,	WasteCode.haz_flag 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status = 'A'
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_audit_log] TO [EQAI]
    AS [dbo];

