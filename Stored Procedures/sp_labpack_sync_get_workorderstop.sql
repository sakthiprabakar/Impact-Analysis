create procedure [dbo].[sp_labpack_sync_get_workorderstop]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderStop details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select ws.workorder_id,
		ws.company_id,
		ws.profit_ctr_id,
		ws.stop_sequence_id,
		ws.schedule_contact,
		ws.schedule_contact_title,
		ws.date_est_arrive,
		ws.date_est_depart,
		ws.date_added,
		ws.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderStop ws
	on ws.workorder_id = wh.workorder_id
	and ws.company_id = wh.company_id
	and ws.profit_ctr_id = wh.profit_ctr_id
	and ws.stop_sequence_id = 1
where tcl.trip_connect_log_id = @trip_connect_log_id