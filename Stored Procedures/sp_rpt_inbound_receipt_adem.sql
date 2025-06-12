CREATE PROCEDURE sp_rpt_inbound_receipt_adem
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_inbound_receipt_adem

10/22/2014	SM	Created. This report is for EQ Alabama. Report list all the waste codes
				on a inbound receipt which is not in a trip

sp_rpt_inbound_receipt_adem 32, 0, '07/01/2014','07/31/2014', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT
	Receipt.company_id
,	Receipt.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt.receipt_date
,	Receipt.manifest
,	Receipt.receipt_id
,	Receipt.line_id
,	ReceiptPrice.bill_quantity
,	ReceiptPrice.bill_unit_code
,	Profile.profile_id
,	Receipt.approval_code
,	Profile.approval_desc
,	waste_code_list = dbo.fn_receipt_waste_code_list ( Receipt.company_id,Receipt.profit_ctr_id,Receipt.receipt_id,Receipt.line_id)
,	Receipt.customer_id
,	Customer.cust_name
,	Receipt.generator_id
,	Generator.epa_id
,	Generator.generator_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
JOIN ReceiptPrice
	ON ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status = 'A'
	AND Receipt.fingerpr_status not in ( 'V','R')
	AND Receipt.trans_type = 'D'
	AND  0 = (  SELECT count(BillingLinkLookup.receipt_id)
				FROM BillingLinkLookup,   
				TripHeader,   
				WorkorderHeader  
   WHERE ( TripHeader.trip_id = WorkorderHeader.trip_id ) and  
         ( WorkorderHeader.workorder_ID = BillingLinkLookup.source_id ) and  
         ( WorkorderHeader.company_id = BillingLinkLookup.source_company_id ) and  
         ( WorkorderHeader.profit_ctr_ID = BillingLinkLookup.source_profit_ctr_id ) and  
         (  BillingLinkLookup.trans_source = 'I' ) AND  
         ( BillingLinkLookup.source_type = 'W' ) AND  
         ( BillingLinkLookup.receipt_id = Receipt.receipt_id ) 
         and billinglinklookup.company_id = receipt.company_id 
			and billinglinklookup.profit_ctr_id = receipt.profit_ctr_id   ) 
order by receipt.receipt_date,receipt.receipt_id, receipt.line_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inbound_receipt_adem] TO [EQAI]
    AS [dbo];

