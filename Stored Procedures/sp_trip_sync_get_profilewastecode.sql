
create procedure sp_trip_sync_get_profilewastecode
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileWasteCode table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
 10/13/2010 - rb on first download of trip, purge waste codes from ProfileWasteCode table
 08/15/2012 - rb Version 3.0, LabPack - localdb had modified_by and date_modified added
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
	select distinct 'delete ProfileWasteCode where profile_id = ' + convert(varchar(20),WorkOrderDetail.profile_id) as sql
	from WorkOrderDetail
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and ISNULL(TSDF.eq_flag,'') = 'T'
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
	from ProfileWasteCode
	join WorkOrderDetail
		on ProfileWasteCode.profile_id = WorkOrderDetail.profile_id
		and WorkOrderDetail.resource_type = 'D'
		and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
	join TSDF
		on WorkOrderDetail.TSDF_code = TSDF.TSDF_code
		and ISNULL(TSDF.eq_flag,'') = 'T'
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
    ON OBJECT::[dbo].[sp_trip_sync_get_profilewastecode] TO [EQAI]
    AS [dbo];

