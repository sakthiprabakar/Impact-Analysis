CREATE procedure [dbo].[sp_labpack_sync_get_company]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the Company details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted


select distinct
	c.company_id,
	c.company_name,
	c.address_1,
	c.address_2,
	c.address_3,
	c.phone,
	c.fax,
	c.EPA_ID,
	c.date_added,
	c.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id= tcl.trip_id
join Company c
	on c.company_id = wh.company_id
where tcl.trip_connect_log_id = @trip_connect_log_id
