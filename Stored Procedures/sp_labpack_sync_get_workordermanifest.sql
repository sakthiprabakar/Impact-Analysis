create procedure [dbo].[sp_labpack_sync_get_workordermanifest]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderManifest details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted
						
select wm.workorder_ID,
		wm.company_id,
		wm.profit_ctr_ID,
		wm.manifest,
		wm.manifest_flag,
		wm.manifest_state,
		wm.date_added,
		wm.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderManifest wm
	on wm.workorder_id = wh.workorder_id
	and wm.company_id = wh.company_id
	and wm.profit_ctr_id = wh.profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id