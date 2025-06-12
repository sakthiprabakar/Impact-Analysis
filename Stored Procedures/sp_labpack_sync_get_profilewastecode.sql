create procedure [dbo].[sp_labpack_sync_get_profilewastecode]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ProfileWasteCode details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pwc.profile_id,
	pwc.primary_flag,
	pwc.waste_code,
	pwc.sequence_id,
	pwc.waste_code_uid,
	pwc.sequence_flag,
	pwc.date_added
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join ProfileWasteCode pwc
	on pwc.profile_id = wd.profile_id
where tcl.trip_connect_log_id = @trip_connect_log_id