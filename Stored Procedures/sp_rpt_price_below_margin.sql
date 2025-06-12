CREATE PROCEDURE sp_rpt_price_below_margin 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code char(2)
AS
/*****************************************************************************************
PB Object(s):	r_price_below_margin

12/09/2010 SK Created new on Plt_AI

sp_rpt_price_below_margin 0, -1, '01-01-2005','01-31-2005', 1, 999999, '99'
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT
	WorkOrderHeader.workorder_id
,	WorkOrderHeader.company_id
,	WorkorderHeader.profit_ctr_ID
,	end_date
,	resource_type
,	resource_class_code
,	WorkOrderDetail.description
,	cost
,	cost_factor
,	price
,	price_source
,	Company.company_name
,	profitcenter.profit_ctr_name  
FROM workorderheader
JOIN Company
	ON Company.company_id = WorkorderHeader.company_id
INNER JOIN workorderdetail 
	ON WorkOrderHeader.workorder_id = WorkOrderDetail.workorder_id
	AND WorkOrderHeader.profit_ctr_id = WorkOrderDetail.profit_ctr_id
	AND WorkOrderHeader.company_id = WorkOrderDetail.company_id
	AND WorkOrderDetail.group_instance_id = 0
	AND WorkOrderDetail.resource_type <> 'D' 
	AND WorkorderDetail.bill_rate > 0 
INNER JOIN profitcenter 
	ON WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id 
	AND ProfitCenter.company_ID = WorkorderHeader.company_id
INNER JOIN CustomerBilling 
	ON WorkOrderHeader.customer_id = CustomerBilling.customer_id 
	AND IsNull(WorkorderHeader.billing_project_id,0) = CustomerBilling.billing_project_id
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code)) 
WHERE WorkOrderHeader.workorder_status in ('A','P')
	AND WorkOrderHeader.submitted_flag = 'F' 
	AND WorkOrderDetail.price < (WorkOrderDetail.cost / (1 - ProfitCenter.cost_factor))
	AND WorkOrderHeader.fixed_price_flag = 'F' 
	AND WorkOrderHeader.end_date BETWEEN @date_from AND @date_to 
	AND WorkOrderHeader.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR WorkOrderHeader.profit_ctr_id = @profit_ctr_id)
	AND (@company_id = 0 OR WorkOrderHeader.company_id = @company_id)
	
UNION ALL

SELECT
	WorkOrderHeader.workorder_id
,	WorkOrderHeader.company_id
,	WorkorderHeader.profit_ctr_ID
,	end_date
,	resource_type
,	resource_class_code
,	WorkOrderDetail.description
,	cost
,	cost_factor
,	price
,	price_source
,	Company.company_name
,	profitcenter.profit_ctr_name  
FROM workorderheader
JOIN Company
	ON Company.company_id = WorkorderHeader.company_id
INNER JOIN workorderdetail 
	ON WorkOrderHeader.workorder_id = WorkOrderDetail.workorder_id
	AND WorkOrderHeader.profit_ctr_id = WorkOrderDetail.profit_ctr_id
	AND WorkOrderHeader.company_id = WorkOrderDetail.company_id
	AND WorkOrderDetail.resource_type = 'G'
	AND WorkorderDetail.bill_rate > 0 
INNER JOIN profitcenter 
	ON WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id 
	AND ProfitCenter.company_ID = WorkorderHeader.company_id
INNER JOIN CustomerBilling 
	ON WorkOrderHeader.customer_id = CustomerBilling.customer_id 
	AND IsNull(WorkorderHeader.billing_project_id,0) = CustomerBilling.billing_project_id
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code)) 
WHERE WorkOrderHeader.workorder_status in ('A','P')
	AND WorkOrderHeader.submitted_flag = 'F' 
	AND WorkOrderDetail.price < (WorkOrderDetail.cost / (1 - ProfitCenter.cost_factor))
	AND WorkOrderHeader.fixed_price_flag = 'F' 
	AND WorkOrderHeader.end_date BETWEEN @date_from AND @date_to 
	AND WorkOrderHeader.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR WorkOrderHeader.profit_ctr_id = @profit_ctr_id)
	AND (@company_id = 0 OR WorkOrderHeader.company_id = @company_id)

UNION ALL

SELECT
	WorkOrderHeader.workorder_id
,	WorkOrderHeader.company_id
,	WorkorderHeader.profit_ctr_ID
,	end_date
,	'D'
,	TSDF_code
,	TSDF_approval_code
,	cost
,	cost_factor
,	price
,	price_source
,	Company.company_name
,	profitcenter.profit_ctr_name 
FROM workorderheader
JOIN Company
	ON Company.company_id = WorkorderHeader.company_id 
INNER JOIN workorderdetail 
	ON WorkOrderHeader.workorder_id = WorkOrderDetail.workorder_id
	AND WorkOrderHeader.profit_ctr_id = WorkOrderDetail.profit_ctr_id
	AND WorkOrderHeader.company_id = WorkOrderDetail.company_id
	AND WorkOrderDetail.resource_type = 'D'
	AND WorkorderDetail.bill_rate > 0 
INNER JOIN profitcenter 
	ON WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id 
	AND ProfitCenter.company_ID = WorkorderHeader.company_id
INNER JOIN CustomerBilling 
	ON WorkOrderHeader.customer_id = CustomerBilling.customer_id 
	AND IsNull(WorkorderHeader.billing_project_id,0) = CustomerBilling.billing_project_id
	AND ((@territory_code = '99') OR (CustomerBilling.territory_code = @territory_code)) 
WHERE WorkOrderHeader.workorder_status in ('A','P')
	AND WorkOrderHeader.submitted_flag = 'F' 
	AND WorkOrderDetail.price < (WorkOrderDetail.cost / (1 - ProfitCenter.cost_factor))
	AND WorkOrderHeader.fixed_price_flag = 'F' 
	AND WorkOrderHeader.end_date BETWEEN @date_from AND @date_to 
	AND WorkOrderHeader.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR WorkOrderHeader.profit_ctr_id = @profit_ctr_id)
	AND (@company_id = 0 OR WorkOrderHeader.company_id = @company_id)
ORDER BY WorkOrderHeader.workorder_id, resource_type 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_price_below_margin] TO [EQAI]
    AS [dbo];

