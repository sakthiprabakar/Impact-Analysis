
create procedure sp_trip_sync_get_profileldrsubcategory
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileLDRSubcategory table on a trip local database

 loads to Plt_ai
 
 07/30/2013 - rb created
****************************************************************************************/

declare @s_version varchar(10),
		@dot int,
		@version numeric(6,2)


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

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

if @version < 3.07
begin
	select '' as sql
	return 0
end


select distinct 'delete ProfileLDRSubcategory where profile_id = ' + convert(varchar(10),wd.profile_id) as sql
from WorkOrderDetail wd
join WorkOrderHeader wh
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and isnull(wh.field_requested_action,'') <> 'D'
join TripConnectLog tcl
	on wh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id
where isnull(wd.profile_id,0) > 0

union

select distinct 'insert ProfileLDRSubcategory values ('
+ isnull(convert(varchar(20),pls.profile_id),'null')
+ ', ' + isnull(convert(varchar(20),pls.ldr_subcategory_id),'null')
+ ', ' + isnull('''' + replace(pls.added_by, '''', '''''') + '''','null')
+ ', ' + isnull('''' + convert(varchar(20),pls.date_added,120) + '''','null')
+ ', ' + isnull('''' + replace(pls.modified_by, '''', '''''') + '''','null')
+ ', ' + isnull('''' + convert(varchar(20),pls.date_modified,120) + '''','null') + ')' as sql
from ProfileLDRSubcategory pls
join WorkOrderDetail wd
	on pls.profile_id = wd.profile_id
join WorkOrderHeader wh
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and isnull(wh.field_requested_action,'') <> 'D'
join TripConnectLog tcl
	on wh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id

order by sql asc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profileldrsubcategory] TO [EQAI]
    AS [dbo];

