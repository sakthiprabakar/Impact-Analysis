
create or alter procedure [dbo].[sp_trip_sync_get_generator]
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Generator table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/01/2010 - rb new column added, DEA_ID
 12/13/2010 - rb when a stop was added to a trip and generator changed, record was not
                 being pulled
 07/15/2013 - rb Waste Code conversion Phase II...support for new display/status columns
 06/23/2014 - rb Added convert(varchar(5),...) to manifest_waste_code_split_flag, 'null' was being truncated to 'nul'
 04/21/2025 - mm Rally TA537270 - Modified to align with Generator table changes.
****************************************************************************************/

declare @s_version varchar(10),
		@dot int,
		@version numeric(6,2)

set transaction isolation level read uncommitted

select @s_version = tcca.client_app_version
from TripConnectLog tcl, TripConnectClientApp tcca
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_client_app_id = tcca.trip_client_app_id

select @dot = CHARINDEX('.',@s_version)
if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)

select 'delete from Generator where generator_id = ' + convert(varchar(20),Generator.generator_id)
+ ' insert into Generator values('
+ convert(varchar(20),Generator.generator_id) + ','
+ isnull('''' + replace(Generator.EPA_ID, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Generator.generator_type_id),'null') + ','
+ isnull('''' + replace(Generator.status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_address_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_address_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_address_3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_address_4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_address_5, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_phone, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_fax, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LEFT(Generator.added_by, 10), '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Generator.date_added,120) + '''','null') + ','
+ isnull('''' + replace(LEFT(Generator.modified_by, 10), '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Generator.date_modified,120) + '''','null') + ','
+ isnull(convert(varchar(20),Generator.sic_code),'null') + ','
+ isnull('''' + replace(Generator.source, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_addr1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_addr2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_addr3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_addr4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_addr5, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Generator.gen_directions), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_state, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Generator.generator_county),'null') + ','
+ isnull('''' + replace(Generator.generator_country, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.site_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.site_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.state_id, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_city, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.generator_zip_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_city, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_state, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.gen_mail_zip_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.reporting_status, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Generator.TAB),'null') + ','
+ isnull(convert(varchar(20),Generator.NAICS_code),'null') + ','
+ isnull('''' + replace(Generator.eq_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Generator.eq_company),'null') + ','
+ isnull(convert(varchar(20),Generator.eq_profit_ctr),'null') + ','
+ isnull('''' + replace(Generator.outbound_restricted, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Generator.emergency_phone_number, '''', '''''') + '''','null')
+ case when @version < 2.02 then '' else ',' + isnull('''' + replace(Generator.DEA_ID, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(Generator.emergency_contract_number, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull(convert(varchar(5),'''' + Generator.manifest_waste_code_split_flag + ''''),'null') end
+ ')' as sql
from Generator, WorkOrderHeader, TripConnectLog
where Generator.generator_id = WorkOrderHeader.generator_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Generator.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_generator] TO [EQAI];

