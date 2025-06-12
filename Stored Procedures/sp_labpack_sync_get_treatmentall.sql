create procedure [dbo].[sp_labpack_sync_get_treatmentall]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TreatmentAll details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	t.treatment_id,
	t.company_id,
	t.profit_ctr_id,
	t.status,
	t.treatment_desc,
	t.date_added,
	t.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and wd.resource_type = 'D'
join ProfileQuoteApproval pqa
	on pqa.profile_id = wd.profile_id
	and pqa.company_id = wd.profile_company_id
	and pqa.profit_ctr_id = wd.profile_profit_ctr_id
join Treatment t
	on t.treatment_id = pqa.treatment_id
	and t.company_id = pqa.company_id
	and t.profit_ctr_id = pqa.profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id