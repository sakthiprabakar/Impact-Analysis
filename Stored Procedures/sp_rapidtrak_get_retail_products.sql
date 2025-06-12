if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_retail_products')
	drop procedure sp_rapidtrak_get_retail_products
go

create procedure sp_rapidtrak_get_retail_products
	@co_pc varchar(4)
as
/*

exec sp_rapidtrak_get_retail_products '1409'

*/

declare @company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted

select product_ID,
	product_code,
	short_description,
	default_staging_row,
	quantity_required_flag,
	return_weight_required_flag
from Product  
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and retail_flag = 'T'
and status = 'A'

return 0
go

grant execute on sp_rapidtrak_get_retail_products to EQAI
go
