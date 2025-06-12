use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_tsdfapprovaltemplate')
	drop procedure sp_labpack_sync_get_tsdfapprovaltemplate
go

create procedure [dbo].[sp_labpack_sync_get_tsdfapprovaltemplate]
	@last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDFApproval details

 loads to Plt_ai
 
 06/14/2021 - rb created

 EXEC sp_labpack_sync_get_tsdfapprovaltemplate
 EXEC sp_labpack_sync_get_tsdfapprovaltemplate '12:34:56'

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	ta.TSDF_approval_id,
	ta.company_id,
	ta.profit_ctr_id,
	ta.TSDF_code,
	ta.TSDF_approval_code,
	ta.waste_stream,
	ta.customer_id,
	ta.generator_id,
	ta.waste_desc,
	ta.TSDF_approval_status,
	ta.bulk_flag,
	ta.release_code,
	ta.generating_process,
	ta.comments,
	ta.reportable_quantity_flag,
	ta.RQ_reason,
	ta.DOT_shipping_name,
	ta.hazmat,
	ta.hazmat_class,
	ta.subsidiary_haz_mat_class,
	ta.UN_NA_flag,
	ta.UN_NA_number,
	ta.package_group,
	ta.ERG_number,
	ta.ERG_suffix,
	ta.waste_water_flag,
	ta.LDR_subcategory,
	ta.manifest_handling_code,
	ta.manifest_wt_vol_unit,
	ta.hand_instruct,
	ta.waste_managed_id,
	ta.placard_text,
	ta.manifest_container_code,
	ta.management_code,
	ta.land_ban_ref,
	ta.LDR_required,
	ta.gen_waste_stream_code,
	ta.consistency,
	ta.pH_range,
	ta.treatment_method,
	ta.regulatory_body_code,
	ta.EPA_form_code,
	ta.EPA_source_code,
	ta.EPA_haz_list_type,
	ta.export_code,
	ta.RCRA_haz_flag,
	ta.treatment_process_id,
	ta.disposal_service_id,
	ta.disposal_service_other_desc,
	ta.manifest_dot_sp_number,
	ta.rq_threshold,
	ta.manifest_message,
	ta.empty_bottle_flag,
	ta.residue_pounds_factor,
	ta.residue_manifest_print_flag,
	ta.print_dot_sp_flag,
	ta.dot_sp_permit_text,
	t.treatment_id,
	ta.manifest_actual_wt_flag,
	ta.empty_bottle_count_manifest_print_flag,
	ta.date_added,
	ta.date_modified,
	ta.DOT_shipping_desc_additional,
	dbo.fn_get_label_default_type('T', ta.TSDF_approval_id, ta.company_id, ta.profit_ctr_id, 0, 0) label_type,
	ta.process_code_uid,
	ta.created_from_template_tsdf_approval_id
from TSDFApproval ta
left outer join Treatment t
	on t.company_id = ta.company_id
	and t.profit_ctr_id = ta.profit_ctr_id
	and t.wastetype_id = ta.wastetype_id
	and t.treatment_process_id = ta.treatment_process_id
	and t.disposal_service_id = ta.disposal_service_id
where coalesce(ta.labpack_template_flag,'F') = 'T'
and (ta.date_added > coalesce(@last_sync_dt,'01/01/2000') or ta.date_modified > coalesce(@last_sync_dt,'01/01/2000'))
go

grant execute on sp_labpack_sync_get_tsdfapprovaltemplate to eqai
go
