if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_location_tracking_num')
	drop procedure sp_rapidtrak_get_container_location_tracking_num
go

create procedure sp_rapidtrak_get_container_location_tracking_num
	@container varchar(20)
as
--
--exec sp_rapidtrak_get_container_location_tracking_num 'DL-2100-414910'
--
declare
	@type char,
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@available_percent int,
	@location varchar(15),
	@tracking_num varchar(15),
	@cycle int

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

set transaction isolation level read uncommitted

select @location = location,
		@tracking_num = tracking_num,
		@cycle = cycle
from ContainerDestination
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id  
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id
and container_type = @type
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = @company_id
					and profit_ctr_id = @profit_ctr_id  
					and receipt_id = @receipt_id
					and line_id = @line_id
					and container_id = @container_id
					and container_type = @type)

select coalesce(@location,'') as location, coalesce(@tracking_num,'') as tracking_num, coalesce(convert(varchar(10),@cycle),'') as cycle
return 0
go

grant execute on sp_rapidtrak_get_container_location_tracking_num to EQAI, TRIPSERV
go
