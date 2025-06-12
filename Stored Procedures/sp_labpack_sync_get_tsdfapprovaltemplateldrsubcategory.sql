use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory')
	drop procedure sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory
go

create procedure [dbo].[sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalLDRSubcategory details

 loads to Plt_ai
 
 06/15/2021 - rb created

 EXEC sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory
 EXEC sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	tls.tsdf_approval_id,
	tls.ldr_subcategory_id,
	tls.date_added,
	tls.date_modified
from TSDFApproval ta
join TSDFApprovalLDRSubcategory tls
	on tls.tsdf_approval_id = ta.tsdf_approval_id
where coalesce(ta.labpack_template_flag,'F') = 'T'
and (ta.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or ta.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or tls.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or tls.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_tsdfapprovaltemplateldrsubcategory to eqai
go
