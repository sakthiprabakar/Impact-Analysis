
create procedure sp_trip_sync_get_profilexmerchandisecategory
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileXMerchandiseCategory table on a trip local database

 loads to Plt_ai
 
 03/29/2010 - rb created
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
 05/06/2010 - rb compare modified_date to new TripConnectLog last_merchandise_download_date column
 08/18/2011 - rb Serial number, incremental merchandise download
 10/21/2011 - rb Remove requirement that upload_merchandise_ind be set in order to download DEA
 02/06/2012 - rb Ignore when WorkOrder/Trip screens set Refresh on Field Device
 02/29/2012 - rb Refresh this table every sync, because categories can be removed from Profiles
****************************************************************************************/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

select distinct 'delete ProfileXMerchandiseCategory where profile_id = ' + convert(varchar(10),ProfileXMerchandiseCategory.profile_id) as sql
from ProfileXMerchandiseCategory, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileXMerchandiseCategory.profile_id = WorkOrderDetail.profile_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'

union

select distinct 'insert into ProfileXMerchandiseCategory values('
+ convert(varchar(20),ProfileXMerchandiseCategory.profile_id) + ','
+ convert(varchar(20),ProfileXMerchandiseCategory.category_id) + ','
+ isnull('''' + replace(ProfileXMerchandiseCategory.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileXMerchandiseCategory.date_added,120) + '''','null') + ','
+ isnull('''' + replace(ProfileXMerchandiseCategory.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileXMerchandiseCategory.date_modified,120) + '''','null') + ')' as sql
from ProfileXMerchandiseCategory, Merchandise, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileXMerchandiseCategory.category_id = Merchandise.category_id
and Merchandise.merchandise_status = 'A'
and ProfileXMerchandiseCategory.profile_id = WorkOrderDetail.profile_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'

order by sql asc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profilexmerchandisecategory] TO [EQAI]
    AS [dbo];

