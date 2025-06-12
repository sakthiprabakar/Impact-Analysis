if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_retail_order_info')
	drop procedure sp_rapidtrak_get_retail_order_info
go

create procedure sp_rapidtrak_get_retail_order_info
	@package_barcode varchar(100)
as
/*
ADO 29422

exec sp_rapidtrak_get_retail_order_info '1Z584Y450346805577'

*/

set transaction isolation level read uncommitted

select
	convert(varchar(10),oi.order_id) + '-' + convert(varchar(10),oi.line_id) + '-' + convert(varchar(10),oi.sequence_id) order_number,
	oh.ship_cust_name,
	oh.ship_addr1,
	oh.ship_addr2,
	oh.ship_addr3,
	oh.ship_city,
	oh.ship_state,
	oh.ship_zip_code,
	oh.ship_attention_name,
	oh.ship_phone,
	oh.order_date,
	oi.date_returned,
	p.product_code,
	p.description product_description,
	case oh.order_type when 'A' then 'On Account' else 'Charged' end purchase_type,
	oi.staging_row,
	p.short_description,
	p.product_id
from OrderDetail od
join OrderHeader oh
	on oh.order_id = od.order_id
join OrderItem oi
	on oi.order_id = od.order_id
	and oi.line_id = od.line_id
	and (oi.tracking_barcode_shipped = @package_barcode
		or oi.tracking_barcode_returned = @package_barcode) 
join Product p
	on p.product_ID = od.product_id
	and p.company_id = od.company_ID
	and p.profit_ctr_id = od.profit_ctr_ID

return 0
go

grant execute on sp_rapidtrak_get_retail_order_info to EQAI
go
