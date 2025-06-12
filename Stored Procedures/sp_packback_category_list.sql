--- drop proc if exists sp_packback_category_list
go

create proc sp_packback_category_list
as
/* **********************************************************************
sp_packback_category_list
	Lists active (active products using) packback products

7/1/2022 JPB	Created


sp_packback_category_list

********************************************************************** */

select distinct rpc.product_category_id, rpc.name as category_name, rpc.category_order, rpc.image_large, rpc.image_medium, rpc.image_small
from RetailProductCategory rpc
join Product p on rpc.product_category_id = p.product_category_id
WHERE p.retail_flag = 'T'
and p.status = 'A'
and p.view_on_web_flag = 'T'
and rpc.status = 'A'
ORDER BY rpc.category_order, rpc.name

go

grant execute on sp_packback_category_list to eqai
go
grant execute on sp_packback_category_list to cor_user
go

