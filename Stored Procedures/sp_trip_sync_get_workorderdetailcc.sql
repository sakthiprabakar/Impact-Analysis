
create procedure sp_trip_sync_get_workorderdetailcc
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderDetailCC table on a trip local database

 loads to Plt_ai
 
 06/16/2009 - rb created
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance
 09/25/2015 - rb added container type and size
 10/23/2017 - mm Added two unions for GEM 45037 (CCIDs not available in Print Labels on a replacement stop).

****************************************************************************************/

declare @s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set transaction isolation level read uncommitted

select @s_version = tcca.client_app_version
from TripConnectLog tcl
join TripHeader t
	on tcl.trip_id = t.trip_id
join TripConnectClientApp tcca
	on tcl.trip_client_app_id = tcca.trip_client_app_id
where tcl.trip_connect_log_id = @trip_connect_log_id

select @dot = CHARINDEX('.',@s_version)
if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)

select 'if not exists (select 1 from WorkOrderDetailCC where workorder_id = ' + convert(varchar(20), WorkOrderDetailCC.workorder_id) + ' and company_id = ' + convert(varchar(20), WorkOrderDetailCC.company_id) + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderDetailCC.profit_ctr_id) + ' and sequence_id = ' + convert(varchar(20), WorkOrderDetailCC.sequence_id) + ' and consolidated_container_id = ' + convert(varchar(20),WorkOrderDetailCC.consolidated_container_id)
+ ') insert into WorkOrderDetailCC values('
+ convert(varchar(20),WorkOrderDetailCC.workorder_id) + ','
+ convert(varchar(20),WorkOrderDetailCC.company_id) + ','
+ convert(varchar(20),WorkOrderDetailCC.profit_ctr_id) + ','
+ convert(varchar(20),WorkOrderDetailCC.sequence_id) + ','
+ convert(varchar(20),WorkOrderDetailCC.consolidated_container_id) + ','
+ convert(varchar(20),WorkOrderDetailCC.percentage) + ','
+ isnull('''' + replace(WorkOrderDetailCC.added_by, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(WorkOrderDetailCC.modified_by, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + convert(varchar(20),WorkOrderDetailCC.destination_container_id) + '''','null')
+ case when @version < 4.26 then '' else ',' + isnull('''' + replace(WorkOrderDetailCC.container_type, '''', '''''') + '''','null') end
+ case when @version < 4.26 then '' else ',' + isnull('''' + replace(WorkOrderDetailCC.container_size, '''', '''''') + '''','null') end
+ ')' as sql
from WorkOrderDetailCC, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetailCC.workorder_id = WorkOrderDetail.workorder_id
and WorkOrderDetailCC.company_id = WorkOrderDetail.company_id
and WorkOrderDetailCC.profit_ctr_id = WorkOrderDetail.profit_ctr_id
and WorkOrderDetailCC.sequence_id = WorkOrderDetail.sequence_id
and WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetailCC.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')
union
select 'delete WorkOrderDetailCC where workorder_id = ' + convert(varchar(20), WorkOrderDetail.workorder_id) + ' and company_id = ' + convert(varchar(20), WorkOrderDetail.company_id) + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderDetail.profit_ctr_id) + ' and sequence_id = ' + convert(varchar(20), WorkOrderDetail.sequence_id)
from WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.bill_rate,0) = -2
and WorkOrderHeader.field_upload_date is null
union
select distinct 'delete WorkOrderDetailCC where workorder_id = ' + convert(varchar(20), WorkOrderHeader.workorder_id) + ' and company_id = ' + convert(varchar(20), WorkOrderHeader.company_id) + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderHeader.profit_ctr_id) 
from WorkOrderHeader, TripConnectLog
where WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.workorder_status,'') = 'V'
and WorkOrderHeader.field_upload_date is null

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderdetailcc] TO [EQAI]
    AS [dbo];

