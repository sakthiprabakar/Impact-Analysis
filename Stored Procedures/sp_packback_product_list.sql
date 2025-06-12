--drop proc if exists sp_packback_product_list
go

create proc sp_packback_product_list (
	@product_category_id varchar(100) = null
	, @search varchar(100) = null
    , @customer_id int = null
	, @promotion_code varchar(15) = null
	, @cart_id		int = null


)
as
/* **********************************************************************
sp_packback_product_list
	Lists active (active products using) packback products

7/1/2022 JPB	Created


sp_packback_product_list
	@product_category_id = null
	, @search = 'hg'
	
********************************************************************** */

drop table if exists #o
drop table if exists #o2

-- declare @product_category_id varchar(100) = '1'
declare @product_category_list table (
	product_category_id int
)

if isnull(@product_category_id, '') <> ''
	insert @product_category_list (product_category_id)
	select product_category_id
	from RetailProductcategory rpc
	join dbo.fn_SplitXsvText(',', 1, @product_category_id) x
	on convert(int, x.row) = rpc.product_category_id
	and x.row is not null
	where rpc.status = 'A'

if (select count(*) from @product_category_list) = 0
	insert @product_category_list 	
	select distinct product_category_id
	from RetailProductcategory rpc
	where rpc.status = 'A'


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
join @product_category_list l on l.product_category_id = p.product_category_id
left outer join OrderDetailCart c on p.product_id = c.product_id and c.cart_id = @cart_id
WHERE p.retail_flag = 'T'
and p.status = 'A'
and p.view_on_web_flag = 'T'
and rpc.status = 'A'
ORDER BY rpc.category_order, rpc.name, p.description

update #o set
	product_quote_id = convert(int, left(product_quote_id_string, charindex('#', product_quote_id_string)-1)),
	price = convert(money, right(product_quote_id_string, len(product_quote_id_string) - charindex('#', product_quote_id_string)))

select * into #o2 from #o WHERE 1=0

if isnull(@search, '') <> ''
	insert #o2 
	select * 
	from #o
	WHERE isnull(convert(varchar(max),description), '') + ' '
		+ isnull(convert(varchar(max),short_description), '') + ' '
		+ isnull(convert(varchar(max),return_description), '') + ' '
		+ isnull(convert(varchar(max),summary_description), '') + ' '
		+ isnull(convert(varchar(max),html_description), '')
		like '%' + replace(@search, ' ', '%') + '%'
else
	insert #o2 
	select * 
	from #o

select * from #o2 
ORDER BY category_order, category_name, description
	
	
go

grant execute on sp_packback_product_list to eqai
go
grant execute on sp_packback_product_list to cor_user
go
