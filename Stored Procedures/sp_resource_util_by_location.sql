CREATE PROCEDURE sp_resource_util_by_location 
	@company_id		int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code char(2)
AS
/*****************************************************************************************
PB Object(s):	r_resource_util_by_location

11/20/2000 SCC	Created
12/13/2005 JDB	Modified to use Billing instead of Ticket table
05/08/2007 JDB	Modified to use CustomerBilling.territory_code
04/07/2010 RJG	added defaultProfitCenter join
12/09/2010 SK	Added Company_ID as input arg, added joins to company
				Moved to Plt_AI
01/19/2011 SK	Data Conversion - Changed to get total amt from BillingDetail
01/21/2011 SK	Included Insurance/Energy amts in total amt
6/11/2024 Prakash - DevOps #86992 - Passed profit_ctr_id argument to fn_get_assigned_resource_class_code and included the resource uid in Resource Join
			
sp_resource_util_by_location 14, '01-01-2010','01-10-2010', 1, 999999, '99'

example of Insurance amt in total for above run:
Select * from Billing where company_id = 14 and profit_ctr_id = 0 and receipt_id = 12259300 and line_id = 1
Select * from BillingDetail where company_id = 14 and profit_ctr_id = 0 and receipt_id = 12259300 and line_id = 1

sp_helptext sp_resource_util_by_location
sp_resource_util_by_location 21, '05-01-2010','05-15-2010', 1, 999999, '99'
sp_resource_util_by_location 14, '05-01-2010','07-31-2010', 1, 999999, '99'


******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

Declare @billing_total table(
	company_id			int
,	profit_ctr_id		int
,	receipt_id			int
,	line_id				int
,	price_id			int
,	total				money
)

-- Get the revenue from BillingDetail for Billing Invoiced Lines
INSERT @billing_total
SELECT
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id
,	SUM(IsNull(bd.extended_amt,0.000)) AS total
FROM Billing b
LEFT JOIN BillingDetail bd
	ON bd.company_id = b.company_id
	AND bd.profit_ctr_id = b.profit_ctr_id
	AND bd.receipt_id = b.receipt_id
	AND bd.line_id = b.line_id
	AND bd.price_id = b.price_id
	AND bd.trans_type = b.trans_type
	AND bd.trans_source = b.trans_source
	--AND bd.billing_type NOT IN ('Insurance', 'Energy')
WHERE  b.status_code = 'I' 
	AND b.invoice_date BETWEEN @date_from AND @date_to
	AND b.company_id = @company_id
GROUP BY
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id

-- Select the Invoiced billing lines
SELECT DISTINCT
	Billing.profit_ctr_id,
	Billing.company_id,
	profitCenter.profit_ctr_name,
	defaultProfitCenter.profit_ctr_name as location,
	CASE WHEN customer.customer_type = 'IC' THEN 'IC Billed' ELSE 'Customer Billed' END AS customer_type,
	wod.resource_assigned,
	Billing.bill_unit_code, 
	SUM(Billing.quantity) AS quantity,
	--SUM(Billing.total_extended_amt) AS revenue,
	ISNULL(SUM(bd.total), 0.000) AS revenue,
	SUM(Billing.cost) AS cost,
	ProfitCenter.cost_factor
INTO #tmp
FROM Billing
LEFT OUTER JOIN @billing_total bd
	ON bd.company_id = Billing.company_id
	AND bd.profit_ctr_id = Billing.profit_ctr_id
	AND bd.receipt_id = Billing.receipt_id
	AND bd.line_id = Billing.line_id
	AND bd.price_id = Billing.price_id
	--AND Billing.workorder_resource_type in ('E', 'L')
JOIN WorkOrderHeader woh
	ON woh.company_id = Billing.company_id
	AND woh.profit_ctr_ID = Billing.profit_ctr_id
	AND woh.workorder_ID = Billing.receipt_id
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
JOIN WorkOrderDetail wod
	ON wod.company_id = Billing.company_id
	AND wod.profit_ctr_ID = Billing.profit_ctr_id
	AND wod.workorder_ID = Billing.receipt_id
	AND wod.resource_type = Billing.workorder_resource_type
	AND wod.sequence_id = Billing.workorder_sequence_id
	--AND wod.resource_class_code = dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, wod.company_id, wod.profit_ctr_ID)
	AND wod.resource_type in ('E', 'L')
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
	AND wod.resource_class_code = dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id)
	--AND r.company_id = wod.company_id
JOIN Customer
	ON Customer.customer_id = woh.customer_id
JOIN CustomerBilling cb
	ON  cb.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND cb.customer_id = woh.customer_id
	AND cb.status = 'A'
	AND ((@territory_code = '99') OR (cb.territory_code = @territory_code))
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Billing.company_id
	AND ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id
JOIN ProfitCenter defaultProfitCenter
	ON defaultProfitCenter.profit_ctr_id = r.default_profit_ctr_id
	AND defaultProfitCenter.company_ID = r.company_id 
WHERE Billing.status_code = 'I'
	AND Billing.invoice_date BETWEEN @date_from AND @date_to
	AND Billing.company_id = @company_id
GROUP BY 
	Billing.profit_ctr_id,
	Billing.company_id,
	ProfitCenter.profit_ctr_name,
	ProfitCenter.cost_factor,
	defaultProfitCenter.profit_ctr_name,
	customer.customer_type,
	wod.resource_assigned,
	Billing.bill_unit_code
	
UNION ALL
-- Select N/C, submitted work orders
SELECT DISTINCT
	woh.profit_ctr_id,
	woh.company_id,
	profitCenter.profit_ctr_name,
	defaultProfitCenter.profit_ctr_name as location,
	CASE WHEN customer.customer_type = 'IC' THEN 'IC Billed' ELSE 'Customer Billed' END AS customer_type,
	wod.resource_assigned,
	wod.bill_unit_code, 
	SUM(quantity_used) AS quantity,
	0 AS revenue,
	SUM(ISNULL(wod.cost, 0) * quantity_used) AS cost,
	ProfitCenter.cost_factor
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type in ('E','L')
	-- The formula below is used to identify N/C workorders.  If any of 3 arguments is zero => N/C
	AND ((wod.bill_rate * wod.quantity_used * wod.price) = 0)
	--AND wod.resource_class_code = dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, wod.company_id, wod.profit_ctr_ID)
JOIN Resource r
	ON r.resource_uid = wod.resource_uid
	AND wod.resource_class_code = dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, r.company_id, r.default_profit_ctr_id)
	--AND r.company_id = wod.company_id
JOIN Customer
	ON Customer.customer_ID = woh.customer_ID
JOIN CustomerBilling cb
	ON cb.customer_id = woh.customer_ID
	AND cb.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND cb.status = 'A'
	AND ((@territory_code = '99') OR (cb.territory_code = @territory_code))
JOIN ProfitCenter
	ON ProfitCenter.company_ID = woh.company_id
	AND ProfitCenter.profit_ctr_ID = woh.profit_ctr_ID
JOIN ProfitCenter defaultProfitCenter
	ON defaultProfitCenter.profit_ctr_id = r.default_profit_ctr_id
	AND defaultProfitCenter.company_ID = r.company_id 
WHERE woh.workorder_status = 'X'
	AND woh.company_id = @company_id
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
GROUP BY 
	woh.profit_ctr_id,
	woh.company_id,
	ProfitCenter.profit_ctr_name,
	ProfitCenter.cost_factor,
	defaultProfitCenter.profit_ctr_name,
	customer.customer_type,
	wod.resource_assigned,
	wod.bill_unit_code

-- Return results
SELECT	
	profit_ctr_id,
	#tmp.company_id,
	Company.company_name,
	profit_ctr_name,
	location,
	customer_type,
	resource_assigned,
	bill_unit_code, 
	SUM(quantity) AS quantity,
	SUM(revenue) AS revenue,
	SUM(cost) AS cost,
	cost_factor
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
GROUP BY
	profit_ctr_id,
	#tmp.company_id,
	Company.company_name,
	profit_ctr_name,
	cost_factor,
	location,
	customer_type,
	resource_assigned,
	bill_unit_code
ORDER BY profit_ctr_id, location, customer_type, resource_assigned, bill_unit_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_resource_util_by_location] TO [EQAI]
    AS [dbo];

