create procedure [dbo].[sp_labpack_sync_get_profitcenter]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ProfitCenter details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pc.company_ID,
	pc.profit_ctr_ID,
	pc.profit_ctr_name,
	pc.address_1,
	pc.address_2,
	pc.address_3,
	pc.phone,
	pc.fax,
	pc.EPA_ID,
	pc.short_name,
	pc.status,
	pc.default_manifest_state,
	pc.emergency_contact_phone,
	pc.air_permit_flag,
	pc.default_manifest_form_suffix,
	pc.date_added,
	pc.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join ProfitCenter pc
	on pc.company_id = wh.company_id
	and pc.profit_ctr_ID = wh.profit_ctr_ID
where tcl.trip_connect_log_id = @trip_connect_log_id