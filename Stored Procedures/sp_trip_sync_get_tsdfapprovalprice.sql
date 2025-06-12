
create procedure sp_trip_sync_get_tsdfapprovalprice
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDFApprovalPrice table on a trip local database

 loads to Plt_ai
 
 03/17/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
****************************************************************************************/

select 'delete from TSDFApprovalPrice where TSDF_approval_id = ' + convert(varchar(10),TSDFApprovalPrice.TSDF_approval_id)
+ ' insert into TSDFApprovalPrice values('
+ convert(varchar(20),TSDFApprovalPrice.TSDF_approval_id) + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.company_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.profit_ctr_id),'null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.record_type, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.sequence_id),'null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.price),'null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.cost),'null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.customer_cost),'null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.bill_rate),'null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.primary_price_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.resource_class_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApprovalPrice.product_id),'null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.product_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.bill_method, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApprovalPrice.date_added,120) + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApprovalPrice.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.price_increase_2005, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalPrice.price_increase_2006, '''', '''''') + '''','null') + ','
+ ''' ''' + ')' as sql
from TSDFApprovalPrice, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where TSDFApprovalPrice.TSDF_approval_id = WorkOrderDetail.TSDF_approval_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	TSDFApprovalPrice.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900'))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdfapprovalprice] TO [EQAI]
    AS [dbo];

