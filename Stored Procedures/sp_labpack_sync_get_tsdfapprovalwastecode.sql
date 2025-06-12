create procedure [dbo].[sp_labpack_sync_get_tsdfapprovalwastecode]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalWasteCode details

 loads to Plt_ai
 
 11/04/2019 - rb created

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
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and wd.resource_type = 'D'
join TSDF t
	on t.TSDF_code = wd.TSDF_code
	and isnull(t.eq_flag,'F') = 'F'
join TSDFApprovalWasteCode tawc
	on tawc.TSDF_approval_id = wd.TSDF_approval_id
where tcl.trip_connect_log_id = @trip_connect_log_id