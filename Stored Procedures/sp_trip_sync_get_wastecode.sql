
create procedure sp_trip_sync_get_wastecode
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WasteCode table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 08/12/2009 - added limitation by generator destination state
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 07/25/2010 - rb where clause needs to check for workorderdetail record being added as well
 08/15/2012 - rb Version 3.0 LabPack .. pull entire table for LabPack trip
 10/18/2012 - rb Merge changes for Forms project, rowguid was removed from Wastecode table
 04/17/2013 - rb Waste Code conversion...added waste_code_uid for version 3.06 forward
 07/15/2013 - rb Waste Code conversion Phase II...support for new display/status columns
 08/28/2015 - rb More efficient to just refresh the table
 08/11/2020 - mm DevOps 16792 - Added table WasteCodeXGenerator, because I added TX state 
			  waste code logic from EQAI's fn_tbl_manifest_waste_codes_receipt_wo, and that
			  logic requires WasteCodeXGenerator.
****************************************************************************************/

declare @last_download_date datetime,
	@s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set transaction isolation level read uncommitted


select @last_download_date = tcl.last_download_date,
	@s_version = tcca.client_app_version
from TripConnectLog tcl, TripConnectClientApp tcca
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_client_app_id = tcca.trip_client_app_id

select @dot = CHARINDEX('.',@s_version)
if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)


if @last_download_date is null
	or exists (select 1 from WasteCode where date_added > @last_download_date or date_modified > @last_download_date)

	select 'truncate table WasteCode' as sql
	union
	select 'insert into WasteCode values('
	+ '''' + replace(WasteCode.waste_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(WasteCode.waste_type_code, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(WasteCode.waste_code_desc, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(WasteCode.haz_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(WasteCode.pcb_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(WasteCode.waste_code_origin, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(WasteCode.state, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WasteCode.date_added,120) + '''','null') + ','
	+ isnull('''' + replace(WasteCode.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WasteCode.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(WasteCode.modified_by, '''', '''''') + '''','null')
	+ ',null'
	+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),WasteCode.waste_code_uid),'null') end
	+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(WasteCode.display_name, '''', '''''') + '''','null') end
	+ case when @version < 3.08 then '' else ',' + isnull(convert(varchar(20),WasteCode.sequence_id),'null') end
	+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(WasteCode.status, '''', '''''') + '''','null') end
	+ ')' as sql
	from WasteCode
	union
	select case when @version < 4.72 then '' else 'truncate table WasteCodeXGenerator' end as sql
	union
	select case when @version < 4.72 then '' else 'insert into WasteCodeXGenerator values('
	+ isnull(convert(varchar(20),WasteCodeXGenerator.waste_code_uid),'null') + ','
	+ isnull(convert(varchar(20),WasteCodeXGenerator.generator_id),'null') + ','
	+ isnull('''' + replace(WasteCodeXGenerator.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WasteCodeXGenerator.date_added,120) + '''','null') + ','
	+ isnull('''' + replace(WasteCodeXGenerator.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),WasteCodeXGenerator.date_modified,120) + '''','null') + ')' end as sql
	 from WasteCodeXGenerator
	order by sql desc
else
	select '' as sql

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_wastecode] TO [EQAI]
    AS [dbo];

