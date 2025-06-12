CREATE PROCEDURE sp_cust_cost_gross_margin 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code	char(2)
AS
/***************************************************************************************
This SP calculates prices and costs for workorders and shows gross margin.

PB Object(s):	r_cust_cost_gross_margin

04/04/2006 SCC	Created from sp_gross_margin
08/16/2006 MK	Added select from Profile for EQ TSDFs
11/15/2006 RG	Modified to exclude workorders that are marked to be excluded on the 
                WorkOrderHeader (include_cost_report_flag = 'F')
04/15/2007 SCC	Changed to use WorkOrderHeader.submitted flag and CustomerBilling.territory_code
11/08/2010 SK	Added company_id as input argument, replaced *= joins with standard ANSI joins
				, added joins to company-profitcenter
				Moved to Plt_AI
11/30/2022 VR   Devops#58677 fix the incorrect join customer_id instead of quote_id
sp_cust_cost_gross_margin 14, 09, '12/01/2007','12/31/2007', 10877, 10877, '99'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	@price_factor money

SET @price_factor = 1

CREATE TABLE #wo (
	company_id			int		NULL
,	profit_ctr_id		int		NULL
,	workorder_id 		int 	NULL
,	workorder_status	char(1) NULL
,	total_price 		money 	NULL
,	total_cost 			money 	NULL
,	customer_id 		int 	NULL
,	cust_discount		float 	NULL
,	price_equipment		money 	NULL
,	price_labor 		money 	NULL
,	price_supplies 		money 	NULL
,	price_disposal 		money 	NULL
,	price_group 		money 	NULL
,	price_other 		money 	NULL
,	cost_equipment 		money 	NULL
,	cost_labor 			money 	NULL
,	cost_supplies 		money 	NULL
,	cost_disposal 		money 	NULL
,	cost_other 			money 	NULL
)

-- Get Customer Costs
SELECT 
	Customer.customer_id,
	WorkorderQuotedetail.company_id,
	WorkorderQuotedetail.profit_ctr_id,
	WorkorderQuotedetail.resource_type,
	WorkorderQuotedetail.resource_item_code,
	WorkorderQuotedetail.customer_cost,
	WorkorderQuoteHeader.quote_id
INTO #tmp_cust_cost
FROM Customer
JOIN WorkorderQuoteHeader
	/*ON Customer.customer_id = WorkorderQuoteHeader.quote_id*/
	ON Customer.customer_id = WorkorderQuoteHeader.customer_id --Devops#58677 fix the incorrect join customer_id instead of quote_id
	AND WorkorderQuoteHeader.curr_status_code = 'A'
	AND WorkorderQuoteHeader.quote_type = 'C'
	AND (@company_id = 0 OR WorkorderQuoteHeader.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR WorkorderQuoteHeader.profit_ctr_id = @profit_ctr_id)
JOIN WorkorderQuoteDetail
	ON WorkorderQuoteHeader.profit_ctr_id = WorkorderQuoteDetail.profit_ctr_id
	AND WorkorderQuoteHeader.company_id = WorkorderQuoteDetail.company_id
	AND WorkorderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
	AND WorkorderQuoteDetail.record_type = 'P'
WHERE ISNULL(Customer.customer_cost_flag, 'F') = 'T'
	AND EXISTS (SELECT 1 FROM WorkOrderHeader woh
				JOIN CustomerBilling
					ON woh.customer_id = CustomerBilling.customer_id
					AND ISNULL(woh.billing_project_id,0) = CustomerBilling.billing_project_id
					AND CustomerBilling.status = 'A'
					AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
				WHERE woh.workorder_status = 'A' 
					AND ISNULL(woh.submitted_flag,'F') = 'T'
					AND woh.end_date BETWEEN @date_from AND @date_to
					AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
					AND woh.customer_id = Customer.customer_id
					AND (@company_id = 0 OR woh.company_id = @company_id)
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
				)
UNION
SELECT 
	Customer.customer_id,
	WorkorderQuotedetail.company_id,
	WorkorderQuotedetail.profit_ctr_id,
	WorkorderQuotedetail.resource_type,
	WorkorderQuotedetail.resource_item_code,
	WorkorderQuotedetail.customer_cost,
	WorkorderQuoteHeader.quote_id
FROM Customer
JOIN WorkorderQuoteHeader
	ON Customer.customer_id = WorkorderQuoteHeader.customer_id
	AND WorkorderQuoteHeader.curr_status_code = 'A'
	AND WorkorderQuoteHeader.quote_type = 'P'
	AND (@company_id = 0 OR WorkorderQuoteHeader.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR WorkorderQuoteHeader.profit_ctr_id = @profit_ctr_id)
JOIN WorkorderQuoteDetail
	ON WorkorderQuoteHeader.profit_ctr_id = WorkorderQuoteDetail.profit_ctr_id
	AND WorkorderQuoteHeader.company_id = WorkorderQuoteDetail.company_id
	AND WorkorderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
	AND WorkorderQuoteDetail.record_type = 'P'
JOIN WorkOrderHeader
	ON WorkorderQuoteDetail.quote_id = WorkOrderHeader.quote_id
WHERE ISNULL(Customer.customer_cost_flag, 'F') = 'T'
	AND EXISTS (SELECT 1 FROM WorkOrderHeader woh
				JOIN CustomerBilling
					ON woh.customer_id = CustomerBilling.customer_id
					AND ISNULL(woh.billing_project_id,0) = CustomerBilling.billing_project_id
					AND CustomerBilling.status = 'A'
					AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
				WHERE woh.workorder_status = 'A' 
					AND ISNULL(woh.submitted_flag,'F') = 'T'
					AND woh.end_date BETWEEN @date_from AND @date_to
					AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
					AND woh.customer_id = Customer.customer_id
					AND (@company_id = 0 OR woh.company_id = @company_id)
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
				)

-- These are customer disposal costs
SELECT 
	Customer.customer_id,
	TSDFApproval.company_id,
	TSDFApproval.profit_ctr_id,
	TSDFApproval.TSDF_approval_code,
	TSDFApproval.TSDF_approval_id,
	TSDFApprovalPrice.customer_cost,
	'F' as eq_flag
INTO #tmp_cust_disposal_cost
FROM Customer
JOIN TSDFApproval
	ON Customer.customer_id = TSDFapproval.customer_id
	AND TSDFApproval.tsdf_approval_status = 'A'
	AND (@company_id = 0 OR TSDFApproval.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR TSDFApproval.profit_ctr_id = @profit_ctr_id)
JOIN TSDFApprovalPrice
	ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
WHERE 
	ISNULL(Customer.customer_cost_flag, 'F') = 'T' 
	AND EXISTS (SELECT 1 FROM WorkOrderHeader woh
				JOIN WorkOrderDetail wod
					ON woh.profit_ctr_id = wod.profit_ctr_id
					AND woh.company_id = wod.company_id	
					AND woh.workorder_id = wod.workorder_id
					AND wod.resource_type = 'D'
				JOIN CustomerBilling
					ON woh.customer_id = CustomerBilling.customer_id
					AND ISNULL(woh.billing_project_id,0) = CustomerBilling.billing_project_id
					AND CustomerBilling.status = 'A'
					AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
				WHERE woh.workorder_status = 'A' AND ISNULL(woh.submitted_flag,'F') = 'T'
					AND woh.end_date BETWEEN @date_from AND @date_to
					AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
					AND woh.customer_id = Customer.customer_id
					AND (@company_id = 0 OR woh.company_id = @company_id)
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
					AND wod.tsdf_approval_id = TSDFapproval.tsdf_approval_id
					and wod.bill_unit_code = TSDFapprovalPrice.bill_unit_code
					AND TSDFApproval.tsdf_approval_status = 'A'
				)
UNION
SELECT 
	Customer.customer_id,
	ProfileQuoteDetail.company_id,
	ProfileQuoteDetail.profit_ctr_id,
	ProfileQuoteApproval.approval_code,
	ProfileQuoteApproval.profile_id,
	ProfileQuoteDetail.customer_cost,
	'T' as eq_flag
FROM Profile
INNER JOIN ProfileQuoteDetail 
	ON Profile.profile_id = ProfileQuoteDetail.profile_id
	AND (@company_id = 0 OR ProfileQuoteDetail.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR ProfileQuoteDetail.profit_ctr_id = @profit_ctr_id)
INNER JOIN ProfileQuoteApproval 
	ON (ProfileQuoteDetail.profile_id = ProfileQuoteApproval.profile_id
	AND ProfileQuoteDetail.company_id = ProfileQuoteApproval.company_id
	AND ProfileQuoteDetail.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
INNER JOIN Customer 
	ON Profile.customer_id = Customer.customer_id
INNER JOIN ProfitCenter 
	ON ProfileQuoteDetail.company_id = ProfitCenter.company_id
	AND ProfileQuoteDetail.profit_ctr_id = ProfitCenter.profit_ctr_id
WHERE ISNULL(Customer.customer_cost_flag, 'F') = 'T'
	AND EXISTS (SELECT 1 FROM WorkOrderHeader woh
				JOIN WorkOrderDetail wod
					ON wod.workorder_ID = woh.workorder_ID
					AND wod.company_id = woh.company_id
					AND wod.profit_ctr_ID = woh.profit_ctr_ID
					AND wod.resource_type = 'D'
					AND wod.profile_company_id = ProfileQuoteDetail.company_id
					AND wod.profile_profit_ctr_id = ProfileQuoteDetail.profit_ctr_id
					AND wod.profile_id = ProfileQuoteDetail.profile_id
					AND wod.bill_unit_code = ProfileQuoteDetail.bill_unit_code
				JOIN CustomerBilling
					ON woh.customer_id = CustomerBilling.customer_id
					AND ISNULL(woh.billing_project_id,0) = CustomerBilling.billing_project_id
					AND CustomerBilling.status = 'A'
					AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
				WHERE woh.workorder_status = 'A' 
					AND ISNULL(woh.submitted_flag, 'F') = 'T'
					AND woh.end_date BETWEEN @date_from AND @date_to
					AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
					AND woh.customer_id = Customer.customer_id
					AND (@company_id = 0 OR woh.company_id = @company_id)
					AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
				)

/* Insert records */
INSERT #wo
SELECT 
	woh.company_id
,	woh.profit_ctr_id
,	woh.workorder_id
,	woh.workorder_status
,	woh.total_price
,	0.00 AS total_cost
,	woh.customer_id
,	woh.cust_discount
,	price_equipment = ISNULL((SELECT SUM( quantity_used * price ) FROM WorkOrderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id
									AND woh.profit_ctr_id = wod.profit_ctr_id
									AND woh.company_id = wod.company_id 
									AND bill_rate > 0 
									AND wod.resource_type = 'E'), 0)
,	price_labor = ISNULL((SELECT SUM( quantity_used * price ) FROM WorkOrderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id
								AND woh.company_id = wod.company_id 
								AND bill_rate > 0 
								AND wod.resource_type = 'L'), 0)
,	price_supplies = ISNULL((SELECT SUM( quantity_used * price ) FROM WorkOrderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id
									AND woh.company_id = wod.company_id 
									AND bill_rate > 0 
									AND wod.resource_type = 'S'), 0)
,	price_disposal = ISNULL((SELECT SUM(quantity_used * price ) FROM WorkOrderDetail wod 
								WHERE woh.workorder_id = wod.workorder_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id
									AND woh.company_id = wod.company_id 
									AND bill_rate > 0 
									AND wod.resource_type = 'D'), 0)
,	price_group = 0
,	price_other = ISNULL((SELECT SUM(quantity_used * price ) FROM WorkOrderDetail wod 
							WHERE woh.workorder_id = wod.workorder_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id
								AND woh.company_id = wod.company_id 
								AND bill_rate > 0
								AND wod.resource_type = 'O'), 0)
,	cost_equipment = ISNULL((SELECT SUM((wod.quantity_used * ISNULL(COALESCE(#tmp_cust_cost.customer_cost, (wod.price * @price_factor)),0)))  
								FROM WorkOrderDetail wod
								LEFT OUTER JOIN #tmp_cust_cost
									ON #tmp_cust_cost.customer_id = woh.customer_id
									AND #tmp_cust_cost.profit_ctr_id = woh.profit_ctr_id
									AND #tmp_cust_cost.company_id = woh.company_id
									AND #tmp_cust_cost.resource_type = wod.resource_type
									AND #tmp_cust_cost.resource_item_code = wod.resource_class_code
									AND #tmp_cust_cost.quote_id = woh.quote_id
								WHERE woh.workorder_id = wod.workorder_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id
									AND woh.company_id = wod.company_id 
									AND wod.resource_type = 'E'
							), 0)
,	cost_labor = ISNULL((SELECT SUM( quantity_used * ISNULL(COALESCE(#tmp_cust_cost.customer_cost, (wod.price * @price_factor)),0) )  
							FROM WorkOrderDetail wod
							LEFT OUTER JOIN #tmp_cust_cost
									ON #tmp_cust_cost.customer_id = woh.customer_id
									AND #tmp_cust_cost.profit_ctr_id = woh.profit_ctr_id
									AND #tmp_cust_cost.company_id = woh.company_id
									AND #tmp_cust_cost.resource_type = wod.resource_type
									AND #tmp_cust_cost.resource_item_code = wod.resource_class_code
									AND #tmp_cust_cost.quote_id = woh.quote_id
							WHERE woh.workorder_id = wod.workorder_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id
								AND woh.company_id = wod.company_id 
								AND wod.resource_type = 'L'
							), 0)
,	cost_supplies = ISNULL((SELECT SUM( quantity_used * ISNULL(COALESCE(#tmp_cust_cost.customer_cost, (wod.price * @price_factor)),0) )  
							FROM WorkOrderDetail wod
							LEFT OUTER JOIN #tmp_cust_cost
									ON #tmp_cust_cost.customer_id = woh.customer_id
									AND #tmp_cust_cost.profit_ctr_id = woh.profit_ctr_id
									AND #tmp_cust_cost.company_id = woh.company_id
									AND #tmp_cust_cost.resource_type = wod.resource_type
									AND #tmp_cust_cost.resource_item_code = wod.resource_class_code
									AND #tmp_cust_cost.quote_id = woh.quote_id
							WHERE woh.workorder_id = wod.workorder_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id
								AND woh.company_id = wod.company_id 
								AND wod.resource_type = 'S'
							), 0)
,	cost_disposal = ISNULL((SELECT SUM( quantity_used * ISNULL(COALESCE(#tmp_cust_disposal_cost.customer_cost, (wod.price * @price_factor)),0) )  
								FROM WorkOrderDetail wod
								LEFT OUTER JOIN #tmp_cust_disposal_cost
									ON #tmp_cust_disposal_cost.profit_ctr_id = woh.profit_ctr_id
									AND #tmp_cust_disposal_cost.company_id = woh.company_id
									AND #tmp_cust_disposal_cost.tsdf_approval_code = wod.tsdf_approval_code
									AND ((#tmp_cust_disposal_cost.eq_flag = 'F' and wod.tsdf_approval_id = #tmp_cust_disposal_cost.tsdf_approval_id)
											OR (#tmp_cust_disposal_cost.eq_flag = 'T' and wod.profile_id = #tmp_cust_disposal_cost.tsdf_approval_id))
								WHERE woh.workorder_id = wod.workorder_id 
									AND woh.profit_ctr_id = wod.profit_ctr_id 
									AND woh.company_id = wod.company_id 
									AND wod.resource_type = 'D'
									AND wod.bill_rate >= 0  -- Skip cost on manifest only disposal lines
							), 0)
,	cost_other = ISNULL((SELECT SUM( quantity_used * ISNULL(COALESCE(#tmp_cust_cost.customer_cost, (wod.price * @price_factor)),0) )  
							FROM WorkOrderDetail wod
							LEFT OUTER JOIN #tmp_cust_cost
									ON #tmp_cust_cost.customer_id = woh.customer_id
									AND #tmp_cust_cost.profit_ctr_id = woh.profit_ctr_id
									AND #tmp_cust_cost.company_id = woh.company_id
									AND #tmp_cust_cost.resource_type = wod.resource_type
									AND #tmp_cust_cost.resource_item_code = wod.resource_class_code
									AND #tmp_cust_cost.quote_id = woh.quote_id
							WHERE woh.workorder_id = wod.workorder_id 
								AND woh.profit_ctr_id = wod.profit_ctr_id 
								AND woh.company_id = wod.company_id 
								AND wod.resource_type = 'O'
							), 0)
FROM WorkOrderHeader woh
JOIN Customer
	ON Customer.customer_ID = woh.customer_id
	AND ISNULL(Customer.customer_cost_flag,'F') = 'T'
JOIN CustomerBilling
	ON CustomerBilling.customer_id = woh.customer_id
	AND ISNULL(woh.billing_project_id,0) = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code))
WHERE woh.workorder_status = 'A' 
	AND ISNULL(woh.submitted_flag,'F') = 'T'
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND (@company_id = 0 OR woh.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
    AND ISNULL(woh.include_cost_report_flag, 'T') = 'T'
-- rg111506 exclude workorders that are marked not to include
GROUP BY 
	woh.company_id,
	woh.profit_ctr_id,
	woh.workorder_id,
	woh.workorder_status,
	woh.total_price,
	woh.customer_id,
	woh.cust_discount,
	woh.quote_id

-- set the total cost
UPDATE #wo SET total_cost = cost_equipment + cost_labor + cost_supplies + cost_disposal + cost_other

SELECT DISTINCT
	customer.cust_name,
	workorder_status,
	workorder_id,
	Billing.invoice_code,
	#wo.customer_id,
	#wo.cust_discount, 
	price_equipment = price_equipment * ((100 - #wo.cust_discount) / 100),
	price_labor = price_labor * ((100 - #wo.cust_discount) / 100),
	price_supplies = price_supplies * ((100 - #wo.cust_discount) / 100),
	price_disposal = price_disposal * ((100 - #wo.cust_discount) / 100),
	price_group = price_group * ((100 - #wo.cust_discount) / 100),
	price_other = price_other * ((100 - #wo.cust_discount) / 100),
	total_price,
	cost_equipment,
	cost_labor,
	cost_supplies,
	cost_disposal,
	cost_other,
	total_cost,
	#wo.company_id,
	#wo.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM #wo
JOIN Company
	ON Company.company_id = #wo.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #wo.company_id
	AND ProfitCenter.profit_ctr_ID = #wo.profit_ctr_id
JOIN customer
	ON customer.customer_id = #wo.customer_id
LEFT OUTER JOIN Billing
	ON Billing.company_id = #wo.company_id
	AND Billing.profit_ctr_id = #wo.profit_ctr_id
	AND Billing.receipt_id  = #wo.workorder_id
	AND Billing.trans_source = 'W'
ORDER BY customer.cust_name, workorder_status

DROP TABLE #wo

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cust_cost_gross_margin] TO [EQAI]
    AS [dbo];

