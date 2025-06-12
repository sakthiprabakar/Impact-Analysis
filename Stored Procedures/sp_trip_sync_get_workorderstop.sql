
create procedure sp_trip_sync_get_workorderstop
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderTransporter table on a trip local database

 loads to Plt_ai
 
 02/03/2011 - rb created
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance
****************************************************************************************/

set transaction isolation level read uncommitted

select distinct 'if not exists (select 1 from WorkOrderStop where workorder_id = ' + convert(varchar(20),WorkOrderHeader.workorder_id) + ' and company_id = ' + convert(varchar(20),WorkOrderHeader.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderHeader.profit_ctr_id) + ' and stop_sequence_id = ' + convert(varchar(20),WorkOrderStop.stop_sequence_id)
+ ') insert into WorkOrderStop values('
+ convert(varchar(20),WorkOrderStop.workorder_id) + ','
+ convert(varchar(20),WorkOrderStop.company_id) + ','
+ convert(varchar(20),WorkOrderStop.profit_ctr_id) + ','
+ convert(varchar(20),WorkOrderStop.stop_sequence_id) + ','
+ isnull('''' + replace(WorkOrderStop.station_id, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderStop.est_time_amt),'null') + ','
+ isnull('''' + replace(WorkOrderStop.est_time_unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.schedule_contact, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.schedule_contact_title, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.pickup_contact, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.pickup_contact_title, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.confirmation_date,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.waste_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderStop.decline_id),'null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_est_arrive,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_est_depart,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_act_arrive,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_act_depart,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_added,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderStop.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderStop.date_modified,120) + '''','null') + ')' as sql
from WorkOrderStop, WorkOrderHeader, TripConnectLog
where WorkOrderStop.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderStop.company_id = WorkOrderHeader.company_id
and WorkOrderStop.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderStop.stop_sequence_id = 1
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderStop.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderstop] TO [EQAI]
    AS [dbo];

