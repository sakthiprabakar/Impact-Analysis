
create procedure sp_trip_sync_get_disposition
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Disposition table

 loads to Plt_ai
 
 02/09/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
****************************************************************************************/

declare @last_download_date datetime

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'delete from Disposition where disposition_id = ' + convert(varchar(20), Disposition.disposition_id)
+ ' insert into Disposition values('
+ convert(varchar(20),Disposition.disposition_id) + ','
+ '''' + replace(Disposition.disposition_desc, '''', '''''') + '''' + ','
+ '''' + replace(Disposition.type_code, '''', '''''') + '''' + ','
+ isnull(convert(varchar(20),Disposition.customer_id),'null') + ','
+ isnull('''' + replace(Disposition.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Disposition.date_added,120) + '''','null') + ','
+ isnull('''' + replace(Disposition.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Disposition.date_modified,120) + '''','null') + ')' as sql
from Disposition
where date_modified > isnull(@last_download_date,'01/01/1900')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_disposition] TO [EQAI]
    AS [dbo];

