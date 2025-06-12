if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_retail_product_info')
	drop procedure sp_rapidtrak_get_retail_product_info
go

create procedure sp_rapidtrak_get_retail_product_info
	@product_id int
as
/*

exec sp_rapidtrak_get_retail_product_info 854

*/


set transaction isolation level read uncommitted

select product_code,
	short_description,
	default_staging_row,
	quantity_required_flag,
	return_weight_required_flag
from Product  
where product_id = @product_id

return 0
go

grant execute on sp_rapidtrak_get_retail_product_info to EQAI
go
