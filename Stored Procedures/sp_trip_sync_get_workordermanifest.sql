
create procedure sp_trip_sync_get_workordermanifest
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderManifest table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 01/21/2011 - rb Column changes to all Workorder-related tables
 07/13/2011 - rb Added WorkOrderManifest.date_modified > last_download_date
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance
 12/04/2012 - rb Update manifest_state so if a manifest is changed to BOL, drivers get the update
 07/17/2018 - MPM - Added generator_sign_name and generator_sign_date columns.
 10/22/2019	- MPM - DevOps 12549 - Modified to use the Replace function for generator_sign_name
					so that special characters like an apostrophe or double quotes are
					properly handled.
****************************************************************************************/

set transaction isolation level read uncommitted

declare @s_version varchar(10),
		@dot int,
		@version numeric(6,2)

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
						
select 'if exists (select 1 from WorkOrderManifest where workorder_id = ' + convert(varchar(20),WorkOrderManifest.workorder_id) + ' and company_id = ' + isnull(convert(varchar(20),WorkOrderManifest.company_id),'null') + ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderManifest.profit_ctr_ID) + ' and manifest = ' + isnull('''' + replace(WorkOrderManifest.manifest, '''', '''''') + '''','null')
+ ') update WorkOrderManifest set manifest_state = ' + isnull('''' + replace(WorkOrderManifest.manifest_state, '''', '''''') + '''','null')
+ ' where workorder_id = ' + convert(varchar(20),WorkOrderManifest.workorder_id) + ' and company_id = ' + isnull(convert(varchar(20),WorkOrderManifest.company_id),'null') + ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderManifest.profit_ctr_ID) + ' and manifest = ' + isnull('''' + replace(WorkOrderManifest.manifest, '''', '''''') + '''','null')
+ ' else insert into WorkOrderManifest values ('
+ convert(varchar(20),WorkOrderManifest.workorder_ID) + ','
+ isnull(convert(varchar(20),WorkOrderManifest.company_id),'null') + ','
+ convert(varchar(20),WorkOrderManifest.profit_ctr_ID) + ','
+ isnull('''' + replace(WorkOrderManifest.manifest, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.manifest_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.EQ_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.manifest_state, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.gen_manifest_doc_number, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderManifest.date_delivered,120) + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + replace(WorkOrderManifest.transporter_code_1, '''', '''''') + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + replace(WorkOrderManifest.transporter_code_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.discrepancy_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.discrepancy_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderManifest.discrepancy_resolution, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderManifest.discrepancy_resolution_date,120) + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + replace(WorkOrderManifest.transporter_license_1, '''', '''''') + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + replace(WorkOrderManifest.transporter_license_2, '''', '''''') + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + convert(varchar(20),WorkOrderManifest.transporter_receive_date,120) + '''','null') + ','
-- rb 01/21/2011 + isnull('''' + replace(WorkOrderManifest.container_code, '''', '''''') + '''','null') + ','
-- rb 01/21/2011 + isnull(convert(varchar(20),WorkOrderManifest.quantity),'null') + ','
+ isnull('''' + replace(WorkOrderManifest.continuation_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderManifest.site_id),'null') + ','
+ isnull('''' + replace(WorkOrderManifest.added_by, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(WorkOrderManifest.modified_by, '''', '''''') + '''','null') + ','
+ 'null' 
-- mpm 10/22/2019 + case when @version < 4.57 then '' else ',' + coalesce('''' + WorkOrderManifest.generator_sign_name + '''','null') end 
+ case when @version < 4.57 then '' else ',' + isnull('''' + replace(WorkOrderManifest.generator_sign_name, '''', '''''') + '''','null') end
+ case when @version < 4.57 then '' else ',' + isnull('''' + convert(varchar(20),WorkOrderManifest.generator_sign_date,120) + '''','null') end
+ ')' as sql
from WorkOrderManifest, WorkOrderHeader, TripConnectLog
where WorkOrderManifest.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderManifest.company_id = WorkOrderHeader.company_id
and WorkOrderManifest.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderManifest.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workordermanifest] TO [EQAI]
    AS [dbo];

