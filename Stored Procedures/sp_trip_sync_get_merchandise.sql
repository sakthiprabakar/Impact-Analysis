
create procedure sp_trip_sync_get_merchandise
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Merchandise table on a trip local database

 loads to Plt_ai
 
 04/01/2010 - rb created
 04/26/2010 - rb add strength, unit and package_size fields
 05/06/2010 - rb compare modified_date to new TripConnectLog last_merchandise_download_date column
 12/10/2010 - rb merchandise tables were being refreshed when new stops were added to a trip
 08/18/2011 - rb Serial number, incremental merchandise download
 10/21/2011 - rb Remove requirement that upload_merchandise_ind be set in order to download DEA
 02/06/2012 - rb Ignore Refresh on Field Device set on Workorder/Trip screens
 02/29/2012 - rb Incorporate merchandise category_id to determine last refresh dates
 08/14/2014 - rb date_modified included for versions > 4
 09/18/2014 - rb modified to include Merchandise records with status changed from 'A' to something else
****************************************************************************************/

declare	@msg varchar(255),
	@idx int,
	@serial_number varchar(20),
	@tcl2_id int,
	@s_version varchar(10),
	@dot int,
	@version numeric(6,2)


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

set nocount on

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

-- rb 08/24/2011 record serial # if it can be determined
select @tcl2_id = max(tcl2.trip_connect_log_id)
from TripConnectLog tcl, TripConnectLog tcl2, TripConnectLogDetail tcld
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_id = tcl2.trip_id
and tcl2.trip_connect_log_id = tcld.trip_connect_log_id
and tcld.request like 'Trip%Serial #%'

select @msg = request
from TripConnectLogDetail
where trip_connect_log_id = @tcl2_id
and request like 'Trip%Serial #%'

if datalength(ltrim(rtrim(isnull(@msg,'')))) > 0
begin
	select @idx = charindex (' Serial ',@msg,1)
	select @serial_number = ltrim(rtrim(substring (@msg, @idx + 9,DATALENGTH(@msg) - @idx - 8)))
end

select distinct pxmc.category_id
into #categories
from WorkOrderDetail wd
join ProfileXMerchandiseCategory pxmc on wd.profile_id = pxmc.profile_id
join WorkorderHeader wh on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
join TripConnectLog tcl on wh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id

set nocount off

select 'if exists (select 1 from Merchandise where merchandise_id = ' + convert(varchar(20),Merchandise.merchandise_id)
+ ') update Merchandise set merchandise_desc = ''' + replace(Merchandise.merchandise_desc, '''', '''''') + ''''
+ ', merchandise_status = ''' + replace(Merchandise.merchandise_status, '''', '''''') + ''''
+ ', merchandise_type_id = ' + convert(varchar(20),Merchandise.merchandise_type_id)
+ ', category_id = ' + convert(varchar(20),Merchandise.category_id)
+ ', dea_schedule = ' + isnull('''' + replace(Merchandise.dea_schedule, '''', '''''') + '''','null')
+ ', strength = ' + isnull('''' + replace(Merchandise.strength, '''', '''''') + '''','null')
+ ', unit = ' + isnull('''' + replace(Merchandise.unit, '''', '''''') + '''','null')
+ ', package_size = ' + isnull('''' + replace(Merchandise.package_size, '''', '''''') + '''','null')
+ case when @version < 4.02 then '' else ', date_modified=' + isnull('''' + CONVERT(varchar(25),Merchandise.date_modified,121) + '''','null') end
+ ' where merchandise_id = ' + convert(varchar(20),Merchandise.merchandise_id)
+ ' else insert Merchandise values('
+ convert(varchar(20),Merchandise.merchandise_id) + ','
+ '''' + replace(Merchandise.merchandise_desc, '''', '''''') + '''' + ','
+ '''' + replace(Merchandise.merchandise_status, '''', '''''') + '''' + ','
+ convert(varchar(20),Merchandise.merchandise_type_id) + ','
+ isnull(convert(varchar(20),Merchandise.category_id),'null') + ','
+ isnull('''' + replace(Merchandise.dea_schedule, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Merchandise.strength, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Merchandise.unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Merchandise.package_size, '''', '''''') + '''','null')
+ case when @version < 4.02 then '' else ',' + isnull('''' + CONVERT(varchar(25),Merchandise.date_modified,121) + '''','null') end
+ ')' as sql
from Merchandise
join #categories
	on #categories.category_id = Merchandise.category_id
join TripConnectLog
	on TripConnectLog.trip_connect_log_id = @trip_connect_log_id
left outer join TripMerchandiseDownloadLog
	on TripMerchandiseDownloadLog.serial_number = @serial_number
	and TripMerchandiseDownloadLog.category_id = #categories.category_id
where Merchandise.merchandise_status = 'A'
	and (Merchandise.date_added > isnull(TripMerchandiseDownloadLog.last_download_date,'01/01/1900')
	or Merchandise.date_modified > isnull(TripMerchandiseDownloadLog.last_download_date,'01/01/1900'))
union
select 'update Merchandise set merchandise_status = ''' + replace(Merchandise.merchandise_status, '''', '''''') + ''''
+ case when @version < 4.02 then '' else ', date_modified=' + isnull('''' + CONVERT(varchar(25),Merchandise.date_modified,121) + '''','null') end
+ ' where merchandise_id = ' + convert(varchar(20),Merchandise.merchandise_id) as sql
from Merchandise
join #categories
	on #categories.category_id = Merchandise.category_id
join TripConnectLog
	on TripConnectLog.trip_connect_log_id = @trip_connect_log_id
left outer join TripMerchandiseDownloadLog
	on TripMerchandiseDownloadLog.serial_number = @serial_number
	and TripMerchandiseDownloadLog.category_id = #categories.category_id
where Merchandise.merchandise_status = 'I'
	and (Merchandise.date_added > isnull(TripMerchandiseDownloadLog.last_download_date,'01/01/1900')
	or Merchandise.date_modified > isnull(TripMerchandiseDownloadLog.last_download_date,'01/01/1900'))

drop table #categories

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_merchandise] TO [EQAI]
    AS [dbo];

