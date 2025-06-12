
drop procedure if exists sp_trip_sync_get_customer
go

create procedure sp_trip_sync_get_customer
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Customer table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 06/21/2011 - rb add EQ approved offerer columns
 08/15/2012 - rb discovered that forced refresh was not being checked
 04/20/2015 - rb modifications to support Kroger Invoicing requirements (pull GeneratorSubLocation table)
 09/04/2015 - rb added consolidate_container_flag
 11/24/2015 - rb new pickup_report_flag in CustomerBilling table
 11/22/2021 - mm DevOps 19701 - Added new CustomerBilling columns for "approved offeror".

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

select 'delete Customer where customer_id = ' + convert(varchar(20),Customer.customer_id)
+ ' insert Customer values('
+ convert(varchar(20),Customer.customer_ID) + ','
+ isnull('''' + replace(Customer.cust_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.customer_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_addr1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_addr2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_addr3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_addr4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_addr5, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_city, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_state, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_zip_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_country, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_sic_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_phone, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_fax, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.mail_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Customer.cust_directions), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.terms_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Customer.date_added,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),Customer.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(Customer.designation, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.generator_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.web_access_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.next_WCR),'null') + ','
+ isnull('''' + replace(Customer.cust_category, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.cust_website, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.cust_parent_ID),'null') + ','
+ isnull('''' + replace(Customer.cust_prospect_flag, '''', '''''') + '''','null') + ','
+ '''' + replace(Customer.rowguid, '''', '''''') + '''' + ','
+ isnull('''' + replace(Customer.eq_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.eq_company),'null') + ','
+ isnull('''' + replace(Customer.customer_cost_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.cust_naics_code),'null') + ','
+ isnull('''' + replace(Customer.cust_status, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.eq_profit_ctr),'null') + ','
+ isnull('''' + replace(Customer.SPOC_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_cust_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_addr1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_addr2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_addr3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_addr4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_addr5, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_city, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_state, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_zip_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.bill_to_country, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Customer.credit_limit),'null') + ','
+ isnull('''' + replace(Customer.labpack_trained_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Customer.national_account_flag, '''', '''''') + '''','null')
+ case when @version < 2.18 then '' else ',' + isnull('''' + replace(Customer.eq_approved_offerer_flag, '''', '''''') + '''','null')
	+ ',' + isnull('''' + replace(Customer.eq_approved_offerer_desc, '''', '''''') + '''','null')
	+ ',' + isnull('''' + convert(varchar(20),Customer.eq_offerer_effective_dt,120) + '''','null') end
+ case when @version < 4.26 then '' else ',' + isnull('''' + replace(Customer.consolidate_containers_flag, '''', '''''') + '''','null') end
+ ')' as sql
from Customer, WorkOrderHeader, TripConnectLog
where Customer.customer_id = WorkOrderHeader.customer_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Customer.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.field_requested_action = 'R')
union
select distinct 'delete GeneratorSubLocation where customer_id = ' + convert(varchar(20),GeneratorSubLocation.customer_id) + ' and generator_sublocation_id = ' + convert(varchar(20),GeneratorSubLocation.generator_sublocation_id)
+ ' insert GeneratorSubLocation values('
+ convert(varchar(20),GeneratorSubLocation.customer_ID) + ','
+ convert(varchar(20),GeneratorSubLocation.generator_sublocation_ID) + ','
+ '''' + replace(GeneratorSubLocation.status, '''', '''''') + '''' + ','
+ '''' + replace(GeneratorSubLocation.code, '''', '''''') + '''' + ','
+ '''' + replace(GeneratorSubLocation.description, '''', '''''') + '''' + ','
+ isnull('''' + replace(GeneratorSubLocation.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),GeneratorSubLocation.date_added,120) + '''','null') + ','
+ isnull('''' + replace(GeneratorSubLocation.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),GeneratorSubLocation.date_modified,120) + '''','null')
+ ')' as sql
from GeneratorSubLocation, WorkOrderHeader, TripConnectLog
where GeneratorSubLocation.customer_id = WorkOrderHeader.customer_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and @version >= 4.16
union
select distinct 'delete CustomerBilling where customer_id = ' + convert(varchar(20),WorkOrderHeader.customer_id) + ' and billing_project_id = ' + convert(varchar(20),WorkOrderHeader.billing_project_id)
+ ' insert CustomerBilling values('
+ convert(varchar(20),WorkOrderHeader.customer_ID) + ','
+ convert(varchar(20),WorkOrderHeader.billing_project_ID) + ','
+ isnull('''' + replace(CustomerBilling.pickup_report_flag, '''', '''''') + '''','null')
+ case when @version < 4.81 then '' else ',' + isnull('''' + replace(CustomerBilling.eq_offeror_bp_override_flag, '''', '''''') + '''','null')
	+ ',' + isnull('''' + replace(CustomerBilling.eq_approved_offeror_flag, '''', '''''') + '''','null')
	+ ',' + isnull('''' + replace(CustomerBilling.eq_approved_offeror_desc, '''', '''''') + '''','null')
	+ ',' + isnull('''' + convert(varchar(20),CustomerBilling.eq_offeror_effective_dt,120) + '''','null') end
+ ')' as sql
from CustomerBilling, WorkOrderHeader, TripConnectLog
where CustomerBilling.customer_id = WorkOrderHeader.customer_id
and CustomerBilling.billing_project_id = WorkOrderHeader.billing_project_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and WorkOrderHeader.workorder_status <> 'V'
and WorkOrderHeader.billing_project_id is not null
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and @version >= 4.29


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_customer] TO [EQAI]
    AS [dbo];

