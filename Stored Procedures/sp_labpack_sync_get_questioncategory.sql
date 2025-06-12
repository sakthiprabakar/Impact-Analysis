create procedure [dbo].[sp_labpack_sync_get_questioncategory]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the QuestionCategory details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted


select question_category_id,
		category_desc,
		category_status,
		date_added,
		date_modified
from QuestionCategory