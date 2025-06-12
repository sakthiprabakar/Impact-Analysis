use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profiletemplatewastecode')
	drop procedure sp_labpack_sync_get_profiletemplatewastecode
go

create procedure [dbo].[sp_labpack_sync_get_profiletemplatewastecode]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the ProfileWasteCode details

 loads to Plt_ai
 
 06/14/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplatewastecode
 EXEC sp_labpack_sync_get_profiletemplatewastecode '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pwc.profile_id,
	pwc.primary_flag,
	pwc.waste_code,
	pwc.sequence_id,
	pwc.waste_code_uid,
	pwc.sequence_flag,
	pwc.date_added
from Profile p
join ProfileWasteCode pwc
	on pwc.profile_id = p.profile_id
where coalesce(p.labpack_template_flag,'F') = 'T'
and (p.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or p.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or pwc.date_added > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_profiletemplatewastecode to eqai
go
