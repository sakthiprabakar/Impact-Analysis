
CREATE PROCEDURE sp_rpt_retail_outbounded 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@cust_id_from		int
,	@cust_id_to			int
,	@product_code_from	varchar(15)
,	@product_code_to	varchar(15)
,	@generator_id_from	int
,	@generator_id_to	int
,	@state				varchar(2)
AS

/***********************************************************************
PB Object(s):	r_retail_outbounded
	
11/10/2010 SK	Created on Plt_AI

sp_rpt_retail_outbounded 14, -1, '05/01/2010', '05/31/2010', 1, 999999, '0', 'zzzzzzz', 1, 99999, 'XX'
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
	AND OrderItem.date_shipped IS NOT NULL
	AND OrderItem.date_returned IS NOT NULL
	AND OrderItem.date_outbound_receipt IS NOT NULL
	AND OrderItem.date_outbound_receipt BETWEEN @date_from AND @date_to
JOIN Product
	ON Product.company_ID = OrderDetail.company_id
	AND Product.profit_ctr_ID = OrderDetail.profit_ctr_id
	AND Product.product_ID = OrderDetail.product_id
	AND Product.product_code BETWEEN @product_code_from AND @product_code_to
JOIN Company
	ON Company.company_id = OrderDetail.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = OrderDetail.company_id
	AND ProfitCenter.profit_ctr_id = OrderDetail.profit_ctr_id
LEFT OUTER JOIN Generator 
	ON Generator.generator_id = OrderHeader.generator_id
WHERE OrderHeader.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND ((@generator_id_from = 1 AND @generator_id_to = 99999) 
			OR OrderHeader.generator_id BETWEEN @generator_id_from AND @generator_id_to)
	AND (@state = 'XX' OR OrderHeader.ship_state = @state)		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_retail_outbounded] TO [EQAI]
    AS [dbo];

