CREATE procedure [dbo].[sp_labpack_sync_get_constituentunit]
  -- @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ConstituentUnit details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select constituent_unit
from ConstituentUnit
