use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profiletemplateconstituent')
	drop procedure sp_labpack_sync_get_profiletemplateconstituent
go

create procedure [dbo].[sp_labpack_sync_get_profiletemplateconstituent]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the ProfileConstituent details

 loads to Plt_ai
 
 06/08/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplateconstituent
 EXEC sp_labpack_sync_get_profiletemplateconstituent '06/12/2021 12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pc.profile_id,
	pc.const_id,
	pc.concentration,
	pc.unit,
	pc.UHC,
	pc.date_added,
	pc.date_modified
from Profile p
join ProfileConstituent pc
	on pc.profile_id = p.profile_id
where coalesce(p.labpack_template_flag,'F') = 'T'
and (p.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or p.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or pc.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or pc.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_profiletemplateconstituent to eqai
go
