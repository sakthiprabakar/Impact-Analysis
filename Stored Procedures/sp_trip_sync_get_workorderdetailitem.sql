
create procedure sp_trip_sync_get_workorderdetailitem
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderDetailItem table on a trip local database

 loads to Plt_ai
 
 03/19/2010 - rb created
 04/01/2010 - rb new columns added, form_group, contents, percentage, DEA_schedule
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 03/01/2012 - rb Added dea_form_222_number column, to collect numbers as they're printed
 08/15/2012 - rb Version 3.0 LabPack, added dosage_type_id and constituent related fields
****************************************************************************************/

declare @s_version varchar(10),
		@dot int,
		@version numeric(6,2)

set transaction isolation level read uncommitted

select @s_version = tcca.client_app_version
from TripConnectLog tcl, TripConnectClientApp tcca
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_client_app_id = tcca.trip_client_app_id

select @dot = CHARINDEX('.',@s_version)
if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)


select 'if not exists (select 1 from WorkOrderDetailItem where workorder_id = ' + convert(varchar(20), WorkOrderDetailItem.workorder_id) + ' and company_id = ' + convert(varchar(20), WorkOrderDetailItem.company_id) + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderDetailItem.profit_ctr_id) + ' and sequence_id = ' + convert(varchar(20), WorkOrderDetailItem.sequence_id) + ' and sub_sequence_id = ' + convert(varchar(20),WorkOrderDetailItem.sub_sequence_id)
+ ') insert into WorkOrderDetailItem values('
+ convert(varchar(20),WorkOrderDetailItem.workorder_id) + ','
+ convert(varchar(20),WorkOrderDetailItem.company_id) + ','
+ convert(varchar(20),WorkOrderDetailItem.profit_ctr_id) + ','
+ convert(varchar(20),WorkOrderDetailItem.sequence_id) + ','
+ convert(varchar(20),WorkOrderDetailItem.sub_sequence_id) + ','
+ '''' + replace(WorkOrderDetailItem.item_type_ind, '''', '''''') + '''' + ','
+ convert(varchar(20),WorkOrderDetailItem.month) + ','
+ convert(varchar(20),WorkOrderDetailItem.year) + ','
+ isnull(convert(varchar(20),WorkOrderDetailItem.pounds),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetailItem.ounces),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetailItem.merchandise_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetailItem.merchandise_quantity),'null') + ','
+ isnull('''' + replace(WorkOrderDetailItem.merchandise_code_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetailItem.merchandise_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetailItem.manual_entry_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetailItem.note, '''', '''''') + '''','null') + ','
+ '''' + replace(WorkOrderDetailItem.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),dateadd(yy,-2,WorkOrderDetailItem.date_added),120) + '''' + ','
+ '''' + replace(WorkOrderDetailItem.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),dateadd(yy,-2,WorkOrderDetailItem.date_modified),120) + ''''
+ case when @version < 2.02 then ''
	else ',' + isnull(convert(varchar(20),WorkOrderDetailItem.form_group),'null') + ','
		+ isnull('''' + replace(WorkOrderDetailItem.contents, '''', '''''') + '''','null') + ','
		+ isnull(convert(varchar(20),WorkOrderDetailItem.percentage),'null') + ','
		+ isnull('''' + replace(WorkOrderDetailItem.DEA_schedule, '''', '''''') + '''','null') end
+ case when @version < 2.29 then '' else ',' + isnull('''' + replace(WorkOrderDetailItem.dea_form_222_number, '''', '''''') + '''','null') end
+ case when @version < 3.0 then ''
	else ',' + isnull(convert(varchar(20),WorkOrderDetailItem.dosage_type_id),'null') + ','
		+ isnull(convert(varchar(20),WorkOrderDetailItem.parent_sub_sequence_id),'null') + ','
		+ isnull(convert(varchar(20),WorkOrderDetailItem.const_id),'null') + ','
		+ isnull(convert(varchar(20),WorkOrderDetailItem.const_percent),'null') + ','
		+ isnull('''' + replace(WorkOrderDetailItem.const_uhc, '''', '''''') + '''','null') end
+ ')' as sql
from WorkOrderDetailItem, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetailItem.workorder_id = WorkOrderDetail.workorder_id
and WorkOrderDetailItem.company_id = WorkOrderDetail.company_id
and WorkOrderDetailItem.profit_ctr_id = WorkOrderDetail.profit_ctr_id
and WorkOrderDetailItem.sequence_id = WorkOrderDetail.sequence_id
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
	WorkOrderDetailItem.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderdetailitem] TO [EQAI]
    AS [dbo];

