
create procedure sp_trip_sync_get_tsdfdearegistration
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDFDEARegistration table on a trip local database

 loads to Plt_ai
 
 05/16/2011 - rb created
 05/26/2011 - rb hotfix after deploy, need to return empty string for previous versions
 08/26/2011 - rb need to make select distinct, returning lots of duplicate rows
 06/13/2018 - rb GEM:51542 add support to sync TSDF_codes renamed in EQAI
 01/29/2020 - MPM - DevOps 13376 - Modified to truncate table and re-insert all rows from Plt_ai
				to prevent duplicate rows from being inserted in the local trip_client DB.

****************************************************************************************/

declare @s_version varchar(10),
		@dot int,
		@version numeric(6,2)

set nocount on

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

if @version >= 2.16
begin
	select 'truncate table TSDFDEARegistration' as sql 
	union
	select distinct 'insert into TSDFDEARegistration values('
	+ '''' + replace(TSDFDEARegistration.TSDF_code, '''', '''''') + '''' + ','
	+ '''' + replace(TSDFDEARegistration.state_abbr, '''', '''''') + '''' + ','
	+ convert(varchar(20),TSDFDEARegistration.sequence_id) + ','
	+ '''' + replace(TSDFDEARegistration.permit_license_registration, '''', '''''') + '''' + ','
	+ '''' + replace(TSDFDEARegistration.added_by, '''', '''''') + '''' + ','
	+ '''' + convert(varchar(20),TSDFDEARegistration.date_added,120) + '''' + ','
	+ '''' + replace(TSDFDEARegistration.modified_by, '''', '''''') + '''' + ','
	+ '''' + convert(varchar(20),TSDFDEARegistration.date_modified,120) + '''' + ')' as sql
	from TSDFDEARegistration
	order by sql
end
else
	select '' as sql

set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdfdearegistration] TO [EQAI]
    AS [dbo];

