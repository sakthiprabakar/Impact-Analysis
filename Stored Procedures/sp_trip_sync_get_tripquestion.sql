
create procedure sp_trip_sync_get_tripquestion
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the BillUnit table

 loads to Plt_ai
 
 03/17/2009 - rb created
 05/04/2010 - rb need to generate update statements on ltl_pickup_ind when date_added
              is less than last_download_date but date_modified is greater than it
****************************************************************************************/

select 'if not exists (select 1 from TripQuestion where workorder_id = ' + convert(varchar(20),TripQuestion.workorder_id) + ' and company_id = ' + convert(varchar(20),TripQuestion.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),TripQuestion.profit_ctr_id)  + ' and question_sequence_id = ' + convert(varchar(20),TripQuestion.question_sequence_id)
+ ') insert into TripQuestion values('
+ convert(varchar(20),TripQuestion.workorder_id) + ','
+ convert(varchar(20),TripQuestion.company_id) + ','
+ convert(varchar(20),TripQuestion.profit_ctr_id) + ','
+ convert(varchar(20),TripQuestion.question_sequence_id) + ','
+ isnull(convert(varchar(20),TripQuestion.question_id),'null') + ','
+ isnull(convert(varchar(20),TripQuestion.question_category_id),'null') + ','
+ convert(varchar(20),TripQuestion.answer_type_id) + ','
+ '''' + replace(TripQuestion.question_text, '''', '''''') + '''' + ','
+ isnull('''' + replace(TripQuestion.answer_text, '''', '''''') + '''','null') + ','
+ '''' + replace(TripQuestion.view_on_web_flag, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),TripQuestion.date_added,120) + '''' + ','
+ '''' + replace(TripQuestion.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),TripQuestion.date_modified,120) + '''' + ','
+ '''' + replace(TripQuestion.modified_by, '''', '''''') + '''' + ','
+ isnull(convert(varchar(20),TripQuestion.print_on_ltl_ind),'null') + ')' as sql
 from TripQuestion, WorkOrderHeader, TripConnectLog
where TripQuestion.workorder_id = WorkOrderHeader.workorder_id
and TripQuestion.company_id = WorkOrderHeader.company_id
and TripQuestion.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (TripQuestion.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	 WorkOrderHeader.field_requested_action = 'R')
union
select 'update TripQuestion set print_on_ltl_ind = '
+ isnull(convert(varchar(20),TripQuestion.print_on_ltl_ind),'null')
+ ', date_modified = ''' + convert(varchar(20),TripQuestion.date_modified,120) + ''''
+ ' where workorder_id = ' + convert(varchar(20),TripQuestion.workorder_id)
+ ' and company_id = ' + convert(varchar(20),TripQuestion.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),TripQuestion.profit_ctr_id) 
+ ' and question_sequence_id = ' + convert(varchar(20),TripQuestion.question_sequence_id) as sql
from TripQuestion, WorkOrderHeader, TripConnectLog
where TripQuestion.workorder_id = WorkOrderHeader.workorder_id
and TripQuestion.company_id = WorkOrderHeader.company_id
and TripQuestion.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and TripQuestion.date_added < isnull(TripConnectLog.last_download_date,'01/01/1900')
and TripQuestion.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tripquestion] TO [EQAI]
    AS [dbo];

