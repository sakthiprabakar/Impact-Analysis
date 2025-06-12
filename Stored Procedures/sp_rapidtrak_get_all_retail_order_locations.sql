if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_all_retail_order_locations')
	drop procedure sp_rapidtrak_get_all_retail_order_locations
go

create procedure sp_rapidtrak_get_all_retail_order_locations
as
/*

exec sp_rapidtrak_get_all_retail_order_locations

*/

set transaction isolation level read uncommitted

select distinct right('0' + convert(varchar(2),od.company_id),2) + right('0' + convert(varchar(2),od.profit_ctr_id),2) location
from OrderHeader oh
join OrderDetail od
	on oh.order_id = od.order_id
order by right('0' + convert(varchar(2),od.company_id),2) + right('0' + convert(varchar(2),od.profit_ctr_id),2)

return 0
go

grant execute on sp_rapidtrak_get_all_retail_order_locations to EQAI
go
