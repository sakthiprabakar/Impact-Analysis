CREATE PROCEDURE sp_rpt_treatment_avg_price
	@company_id			int
,	@profit_ctr_id		int
,	@invoice_date_from	datetime
,	@invoice_date_to	datetime
,	@service_date_from	datetime
,	@service_date_to	datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@customer_type		varchar(10)
AS

/***************************************************************************************
PB Objects: r_treatment_avg_price
11/02/2010 SK	created on Plt_AI

sp_rpt_treatment_avg_price 12, -1, '06-01-2010', '06-30-2010', NULL, NULL, 1, 999999, 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT 
	Receipt.bill_unit_code
,	Receipt.treatment_id
,	treatment.treatment_desc
,	Round(Avg(Billing.price), 2) AS Average_Price
,	Sum(Billing.quantity) AS Total_Quantity
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Billing
	ON Billing.receipt_id = Receipt.receipt_id
	AND Billing.line_id = Receipt.line_id
	AND Billing.company_id = Receipt.company_id
	AND Billing.profit_ctr_id = Receipt.profit_ctr_id
	AND Billing.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to
	AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Billing.status_code = 'I'
JOIN Customer
	ON Customer.customer_ID = Billing.customer_id
	AND (@customer_type = 'ALL' OR Customer.customer_type LIKE @customer_type)
JOIN Treatment
	ON Treatment.company_id = Receipt.company_id
	AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	AND Treatment.treatment_id = Receipt.treatment_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
GROUP BY
	Receipt.bill_unit_code
,	Receipt.treatment_id
,	treatment.treatment_desc
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name

UNION

SELECT 
	Receipt.bill_unit_code
,	Receipt.treatment_id
,	treatment.treatment_desc
,	Round(Avg(Billing.price), 2) AS Average_Price
,	Sum(Billing.quantity) AS Total_Quantity
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Billing
	ON Billing.receipt_id = Receipt.receipt_id
	AND Billing.line_id = Receipt.line_id
	AND Billing.company_id = Receipt.company_id
	AND Billing.profit_ctr_id = Receipt.profit_ctr_id
	AND Billing.billing_date BETWEEN @service_date_from AND @service_date_to
	AND Billing.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Billing.status_code = 'I'
JOIN Customer
	ON Customer.customer_ID = Billing.customer_id
	AND (@customer_type = 'ALL'OR Customer.customer_type LIKE @customer_type)
JOIN Treatment
	ON Treatment.company_id = Receipt.company_id
	AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	AND Treatment.treatment_id = Receipt.treatment_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
GROUP BY
	Receipt.bill_unit_code
,	Receipt.treatment_id
,	treatment.treatment_desc
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_treatment_avg_price] TO [EQAI]
    AS [dbo];

