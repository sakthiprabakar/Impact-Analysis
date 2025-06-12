
create procedure sp_trip_sync_get_dosagetype
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the DosageType table on a trip local database

 loads to Plt_ai
 
 08/15/2012 - rb created for Version 3.0 LabPack
****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'delete DosageType where dosage_type_id=' + convert(varchar(10),DosageType.dosage_type_id)
+ ' insert DosageType values (' + convert(varchar(10),DosageType.dosage_type_id) + ','
+ isnull('''' + replace(DosageType.description, '''', '''''') + '''','null') + ',' 
+ isnull('''' + replace(DosageType.status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DosageType.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),DosageType.date_added,120) + '''','null') + ','
+ isnull('''' + replace(DosageType.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),DosageType.date_modified,120) + '''','null') + ')' as sql
from DosageType
where DosageType.date_modified > isnull(@last_download_date,'01/01/1900')
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_dosagetype] TO [EQAI]
    AS [dbo];

