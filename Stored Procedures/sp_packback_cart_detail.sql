-- drop proc if exists sp_packback_cart_detail
go

create proc sp_packback_cart_detail (
	@cart_id		int
)
as
/* **********************************************************************
sp_packback_cart_detail
	Lists contents of a specific @cart_id

7/12/2022 JPB	Created


SELECT  top 20 * FROM    OrderHeaderCart ORDER BY date_added desc
SELECT  top 20 * FROM    OrderHeader ORDER BY date_added desc

sp_columns OrderHeaderCart

	insert OrderHeaderCart 
	select top 5 
		order_id as cart_id, customer_id, generator_id, contact_id, billing_project_id, contact_first_name
		,contact_last_name, ship_cust_name as contact_company_name, email as contact_email, 'F' as send_email_flag
		, null as contact_phone, ship_cust_name, null as ship_attention_name, ship_addr1, ship_addr2
		,ship_addr3, ship_addr4, ship_city, ship_state, ship_zip_code, 'C' as payment_method, promotion_code
		,release_code, purchase_order, name_on_card, billing_addr1, billing_addr2, billing_addr3
		,billing_addr4, billing_city, billing_state, billing_postal_code, credit_card_auth_id, getdate() as date_added
	from OrderHeader
	ORDER BY date_added desc

	insert OrderDetailCart 
		(cart_id, product_quote_id, product_id, quantity, price, cor_flag, replenishment_flag, date_added)
	select top 5
		order_id - 10504 as cart_id, product_quote_id, product_id, quantity, price, cor_flag, replenishment_flag
		,date_added
	FROM    OrderDetail 
	ORDER BY date_added desc

	SELECT  * FROM    OrderHeaderCart
	SELECT  * FROM    OrderDetailCart

sp_packback_cart_detail 1003
	
********************************************************************** */

select  
	p.product_id
	, p.product_code
	, dbo.fn_retail_product_price(od.product_id, isnull(od.quantity, 1), oh.customer_id, oh.promotion_code, getdate()) as product_quote_id_string
	, od.product_quote_id
	, p.bill_unit_code
	, p.company_id
	, p.profit_ctr_id
	, p.status
	, od.price
	, p.description
	, p.retail_flag
	, p.view_on_web_flag
	, p.ship_length
	, p.ship_width
	, p.ship_height
	, p.ship_weight
	, p.return_length
	, p.return_width
	, p.return_height
	, p.return_weight
	, p.cor_available_flag -- certificate of recycling
	, p.short_description
	, p.return_description
	, p.summary_description
	, p.html_description
	, p.web_image_name_thumb
	, p.web_image_name_full
	, p.return_weight_required_flag
	, rpc.name as category_name
	, rpc.product_category_id
	, rpc.category_order
	, od.line_id
	, od.quantity
	, od.cor_flag
	, od.replenishment_flag
from OrderHeaderCart oh
join OrderDetailCart od on oh.cart_id = od.cart_id
join Product p on od.product_id = p.product_id
join RetailProductCategory rpc on rpc.product_category_id = p.product_category_id
WHERE oh.cart_id = @cart_id
and p.retail_flag = 'T'
and p.view_on_web_flag = 'T'
and p.status = 'A'
and rpc.status = 'A'
ORDER BY rpc.category_order, rpc.name, p.description

	
go

grant execute on sp_packback_cart_detail to eqai
go
grant execute on sp_packback_cart_detail to cor_user
go

