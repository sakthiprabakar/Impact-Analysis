create procedure [dbo].[sp_labpack_sync_get_tsdfapprovalconstituent]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalConstituent details

 loads to Plt_ai
 
 11/04/2019 - rb created

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
join TSDFApprovalConstituent tac
	on tac.TSDF_approval_id = wd.TSDF_approval_id
where tcl.trip_connect_log_id = @trip_connect_log_id
