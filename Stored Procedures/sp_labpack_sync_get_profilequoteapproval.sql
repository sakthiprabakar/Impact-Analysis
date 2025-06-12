create procedure [dbo].[sp_labpack_sync_get_profilequoteapproval]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ProfileQuoteApproval details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pqa.quote_id,
	pqa.profile_id,
	pqa.company_id,
	pqa.profit_ctr_id,
	pqa.status,
	pqa.primary_facility_flag,
	pqa.approval_code,
	pqa.treatment_id,
	pqa.LDR_req_flag,
	pqa.print_dot_sp_flag,
	pqa.consolidate_containers_flag,
	pqa.consolidation_group_uid,
	pqa.air_permit_status_uid,
	pqa.date_added,
	pqa.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join ProfileQuoteApproval pqa
	on pqa.profile_id = wd.profile_id
	and pqa.company_id = wd.profile_company_id
	and pqa.profit_ctr_id = wd.profile_profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id