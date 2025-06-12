CREATE PROCEDURE sp_rpt_pcb_receipt_list 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/*****************************************************************************************
This sp runs for the Inbound Receiving report 'PCB Receipt List'

PB Object(s):	r_pcb_receipt_list

12/17/2010 SK Created new on Plt_AI

sp_rpt_pcb_receipt_list 0, -1, '01-01-2008','01-31-2008', 1, 999999
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.receipt_date
,	Receipt.approval_code
,	wastecode.display_name AS waste_code
,	Receipt.bill_unit_code
,	Receipt.generator_id
,	Receipt.manifest
,	Receipt.quantity
,	Generator.generator_name
,	Generator.epa_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.pcb_flag = 'T'
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE  Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND ( @company_id = 0 OR Receipt.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_mode = 'I' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_pcb_receipt_list] TO [EQAI]
    AS [dbo];

