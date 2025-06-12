
create procedure sp_trip_sync_get_transporter
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Transporter table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 01/21/2011 - rb Column changes to all Workorder-related tables
 08/23/2012 - rb Version 3.0 LabPack...retrieve entire table for LabPack trips
****************************************************************************************/

declare @lab_pack_flag char(1),
	@last_download_date datetime

set transaction isolation level read uncommitted

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

	select 'truncate table Transporter' as sql
	union
	select distinct 'insert into Transporter values('
	+ '''' + replace(Transporter.Transporter_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(Transporter.Transporter_status, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_name, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr1, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr2, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr3, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_EPA_ID, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_fax, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_contact, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.comments, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Transporter.date_added,120) + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Transporter.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(Transporter.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.DOT_id, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_city, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_state, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_zip_code, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_country, '''', '''''') + '''','null') + ','
	+ ''' ''' + ')' as sql
	from Transporter
	where isnull(Transporter_status,'I') = 'A'
	order by sql desc
else
	select distinct 'delete from Transporter where Transporter_code = ''' + Transporter.Transporter_code + ''''
	+ ' insert into Transporter values('
	+ '''' + replace(Transporter.Transporter_code, '''', '''''') + '''' + ','
	+ isnull('''' + replace(Transporter.Transporter_status, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_name, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr1, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr2, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_addr3, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_EPA_ID, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_fax, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_contact, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_contact_phone, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.comments, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Transporter.date_added,120) + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Transporter.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(Transporter.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.DOT_id, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_city, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_state, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_zip_code, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Transporter.Transporter_country, '''', '''''') + '''','null') + ','
	+ ''' ''' + ')' as sql
	from Transporter, WorkOrderTransporter, WorkOrderHeader, TripConnectLog
	where Transporter.Transporter_code = WorkOrderTransporter.transporter_code
	and WorkOrderTransporter.workorder_id = WorkOrderHeader.workorder_id
	and WorkOrderTransporter.company_id = WorkOrderHeader.company_id
	and WorkOrderTransporter.profit_ctr_id = WorkOrderHeader.profit_ctr_id
	and WorkOrderHeader.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	and (Transporter.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
		or WorkOrderTransporter.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
     		or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
		or WorkOrderHeader.field_requested_action = 'R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_transporter] TO [EQAI]
    AS [dbo];

