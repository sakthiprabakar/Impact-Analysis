if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_all_process_locations')
	drop procedure sp_rapidtrak_get_all_process_locations
go

create procedure sp_rapidtrak_get_all_process_locations
	@co_pc	varchar(4)
as
/*
exec sp_rapidtrak_get_all_process_locations '2100'
*/

declare @company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

SELECT DISTINCT pl.location
FROM ProcessLocation pl
JOIN Batch b
	ON b.location = pl.location
	AND b.profit_ctr_id = pl.profit_ctr_id
	AND b.company_id = pl.company_id
	AND b.status = 'O'
WHERE pl.profit_ctr_id = @profit_ctr_id
AND pl.company_id = @company_id
ORDER BY pl.location ASC
go

grant execute on sp_rapidtrak_get_all_process_locations to eqai
go
