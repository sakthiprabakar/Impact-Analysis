
CREATE PROCEDURE sp_rpt_receipts_on_hold 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_receipts_on_hold.sql
PB Object(s):	r_receipts_on_hold
	
10/18/2010 SK	Created on Plt_AI

sp_rpt_receipts_on_hold 21, 0, '7/01/10', '7/31/10'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT 
	receipt.receipt_id
,	receipt.line_id
,	receipt.company_id
,	receipt.profit_ctr_id
,	receipt.receipt_date
,	receipt.approval_code
,	receipt.generator_id
,	receipt.manifest
,	receipt.hauler
,	receipt.lab_comments
,	receipt.truck_code
,	IsNull(Transporter_name, '') AS transporter_name
,	receipt.bill_unit_code
,	receipt.quantity
,	Generator.epa_id
,	Generator.generator_name
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Transporter
	ON Transporter.transporter_code = Receipt.hauler
WHERE (@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'L'
	AND Receipt.fingerpr_status = 'H'
	AND Receipt.receipt_date between @date_from AND @date_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipts_on_hold] TO [EQAI]
    AS [dbo];

