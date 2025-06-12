use Plt_ai
go

drop procedure if exists dbo.sp_d365_pma_export_error_correction
go

create procedure sp_d365_pma_export_error_correction
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int,
	@resource_type varchar(4)
as
/*

03/24/2023 - rwb - Created

*/
declare @prior_export_id int,
		@prior_posting_type varchar(2),
		@prior_posting_status char,
		@version_id int

set transaction isolation level read uncommitted

select @prior_export_id = max(d365_pma_export_uid)
from D365PMAExport
where workorder_id = @workorder_id
and company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and resource_type = @resource_type
and status <> 'V'
and response_text <> 'Returned JSON was an empty string'

if coalesce(@prior_export_id,0) > 0
begin
	select @prior_posting_type = posting_type,
		@prior_posting_status = status
	from D365PMAExport
	where d365_pma_export_uid = @prior_export_id

	if @prior_posting_status = 'E'
	begin
		if @prior_posting_type in ('I','F')
		begin
			if @resource_type = 'ES'
			begin
				select @version_id = max(version_id)
				from D365PMAExportHistoryES
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id

				update D365PMAExportHistoryES
				set status = 'V'
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and version_id = @version_id
				and status = 'A'
			end
			else
			begin
				select @version_id = max(version_id)
				from D365PMAExportHistoryL
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id

				update D365PMAExportHistoryL
				set status = 'V'
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and version_id = @version_id
				and status = 'A'
			end
		end
		else if @prior_posting_type = 'S'
		begin
			if @resource_type = 'ES'
			begin
				select @version_id = max(version_id)
				from D365PMAExportHistoryES
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id

				update D365PMAExportHistoryES
				set status = 'A'
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and version_id = @version_id
				and status = 'V'
			end
			else
			begin
				select @version_id = max(version_id)
				from D365PMAExportHistoryL
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id

				update D365PMAExportHistoryL
				set status = 'A'
				where workorder_id = @workorder_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and version_id = @version_id
				and status = 'V'
			end
		end

		insert D365PMAExport (workorder_id, company_id, profit_ctr_id, resource_type, posting_type, status, response_text)
		values (@workorder_id, @company_id, @profit_ctr_id, @resource_type, 'R', 'N', '')

		insert D365PMAExport (workorder_id, company_id, profit_ctr_id, resource_type, posting_type, status, response_text)
		values (@workorder_id, @company_id, @profit_ctr_id, @resource_type, 'F', 'N', '')
	end
end

select @prior_posting_status prior_posting_status
go

grant execute on sp_d365_pma_export_error_correction to EQAI, AX_SERVICE
go
