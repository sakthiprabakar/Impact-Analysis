use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_tsdfapprovaltemplateprice')
	drop procedure sp_labpack_sync_get_tsdfapprovaltemplateprice
go

create procedure [dbo].[sp_labpack_sync_get_tsdfapprovaltemplateprice]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalPrice details

 loads to Plt_ai
 
 06/15/2021 - rb created

 EXEC sp_labpack_sync_get_tsdfapprovaltemplateprice
 EXEC sp_labpack_sync_get_tsdfapprovaltemplateprice '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	tap.TSDF_approval_id,
	tap.company_id,
	tap.profit_ctr_id,
	tap.status,
	tap.record_type,
	tap.sequence_id,
	tap.bill_unit_code,
	tap.bill_rate,
	tap.date_added,
	tap.date_modified
from TSDFApproval ta
join TSDFApprovalPrice tap
	on tap.tsdf_approval_id = ta.tsdf_approval_id
where coalesce(ta.labpack_template_flag,'F') = 'T'
and (ta.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or ta.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	or tap.date_added > coalesce(@last_sync_dt,'01/01/2000')
	or tap.date_modified > coalesce(@last_sync_dt,'01/01/2000')
	)
go

grant execute on sp_labpack_sync_get_tsdfapprovaltemplateprice to eqai
go
