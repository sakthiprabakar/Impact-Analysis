CREATE procedure [dbo].[sp_labpack_sync_get_ldrwastemanaged]
   --@trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the LDRWasteManaged details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select waste_managed_id,
		version,
		waste_managed_flag,
		contains_listed,
		exhibits_characteristic,
		soil_treatment_standards,
		underlined_text,
		regular_text,
		sort_order,
		date_created,
		date_modified
 from LDRWasteManaged