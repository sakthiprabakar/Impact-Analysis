
create procedure sp_trip_sync_get_manifestcodelookup
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ManifestCodeLookup table on a trip local database

 loads to Plt_ai
 
 08/15/2012 - rb created for Version 3.0 LabPack
****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'truncate table ManifestCodeLookup' as sql
where @last_download_date is null
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)
union
select 'insert into ManifestCodeLookup values('
+ '''' + replace(ManifestCodeLookup.manifest_item, '''', '''''') + '''' + ','
+ '''' + replace(ManifestCodeLookup.manifest_code, '''', '''''') + '''' + ','
+ isnull('''' + replace(ManifestCodeLookup.manifest_desc, '''', '''''') + '''','null') + ')' as sql
from ManifestCodeLookup
where manifest_item in ('erg', 'hazmat_class') 
and @last_download_date is null
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)
order by sql desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_manifestcodelookup] TO [EQAI]
    AS [dbo];

