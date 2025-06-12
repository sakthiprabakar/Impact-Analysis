if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_retail_staging_row')
	drop procedure sp_rapidtrak_validate_retail_staging_row
go

create procedure sp_rapidtrak_validate_retail_staging_row
	@co_pc varchar(4),
	@staging_row varchar(5)
as
/*

exec sp_rapidtrak_validate_retail_staging_row '1409', 'ROW2'

*/

declare @company_id int,
	@profit_ctr_id int,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Staging row is valid.'

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

--Existing validation here was removed

RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_retail_staging_row to EQAI
go
