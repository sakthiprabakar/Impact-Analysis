create procedure [dbo].[sp_labpack_sync_get_tripquestion]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TripQuestion details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select tq.workorder_id,
		tq.company_id,
		tq.profit_ctr_id,
		tq.question_sequence_id,
		tq.question_id,
		tq.question_category_id,
		tq.answer_type_id,
		tq.question_text,
		tq.print_on_ltl_ind,
		tq.date_added,120,
		tq.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join TripQuestion tq
	on tq.workorder_id = wh.workorder_id
	and tq.company_id = wh.company_id
	and tq.profit_ctr_id = wh.profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id