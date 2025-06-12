
create procedure sp_trip_sync_get_tsdfapprovalconstituent
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDFApprovalConstituent table on a trip local database

 loads to Plt_ai
 
 08/10/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
 08/27/2012 - rb added join to TSDF to reference eq_flag
****************************************************************************************/

set transaction isolation level read uncommitted

select 'delete from TSDFApprovalConstituent where tsdf_approval_id = ' + convert(varchar(20),TSDFApprovalConstituent.tsdf_approval_id) + ' and company_id = ' + convert(varchar(20),TSDFApprovalConstituent.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),TSDFApprovalConstituent.profit_ctr_id) + ' and const_id = ' + convert(varchar(20),TSDFApprovalConstituent.const_id)
+ ' insert into TSDFApprovalConstituent values('
+ convert(varchar(20),TSDFApprovalConstituent.TSDF_approval_id) + ','
+ isnull(convert(varchar(20),TSDFApprovalConstituent.company_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApprovalConstituent.profit_ctr_id),'null') + ','
+ convert(varchar(20),TSDFApprovalConstituent.const_id) + ','
+ isnull(convert(varchar(20),TSDFApprovalConstituent.concentration),'null') + ','
+ isnull('''' + replace(TSDFApprovalConstituent.unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalConstituent.UHC, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalConstituent.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApprovalConstituent.date_added,120) + '''','null') + ','
+ isnull('''' + replace(TSDFApprovalConstituent.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApprovalConstituent.date_modified,120) + '''','null') + ','
+ '''' + replace(TSDFApprovalConstituent.rowguid, '''', '''''') + '''' + ')' as sql
 from TSDFApprovalConstituent, WorkOrderDetail, TSDF, WorkOrderHeader, TripConnectLog
where TSDFApprovalConstituent.tsdf_approval_id = WorkOrderDetail.tsdf_approval_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.tsdf_code = TSDF.tsdf_code
and TSDF.eq_flag = 'F'
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and WorkOrderHeader.field_upload_date is null
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	TSDFApprovalConstituent.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdfapprovalconstituent] TO [EQAI]
    AS [dbo];

