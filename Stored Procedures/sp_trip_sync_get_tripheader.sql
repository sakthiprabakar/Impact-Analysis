
create procedure sp_trip_sync_get_tripheader
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TripHeader table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 01/06/2010 - rb removed where clause check for after last_download_date
 08/15/2012 - rb Version 3.0, LabPack ... added lab_pack_flag
 07/23/2015 - rb Add Tractor and Trailer number fields
                 -- and added check for TripHeader date_modified to avoid clobbering BOL ability
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


select 'if not exists (select 1 from TripHeader where trip_id = ' + convert(varchar(20), TripHeader.trip_id)
+ ') insert into TripHeader values('
+ convert(varchar(20),TripHeader.trip_id) + ','
+ isnull(convert(varchar(20),TripHeader.company_id),'null') + ','
+ isnull(convert(varchar(20),TripHeader.profit_ctr_id),'null') + ','
+ '''' + replace(TripHeader.trip_status, '''', '''''') + '''' + ','
+ isnull('''' + replace(TripHeader.trip_pass_code, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TripHeader.trip_start_date,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),TripHeader.trip_end_date,120) + '''','null') + ','
+ '''' + replace(TripHeader.type_code, '''', '''''') + '''' + ','
+ '''' + replace(TripHeader.trip_desc, '''', '''''') + '''' + ','
+ isnull('''' + replace(TripHeader.template_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.transporter_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.resource_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.driver_company, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.driver_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.drivers_license_CDL, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.truck_DOT_number, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.upload_merchandise_ind, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TripHeader.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TripHeader.date_added,120) + '''','null') + ','
+ isnull('''' + replace(TripHeader.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TripHeader.date_modified,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),TripHeader.field_initial_connect_date,120) + '''','null') + ','
+ isnull('''' + replace(TripHeader.use_manifest_haz_only_flag, '''', '''''') + '''','null')
+ case when @version < 3.0 then '' else ',''' + isnull(TripHeader.lab_pack_flag,'F') + '''' end
+ case when @version < 4.20 then '' else ',' + isnull('''' + replace(TripHeader.tractor_number, '''', '''''') + '''','null') end
+ case when @version < 4.20 then '' else ',' + isnull('''' + replace(TripHeader.trailer_number, '''', '''''') + '''','null') end
+ ')'
+ ' else update TripHeader set use_manifest_haz_only_flag='
+ isnull('''' + replace(TripHeader.use_manifest_haz_only_flag, '''', '''''') + '''','null')
+ case when @version < 3.0 then '' else ',lab_pack_flag=' + isnull('''' + replace(TripHeader.lab_pack_flag, '''', '''''') + '''','null') end
+ ' where trip_id=' + convert(varchar(20),TripHeader.trip_id) as sql
from TripHeader, TripConnectLog
where TripHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and TripHeader.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tripheader] TO [EQAI]
    AS [dbo];

