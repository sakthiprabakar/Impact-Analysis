CREATE procedure [dbo].[sp_labpack_sync_get_ldrsubcategory]
   --@trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the LDRSubcategory details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select subcategory_id,
		short_desc
from LDRSubcategory
