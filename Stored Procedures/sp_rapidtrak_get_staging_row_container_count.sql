if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_staging_row_container_count')
	drop procedure sp_rapidtrak_get_staging_row_container_count
go

create procedure sp_rapidtrak_get_staging_row_container_count
	@co_pc varchar(4),
	@location varchar(5)
as
/*

exec sp_rapidtrak_get_staging_row_container_count '2100', 'NP9'

*/

declare
	@company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted

SELECT count(*) as container_count
FROM Container
WHERE staging_row = @location
AND company_id = @company_id
AND profit_ctr_id = @profit_ctr_id
AND status = 'N'

return 0
go

grant execute on sp_rapidtrak_get_staging_row_container_count to EQAI
go
