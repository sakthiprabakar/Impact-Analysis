create procedure [dbo].[sp_labpack_sync_get_tsdfapprovalprice]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TSDFApprovalPrice details

 loads to Plt_ai
 
 11/04/2019 - rb created

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
join TSDFApprovalPrice tap
	on tap.TSDF_approval_id = wd.TSDF_approval_id
where tcl.trip_connect_log_id = @trip_connect_log_id