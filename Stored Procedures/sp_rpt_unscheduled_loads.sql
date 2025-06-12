CREATE PROCEDURE sp_rpt_unscheduled_loads 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS
/*****************************************************************************************
PB Object(s):	r_unscheduled_loads

12/09/2010 SK Created new on Plt_AI

sp_rpt_unscheduled_loads 21, -1, '01-01-2009','01-31-2009', 1, 999999
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_id,
	Receipt.receipt_date,
	Receipt.date_scheduled,
	CASE WHEN Receipt.trans_type = 'D' THEN 'Disposal' ELSE 'Transfer' END as schedule_type,
	CASE Receipt.bulk_flag WHEN 'B' THEN 'Bulk' WHEN 'N' THEN 'Non-Bulk' ELSE 'Undefined' END as load_type,
	Receipt.quantity, 
	Receipt.bill_unit_code,
	Receipt.customer_id, 
	Receipt.approval_code,
	Customer.cust_name,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Customer 
	ON Customer.customer_ID = Receipt.customer_id
WHERE Receipt.trans_type IN ('D','X')
	AND Receipt.receipt_status IN ('N','L','U','A')
	AND Receipt.schedule_confirmation_id IS NULL
	AND ( @company_id = 0 OR Receipt.company_id = @company_id)
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
	AND (Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to)
	AND (Receipt.receipt_date BETWEEN @date_from AND @date_to)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_unscheduled_loads] TO [EQAI]
    AS [dbo];

