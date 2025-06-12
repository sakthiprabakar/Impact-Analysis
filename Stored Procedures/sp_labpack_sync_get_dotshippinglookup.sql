CREATE procedure [dbo].[sp_labpack_sync_get_dotshippinglookup]
   --@trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the DOTShippingLookup details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select DOT_shipping_name,
		hazmat_flag,
		hazmat_class,
		sub_hazmat_class,
		UN_NA_flag,
		UN_NA_number,
		packing_group,
		ERG_number,
		ERG_suffix
from DOTShippingLookup
