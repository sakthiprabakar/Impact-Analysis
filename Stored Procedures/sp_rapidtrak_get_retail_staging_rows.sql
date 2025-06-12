if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_retail_staging_rows')
	drop procedure sp_rapidtrak_get_retail_staging_rows
go

create procedure sp_rapidtrak_get_retail_staging_rows
	@co_pc varchar(4)
as
/*

exec sp_rapidtrak_get_retail_staging_rows '1409'

*/

declare @company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted

select distinct oi.staging_row
from OrderItem oi
join OrderHeader oh
    on oh.order_id = oi.order_id
join OrderDetail od
    on od.order_id = oi.order_id
    and od.line_id = oi.line_id
where od.company_id = @company_id
and od.profit_ctr_id = @profit_ctr_id
and oi.outbound_receipt_id is null
and coalesce(oi.staging_row,'') <> ''
union
select distinct staging_row
from StagingRow
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and status = 'A'

return 0
go

grant execute on sp_rapidtrak_get_retail_staging_rows to EQAI
go
