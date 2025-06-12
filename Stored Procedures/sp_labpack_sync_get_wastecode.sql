CREATE procedure [dbo].[sp_labpack_sync_get_wastecode]
   @trip_connect_log_id int = null,
   @last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the WasteCode details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added @last_sync_dt argument

****************************************************************************************/

set transaction isolation level read uncommitted

select waste_code,
		waste_type_code,
		waste_code_desc,
		haz_flag,
		pcb_flag,
		waste_code_origin,
		state,
		waste_code_uid,
		display_name,
		sequence_id,
		status,
		date_added,
		date_modified
from WasteCode
where (date_added > coalesce(@last_sync_dt,'01/01/1980') or
	   date_modified > coalesce(@last_sync_dt,'01/01/1980'))