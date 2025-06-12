CREATE procedure [dbo].[sp_labpack_sync_get_tsdf]
   @trip_connect_log_id int = null,
   @last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the TSDF details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added @last_sync_dt argument

****************************************************************************************/

set transaction isolation level read uncommitted

select TSDF_code,
		TSDF_status,
		TSDF_name,
		TSDF_addr1,
		TSDF_addr2,
		TSDF_addr3,
		TSDF_EPA_ID,
		TSDF_phone,
		TSDF_fax,
		TSDF_contact,
		TSDF_contact_phone,
		TSDF_city,
		TSDF_state,
		TSDF_zip_code,
		emergency_contact_phone,
		eq_flag,
		eq_company,
		eq_profit_ctr,
		directions,
		comments,
		DEA_ID,
		DEA_phone,
		date_added,
		date_modified
from TSDF
where (date_added > coalesce(@last_sync_dt,'01/01/1980') or
	   date_modified > coalesce(@last_sync_dt,'01/01/1980'))
