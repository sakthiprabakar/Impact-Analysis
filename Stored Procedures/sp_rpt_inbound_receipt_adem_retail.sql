CREATE PROCEDURE sp_rpt_inbound_receipt_adem_retail
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_inbound_receipt_adem_retail

10/22/2014	SM	Created for EQ alabama. This report will list all receipts and stock containers
				range went on to a trip
sp_rpt_inbound_receipt_adem_retail 32, 0, '10/01/2014','10/31/2014', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT    
	receipt.company_id  
,	receipt.profit_ctr_id 
,	ProfitCenter.profit_ctr_name
,	WorkorderHeader.trip_id
,	WorkorderHeader.company_id AS trip_company_id
,	WorkorderHeader.profit_Ctr_id AS trip_profit_ctr_id
,	receipt.receipt_date
,	min ( receipt.receipt_id ) as receipt_start
,	max ( receipt.receipt_id ) as receipt_end
,	min ( Containerdestination.base_container_id )  as stock_start
,	max ( Containerdestination.base_container_id  ) as stock_end
FROM Receipt
JOIN ProfitCenter 	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN BillingLinkLookup ON	BillingLinkLookup.company_id = receipt.company_id 
	AND receipt.receipt_id = BillingLinkLookup.receipt_id
	AND receipt.profit_ctr_id = BillingLinkLookup.profit_ctr_id
	AND BillingLinkLookup.trans_source = 'I'  
    AND BillingLinkLookup.source_type = 'W' 
JOIN  WorkorderHeader ON WorkorderHeader.workorder_ID = BillingLinkLookup.source_id  
	AND WorkorderHeader.company_id = BillingLinkLookup.source_company_id 
    AND WorkorderHeader.profit_ctr_ID = BillingLinkLookup.source_profit_ctr_id 
	AND WorkorderHeader.trip_id > 0
JOIN Containerdestination ON   Containerdestination.company_id = Receipt.company_id
	AND Containerdestination.profit_ctr_id = Receipt.profit_ctr_id
	AND Containerdestination.receipt_id  = Receipt.receipt_id
	AND Containerdestination.line_id = Receipt.line_id
WHERE  ( @company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
    AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status = 'A'
	AND Receipt.fingerpr_status not in ( 'V','R')
	AND Receipt.trans_type = 'D'
GROUP By   	receipt.company_id  
,	receipt.profit_ctr_id 
,	ProfitCenter.profit_ctr_name
,	WorkorderHeader.trip_id
,	WorkorderHeader.company_id
,	WorkorderHeader.profit_ctr_id
,	receipt.receipt_date    
Order by WorkorderHeader.trip_id
         



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inbound_receipt_adem_retail] TO [EQAI]
    AS [dbo];

