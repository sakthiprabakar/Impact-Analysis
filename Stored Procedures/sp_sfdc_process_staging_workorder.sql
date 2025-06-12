USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_process_staging_workorder]    Script Date: 10/14/2024 3:29:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[sp_sfdc_process_staging_workorder]
	@salesforce_invoice_csid varchar(18)
as
/*********************
 *
 * 03/04/2024 - rwb - Created
 * 06/12/2024 - rwb - Rally DE34339 - Need to populate new resource_uid column
 * 08/07/2024 - rwb - Rally TA431213 - Add SFSWorkOrderManifest and SFSWorkOrderDetailUnit
 * 08/09/2024  -Venu - US#118337 - conditional basis workorder insert handled
 * 09/30/2024  -Venu - DE35881  - For disposal record addtional table entires are added conditional workordertracking and workorderstop
 * 10/10/2024  -Venu  - DE35912  - During Disposal line submit if user manualy create the manifest in EQAI UI then that should not insert once again instead we need to update.
 * 10/22/2024  -Nagaraj M - DE36013 - Inserting the audit records during workorderheader creation itself.
 *********************/

declare
	@sfs_workorderheader_uid int,
    @sfs_workorderdetail_uid int,
	@is_success int,
	@as_message varchar(255),
	@sql varchar(255),
	@ll_workorder_cnt int,
	@workorder_id_ret int,
	@MANIFEST varchar(15),
	@company_id int,
	@profit_ctr_ID int,
	@ll_cnt_manifest_woh int,
	@manifest_state_ret char(2),
	@manifest_flag_ret char(1),
	@modified_by_ret varchar(40)

set @is_success = 1
set @as_message = 'SUCCESS'
set transaction isolation level read uncommitted

begin transaction

select @sfs_workorderheader_uid = max([sfs_workorderheader_uid])
from SFSWorkOrderHeader
where [salesforce_invoice_csid] = @salesforce_invoice_csid

if coalesce(@sfs_workorderheader_uid,0) < 1
begin
	set @is_success = 0
	set @as_message = 'ERROR: Salesforce invoice CSID ' + @salesforce_invoice_csid + ' not found in SFSWorkOrderHeader'
	goto END_OF_PROC
end

Select @ll_workorder_cnt= count(*) from workorderheader where salesforce_invoice_csid=@salesforce_invoice_csid

If @ll_workorder_cnt=0
Begin
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


End


--WorkOrderDetail (must use a cursor because a bulk update raises an error in an insert trigger)
declare c_loop cursor fast_forward for
select sfs_workorderdetail_uid
from dbo.SFSWorkOrderDetail
where sfs_workorderheader_uid = @sfs_workorderheader_uid

open c_loop
fetch c_loop into @sfs_workorderdetail_uid

while @@FETCH_STATUS = 0
begin
	insert WorkOrderDetail (
	[workorder_ID],
	[company_id],
	[profit_ctr_ID],
	[resource_type],
	[sequence_ID],
	[resource_class_code],
	[resource_assigned],
	[bill_unit_code],
	[price],
	[cost],
	[quantity],
	[quantity_used],
	[bill_rate],
	[description],
	[description_2],
	[price_class],
	[price_source],
	[cost_class],
	[cost_source],
	[priced_flag],
	[group_instance_id],
	[group_code],
	[requested_by],
	[TSDF_code],
	[TSDF_approval_code],
	[manifest],
	[manifest_page_num],
	[manifest_line],
	[manifest_line_id],
	[container_count],
	[container_code],
	[waste_stream],
	[confirmation_number],
	[scheduled_time],
	[disposal_scheduled],
	[disposal_sequence_ID],
	[requisition],
	[TSDF_approval_bill_unit_code],
	[billing_sequence_id],
	[profile_id],
	[profile_company_id],
	[profile_profit_ctr_id],
	[TSDF_approval_id],
	[DOT_shipping_name],
	[manifest_hand_instruct],
	[manifest_waste_desc],
	[management_code],
	[reportable_quantity_flag],
	[RQ_reason],
	[hazmat],
	[hazmat_class],
	[subsidiary_haz_mat_class],
	[UN_NA_flag],
	[UN_NA_number],
	[package_group],
	[ERG_number],
	[ERG_suffix],
	[manifest_handling_code],
	[manifest_wt_vol_unit],
	[extended_price],
	[extended_cost],
	[print_on_invoice_flag],
	[drmo_clin_num],
	[drmo_hin_num],
	[drmo_doc_num],
	[transfer_flag],
	[transfer_company_id],
	[transfer_profit_ctr_id],
	[field_requested_action],
	[manifest_dot_sp_number],
	[added_by],
	[date_added],
	[modified_by],
	[date_modified],
	[currency_code],
	[DOT_waste_flag],
	[DOT_shipping_desc_additional],
	[class_7_additional_desc],
	[date_service],
	[prevailing_wage_code],
	[salesforce_bundle_id],
	[salesforce_invoice_line_id],
	[salesforce_task_name],
    [resource_uid],
	[cost_quantity]
	)
	select
	[workorder_ID],
	[company_id],
	[profit_ctr_ID],
	[resource_type],
	[sequence_ID],
	[resource_class_code],
	[resource_assigned],
	[bill_unit_code],
	[price],
	[cost],
	[quantity],
	[quantity_used],
	[bill_rate],
	[description],
	[description_2],
	[price_class],
	[price_source],
	[cost_class],
	[cost_source],
	[priced_flag],
	[group_instance_id],
	[group_code],
	[requested_by],
	[TSDF_code],
	[TSDF_approval_code],
	[manifest],
	[manifest_page_num],
	[manifest_line],
	[manifest_line_id],
	[container_count],
	[container_code],
	[waste_stream],
	[confirmation_number],
	[scheduled_time],
	[disposal_scheduled],
	[disposal_sequence_ID],
	[requisition],
	[TSDF_approval_bill_unit_code],
	[billing_sequence_id],
	[profile_id],
	[profile_company_id],
	[profile_profit_ctr_id],
	[TSDF_approval_id],
	[DOT_shipping_name],
	[manifest_hand_instruct],
	[manifest_waste_desc],
	[management_code],
	[reportable_quantity_flag],
	[RQ_reason],
	[hazmat],
	[hazmat_class],
	[subsidiary_haz_mat_class],
	[UN_NA_flag],
	[UN_NA_number],
	[package_group],
	[ERG_number],
	[ERG_suffix],
	[manifest_handling_code],
	[manifest_wt_vol_unit],
	[extended_price],
	[extended_cost],
	[print_on_invoice_flag],
	[drmo_clin_num],
	[drmo_hin_num],
	[drmo_doc_num],
	[transfer_flag],
	[transfer_company_id],
	[transfer_profit_ctr_id],
	[field_requested_action],
	[manifest_dot_sp_number],
	[added_by],
	[date_added],
	[modified_by],
	[date_modified],
	[currency_code],
	[DOT_waste_flag],
	[DOT_shipping_desc_additional],
	[class_7_additional_desc],
	[date_service],
	[prevailing_wage_code],
	[salesforce_bundle_id],
	[salesforce_invoice_line_id],
	[salesforce_task_name],
    [resource_uid],
	[cost_quantity]
	from SFSWorkOrderDetail
	where [sfs_workorderdetail_uid] = @sfs_workorderdetail_uid

    if @@ERROR <> 0
    begin
        close c_loop
        deallocate c_loop
        set @is_success = 0
        set @as_message = 'ERROR: Insert into WorkOrderDetail failed'
        goto END_OF_PROC
    end

	fetch c_loop into @sfs_workorderdetail_uid
end

close c_loop
deallocate c_loop



--WorkorderManifest (must use a cursor because a multiple manifest or same manifest should not insert twice hence handled update too)
declare c_loop cursor fast_forward for
select WORKORDER_ID,MANIFEST,company_id,profit_ctr_ID,manifest_state,manifest_flag,modified_by
from dbo.SFSWorkorderManifest
where sfs_workorderheader_uid = @sfs_workorderheader_uid

open c_loop
fetch c_loop into @workorder_id_ret,@MANIFEST,@company_id,@profit_ctr_ID,@manifest_state_ret,@manifest_flag_ret,@modified_by_ret

while @@FETCH_STATUS = 0
begin

SELECT @ll_cnt_manifest_woh=COUNT(*) FROM  WorkorderManifest WHERE
																WORKORDER_ID=@workorder_id_ret
																AND MANIFEST=TRIM(@MANIFEST)
																and company_id=@company_id
																and profit_ctr_ID=@profit_ctr_ID
										

If @ll_cnt_manifest_woh=0
Begin
--WorkOrderManifest
insert WorkOrderManifest (
[workorder_ID],
[company_id],
[profit_ctr_ID],
[manifest],
[manifest_flag],
[EQ_flag],
[manifest_state],
[gen_manifest_doc_number],
[date_delivered],
[discrepancy_flag],
[discrepancy_desc],
[discrepancy_resolution],
[discrepancy_resolution_date],
[continuation_flag],
[site_id],
[added_by],
[date_added],
[modified_by],
[date_modified],
[discrepancy_qty_flag],
[discrepancy_type_flag],
[discrepancy_residue_flag],
[discrepancy_part_reject_flag],
[discrepancy_full_reject_flag],
[missed_load_flag],
[generator_sign_name],
[generator_sign_date]
)
select
[workorder_ID],
[company_id],
[profit_ctr_ID],
[manifest],
[manifest_flag],
[EQ_flag],
[manifest_state],
[gen_manifest_doc_number],
[date_delivered],
[discrepancy_flag],
[discrepancy_desc],
[discrepancy_resolution],
[discrepancy_resolution_date],
[continuation_flag],
[site_id],
[added_by],
[date_added],
[modified_by],
[date_modified],
[discrepancy_qty_flag],
[discrepancy_type_flag],
[discrepancy_residue_flag],
[discrepancy_part_reject_flag],
[discrepancy_full_reject_flag],
[missed_load_flag],
[generator_sign_name],
[generator_sign_date]
from SFSWorkOrderManifest
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid and
WORKORDER_ID=@workorder_id_ret and
MANIFEST=TRIM(@MANIFEST) and
company_id=@company_id and
profit_ctr_ID=@profit_ctr_ID

End
if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderManifest failed'
	goto END_OF_PROC
end

If @ll_cnt_manifest_woh > 0
Begin



update WorkorderManifest set 
			manifest_state= ' ' + @manifest_state_ret,
			manifest_flag=@manifest_flag_ret,
			modified_by=@modified_by_ret,
			date_modified=getdate()			
			where
			manifest=trim(@manifest) and
			company_id=@company_id and
			profit_Ctr_id=@profit_Ctr_id and
			(
			ISNULL(NULLIF(manifest_state, 'NA'), '') <> ISNULL(NULLIF(@manifest_state_ret, 'NA'), '') or
			ISNULL(NULLIF(manifest_flag, 'NA'), '') <> ISNULL(NULLIF(@manifest_flag_ret, 'NA'), '') 
			) and
			WORKORDER_ID=@workorder_id_ret
	
	if @@ERROR <> 0
	begin
		set @is_success = 0
		set @as_message = 'ERROR: Update into WorkOrderManifest failed'
		goto END_OF_PROC
	end


End

fetch c_loop into @workorder_id_ret,@MANIFEST,@company_id,@profit_ctr_ID,@manifest_state_ret,@manifest_flag_ret,@modified_by_ret
end

close c_loop
deallocate c_loop

--WorkOrderDetailUnit
insert WorkOrderDetailUnit (
[workorder_id],
[company_id],
[profit_ctr_id],
[sequence_id],
[size],
[bill_unit_code],
[quantity],
[cost],
[cost_source],
[extended_cost],
[price],
[price_source],
[extended_price],
[manifest_flag],
[billing_flag],
[priced_flag],
[requested_by],
[added_by],
[date_added],
[modified_by],
[date_modified],
[currency_code]
)
select
[workorder_id],
[company_id],
[profit_ctr_id],
[sequence_id],
[size],
[bill_unit_code],
[quantity],
[cost],
[cost_source],
[extended_cost],
[price],
[price_source],
[extended_price],
[manifest_flag],
[billing_flag],
[priced_flag],
[requested_by],
[added_by],
[date_added],
[modified_by],
[date_modified],
[currency_code]
from SFSWorkOrderDetailUnit
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into WorkOrderDetailUnit failed'
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
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into Note failed'
	goto END_OF_PROC
end


--ScanImage
select @sql = [current_database]
from Plt_image..ScanCurrentDB

set @sql = 'insert ' + @sql
+ '.dbo.ScanImage (
[image_id],
[image_blob]
)
select
[image_id],
[image_blob]
from SFSScanImage
where [sfs_workorderheader_uid] = ' + convert(varchar(10),@sfs_workorderheader_uid)

execute(@sql)

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into ScanImage failed'
	goto END_OF_PROC
end

--Scan
insert Plt_image.dbo.Scan (
[company_id],
[profit_ctr_id],
[image_id],
[document_source],
[type_id],
[status],
[document_name],
[date_added],
[date_modified],
[added_by],
[modified_by],
[date_voided],
[customer_id],
[receipt_id],
[manifest],
[manifest_flag],
[approval_code],
[workorder_id],
[generator_id],
[invoice_print_flag],
[image_resolution],
[scan_file],
[description],
[form_id],
[revision_id],
[form_version_id],
[form_type],
[file_type],
[profile_id],
[page_number],
[print_in_file],
[view_on_web],
[app_source],
[upload_date],
[merchandise_id],
[trip_id],
[batch_id],
[TSDF_code],
[TSDF_approval_id],
[quote_id],
[loc_code],
[man_sys_number],
[work_order_number]
)
select
[company_id],
[profit_ctr_id],
[image_id],
[document_source],
[type_id],
[status],
[document_name],
[date_added],
[date_modified],
[added_by],
[modified_by],
[date_voided],
[customer_id],
[receipt_id],
[manifest],
[manifest_flag],
[approval_code],
[workorder_id],
[generator_id],
[invoice_print_flag],
[image_resolution],
[scan_file],
[description],
[form_id],
[revision_id],
[form_version_id],
[form_type],
[file_type],
[profile_id],
[page_number],
[print_in_file],
[view_on_web],
[app_source],
[upload_date],
[merchandise_id],
[trip_id],
[batch_id],
[TSDF_code],
[TSDF_approval_id],
[quote_id],
[loc_code],
[man_sys_number],
[work_order_number]
from SFSScan
where [sfs_workorderheader_uid] = @sfs_workorderheader_uid

if @@ERROR <> 0
begin
	set @is_success = 0
	set @as_message = 'ERROR: Insert into Scan failed'
	goto END_OF_PROC
end


------------------
--SUCCESS:
------------------
commit transaction

------------------
--END OF PROC:
------------------
END_OF_PROC:
if @is_success = 0
	rollback transaction

select @is_success is_success, @as_message message
return 0

Go


go

GRANT EXECUTE on [dbo].[sp_sfdc_process_staging_workorder] to EQAI, svc_CorAppUser
GO
