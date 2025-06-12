create procedure [dbo].[sp_labpack_sync_get_workorderheader]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderHeader details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select wh.workorder_ID,
		wh.company_id,
		wh.profit_ctr_ID,
		wh.workorder_status,
		wh.workorder_type,
		wh.customer_ID,
		wh.generator_id,
		wh.description,
		wh.start_date,
		wh.end_date,
		wh.comments,
		wh.trip_id,
		wh.trip_sequence_id,
		wh.trip_eq_comment,
		wh.tractor_trailer_number,
		wh.ltl_title_comment,
		wh.trip_stop_rate_flag,
		wh.generator_sublocation_ID,
		wh.offschedule_service_flag,
		wh.date_added,
		wh.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
where tcl.trip_connect_log_id = @trip_connect_log_id