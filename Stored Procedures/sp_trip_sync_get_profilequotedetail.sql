
create procedure sp_trip_sync_get_profilequotedetail
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfileQuoteDetail table on a trip local database

 loads to Plt_ai
 
 03/17/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (inital implementation was for new stop)
 01/21/2011 - rb Intercompany / Surcharge changes, new columns
****************************************************************************************/

select distinct 'delete from ProfileQuoteDetail where quote_id = ' + convert(varchar(20),ProfileQuoteDetail.quote_id)
+ ' insert into ProfileQuoteDetail values('
+ convert(varchar(20),ProfileQuoteDetail.quote_id) + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.profile_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.company_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.profit_ctr_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.status, '''', '''''') + '''','null') + ','
+ convert(varchar(20),ProfileQuoteDetail.sequence_id) + ','
+ isnull('''' + replace(ProfileQuoteDetail.record_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.price),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.service_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.bulk_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.surcharge_price),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.min_quantity),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.bill_method, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.bill_quantity_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.hours_free_unloading),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.hours_free_loading),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.demurrage_price),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.unused_truck_price),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.lay_over_charge),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileQuoteDetail.date_added,120) + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfileQuoteDetail.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.print_on_invoice_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.product_ID),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.product_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.primary_price_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.apply_to_price),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.ref_sequence_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.transporter_id),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.transporter_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.orig_customer_price),'null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.resource_class_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.price_increase_2005, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfileQuoteDetail.price_increase_2006, '''', '''''') + '''','null') + ','
+ ''' ''' + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.resource_class_company_id),'null') + ','
+ isnull(convert(varchar(20),ProfileQuoteDetail.customer_cost),'null') + ')' as sql
from ProfileQuoteDetail, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileQuoteDetail.profile_id = WorkOrderDetail.profile_id
and ProfileQuoteDetail.company_id = WorkorderDetail.profile_company_id
and ProfileQuoteDetail.profit_ctr_id = WorkorderDetail.profile_profit_ctr_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (ProfileQuoteDetail.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profilequotedetail] TO [EQAI]
    AS [dbo];

