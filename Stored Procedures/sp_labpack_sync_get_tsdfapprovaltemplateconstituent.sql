use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_tsdfapprovaltemplateconstituent')
	drop procedure sp_labpack_sync_get_tsdfapprovaltemplateconstituent
go

create procedure [dbo].[sp_labpack_sync_get_tsdfapprovaltemplateconstituent]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalConstituent details

 loads to Plt_ai
 
 06/14/2021 - rb created

 EXEC sp_labpack_sync_get_tsdfapprovaltemplateconstituent
 EXEC sp_labpack_sync_get_tsdfapprovaltemplateconstituent '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	tac.TSDF_approval_id,
	tac.company_id,
	tac.profit_ctr_id,
	tac.const_id,
	tac.concentration,
	tac.unit,
	tac.UHC,
	tac.date_added,
	tac.date_modified
from TSDFApproval t
join TSDFApprovalConstituent tac
	on tac.tsdf_approval_id = t.tsdf_approval_id
where coalesce(t.labpack_template_flag,'F') = 'T'
and (t.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or t.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or tac.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or tac.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_tsdfapprovaltemplateconstituent to eqai
go
