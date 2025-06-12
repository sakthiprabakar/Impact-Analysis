
CREATE PROCEDURE sp_rpt_retail_inventory 
	@company_id			int
,	@profit_ctr_id		int
AS
/***********************************************************************
PB Object(s):	r_retail_inventory
	
11/10/2010 SK	Created on Plt_AI

sp_rpt_retail_inventory 14, -1
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT 
	OrderHeader.order_id
,	OrderHeader.order_date
,	OrderItem.date_shipped
,	OrderHeader.customer_id
,	OrderHeader.ship_cust_name
,	OrderHeader.ship_state
,	Product.product_code
,	Product.short_description
,	Generator.generator_name
,	OrderHeader.generator_id
,	OrderDetail.company_id
,	OrderDetail.profit_ctr_id
,	OrderItem.date_returned
,	OrderItem.staging_row
,	OrderItem.quantity_returned
,	OrderItem.date_outbound_receipt
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM OrderHeader 
JOIN OrderDetail
	ON OrderDetail.order_id = OrderHeader.order_id
	AND (@company_id = 0 OR OrderDetail.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR OrderDetail.profit_ctr_id = @profit_ctr_id)
JOIN OrderItem
	ON OrderItem.order_id = OrderDetail.order_id
	AND OrderItem.line_id = OrderDetail.line_id
	AND OrderItem.date_returned IS NOT NULL
	AND OrderItem.date_outbound_receipt IS NULL
JOIN Product
	ON Product.company_ID = OrderDetail.company_id
	AND Product.profit_ctr_ID = OrderDetail.profit_ctr_id
	AND Product.product_ID = OrderDetail.product_id
JOIN Company
	ON Company.company_id = OrderDetail.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = OrderDetail.company_id
	AND ProfitCenter.profit_ctr_id = OrderDetail.profit_ctr_id
LEFT OUTER JOIN Generator 
	ON Generator.generator_id = OrderHeader.generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_retail_inventory] TO [EQAI]
    AS [dbo];

