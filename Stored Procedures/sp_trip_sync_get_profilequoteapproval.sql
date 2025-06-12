
create procedure sp_trip_sync_get_profilequoteapproval
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileQuoteApproval table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 11/10/2009 - rb Added company_id and profit_ctr_id to 'if not exists ( )' statement
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
 08/26/2015 - rb added print_dot_sp_flag
 09/04/2015 - rb added consolidate_container_flag
 01/16/2018	- mpm	Added consolidation_group_uid.
 04/26/2018	- mpm	Added air_permit_status_uid.

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

select distinct 'delete from ProfileQuoteApproval where quote_id = ' + convert(varchar(20),ProfileQuoteApproval.quote_id) + ' and company_id = ' + convert(varchar(20),ProfileQuoteApproval.company_id) + ' and profit_ctr_id = ' + convert(varchar(20),ProfileQuoteApproval.profit_ctr_id)
+ ' insert into ProfileQuoteApproval values('
+ convert(varchar(20),ProfileQuoteApproval.quote_id) + ','
+ convert(varchar(20),ProfileQuoteApproval.profile_id) + ','
+ convert(varchar(20),ProfileQuoteApproval.company_id) + ','
+ convert(varchar(20),ProfileQuoteApproval.profit_ctr_id) + ','
+ isnull('''' + replace(ProfileQuoteApproval.status, '''', '''''') + '''','null') + ','
+ '''' + replace(ProfileQuoteApproval.primary_facility_flag, '''', '''''') + '''' + ','
+ '''' + replace(ProfileQuoteApproval.approval_code, '''', '''''') + '''' + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.treatment_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.confirm_author, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.confirm_update_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileQuoteApproval.confirm_update_date,120) + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.disposal_service_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.disposal_service, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.disposal_service_other_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.purchase_order, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.release, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.sr_type_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.srec_exempt_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.LDR_req_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.location_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.location, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.location_control, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.OB_EQ_profile_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.OB_EQ_company_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.OB_EQ_profit_ctr_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.OB_TSDF_approval_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.insurance_exempt, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileQuoteApproval.date_added,120) + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileQuoteApproval.date_modified,120) + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.billing_project_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.po_sequence_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteApproval.treatment_process_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.load_intervention_required, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.load_intervention_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.ensr_exempt, '''', '''''') + '''','null')
+ case when @version < 4.25 then '' else ',' + isnull('''' + replace(ProfileQuoteApproval.print_dot_sp_flag, '''', '''''') + '''','null') end
+ case when @version < 4.26 then '' else ',' + isnull('''' + replace(ProfileQuoteApproval.consolidate_containers_flag, '''', '''''') + '''','null') end
+ case when @version < 4.48 then '' else ',' + isnull(convert(varchar(20),ProfileQuoteApproval.consolidation_group_uid),'null') end
+ case when @version < 4.55 then '' else ',' + isnull(convert(varchar(20),ProfileQuoteApproval.air_permit_status_uid),'null') end
+ ')' as sql
from ProfileQuoteApproval, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileQuoteApproval.profile_id = WorkOrderDetail.profile_id
and ProfileQuoteApproval.company_id = WorkorderDetail.profile_company_id
and ProfileQuoteApproval.profit_ctr_id = WorkorderDetail.profile_profit_ctr_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (ProfileQuoteApproval.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profilequoteapproval] TO [EQAI]
    AS [dbo];

