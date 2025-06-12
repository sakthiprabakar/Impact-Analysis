/***************************************************************************
08/19/2004 SCC	Created
06/24/2014 AM - Moved to plt_ai and added company_id

sp_rpt_new_business '01-1-2014', '02-02-2014', 0, 21

***************************************************************************/
CREATE PROCEDURE sp_rpt_new_business
	@date_from datetime,
	@date_to datetime,
	@profit_ctr_id	int,
	@company_id int
AS

SELECT DISTINCT customer_id,
	profit_ctr_id,
	company_id,
	min(receipt_date) as receipt_date,
	earliest_ship_date = IsNull((SELECT min(R2.receipt_date) FROM Receipt R2 WHERE R2.customer_id = Receipt.customer_id
		AND R2.trans_mode = 'I' and R2.trans_type = 'D' AND R2.receipt_status NOT IN ('T', 'V', 'R') 
		AND R2.profit_ctr_id = Receipt.profit_ctr_id AND R2.company_id = Receipt.company_id ), '12-31-2999')
INTO #tmp_receipt
FROM Receipt
WHERE Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status NOT IN ('T', 'V', 'R') 
	AND Receipt.profit_ctr_id = @profit_ctr_id 
	AND Receipt.company_id = @company_id
	AND Receipt.receipt_date between @date_from and @date_to
GROUP BY profit_ctr_id, customer_id, company_id 


SELECT	DISTINCT Receipt.customer_id,
	Customer.cust_name,
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_date,
	Receipt.receipt_status,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	Receipt.quantity,
	ProfitCenter.profit_ctr_name,
    Receipt.company_id
   FROM Receipt, Customer, #tmp_receipt, ProfitCenter
   WHERE Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status NOT IN ('T', 'V', 'R') 
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id 
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfitCenter.company_id = Receipt.company_id
	AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
	AND Receipt.company_id = ProfitCenter.company_id 
	AND Receipt.receipt_date between @date_from and @date_to
	AND Receipt.customer_id = Customer.customer_id
	AND Receipt.customer_id = #tmp_receipt.customer_id
	AND #tmp_receipt.receipt_date <= #tmp_receipt.earliest_ship_date
ORDER BY customer.cust_name, Receipt.receipt_date, Receipt.line_id, Receipt.bulk_flag


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_new_business] TO [EQAI]
    AS [dbo];

