
create procedure sp_trip_sync_get_company
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Company table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
****************************************************************************************/

select 'delete from Company where company_id = ' + convert(varchar(20),Company.company_id)
+ ' insert into Company values('
+ convert(varchar(20),Company.company_id) + ','
+ '''' + replace(Company.company_name, '''', '''''') + '''' + ','
+ isnull('''' + replace(Company.dunn_and_bradstreet_id, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.remit_to, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.address_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.address_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.address_3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.phone, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.fax, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.EPA_ID, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Company.date_added,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),Company.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(Company.modified_by, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Company.insurance_surcharge_percent),'null') + ','
+ isnull('''' + replace(Company.phone_customer_service, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Company.next_project_id),'null') + ','
+ isnull('''' + replace(Company.payroll_company_id, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.view_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.view_invoicing_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.view_aging_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Company.view_survey_on_web, '''', '''''') + '''','null') + ','
+ '''' + replace(Company.rowguid, '''', '''''') + '''' + ')' as sql
from Company, WorkOrderHeader, TripConnectLog
where Company.company_id = WorkOrderHeader.company_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Company.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900'))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_company] TO [EQAI]
    AS [dbo];

