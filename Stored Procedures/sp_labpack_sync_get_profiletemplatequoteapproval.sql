use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profiletemplatequoteapproval')
	drop procedure sp_labpack_sync_get_profiletemplatequoteapproval
go

create procedure [dbo].[sp_labpack_sync_get_profiletemplatequoteapproval]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the ProfileQuoteApproval details

 loads to Plt_ai
 
 06/14/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplatequoteapproval
 EXEC sp_labpack_sync_get_profiletemplatequoteapproval '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pqa.quote_id,
	pqa.profile_id,
	pqa.company_id,
	pqa.profit_ctr_id,
	pqa.status,
	pqa.primary_facility_flag,
	pqa.approval_code,
	pqa.treatment_id,
	pqa.LDR_req_flag,
	pqa.print_dot_sp_flag,
	pqa.consolidate_containers_flag,
	pqa.consolidation_group_uid,
	pqa.air_permit_status_uid,
	pqa.date_added,
	pqa.date_modified
from Profile p
join ProfileQuoteApproval pqa
	on pqa.profile_id = p.profile_id
where coalesce(p.labpack_template_flag,'F') = 'T'
and (p.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or p.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or pqa.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or pqa.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_profiletemplatequoteapproval to eqai
go
