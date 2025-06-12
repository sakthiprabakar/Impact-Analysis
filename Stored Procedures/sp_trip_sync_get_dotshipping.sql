
create procedure sp_trip_sync_get_dotshipping
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the DOTShipping table on a trip local database

 loads to Plt_ai
 
 08/15/2012 - rb created for Version 3.0 LabPack
****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id


select 'delete DOTShipping where DOT_shipping_id = ' + CONVERT(varchar(10),DOTShipping.DOT_shipping_id)
+ ' insert DOTShipping values('
+ convert(varchar(20),DOTShipping.DOT_shipping_id) + ','
+ '''' + replace(convert(varchar(4096),DOTShipping.DOT_shipping_name), '''', '''''') + '''' + ','
+ isnull('''' + replace(DOTShipping.hazmat_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShipping.hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShipping.sub_hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShipping.UN_NA_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),DOTShipping.UN_NA_number),'null') + ','
+ isnull('''' + replace(DOTShipping.packing_group, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),DOTShipping.ERG_number),'null') + ','
+ isnull('''' + replace(DOTShipping.ERG_suffix, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShipping.created_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),DOTShipping.date_added,120) + '''','null') + ','
+ isnull('''' + replace(DOTShipping.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),DOTShipping.date_modified,120) + '''','null') + ')' as sql
from DOTShipping
where DOTShipping.date_modified > isnull(@last_download_date,'01/01/1900')
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_dotshipping] TO [EQAI]
    AS [dbo];

