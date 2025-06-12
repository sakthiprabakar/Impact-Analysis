create procedure [dbo].[sp_labpack_sync_get_workorderwastecode]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderWasteCode details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	wwc.workorder_id,
	wwc.company_id,
	wwc.profit_ctr_id,
	wwc.workorder_sequence_id,
	wwc.waste_code,
	wwc.sequence_id,
	wwc.waste_code_uid,
	wwc.date_added
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderWasteCode wwc
	on wwc.workorder_id = wh.workorder_id
	and wwc.company_id = wh.company_id
	and wwc.profit_ctr_id = wh.profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id