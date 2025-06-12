use Plt_ai
go

drop procedure if exists dbo.sp_d365_pma_export_get_next
go

create procedure sp_d365_pma_export_get_next
	@last_export_id int = 0
as
/*

03/24/2023 - rwb - Created

exec sp_d365_pma_export_get_next 0

*/
declare @next_id int,
		@resource_type varchar(10),
		@return_value varchar(15)

set transaction isolation level read uncommitted

select @next_id = min(d365_pma_export_uid)
from D365PMAExport
where d365_pma_export_uid > @last_export_id
and status = 'N'

set @return_value = convert(varchar(10),coalesce(@next_id,0))

if @next_id > 0
begin
	select @resource_type = resource_type
	from D365PMAExport
	where d365_pma_export_uid = @next_id

	set @return_value = @return_value + '-' + @resource_type
end

select @return_value as next_id
go

grant execute on sp_d365_pma_export_get_next to EQAI, AX_SERVICE
go
