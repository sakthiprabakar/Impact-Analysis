
create procedure sp_trip_sync_get_workorderwastecode
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderWasteCode table on a trip local database

 loads to Plt_ai
 
 02/03/2011 - rb created
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 08/15/2012 - rb Version 3.0, LabPack - localdb had modified_by and date_modified added
 10/01/2012 - rb Need to pull entire set down every time bc no date_modified field
		(required for aerosol additional waste_code fix, but not a bad thing to do anyway)
 04/17/2013 - rb Waste Code conversion...added waste_code_uid for version 3.06 forward
 05/07/2014 - rb Labpack users were getting duplicate waste codes if they synchronized
					a stop where they edited waste codes on an existing approval
 08/27/2015 - rb Prevent deletion of Labpack-added waste codes and adding dups (new implementation)
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
	select distinct 'delete ProfileWastecode where profile_id = ' + convert(varchar(10),WorkOrderDetail.profile_id) as sql
	from WorkOrderDetail
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'') = 'T'
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
	and WorkOrderDetail.date_added > @last_download_date
	union
	select distinct 'insert ProfileWasteCode values('
	+ convert(varchar(20),ProfileWasteCode.profile_id) + ','
	+ '''' + replace(ProfileWasteCode.primary_flag, '''', '''''') + '''' + ','
	+ '''' + replace(ProfileWasteCode.waste_code, '''', '''''') + '''' + ','
	+ '''' + replace(ProfileWasteCode.added_by, '''', '''''') + '''' + ','
	+ '''' + convert(varchar(20),ProfileWasteCode.date_added,120) + '''' + ','
	+ '''' + replace(ProfileWasteCode.rowguid, '''', '''''') + '''' + ','
	+ isnull(convert(varchar(20),ProfileWasteCode.sequence_id),'null')
	+ case when @version < 3.0 then '' else ',null,null' end
	+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),ProfileWasteCode.waste_code_uid),'null') end
	+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(ProfileWasteCode.sequence_flag, '''', '''''') + '''','null') end
	+ ')' as sql
	from WorkOrderDetail
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'') = 'T'
	join ProfileWasteCode
		on WorkOrderDetail.profile_id = ProfileWasteCode.profile_id
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
	and WorkOrderDetail.date_added > @last_download_date
	union
	select distinct 'delete TSDFApprovalWasteCode where tsdf_approval_id = ' + convert(varchar(20),WorkOrderDetail.tsdf_approval_id) as sql
	from WorkOrderDetail
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and ISNULL(TSDF.eq_flag,'') <> 'T'
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
	and WorkOrderDetail.date_added > @last_download_date
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
		and WorkOrderDetail.date_added > @last_download_date
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
	union
	select distinct 'insert WorkOrderWasteCode values('
	+ convert(varchar(20),WorkOrderWasteCode.company_id) + ','
	+ convert(varchar(20),WorkOrderWasteCode.profit_ctr_id) + ','
	+ convert(varchar(20),WorkOrderWasteCode.workorder_id) + ','
	+ isnull(convert(varchar(20),WorkOrderWasteCode.workorder_sequence_id),'null') + ','
	+ isnull('''' + replace(WorkOrderWasteCode.waste_code, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),WorkOrderWasteCode.sequence_id),'null') + ','
	+ isnull('''' + replace(WorkOrderWasteCode.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WorkOrderWasteCode.date_added,120) + '''','null')
	+ case when @version < 3.0 then '' else ',null,null' end
	+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),WorkOrderWasteCode.waste_code_uid),'null') end
	+ ')' as sql
	from WorkOrderWasteCode
	join WorkOrderDetail
		on WorkOrderWasteCode.workorder_id = WorkOrderDetail.workorder_id
		and WorkOrderWasteCode.company_id = WorkOrderDetail.company_id
		and WorkOrderWasteCode.profit_ctr_id = WorkOrderDetail.profit_ctr_id
		and WorkOrderWasteCode.workorder_sequence_id = WorkOrderDetail.sequence_id
		and WorkOrderDetail.resource_type = 'D'
		and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
		and WorkOrderDetail.date_added > @last_download_date
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
else
	select distinct 'delete WorkOrderWasteCode where workorder_id = ' + convert(varchar(20),WorkOrderHeader.workorder_id)
	+ ' and company_id = ' + convert(varchar(20),WorkOrderHeader.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderHeader.profit_ctr_id) as sql
	from WorkOrderHeader
	join TripConnectLog
		on WorkOrderHeader.trip_id = TripConnectLog.trip_id
		and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	where WorkOrderHeader.field_upload_date is null
	and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	union
	select distinct 'insert WorkOrderWasteCode values('
	+ convert(varchar(20),WorkOrderWasteCode.company_id) + ','
	+ convert(varchar(20),WorkOrderWasteCode.profit_ctr_id) + ','
	+ convert(varchar(20),WorkOrderWasteCode.workorder_id) + ','
	+ isnull(convert(varchar(20),WorkOrderWasteCode.workorder_sequence_id),'null') + ','
	+ isnull('''' + replace(WorkOrderWasteCode.waste_code, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),WorkOrderWasteCode.sequence_id),'null') + ','
	+ isnull('''' + replace(WorkOrderWasteCode.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WorkOrderWasteCode.date_added,120) + '''','null')
	+ case when @version < 3.0 then '' else ',null,null' end
	+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),WorkOrderWasteCode.waste_code_uid),'null') end
	+ ')' as sql
	from WorkOrderWasteCode
	join WorkOrderDetail
		on WorkOrderWasteCode.workorder_id = WorkOrderDetail.workorder_id
		and WorkOrderWasteCode.company_id = WorkOrderDetail.company_id
		and WorkOrderWasteCode.profit_ctr_id = WorkOrderDetail.profit_ctr_id
		and WorkOrderWasteCode.workorder_sequence_id = WorkOrderDetail.sequence_id
		and WorkOrderDetail.resource_type = 'D'
		and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
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
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderwastecode] TO [EQAI]
    AS [dbo];

