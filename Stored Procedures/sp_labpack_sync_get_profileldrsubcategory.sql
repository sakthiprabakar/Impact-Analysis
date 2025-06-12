create procedure [dbo].[sp_labpack_sync_get_profileldrsubcategory]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ProfileLDRSubcategory details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pls.profile_id,
	pls.ldr_subcategory_id,
	pls.date_added,
	pls.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join ProfileLDRSubcategory pls
	on pls.profile_id = wd.profile_id
join TSDF t
	on t.tsdf_code = wd.tsdf_code
	and coalesce(t.eq_flag,'F') = 'T'
where tcl.trip_connect_log_id = @trip_connect_log_id
