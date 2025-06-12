use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_profile')
	drop procedure sp_labpack_sync_get_profile
go

create procedure [dbo].[sp_labpack_sync_get_profile]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the Profile details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added DOT_shipping_desc_additional column
 04/01/2021 - rb added label_type column
 06/09/2021 - rb added LabPack template columns
 08/03/2021 - rb added LDR underlined_text and regular_text

 EXEC sp_labpack_sync_get_profile 12345

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	p.profile_id,
	p.customer_id,
	p.generator_id,
	p.approval_desc,
	p.tracking_type,
	p.broker_flag,
	p.bulk_flag,
	p.OTS_flag,
	p.transship_flag,
	p.generic_flag,
	p.labpack_flag,
	convert(varchar(max),p.hand_instruct) hand_instruct,
	convert(varchar(max),p.approval_comments) approval_comments,
	convert(varchar(max),p.comments_1) comments_1,
	convert(varchar(max),p.comments_2) comments_2,
	convert(varchar(max),p.comments_3) comments_3,
	convert(varchar(max),p.schedule_comments) schedule_comments,
	convert(varchar(max),p.lab_comments) lab_comments,
	p.reportable_quantity_flag,
	p.RQ_reason,
	p.DOT_shipping_name,
	p.hazmat,
	p.hazmat_class,
	p.subsidiary_haz_mat_class,
	p.UN_NA_flag,
	p.UN_NA_number,
	p.package_group,
	p.ERG_number,
	p.ERG_suffix,
	p.waste_water_flag,
	p.LDR_subcategory,
	p.manifest_handling_code,
	p.manifest_wt_vol_unit,
	p.manifest_hand_instruct,
	p.waste_managed_id,
	p.RCRA_haz_flag,
	p.EPA_form_code,
	p.EPA_source_code,
	p.disposition_id,
	p.rq_threshold,
	p.manifest_dot_sp_number,
	p.manifest_message,
	p.empty_bottle_flag,
	p.residue_pounds_factor,
	p.residue_manifest_print_flag,
	p.gen_process,
	p.dea_flag,
	p.dot_sp_permit_text,
	p.manifest_actual_wt_flag,
	p.empty_bottle_count_manifest_print_flag,
	p.pharmaceutical_flag,
	p.mim_customer_label_flag,
	p.date_added,
	p.date_modified,
	p.DOT_shipping_desc_additional,
	dbo.fn_get_label_default_type('P', p.profile_id, wh.company_id, wh.profit_ctr_id, 0, 0) label_type,
	p.process_code_uid,
	p.created_from_template_profile_id,
	convert(varchar(max),coalesce(case ldr.waste_managed_flag when'S' 
		then REPLACE(
				REPLACE(
					REPLACE(
						CONVERT(varchar(2000), ldr.underlined_text), 
						'|contains_listed:DOES:DOES NOT|', ldr.contains_listed), 
					'|exhibits_characteristic:DOES:DOES NOT|', ldr.exhibits_characteristic), 
				'|soil_treatment_standards:IS SUBJECT TO:COMPLIES WITH|', ldr.soil_treatment_standards)
		else ldr.underlined_text
		end,'')) ldr_underlined_text,
	convert(varchar(max),coalesce(ldr.regular_text,'')) ldr_regular_text,
	coalesce(p.manifest_waste_desc,'') manifest_waste_desc
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join Profile p
	on p.profile_id = wd.profile_id
	and coalesce(p.labpack_template_flag,'F') <> 'T'
left outer join LDRWasteManaged ldr
	on ldr.waste_managed_id = p.waste_managed_id
	and ldr.version = (select max(version) from LDRWasteManaged where waste_managed_id = p.waste_managed_id)
where tcl.trip_connect_log_id = @trip_connect_log_id
go

grant execute on sp_labpack_sync_get_profile to eqai
go
