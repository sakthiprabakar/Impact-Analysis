create procedure [dbo].[sp_labpack_sync_get_profilequotedetail]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ProfileQuoteDetail details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	pqd.quote_id,
	pqd.profile_id,
	pqd.company_id,
	pqd.profit_ctr_id,
	pqd.status,
	pqd.sequence_id,
	pqd.record_type,
	pqd.bill_unit_code,
	pqd.price,
	pqd.service_desc,
	pqd.date_added,
	pqd.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join ProfileQuoteDetail pqd
	on pqd.profile_id = wd.profile_id
	and pqd.company_id = wd.profile_company_id
	and pqd.profit_ctr_id = wd.profile_profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id
