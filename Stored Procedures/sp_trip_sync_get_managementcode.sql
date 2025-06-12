
create procedure sp_trip_sync_get_managementcode
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ManagementCode table on a trip local database

 loads to Plt_ai
 
 08/15/2012 - rb created for Version 3.0 LabPack
 03/14/2013 - rb new status column added, only pull active management codes
****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'truncate table ManagementCode' as sql
where @last_download_date is null
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)
union
select 'insert into ManagementCode values('
+ '''' + replace(ManagementCode.management_code, '''', '''''') + '''' + ','
+ isnull('''' + replace(ManagementCode.management_description, '''', '''''') + '''','null') + ')' as sql
from ManagementCode
where (@last_download_date is null
	or exists (select 1 from TripConnectLog tcl
			join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
					and wh.field_requested_action = 'R'
			where tcl.trip_connect_log_id = @trip_connect_log_id))
and status = 'A'
order by sql desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_managementcode] TO [EQAI]
    AS [dbo];

