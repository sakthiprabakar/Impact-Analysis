CREATE procedure [dbo].[sp_labpack_sync_get_managementcode]
   --@trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ManagementCode details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select management_code,
		management_description
from ManagementCode
where status = 'A'
