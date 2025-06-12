create procedure [dbo].[sp_labpack_sync_get_constituents]
   @trip_connect_log_id int = null,
   @last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the Constituent details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added @last_sync_dt argument

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
	const_id,
	const_desc,
	const_type,
	CAS_code,
	LDR_id,
	date_added,
	date_modified
from Constituents
where LDR_id > 0
and (date_added > coalesce(@last_sync_dt,'01/01/1980') or
	 date_modified > coalesce(@last_sync_dt,'01/01/1980'))
