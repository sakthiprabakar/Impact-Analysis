if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_sizes')
	drop procedure sp_rapidtrak_get_container_sizes
go

create procedure sp_rapidtrak_get_container_sizes
as
--
--exec sp_rapidtrak_get_container_sizes
--

select bill_unit_code, bill_unit_desc
from billunit
where container_flag = 'T'
and disposal_flag = 'T'
order by bill_unit_code
go

grant execute on sp_rapidtrak_get_container_sizes to eqai
go
