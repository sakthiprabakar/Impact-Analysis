
create procedure sp_trip_sync_get_questioncategory
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the BillUnit table

 loads to Plt_ai
 
 03/17/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then inser
****************************************************************************************/

declare @last_download_date datetime

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'delete from QuestionCategory where question_category_id = ' + convert(varchar(20),QuestionCategory.question_category_id)
+ ' insert into QuestionCategory values('
+ convert(varchar(20),QuestionCategory.question_category_id) + ','
+ '''' + replace(QuestionCategory.category_desc, '''', '''''') + '''' + ','
+ '''' + replace(QuestionCategory.category_status, '''', '''''') + '''' + ','
+ '''' + replace(QuestionCategory.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),QuestionCategory.date_added,120) + '''' + ','
+ '''' + replace(QuestionCategory.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),QuestionCategory.date_modified,120) + '''' + ')' as sql
from QuestionCategory
where date_modified > isnull(@last_download_date,'01/01/1900')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_questioncategory] TO [EQAI]
    AS [dbo];

