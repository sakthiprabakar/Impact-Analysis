
create procedure sp_trip_sync_get_tsdf
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDF table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/01/2010 - rb new column, DEA_ID
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
 05/13/2011 - rb new column, DEA_phone
 08/15/2012 - rb Version 3.0 LabPack .. pull entire table for LabPack trip
 06/13/2018 - rb GEM:51542 add support to sync TSDF_codes renamed in EQAI
 09/11/2018 - rb Correction made for GEM:51542 to correct duplicate TSDFs after downloading a trip, before first sync

****************************************************************************************/

declare @s_version varchar(10),
	@dot int,
	@version numeric(6,2),
	@lab_pack_flag char(1),
	@last_download_date datetime

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

select @lab_pack_flag = isnull(th.lab_pack_flag,'F')
from TripHeader th
join TripConnectLog tcl
	on tcl.trip_id = th.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id


-- for labpack, pull entire table
if @lab_pack_flag = 'T' and (@last_download_date is null
			or exists (select 1 from TripConnectLog tcl
				join WorkOrderHeader wh on tcl.trip_id = wh.trip_id
							and wh.field_requested_action = 'R'
				where tcl.trip_connect_log_id = @trip_connect_log_id))


	select 'truncate table TSDF' as sql
	union
	select 'insert into TSDF values('
	+ '''' + replace(TSDF.TSDF_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TSDF.TSDF_status, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_name, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr1, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr2, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr3, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_EPA_ID, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_fax, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_contact, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_city, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_state, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_zip_code, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.state_regulatory_id, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.facility_type, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.emergency_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.eq_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),TSDF.eq_company),'null') + ','
	+ isnull(convert(varchar(20),TSDF.eq_profit_ctr),'null') + ','
	+ isnull('''' + replace(TSDF.directions, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.comments, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TSDF.date_added,120) + '''','null') + ','
	+ isnull('''' + replace(TSDF.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TSDF.date_modified,120) + '''','null') + ','
	+ '''' + replace(TSDF.rowguid, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TSDF.DEA_ID, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.DEA_phone, '''', '''''') + '''','null') + ')' as sql
	from TSDF
	order by sql desc
else
	select distinct 'delete from TSDF where TSDF_code = ''' + wd.tsdf_code + '''' as sql
	from WorkOrderDetail wd
	join WorkOrderHeader wh
		on wh.workorder_id = wd.workorder_id
		and wh.company_id = wd.company_id
		and wh.profit_ctr_id = wd.profit_ctr_id
	join TripConnectLog tcl
		on tcl.trip_id = wh.trip_id
		and tcl.trip_connect_log_id = @trip_connect_log_id
	where wd.resource_type = 'D'
	and coalesce(wd.tsdf_code,'') <> ''
	union
	select distinct 'insert into TSDF values('
	+ '''' + replace(TSDF.TSDF_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TSDF.TSDF_status, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_name, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr1, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr2, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_addr3, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_EPA_ID, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_fax, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_contact, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_city, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_state, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.TSDF_zip_code, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.state_regulatory_id, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.facility_type, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.emergency_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.eq_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),TSDF.eq_company),'null') + ','
	+ isnull(convert(varchar(20),TSDF.eq_profit_ctr),'null') + ','
	+ isnull('''' + replace(TSDF.directions, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.comments, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TSDF.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TSDF.date_added,120) + '''','null') + ','
	+ isnull('''' + replace(TSDF.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TSDF.date_modified,120) + '''','null') + ','
	+ '''' + replace(TSDF.rowguid, '''', '''''') + ''''
	+ case when @version < 2.02 then '' else ',' + isnull('''' + replace(TSDF.DEA_ID, '''', '''''') + '''','null') end
	+ case when @version < 2.16 then '' else ',' + isnull('''' + replace(TSDF.DEA_phone, '''', '''''') + '''','null') end
	+ ')' as sql
	from TSDF, WorkOrderDetail, WorkOrderHeader, TripConnectLog
	where TSDF.TSDF_code = WorkOrderDetail.TSDF_code
	and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
	and WorkOrderDetail.company_id = WorkOrderHeader.company_id
	and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
	and WorkOrderDetail.resource_type = 'D'
	and WorkOrderHeader.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	order by sql asc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdf] TO [EQAI]
    AS [dbo];

