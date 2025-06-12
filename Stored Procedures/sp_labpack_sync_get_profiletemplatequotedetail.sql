use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profiletemplatequotedetail')
	drop procedure sp_labpack_sync_get_profiletemplatequotedetail
go

create procedure [dbo].[sp_labpack_sync_get_profiletemplatequotedetail]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the ProfileQuoteDetail details

 loads to Plt_ai
 
 06/14/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplatequotedetail
 EXEC sp_labpack_sync_get_profiletemplatequotedetail '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pqd.quote_id,
	pqd.profile_id,
	pqd.company_id,
	pqd.profit_ctr_id,
	pqd.status,
	pqd.sequence_id,
	pqd.record_type,
	pqd.bill_unit_code,
	pqd.price,
	pqd.service_desc,
	pqd.date_added,
	pqd.date_modified
from Profile p
join ProfileQuoteDetail pqd
	on pqd.profile_id = p.profile_id
where coalesce(p.labpack_template_flag,'F') = 'T'
and (p.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or p.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or pqd.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or pqd.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_profiletemplatequotedetail to eqai
go
