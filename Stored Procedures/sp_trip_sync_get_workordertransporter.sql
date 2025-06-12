
create procedure sp_trip_sync_get_workordertransporter
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderTransporter table on a trip local database

 loads to Plt_ai
 
 02/03/2011 - rb created
 03/10/2011 - rb need to include manifest in where clause, multiple manifests pulls duplicates
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct 'if not exists (select 1 from WorkOrderTransporter where workorder_id = ' + convert(varchar(20),WorkOrderDetail.workorder_id) + ' and company_id = ' + convert(varchar(20),WorkOrderDetail.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderDetail.profit_ctr_id) + ' and manifest = ''' + WorkOrderDetail.manifest + '''' + ' and transporter_sequence_id = ' + convert(varchar(20),WorkOrderTransporter.transporter_sequence_id)
+ ') insert into WorkOrderTransporter values('
+ isnull(convert(varchar(20),WorkOrderTransporter.company_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderTransporter.profit_ctr_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderTransporter.workorder_id),'null') + ','
+ isnull('''' + replace(WorkOrderTransporter.manifest, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderTransporter.transporter_sequence_id),'null') + ','
+ isnull('''' + replace(WorkOrderTransporter.transporter_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderTransporter.transporter_sign_name, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderTransporter.transporter_sign_date,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderTransporter.transporter_license_nbr, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderTransporter.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderTransporter.date_added,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderTransporter.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderTransporter.date_modified,120) + '''','null') + ')' as sql
from WorkOrderTransporter, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderTransporter.workorder_id = WorkOrderDetail.workorder_id
and WorkOrderTransporter.company_id = WorkOrderDetail.company_id
and WorkOrderTransporter.profit_ctr_id = WorkOrderDetail.profit_ctr_id
and WorkOrderTransporter.manifest = WorkOrderDetail.manifest
and WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderTransporter.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workordertransporter] TO [EQAI]
    AS [dbo];

