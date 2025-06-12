CREATE PROCEDURE sp_rpt_shipments_by_cust
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/***************************************************************************************
11/11/2010 SK	created on Plt_AI

PB Object : r_shipments_by_cust

sp_rpt_shipments_by_cust 14, 4, '2010-06-01', '2010-06-30', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.customer_id
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.date_added
,	Customer.cust_name 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN Customer
	ON Customer.customer_ID = Receipt.customer_id
WHERE	( @company_id = 0 OR Receipt.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND receipt.receipt_status = 'A'
	AND receipt.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_shipments_by_cust] TO [EQAI]
    AS [dbo];

