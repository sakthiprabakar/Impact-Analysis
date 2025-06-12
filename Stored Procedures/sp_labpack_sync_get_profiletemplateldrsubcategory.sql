use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profiletemplateldrsubcategory')
	drop procedure sp_labpack_sync_get_profiletemplateldrsubcategory
go

create procedure [dbo].[sp_labpack_sync_get_profiletemplateldrsubcategory]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the ProfileLDRSubcategory details

 loads to Plt_ai
 
 06/08/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplateldrsubcategory
 EXEC sp_labpack_sync_get_profiletemplateldrsubcategory '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pls.profile_id,
	pls.ldr_subcategory_id,
	pls.date_added,
	pls.date_modified
from Profile p
join ProfileLDRSubcategory pls
	on pls.profile_id = p.profile_id
where coalesce(p.labpack_template_flag,'F') = 'T'
and (p.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or p.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or pls.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or pls.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_profiletemplateldrsubcategory to eqai
go
