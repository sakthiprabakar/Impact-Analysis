CREATE procedure [dbo].[sp_labpack_sync_get_billunit]
  -- @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the BillUnit table (full replacement)

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select bill_unit_code,
		bill_unit_desc,
		disposal_flag,
		coalesce(gal_conv,'') gal_conv,
		coalesce(yard_conv,'') yard_conv,
		coalesce(kg_conv,'') kg_conv,
		coalesce(pound_conv,'') pound_conv,
		coalesce(manifest_unit,'') manifest_unit,
		date_added,
		date_modified
from BillUnit
where container_flag = 'T'