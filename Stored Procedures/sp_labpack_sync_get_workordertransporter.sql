create procedure [dbo].[sp_labpack_sync_get_workordertransporter]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderTransporter details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	wt.workorder_id,
	wt.company_id,
	wt.profit_ctr_id,
	wt.manifest,
	wt.transporter_sequence_id,
	wt.transporter_code,
	wt.transporter_license_nbr,
	wt.date_added,
	wt.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderTransporter wt
	on wt.workorder_id = wh.workorder_id
	and wt.company_id = wh.company_id
	and wt.profit_ctr_id = wh.profit_ctr_id
where tcl.trip_connect_log_id = @trip_connect_log_id
