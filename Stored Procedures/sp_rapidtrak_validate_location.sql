if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_location')
	drop procedure sp_rapidtrak_validate_location
go

create procedure sp_rapidtrak_validate_location
	@co_pc		varchar(4),
	@location	varchar(15)
as
--
--exec sp_rapidtrak_validate_location '2100', '101'
--

declare @company_id 	int,
	@profit_ctr_id	int,
	@status varchar(5),
	@msg varchar(255)

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set @status = 'OK'
set @msg = 'Location is valid.'

if not exists (select 1
				from ProcessLocation pl
				join Batch b
					on b.location = pl.location
					and b.profit_ctr_id = pl.profit_ctr_id
					and b.company_id = pl.company_id
					and b.status = 'O'
				where pl.profit_ctr_id = @profit_ctr_id
				and pl.company_id = @company_id
				and pl.location = @location)
begin
	set @status = 'ERROR'
	set @msg = 'Error: Location ' + @location + ' is invalid.'
end

select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_location to eqai
go
