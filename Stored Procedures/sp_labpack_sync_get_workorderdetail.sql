create procedure [dbo].[sp_labpack_sync_get_workorderdetail]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderDetail details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added DOT_shipping_desc_additional column

****************************************************************************************/

set transaction isolation level read uncommitted

select wd.workorder_ID,
		wd.company_id,
		wd.profit_ctr_ID,
		wd.resource_type,
		wd.sequence_ID,
		wd.bill_rate,
		wd.description,
		wd.description_2,
		wd.TSDF_code,
		wd.TSDF_approval_code,
		wd.manifest,
		wd.manifest_page_num,
		wd.manifest_line,
		wd.container_count,
		wd.container_code,
		wd.waste_stream,
		wd.billing_sequence_id,
		wd.profile_id,
		wd.profile_company_id,
		wd.profile_profit_ctr_id,
		wd.TSDF_approval_id,
		wd.DOT_shipping_name,
		wd.manifest_hand_instruct,
		wd.manifest_waste_desc,
		wd.management_code,
		wd.reportable_quantity_flag,
		wd.RQ_reason,
		wd.hazmat,
		wd.hazmat_class,
		wd.subsidiary_haz_mat_class,
		wd.UN_NA_flag,
		wd.UN_NA_number,
		wd.package_group,
		wd.ERG_number,
		wd.ERG_suffix,
		wd.manifest_handling_code,
		wd.manifest_wt_vol_unit,
		wd.manifest_dot_sp_number,
		wd.date_added,
		wd.date_modified,
		wd.DOT_shipping_desc_additional
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and wd.resource_type = 'D'
where tcl.trip_connect_log_id = @trip_connect_log_id
