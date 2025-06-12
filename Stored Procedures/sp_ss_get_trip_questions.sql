if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_questions')
	drop procedure sp_ss_get_trip_questions
go

create procedure sp_ss_get_trip_questions
	@trip_id int,
	@trip_sequence_id int = 0
as
set transaction isolation level read uncommitted

select wh.workorder_ID,
		wh.company_id,
		wh.profit_ctr_ID,
		tq.question_sequence_id,
		tq.question_id,
		tq.answer_type_id,
		coalesce(tq.question_text,'') question_text,
		coalesce(tq.print_on_ltl_ind,'') print_on_ltl_ind
from TripHeader th
join WorkOrderHeader wh
	on wh.trip_id = th.trip_id
--	and wh.workorder_status <> 'V'
join TripQuestion tq
	on tq.workorder_id = wh.workorder_ID
	and tq.company_id = wh.company_id
	and tq.profit_ctr_id = wh.profit_ctr_ID
where th.trip_id = @trip_id
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wh.trip_sequence_id, tq.question_sequence_id
go

grant execute on sp_ss_get_trip_questions to EQAI, TRIPSERV
go
