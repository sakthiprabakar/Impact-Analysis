USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_process_staging_workorderquote]    Script Date: 10/14/2024 3:26:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [dbo].[sp_sfdc_process_staging_workorderquote]
	@salesforce_so_quote_id varchar(80)
as
/*********************
 *
 * 03/04/2024 - rwb - Created
 * 07/22/2024 - rwb - US118337 - It is now possible that an insert into WorkOrderHeader is part of the transaction
 * 09/30/2024  -Venu - DE35881  - For disposal record addtional table entires added workordertracking and workorderstop
 * 11/05/2024  -Venu  - DE36013 - Inserting the audit records during workorderheader creation for Disposal.
 *********************/

declare
	@sfs_workorderquoteheader_uid int,
	@generator_id int,
	@sfs_note_uid int,
	@project_code varchar(15),
    @quote_id int,
    @date_added datetime,
    @sfs_workorderheader_uid int,
	@is_success int,
	@as_message varchar(255)

set @is_success = 1
set @as_message = 'SUCCESS'
set transaction isolation level read uncommitted

begin transaction

--Find quote in staging table
select @sfs_workorderquoteheader_uid = max([sfs_workorderquoteheader_uid])
from SFSWorkOrderQuoteHeader
where [salesforce_so_quote_id] = @salesforce_so_quote_id

if coalesce(@sfs_workorderquoteheader_uid,0) < 1
begin
	set @is_success = 0
	set @as_message = 'ERROR: Salesforce quote ID ' + @salesforce_so_quote_id + ' not found in SFSWorkOrderQuoteHeader'
	goto END_OF_PROC
end

--Get project_code
select @quote_id = quote_id, 
    @project_code = project_code,
    @date_added = date_added
from SFSWorkOrderQuoteHeader
where sfs_workorderquoteheader_uid = @sfs_workorderquoteheader_uid


--WorkOrderQuoteHeader
insert WorkOrderQuoteHeader (
[quote_id],
[quote_revision],
[company_id],
[profit_ctr_id],
[curr_status_code],
[customer_id],
[quote_type],
[confirm_author],
[confirm_update_by],
[confirm_update_date],
[purchase_order],
[release],
[start_date],
[customer_name],
[customer_addr1],
[customer_addr2],
[customer_addr3],
[customer_addr4],
[customer_addr5],
[customer_contact],
[customer_phone],
[customer_fax],
[direct_flag],
[generator_id],
[generator_EPA_ID],
[generator_name],
[generator_addr1],
[generator_addr2],
[generator_addr3],
[generator_addr4],
[generator_addr5],
[generator_phone],
[generator_fax],
[generator_contact],
[project_code],
[project_name],
[project_location],
[job_type],
[waste_general_desc],
[volume],
[frequency],
[disposal_service],
[disposal_service_other_desc],
[probability],
[print_confirm_flag],
[print_gen_flag],
[fax_flag],
[fax_date],
[company_name],
[company_addr1],
[company_addr2],
[company_addr3],
[company_phone],
[company_fax],
[company_EPA_ID],
[added_by],
[date_added],
[modified_by],
[date_modified],
[fixed_price_flag],
[fixed_price],
[comments],
[total_price],
[total_cost],
[rowguid],
[billing_project_id],
[purchase_order_sequence_id],
[AX_Dimension_5_Part_1],
[AX_Dimension_5_Part_2],
[currency_code],
[corporate_revenue_classification_uid],
[labpack_pricing_rollup],
[labpack_quote_flag],
[labpack_quote_status],
[labpack_quote_start_dt],
[labpack_quote_end_dt],
[customer_email],
[use_contact_id],
[external_comments],
[salesforce_so_quote_id]
)
select
[quote_id],
[quote_revision],
[company_id],
[profit_ctr_id],
[curr_status_code],
[customer_id],
[quote_type],
[confirm_author],
[confirm_update_by],
[confirm_update_date],
[purchase_order],
[release],
[start_date],
[customer_name],
[customer_addr1],
[customer_addr2],
[customer_addr3],
[customer_addr4],
[customer_addr5],
[customer_contact],
[customer_phone],
[customer_fax],
[direct_flag],
[generator_id],
[generator_EPA_ID],
[generator_name],
[generator_addr1],
[generator_addr2],
[generator_addr3],
[generator_addr4],
[generator_addr5],
[generator_phone],
[generator_fax],
[generator_contact],
[project_code],
[project_name],
[project_location],
[job_type],
[waste_general_desc],
[volume],
[frequency],
[disposal_service],
[disposal_service_other_desc],
[probability],
[print_confirm_flag],
[print_gen_flag],
[fax_flag],
[fax_date],
[company_name],
[company_addr1],
[company_addr2],
[company_addr3],
[company_phone],
[company_fax],
[company_EPA_ID],
[added_by],
[date_added],
[modified_by],
[date_modified],
[fixed_price_flag],
[fixed_price],
[comments],
[total_price],
[total_cost],
[rowguid],
[billing_project_id],
[purchase_order_sequence_id],
[AX_Dimension_5_Part_1],
[AX_Dimension_5_Part_2],
[currency_code],
[corporate_revenue_classification_uid],
[labpack_pricing_rollup],
[labpack_quote_flag],
[labpack_quote_status],
[labpack_quote_start_dt],
[labpack_quote_end_dt],
[customer_email],
[use_contact_id],
[external_comments],
[salesforce_so_quote_id]
from SFSWorkOrderQuoteHeader
where [sfs_workorderquoteheader_uid] = @sfs_workorderquoteheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderQuoteHeader failed'
	goto END_OF_PROC
end

--WorkOrderQuoteDetail
insert WorkOrderQuoteDetail (
[quote_id],
[company_id],
[profit_ctr_id],
[sequence_id],
[record_type],
[bill_unit_code],
[price],
[service_desc],
[resource_type],
[resource_item_code],
[resource_item_type],
[resource],
[group_code],
[quantity],
[quantity_std],
[quantity_ot],
[price_ot],
[quantity_dt],
[price_dt],
[cost],
[description],
[added_by],
[date_added],
[modified_by],
[date_modified],
[customer_cost],
[price_increase_2006],
[currency_code],
[external_comments],
[profile_id],
[tsdf_approval_id],
[approval_code],
[tsdf_code],
[work_order_quote_price_override_flag],
[work_order_quote_price_overridden_by],
[work_order_quote_price_overridden_date],
[display_wo_quote_price_override_flag],
[salesforce_date_modified],
[salesforce_contract_line],
[salesforce_so_quote_line_id],
[salesforce_cost_markup_type],
[salesforce_cost_markup_amount],
[salesforce_bundle_id],
[salesforce_task_name],
[salesforce_task_CSID]
)
select
[quote_id],
[company_id],
[profit_ctr_id],
[sequence_id],
[record_type],
[bill_unit_code],
[price],
[service_desc],
[resource_type],
[resource_item_code],
[resource_item_type],
[resource],
[group_code],
[quantity],
[quantity_std],
[quantity_ot],
[price_ot],
[quantity_dt],
[price_dt],
[cost],
[description],
[added_by],
[date_added],
[modified_by],
[date_modified],
[customer_cost],
[price_increase_2006],
[currency_code],
[external_comments],
[profile_id],
[tsdf_approval_id],
[approval_code],
[tsdf_code],
[work_order_quote_price_override_flag],
[work_order_quote_price_overridden_by],
[work_order_quote_price_overridden_date],
[display_wo_quote_price_override_flag],
[salesforce_date_modified],
[salesforce_contract_line],
[salesforce_so_quote_line_id],
[salesforce_cost_markup_type],
[salesforce_cost_markup_amount],
[salesforce_bundle_id],
[salesforce_task_name],
[salesforce_task_CSID]
from SFSWorkOrderQuoteDetail
where [sfs_workorderquoteheader_uid] = @sfs_workorderquoteheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderQuoteDetail failed'
	goto END_OF_PROC
end

--Note
insert Note (
[note_id],
[note_source],
[company_id],
[profit_ctr_id],
[note_date],
[subject],
[status],
[note_type],
[note],
[customer_id],
[contact_id],
[generator_id],
[approval_code],
[profile_id],
[receipt_id],
[workorder_id],
[merchandise_id],
[batch_location],
[batch_tracking_num],
[project_id],
[project_record_id],
[project_sort_id],
[contact_type],
[added_by],
[date_added],
[modified_by],
[date_modified],
[app_source],
[rowguid],
[TSDF_approval_id],
[quote_id],
[salesforce_json_flag]
)
select
[note_id],
[note_source],
[company_id],
[profit_ctr_id],
[note_date],
[subject],
[status],
[note_type],
[note],
[customer_id],
[contact_id],
[generator_id],
[approval_code],
[profile_id],
[receipt_id],
[workorder_id],
[merchandise_id],
[batch_location],
[batch_tracking_num],
[project_id],
[project_record_id],
[project_sort_id],
[contact_type],
[added_by],
[date_added],
[modified_by],
[date_modified],
[app_source],
[rowguid],
[TSDF_approval_id],
[quote_id],
[salesforce_json_flag]
from SFSNote
where [sfs_workorderquoteheader_uid] = @sfs_workorderquoteheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into Note failed'
	goto END_OF_PROC
end


--Potentially insert work order header (date_added is just to avoid a potential issue)
select @sfs_workorderheader_uid = max(sfs_workorderheader_uid)
from SFSWorkOrderHeader
where project_code = @project_code
and date_added >= @date_added

if coalesce(@sfs_workorderheader_uid,0) > 0
begin
    --WorkOrderHeader
    insert WorkOrderHeader (
    [workorder_ID],
    [company_id],
    [profit_ctr_ID],
    [revision],
    [workorder_status],
    [workorder_type],
    [submitted_flag],
    [customer_ID],
    [generator_id],
    [billing_project_id],
    [fixed_price_flag],
    [priced_flag],
    [total_price],
    [total_cost],
    [description],
    [template_code],
    [emp_arrive_time],
    [cust_arrive_time],
    [start_date],
    [end_date],
    [urgency_flag],
    [project_code],
    [project_name],
    [project_location],
    [contact_ID],
    [quote_ID],
    [purchase_order],
    [release_code],
    [milk_run],
    [label_haz],
    [label_nonhaz],
    [label_class_3],
    [label_class_4_1],
    [label_class_5_1],
    [label_class_6_1],
    [label_class_8],
    [label_class_9],
    [void_date],
    [void_operator],
    [void_reason],
    [comments],
    [clean_tanker],
    [confined_space],
    [fresh_air],
    [load_count],
    [cust_discount],
    [invoice_comment_1],
    [invoice_comment_2],
    [invoice_comment_3],
    [invoice_comment_4],
    [invoice_comment_5],
    [ae_comments],
    [site_directions],
    [invoice_break_value],
    [problem_id],
    [project_id],
    [project_record_id],
    [include_cost_report_flag],
    [po_sequence_id],
    [billing_link_id],
    [other_submit_required_flag],
    [submit_on_hold_flag],
    [submit_on_hold_reason],
    [trip_id],
    [trip_sequence_id],
    [trip_eq_comment],
    [submitted_by],
    [date_submitted],
    [consolidated_pickup_flag],
    [field_download_date],
    [field_upload_date],
    [field_requested_action],
    [tractor_trailer_number],
    [ltl_title_comment],
    [created_by],
    [date_added],
    [modified_by],
    [date_modified],
    [workorder_type_id],
    [reference_code],
    [trip_stop_rate_flag],
    [generator_sublocation_ID],
    [combined_service_flag],
    [offschedule_service_flag],
    [offschedule_service_reason_ID],
    [trip_void_reasons_id],
    [AX_Dimension_5_Part_1],
    [AX_Dimension_5_Part_2],
    [currency_code],
    [workorderscheduletype_uid],
    [workorder_type_desc_uid],
    [corporate_revenue_classification_uid],
    [ticket_number],
    [tracking_id],
    [tracking_days],
    [tracking_bus_days],
    [tracking_contact],
    [salesforce_invoice_CSID]
    )
    select
    [workorder_ID],
    [company_id],
    [profit_ctr_ID],
    [revision],
    [workorder_status],
    [workorder_type],
    [submitted_flag],
    [customer_ID],
    [generator_id],
    [billing_project_id],
    [fixed_price_flag],
    [priced_flag],
    [total_price],
    [total_cost],
    [description],
    [template_code],
    [emp_arrive_time],
    [cust_arrive_time],
    [start_date],
    [end_date],
    [urgency_flag],
    [project_code],
    [project_name],
    [project_location],
    [contact_ID],
    @quote_ID,
    [purchase_order],
    [release_code],
    [milk_run],
    [label_haz],
    [label_nonhaz],
    [label_class_3],
    [label_class_4_1],
    [label_class_5_1],
    [label_class_6_1],
    [label_class_8],
    [label_class_9],
    [void_date],
    [void_operator],
    [void_reason],
    [comments],
    [clean_tanker],
    [confined_space],
    [fresh_air],
    [load_count],
    [cust_discount],
    [invoice_comment_1],
    [invoice_comment_2],
    [invoice_comment_3],
    [invoice_comment_4],
    [invoice_comment_5],
    [ae_comments],
    [site_directions],
    [invoice_break_value],
    [problem_id],
    [project_id],
    [project_record_id],
    [include_cost_report_flag],
    [po_sequence_id],
    [billing_link_id],
    [other_submit_required_flag],
    [submit_on_hold_flag],
    [submit_on_hold_reason],
    [trip_id],
    [trip_sequence_id],
    [trip_eq_comment],
    [submitted_by],
    [date_submitted],
    [consolidated_pickup_flag],
    [field_download_date],
    [field_upload_date],
    [field_requested_action],
    [tractor_trailer_number],
    [ltl_title_comment],
    [created_by],
    [date_added],
    [modified_by],
    [date_modified],
    [workorder_type_id],
    [reference_code],
    [trip_stop_rate_flag],
    [generator_sublocation_ID],
    [combined_service_flag],
    [offschedule_service_flag],
    [offschedule_service_reason_ID],
    [trip_void_reasons_id],
    [AX_Dimension_5_Part_1],
    [AX_Dimension_5_Part_2],
    [currency_code],
    [workorderscheduletype_uid],
    [workorder_type_desc_uid],
    [corporate_revenue_classification_uid],
    [ticket_number],
    [tracking_id],
    [tracking_days],
    [tracking_bus_days],
    [tracking_contact],
    [salesforce_invoice_CSID]
    from SFSWorkOrderHeader
    where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

    if @@ERROR <> 0
    begin
        set @is_success = 0
        set @as_message = 'ERROR: Insert into WorkOrderHeader failed'
        goto END_OF_PROC
    end

	--WorkOrderTracking
insert WorkOrderTracking (
[company_id],
[profit_ctr_id],
[workorder_id],
[tracking_id],
[tracking_status],
[tracking_contact],
[department_id],
[time_in],
[time_out],
[comment],
[business_minutes],
[added_by],
[date_added],
[modified_by],
[date_modified]
)
select
[company_id],
[profit_ctr_id],
[workorder_id],
[tracking_id],
[tracking_status],
[tracking_contact],
[department_id],
[time_in],
[time_out],
[comment],
[business_minutes],
[added_by],
[date_added],
[modified_by],
[date_modified]
from SFSWorkOrderTracking
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderTracking failed'
	goto END_OF_PROC
end

--WorkOrderStop
insert WorkorderStop (
[workorder_id],
[company_id],
[profit_ctr_id],
[stop_sequence_id],
[station_id],
[est_time_amt],
[est_time_unit],
[schedule_contact],
[schedule_contact_title],
[pickup_contact],
[pickup_contact_title],
[confirmation_date],
[waste_flag],
[decline_id],
[date_est_arrive],
[date_est_depart],
[date_act_arrive],
[date_act_depart],
[added_by],
[date_added],
[modified_by],
[date_modified],
[date_request_initiated],
[start_mileage],
[end_mileage]
)
select
[workorder_id],
[company_id],
[profit_ctr_id],
[stop_sequence_id],
[station_id],
[est_time_amt],
[est_time_unit],
[schedule_contact],
[schedule_contact_title],
[pickup_contact],
[pickup_contact_title],
[confirmation_date],
[waste_flag],
[decline_id],
[date_est_arrive],
[date_est_depart],
[date_act_arrive],
[date_act_depart],
[added_by],
[date_added],
[modified_by],
[date_modified],
[date_request_initiated],
[start_mileage],
[end_mileage]
from SFSWorkorderStop
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderStop failed'
	goto END_OF_PROC
end

--WorkOrderAudit
insert WorkOrderAudit (
[company_id],
[profit_ctr_id],
[Workorder_id],
[resource_type],
[sequence_id],
[table_name],
[column_name],
[before_value],
[after_value],
[audit_reference],
[modified_by],
[date_modified]
)
select
[company_id],
[profit_ctr_id],
[Workorder_id],
[resource_type],
[sequence_id],
[table_name],
[column_name],
[before_value],
[after_value],
[audit_reference],
[modified_by],
[date_modified]
from SFSWorkOrderAudit
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderAudit failed'
	goto END_OF_PROC
end


end


--SUCCESS:
commit transaction

------------------
--END OF PROC:
END_OF_PROC:
if @is_success = 0
	rollback transaction

select @is_success is_success, @as_message message
return 0

Go



GO

GO
GRANT EXECUTE on [dbo].[sp_sfdc_process_staging_workorderquote] to EQAI, svc_CorAppUser
GO
