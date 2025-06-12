if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_staging_count')
	drop procedure sp_rapidtrak_validate_staging_count
go

create procedure sp_rapidtrak_validate_staging_count
	@co_pc			varchar(4),
	@staging_row	varchar(15),
	@expected_count int
as
--
--exec sp_rapidtrak_validate_staging_count '2100', '0729', 10
--

declare @company_id int,
	@profit_ctr_id int,
	@count int,
	@status varchar(7),
	@msg varchar(255)

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set @status = 'OK'
set @msg = 'The expected count matches the container count.'

select @count = count(*)
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and staging_row = @staging_row
and status = 'N'

if @count <> @expected_count
begin
	set @status = 'ERROR'
	set @msg = 'Error: The expected quantity of containers you entered does not match the inventory in this staging row.'
end

select @status as status, @msg as message
go

grant execute on sp_rapidtrak_validate_staging_count to eqai
go
