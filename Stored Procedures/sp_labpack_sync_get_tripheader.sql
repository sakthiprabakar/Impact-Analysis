create procedure [dbo].[sp_labpack_sync_get_tripheader]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the TripHeader details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select th.trip_id,
		th.company_id,
		th.profit_ctr_id,
		th.trip_status,
		th.trip_pass_code,
		th.trip_start_date,
		th.trip_end_date,
		th.type_code,
		th.trip_desc,
		th.template_name,
		th.transporter_code,
		th.resource_code,
		th.driver_company,
		th.driver_name,
		th.drivers_license_CDL,
		th.truck_DOT_number,
		th.upload_merchandise_ind,
		th.use_manifest_haz_only_flag,
		th.lab_pack_flag,
		th.tractor_number,
		th.trailer_number,
		th.date_added,
		th.date_modified
from TripConnectLog tcl
join TripHeader th
	on th.trip_id = tcl.trip_id
where tcl.trip_connect_log_id = @trip_connect_log_id
