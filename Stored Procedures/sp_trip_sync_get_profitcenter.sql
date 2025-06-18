ALTER PROCEDURE dbo.sp_trip_sync_get_profitcenter
	  @trip_connect_log_id INTEGER
as
/***************************************************************************************
 this procedure synchronizes the ProfitCenter table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 03/29/2010 - rb rowguid column removed
 04/26/2018	- mpm - Added air_permit_flag; added @version; changed generated SQL statement from
					"if not exists, then insert" to "delete and then insert".
 06/26/2019 - mpm - Incident 10936 - Added default_manifest_form_suffix column.
 01/20/2025 - bc tweak for Titan
 02/11/2025 - mpm - Rally TA501937
 02/11/2025 - MPM - Rally TA501937/US139807 - Per Blair, added GO statement at end.
****************************************************************************************/
BEGIN

declare @s_version VARCHAR(10)
      , @dot INTEGER
	  , @version NUMERIC(6,2)

set transaction isolation level read uncommitted

select @s_version = tcca.client_app_version
  from TripConnectLog tcl
       join TripConnectClientApp tcca on tcl.trip_client_app_id = tcca.trip_client_app_id
 where tcl.trip_connect_log_id = @trip_connect_log_id


select @dot = CHARINDEX('.',@s_version)

if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = CONVERT(NUMERIC(6,2),SUBSTRING(@s_version,1,@dot-1))
	                + (CONVERT(NUMERIC(6,2),SUBSTRING(@s_version,@dot+1, DATALENGTH(@s_version))) / 100)
						
select distinct 'DELETE FROM ProfitCenter WHERE company_id = ' + CONVERT(VARCHAR(10),pc.company_id) + ' and profit_ctr_id = ' + CONVERT(VARCHAR(10),pc.profit_ctr_id)
     + ' INSERT INTO ProfitCenter VALUES ('
     + CONVERT(VARCHAR(20),pc.company_ID)
     + ',' + CONVERT(VARCHAR(20),pc.profit_ctr_ID)
     + ',' + ISNULL('''' + REPLACE(pc.profit_ctr_name, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.price_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.min_charge),'NULL')
     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),pc.date_added,120) + '''','NULL')
     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),pc.date_modified,120) + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(LEFT(pc.modified_by,8), '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.discount_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.min_price_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.confirm_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.next_receipt_ID),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.ss_next_avail_receipt_ID),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.surcharge_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.next_workorder_ID),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.next_template_ID),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.base_rate_quote_ID),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.default_transporter, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.cost_factor),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.address_1, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.address_2, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.address_3, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.phone, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.fax, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.EPA_ID, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.label_size),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.label_copies),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.container_label_printer),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.zero_billing_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.receipt_days_to_warning),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.receipt_print_type, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.receipt_price_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.receipt_price_adjust_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.receipt_cost_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.approval_override_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.manifest_scan_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.pcb_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.next_container_label_ID),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.approval_type, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.receipt_hours_until_problem),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.short_name, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.[status], '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.default_manifest_state, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.emergency_contact_phone, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.posting_code),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.default_TSDF_code, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.overhead_percent),'NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.admin_percent),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.waste_code_match_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_scheduling_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_approvals_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_waste_received_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_workorders_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.view_waste_summary_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.next_consolidation_ID),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.manifest_continuation_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.scheduling_phone, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.const_match_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.change_const_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.treatment_receipt_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.treatment_container_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.treatment_barcode_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.default_label_type, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),pc.reapproval_days_available),'NULL')
     + ',' + ISNULL('''' + REPLACE(pc.CC_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.GN_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.GWA_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.LDR_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.PQ_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.RA_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.SREC_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.WCR_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.WWA_available, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.cust_serv_email, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.sched_email, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.[description], '''', '''''') + '''','NULL')
     + ',' + '''NULL'''
     + ',' + ISNULL('''' + REPLACE(pc.waste_receipt_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.workorder_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.preassign_receipt_flag, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(pc.labpack_training_required_flag, '''', '''''') + '''','NULL')
     + CASE WHEN @version < 4.55 THEN '' ELSE ',' + ISNULL('''' + REPLACE(pc.air_permit_flag, '''', '''''') + '''','NULL') END
     + CASE WHEN @version < 4.62 THEN '' ELSE ',' + ISNULL('''' + REPLACE(pc.default_manifest_form_suffix, '''', '''''') + '''','NULL') END
     + ')' as [sql]
  from ProfitCenter pc
       join WorkOrderHeader h on pc.company_id = h.company_id
            and pc.profit_ctr_id = h.profit_ctr_id
       join TripConnectLog tcl on h.trip_id = tcl.trip_id
 where tcl.trip_connect_log_id = @trip_connect_log_id
   and h.field_requested_action <> 'D'
   and (h.date_added > ISNULL(tcl.last_download_date,'01/01/1900')
        or h.field_requested_action = 'R')

END;
GO
