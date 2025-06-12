use Plt_ai
go

drop procedure if exists dbo.sp_d365_pma_export_set_status
go

create procedure sp_d365_pma_export_set_status
	@d365_pma_export_uid int,
	@status char(1),
	@msg varchar(max)
as
/*

03/24/2023 - rwb - Created

exec dbo.sp_d365_pma_export_set_status 1, 'P', 'Sent to D365'
exec dbo.sp_d365_pma_export_set_status 1, 'N', null

*/

update D365PMAExport
set status = @status,
	response_text = @msg,
	modified_by = 'AX_SERVICE',
	date_modified = getdate()
where d365_pma_export_uid = @d365_pma_export_uid
go

grant execute on sp_d365_pma_export_set_status to AX_SERVICE, EQAI
go
