CREATE procedure [dbo].[sp_labpack_sync_get_transporter]
   @trip_connect_log_id int = null,
   @last_sync_dt datetime = null
as
/***************************************************************************************
 this procedure retrieves the Transporter details

 loads to Plt_ai
 
 11/04/2019 - rb created
 02/15/2021 - rb added @last_sync_dt argument
****************************************************************************************/

set transaction isolation level read uncommitted

select Transporter_code,
		Transporter_status,
		Transporter_name,
		Transporter_addr1,
		Transporter_addr2,
		Transporter_addr3,
		Transporter_EPA_ID,
		Transporter_phone,
		Transporter_fax,
		Transporter_contact,
		Transporter_contact_phone,
		comments,
		DOT_id,
		Transporter_city,
		Transporter_state,
		Transporter_zip_code,
		Transporter_country,
		date_added,
		date_modified
from Transporter
where isnull(Transporter_status,'I') = 'A'
and (date_added > coalesce(@last_sync_dt,'01/01/1980') or
	 date_modified > coalesce(@last_sync_dt,'01/01/1980'))
