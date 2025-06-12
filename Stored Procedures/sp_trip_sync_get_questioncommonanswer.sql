
create procedure sp_trip_sync_get_questioncommonanswer
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the QuestionCommonAnswer table

 loads to Plt_ai
 
 05/07/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 07/28/2015 - rb added check for Refresh stop
****************************************************************************************/

select 'delete from QuestionCommonAnswer where question_id = ' + convert(varchar(20),QuestionCommonAnswer.question_id) + ' and sequence_id = ' + convert(varchar(20),QuestionCommonAnswer.sequence_id)
+ ' insert into QuestionCommonAnswer values('
+ convert(varchar(20),QuestionCommonAnswer.question_id) + ','
+ convert(varchar(20),QuestionCommonAnswer.sequence_id) + ','
+ '''' + replace(QuestionCommonAnswer.answer_text, '''', '''''') + '''' + ','
+ '''' + replace(QuestionCommonAnswer.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),QuestionCommonAnswer.date_added,120) + '''' + ','
+ '''' + replace(QuestionCommonAnswer.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),QuestionCommonAnswer.date_modified,120) + '''' + ')' as sql
from QuestionCommonAnswer, TripQuestion, WorkOrderHeader, TripConnectLog
where QuestionCommonAnswer.question_id = TripQuestion.question_id
and TripQuestion.workorder_id = WorkOrderHeader.workorder_id
and TripQuestion.company_id = WorkOrderHeader.company_id
and TripQuestion.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (QuestionCommonAnswer.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_questioncommonanswer] TO [EQAI]
    AS [dbo];

