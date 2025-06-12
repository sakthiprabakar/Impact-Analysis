use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_tsdfapprovaltemplatewastecode')
	drop procedure sp_labpack_sync_get_tsdfapprovaltemplatewastecode
go

create procedure [dbo].[sp_labpack_sync_get_tsdfapprovaltemplatewastecode]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalWasteCode details

 loads to Plt_ai
 
 06/15/2021 - rb created

 EXEC sp_labpack_sync_get_profiletemplatewastecode
 EXEC sp_labpack_sync_get_profiletemplatewastecode '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	tawc.TSDF_approval_id,
	tawc.company_id,
	tawc.profit_ctr_id,
	tawc.primary_flag,
	tawc.waste_code,
	tawc.sequence_id,
	tawc.waste_code_uid,
	tawc.sequence_flag,
	tawc.date_added
from TSDFApproval ta
join TSDFApprovalWasteCode tawc
	on tawc.tsdf_approval_id = ta.tsdf_approval_id
where coalesce(ta.labpack_template_flag,'F') = 'T'
and (ta.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or ta.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or tawc.date_added > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_tsdfapprovaltemplatewastecode to eqai
go
