
create procedure sp_trip_sync_get_dotshippinglookup
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the DOTShippingLookup table on a trip local database

 loads to Plt_ai
 
 08/15/2012 - rb created for Version 3.0 LabPack
****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

 select 'if not exists (select 1 from DOTShippingLookup where DOT_shipping_name = ''' + replace(DOTShippingLookup.DOT_shipping_name, '''', '''''') + ''''
+ ') insert into DOTShippingLookup values('
+ '''' + replace(DOTShippingLookup.DOT_shipping_name, '''', '''''') + '''' + ','
+ isnull('''' + replace(DOTShippingLookup.hazmat_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShippingLookup.hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShippingLookup.sub_hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(DOTShippingLookup.UN_NA_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),DOTShippingLookup.UN_NA_number),'null') + ','
+ isnull('''' + replace(DOTShippingLookup.packing_group, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),DOTShippingLookup.ERG_number),'null') + ','
+ isnull('''' + replace(DOTShippingLookup.ERG_suffix, '''', '''''') + '''','null') + ')' as sql
from DOTShippingLookup
where @last_download_date is null
or exists (select 1 from TripConnectLog tcl
		join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
				and wh.field_requested_action = 'R'
		where tcl.trip_connect_log_id = @trip_connect_log_id)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_dotshippinglookup] TO [EQAI]
    AS [dbo];

