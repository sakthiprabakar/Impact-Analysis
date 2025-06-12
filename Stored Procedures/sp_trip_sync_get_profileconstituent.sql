
create procedure sp_trip_sync_get_profileconstituent
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileConstituent table on a trip local database

 loads to Plt_ai
 
 08/10/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
****************************************************************************************/

select distinct 'delete from ProfileConstituent where profile_id = ' + convert(varchar(20),ProfileConstituent.profile_id) + ' and const_id = ' + convert(varchar(20),ProfileConstituent.const_id)
+ ' insert into ProfileConstituent values('
+ convert(varchar(20),ProfileConstituent.profile_id) + ','
+ convert(varchar(20),ProfileConstituent.const_id) + ','
+ isnull(convert(varchar(20),ProfileConstituent.concentration),'null') + ','
+ isnull('''' + replace(ProfileConstituent.unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileConstituent.UHC, '''', '''''') + '''','null') + ','
+ '''' + replace(ProfileConstituent.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),ProfileConstituent.date_added,120) + '''' + ','
+ '''' + replace(ProfileConstituent.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),ProfileConstituent.date_modified,120) + '''' + ','
+ '''' + replace(ProfileConstituent.rowguid, '''', '''''') + '''' + ')' as sql
 from ProfileConstituent, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileConstituent.profile_id = WorkOrderDetail.profile_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.tsdf_approval_id is null
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (ProfileConstituent.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	 WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profileconstituent] TO [EQAI]
    AS [dbo];

