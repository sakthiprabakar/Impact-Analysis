
create procedure sp_trip_sync_get_profitcenter
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ProfitCenter table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 03/29/2010 - rb rowguid column removed
 04/26/2018	- mpm - Added air_permit_flag; added @version; changed generated SQL statement from
					"if not exists, then insert" to "delete and then insert".
 06/26/2019 - mpm - Incident 10936 - Added default_manifest_form_suffix column.
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
						
select distinct 'delete from ProfitCenter where company_id = ' + convert(varchar(10),ProfitCenter.company_id) + ' and profit_ctr_id = ' + convert(varchar(10),ProfitCenter.profit_ctr_id)
+ ' insert into ProfitCenter values('
+ convert(varchar(20),ProfitCenter.company_ID) + ','
+ convert(varchar(20),ProfitCenter.profit_ctr_ID) + ','
+ isnull('''' + replace(ProfitCenter.profit_ctr_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.price_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.min_charge),'null') + ','
+ isnull('''' + convert(varchar(20),ProfitCenter.date_added,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),ProfitCenter.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.discount_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.min_price_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.confirm_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.next_receipt_ID),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.ss_next_avail_receipt_ID),'null') + ','
+ isnull('''' + replace(ProfitCenter.surcharge_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.next_workorder_ID),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.next_template_ID),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.base_rate_quote_ID),'null') + ','
+ isnull('''' + replace(ProfitCenter.default_transporter, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.cost_factor),'null') + ','
+ isnull('''' + replace(ProfitCenter.address_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.address_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.address_3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.phone, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.fax, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.EPA_ID, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.label_size),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.label_copies),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.container_label_printer),'null') + ','
+ isnull('''' + replace(ProfitCenter.zero_billing_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.receipt_days_to_warning),'null') + ','
+ isnull('''' + replace(ProfitCenter.receipt_print_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.receipt_price_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.receipt_price_adjust_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.receipt_cost_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.approval_override_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.manifest_scan_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.pcb_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.next_container_label_ID),'null') + ','
+ isnull('''' + replace(ProfitCenter.approval_type, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.receipt_hours_until_problem),'null') + ','
+ isnull('''' + replace(ProfitCenter.short_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.default_manifest_state, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.emergency_contact_phone, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.posting_code),'null') + ','
+ isnull('''' + replace(ProfitCenter.view_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.default_TSDF_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.overhead_percent),'null') + ','
+ isnull(convert(varchar(20),ProfitCenter.admin_percent),'null') + ','
+ isnull('''' + replace(ProfitCenter.waste_code_match_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.view_scheduling_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.view_approvals_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.view_waste_received_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.view_workorders_on_web, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.view_waste_summary_on_web, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.next_consolidation_ID),'null') + ','
+ isnull('''' + replace(ProfitCenter.manifest_continuation_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.scheduling_phone, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.const_match_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.change_const_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.treatment_receipt_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.treatment_container_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.treatment_barcode_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.default_label_type, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),ProfitCenter.reapproval_days_available),'null') + ','
+ isnull('''' + replace(ProfitCenter.CC_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.GN_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.GWA_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.LDR_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.PQ_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.RA_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.SREC_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.WCR_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.WWA_available, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.cust_serv_email, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.sched_email, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.description, '''', '''''') + '''','null') + ','
+ '''null''' + ','
+ isnull('''' + replace(ProfitCenter.waste_receipt_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.workorder_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.preassign_receipt_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(ProfitCenter.labpack_training_required_flag, '''', '''''') + '''','null')
+ case when @version < 4.55 then '' else ',' + isnull('''' + replace(ProfitCenter.air_permit_flag, '''', '''''') + '''','null') end +
+ case when @version < 4.62 then '' else ',' + isnull('''' + replace(ProfitCenter.default_manifest_form_suffix, '''', '''''') + '''','null') end +
')' as sql
from ProfitCenter, WorkOrderHeader, TripConnectLog
where ProfitCenter.company_id = WorkOrderHeader.company_id
and ProfitCenter.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	 WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profitcenter] TO [EQAI]
    AS [dbo];

