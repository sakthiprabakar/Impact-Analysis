use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_containertype')
	drop procedure sp_labpack_sync_get_containertype
go

create procedure [dbo].[sp_labpack_sync_get_containertype]
as
/***************************************************************************************
 this procedure retrieves the ContainerTypes (full replacement)

 loads to Plt_ai
 
 exec sp_labpack_sync_get_containertype

 08/16/2023 - rwb created

****************************************************************************************/

set transaction isolation level read uncommitted

select
	manifest_code,
	manifest_desc
from ManifestCodeLookup
where manifest_item = 'container'
and coalesce(manifest_code,'') <> ''
go

grant execute on sp_labpack_sync_get_containertype to eqai
go
