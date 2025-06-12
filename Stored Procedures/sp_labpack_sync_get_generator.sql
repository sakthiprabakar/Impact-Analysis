create procedure [dbo].[sp_labpack_sync_get_generator]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the Generator details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
		g.generator_id,
		g.EPA_ID,
		g.generator_type_id,
		g.status,
		g.generator_name,
		g.generator_address_1,
		g.generator_address_2,
		g.generator_address_3,
		g.generator_address_4,
		g.generator_address_5,
		g.generator_city,
		g.generator_state,
		g.generator_zip_code,
		g.generator_phone,
		g.generator_fax,
		g.gen_mail_name,
		g.gen_mail_addr1,
		g.gen_mail_addr2,
		g.gen_mail_addr3,
		g.gen_mail_addr4,
		g.gen_mail_state,
		g.gen_mail_city,
		g.gen_mail_country,
		g.gen_mail_zip_code,
		g.sic_code,
		g.generator_county,
		g.generator_country,
		g.site_type,
		g.site_code,
		g.NAICS_code,
		g.emergency_phone_number,
		g.DEA_ID,
		g.emergency_contract_number,
		g.manifest_waste_code_split_flag,
		g.date_added,
		g.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join Generator g
	on g.generator_id = wh.generator_id
where tcl.trip_connect_log_id = @trip_connect_log_id
