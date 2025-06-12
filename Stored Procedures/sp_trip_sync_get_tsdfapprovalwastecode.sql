
create procedure sp_trip_sync_get_tsdfapprovalwastecode
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDFApprovalWasteCode table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
 08/15/2012 - rb Version 3.0, LabPack - local db had modified_by and date_modified added.
		 Also added what was done for ProfileWasteCodes, delete existing on first trip download
 04/17/2013 - rb Waste Code conversion...added waste_code_uid for version 3.06 forward
 07/15/2013 - rb Waste Code conversion Phase II...support for new display/status columns
 08/27/2015 - rb Prevent deletion of Labpack-added waste codes
****************************************************************************************/

declare @last_download_date datetime,
	@lab_pack_flag char(1),
	@s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set transaction isolation level read uncommitted

select @last_download_date = tcl.last_download_date,
		@lab_pack_flag = isnull(t.lab_pack_flag,'F'),
		@s_version = tcca.client_app_version
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

if @lab_pack_flag = 'T' and @last_download_date is not null
	select '' as sql
else
	select distinct 'delete TSDFApprovalWasteCode where tsdf_approval_id = ' + convert(varchar(20),WorkOrderDetail.tsdf_approval_id) as sql
	from WorkOrderDetail
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'') <> 'T'
	join WorkOrderHeader
		on WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
		and WorkOrderDetail.company_id = WorkOrderHeader.company_id
		and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
		and WorkOrderHeader.field_upload_date is null
		and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	join TripConnectLog
		on WorkOrderHeader.trip_id = TripConnectLog.trip_id
		and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	where WorkOrderDetail.resource_type = 'D'
	and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
	union
	select distinct 'insert TSDFApprovalWasteCode values('
	+ convert(varchar(20),TSDFApprovalWasteCode.TSDF_approval_id) + ','
	+ isnull(convert(varchar(20),TSDFApprovalWasteCode.company_id),'null') + ','
	+ isnull(convert(varchar(20),TSDFApprovalWasteCode.profit_ctr_id),'null') + ','
	+ '''' + replace(TSDFApprovalWasteCode.primary_flag, '''', '''''') + '''' + ','
	+ '''' + replace(TSDFApprovalWasteCode.waste_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TSDFApprovalWasteCode.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TSDFApprovalWasteCode.date_added,120) + '''','null') + ','
	+ '''' + replace(TSDFApprovalWasteCode.rowguid, '''', '''''') + '''' + ','
	+ isnull(convert(varchar(20),TSDFApprovalWasteCode.sequence_id),'null')
	+ case when @version < 3.0 then '' else ',null,null' end
	+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),TSDFApprovalWasteCode.waste_code_uid),'null') end
	+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(TSDFApprovalWasteCode.sequence_flag, '''', '''''') + '''','null') end
	+ ')' as sql
	from TSDFApprovalWasteCode
	join WorkOrderDetail
		on TSDFApprovalWasteCode.tsdf_approval_id = WorkOrderDetail.tsdf_approval_id
		and WorkOrderDetail.resource_type = 'D'
		and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'') <> 'T'
	join WorkOrderHeader
		on WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
		and WorkOrderDetail.company_id = WorkOrderHeader.company_id
		and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
		and WorkOrderHeader.field_upload_date is null
		and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	join TripConnectLog
		on WorkOrderHeader.trip_id = TripConnectLog.trip_id
		and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	order by sql

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdfapprovalwastecode] TO [EQAI]
    AS [dbo];

