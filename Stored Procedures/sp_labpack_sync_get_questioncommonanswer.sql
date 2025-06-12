create procedure [dbo].[sp_labpack_sync_get_questioncommonanswer]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the QuestionCategory details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	qca.question_id,
	qca.sequence_id,
	qca.answer_text,
	qca.date_added,
	qca.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join TripQuestion tq
	on tq.workorder_id = wh.workorder_id
	and tq.company_id = wh.company_id
	and tq.profit_ctr_id = wh.profit_ctr_id
join QuestionCommonAnswer qca
	on qca.question_id = tq.question_id
where tcl.trip_connect_log_id = @trip_connect_log_id