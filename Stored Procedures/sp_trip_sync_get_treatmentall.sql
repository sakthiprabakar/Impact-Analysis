
create procedure sp_trip_sync_get_treatmentall
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TreatmentAll table on a trip local database
* (note that Treatment is TreatmentAll on local db to simulate view in company db)

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/15/2009 - kam  Updated to use fingerprint_type from PQA
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/28/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
 03/07/2012 - rb When treatment_id modified on ProfileQuoteApproval, sync needs to pull treatment
****************************************************************************************/

select distinct 'delete from TreatmentAll where treatment_id = ' + convert(varchar(10),Treatment.treatment_id) + ' and company_id = ' + convert(varchar(10),Treatment.company_id) + ' and profit_ctr_id = ' + convert(varchar(10),Treatment.profit_ctr_id)
+ ' insert into TreatmentAll values('
+ convert(varchar(20),Treatment.treatment_id) + ','
+ convert(varchar(20),Treatment.company_id) + ','
+ convert(varchar(20),Treatment.profit_ctr_id) + ','
+ isnull('''' + replace(Treatment.status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Treatment.treatment_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Treatment.tank_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Treatment.management_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Treatment.BTU_flag),'null') + ','
+ isnull('''' + replace(Treatment.gl_account_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteApproval.fingerprint_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Treatment.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Treatment.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Treatment.date_added,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),Treatment.date_modified,120) + '''','null') + ','
+ isnull(convert(varchar(20),Treatment.reportable_category),'null') + ','
+ isnull(convert(varchar(20),Treatment.commission_category),'null') + ','
+ '''' + ' ' + '''' + ','
+ isnull('''' + replace(Treatment.labpack_training_required_flag, '''', '''''') + '''','null') + ')' as sql
from Treatment, ProfileQuoteApproval, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where Treatment.treatment_id = ProfileQuoteApproval.treatment_id
and Treatment.company_id = ProfileQuoteApproval.company_id
and Treatment.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
and ProfileQuoteApproval.profile_id = WorkOrderDetail.profile_id
and ProfileQuoteApproval.company_id = WorkorderDetail.profile_company_id
and ProfileQuoteApproval.profit_ctr_id = WorkorderDetail.profile_profit_ctr_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Treatment.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
 	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
 	ProfileQuoteApproval.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
 	ProfileQuoteApproval.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_treatmentall] TO [EQAI]
    AS [dbo];

