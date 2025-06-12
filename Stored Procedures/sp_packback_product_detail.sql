-- drop proc if exists sp_packback_product_detail
go

create proc sp_packback_product_detail (
	@product_id int
	, @customer_id int = null
	, @promotion_code varchar(15) = null
	, @cart_id		int = null
)
as
/* **********************************************************************
sp_packback_product_detail
	Lists details for one packback product

7/12/2022 JPB	Created

sp_helptext sp_packback_product_list

sp_packback_product_detail
	@product_id = 865
	
	
********************************************************************** */

drop table if exists #o
drop table if exists #o2

select  
	p.product_id
	, p.product_code
	, dbo.fn_retail_product_price(p.product_id, isnull(c.quantity, 1), @customer_id, @promotion_code, getdate()) as product_quote_id_string
	, convert(int, NULL) as product_quote_id
	, p.bill_unit_code
	, p.company_id
	, p.profit_ctr_id
	, p.status
	, p.price
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
into #o
from Product p
join RetailProductCategory rpc on rpc.product_category_id = p.product_category_id
left outer join OrderDetailCart c on p.product_id = c.product_id and c.cart_id = @cart_id
WHERE p.retail_flag = 'T'
and p.view_on_web_flag = 'T'
and p.status = 'A'
and rpc.status = 'A'
and p.product_id = @product_id
ORDER BY rpc.category_order, rpc.name, p.description

update #o set
	product_quote_id = convert(int, left(product_quote_id_string, charindex('#', product_quote_id_string)-1)),
	price = convert(money, right(product_quote_id_string, len(product_quote_id_string) - charindex('#', product_quote_id_string)))

select * 
into #o2 
from #o

select * from #o2 
ORDER BY category_order, category_name, description
	
go

grant execute on sp_packback_product_detail to eqai
go
grant execute on sp_packback_product_detail to cor_user
go

