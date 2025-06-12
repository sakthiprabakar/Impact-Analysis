use Plt_ai
go

drop procedure if exists dbo.sp_d365_pma_export_error_get_next
go

create procedure sp_d365_pma_export_error_get_next
	@last_export_id int = 0
as
/*

03/24/2023 - rwb - Created
08/14/2024 - rwb - CHG0073636 - Added extra criteria to handle strange case where 2 incremental records are
								created microseconds after full records, and an error occurred on first full posting

exec sp_d365_pma_export_error_get_next
exec sp_d365_pma_export_error_get_next 10611
exec sp_d365_pma_export_error_get_next 465443
*/
declare @d365_pma_export_uid int

set transaction isolation level read uncommitted

select @d365_pma_export_uid = min(e.d365_pma_export_uid)
from D365PMAExport e
where e.d365_pma_export_uid > @last_export_id
and e.status = 'E'
	and (not exists (select 1 from D365PMAExport
					where workorder_id = e.workorder_id
					and company_id = e.company_id
					and profit_ctr_id = e.profit_ctr_id
					and resource_type = e.resource_type
					and status in ('N','C','I','E','P')
					and d365_pma_export_uid > e.d365_pma_export_uid
					)
		or
		exists (select 1 from D365PMAExport e2
					where workorder_id = e.workorder_id
					and company_id = e.company_id
					and profit_ctr_id = e.profit_ctr_id
					and resource_type = e.resource_type
					and posting_type = 'I'
					and status = 'C'
					and response_text = 'Returned JSON was an empty string'
					and d365_pma_export_uid > e.d365_pma_export_uid
					and date_added < dateadd(ss,2,e.date_added)
					and not exists (select 1 from D365PMAExport
									where workorder_id = e2.workorder_id
									and company_id = e2.company_id
									and profit_ctr_id = e2.profit_ctr_id
									and resource_type = e2.resource_type
									and status in ('N','C','I','E','P')
									and d365_pma_export_uid > e2.d365_pma_export_uid
									)
						)
					)
				
select d365_pma_export_uid, workorder_id, company_id, profit_ctr_id, resource_type
from D365PMAExport
where d365_pma_export_uid = @d365_pma_export_uid
go

grant execute on sp_d365_pma_export_error_get_next to EQAI, AX_SERVICE
go
