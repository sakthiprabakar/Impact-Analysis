use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_all_staging_rows')
	drop procedure sp_rapidtrak_get_all_staging_rows
go

create procedure sp_rapidtrak_get_all_staging_rows
	@co_pc varchar(4)
as
/*

01/27/2022 - rwb - Created
11/20/2024 - rwb - CHG0076336 - Added join to StagingRow table in order to pull a more complete list of available staging rows

exec sp_rapidtrak_get_all_staging_rows '2100'

*/

declare
	@company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted

SELECT distinct staging_row
FROM Container
WHERE company_id = @company_id
AND profit_ctr_id = @profit_ctr_id
AND status = 'N'
AND coalesce(staging_row,'') <> ''

UNION
 
SELECT distinct staging_row 
FROM StagingRow
WHERE company_id = @company_id
AND profit_ctr_id = @profit_ctr_id
AND status = 'A'

ORDER BY staging_row

return 0
go

grant execute on sp_rapidtrak_get_all_staging_rows to EQAI
go
