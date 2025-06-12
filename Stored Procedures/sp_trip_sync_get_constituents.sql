
create procedure sp_trip_sync_get_constituents
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Constituents table on a trip local database

 loads to Plt_ai
 
 08/10/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 08/23/2012 - rb Version 3.0 LabPack...retrieve entire table for Lab Pack trips
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

	select 'truncate table Constituents' as sql
	union
	select distinct 'insert Constituents values('
	+ convert(varchar(20),Constituents.const_id) + ','
	+ isnull('''' + replace(Constituents.const_desc, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.created_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_added,120) + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_type, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.CAS_code),'null') + ','
	+ isnull('''' + replace(Constituents.TRI, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DHS, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.VOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.HAP, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_alpha_desc, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.vapor_pressure),'null') + ','
	+ isnull(convert(varchar(20),Constituents.molecular_weight),'null') + ','
	+ isnull(convert(varchar(20),Constituents.density),'null') + ','
	+ isnull('''' + replace(Constituents.diluent_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.diluent_ppm),'null') + ','
	+ isnull('''' + replace(Constituents.TRI_category, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DES_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.LDR_id),'null') + ','
	+ isnull('''' + replace(Constituents.DDVOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.ww_metal, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_unit, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.generic_concentration),'null') + ')' as sql
	from Constituents
	order by sql desc
else
	select distinct 'delete Constituents where const_id = ' + convert(varchar(20),Constituents.const_id)
	+ ' insert Constituents values('
	+ convert(varchar(20),Constituents.const_id) + ','
	+ isnull('''' + replace(Constituents.const_desc, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.created_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_added,120) + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_type, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.CAS_code),'null') + ','
	+ isnull('''' + replace(Constituents.TRI, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DHS, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.VOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.HAP, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_alpha_desc, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.vapor_pressure),'null') + ','
	+ isnull(convert(varchar(20),Constituents.molecular_weight),'null') + ','
	+ isnull(convert(varchar(20),Constituents.density),'null') + ','
	+ isnull('''' + replace(Constituents.diluent_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.diluent_ppm),'null') + ','
	+ isnull('''' + replace(Constituents.TRI_category, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DES_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.LDR_id),'null') + ','
	+ isnull('''' + replace(Constituents.DDVOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.ww_metal, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_unit, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.generic_concentration),'null') + ')' as sql
	 from Constituents, ProfileConstituent, WorkOrderDetail, WorkOrderHeader, TripConnectLog
	where Constituents.const_id = ProfileConstituent.const_id
	and ProfileConstituent.profile_id = WorkOrderDetail.profile_id
	and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
	and WorkOrderDetail.company_id = WorkOrderHeader.company_id
	and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
	and WorkOrderDetail.resource_type = 'D'
	and WorkOrderHeader.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
	and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	and (Constituents.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
	     or WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
	     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900'))
	union
	select distinct 'delete Constituents where const_id = ' + convert(varchar(20),Constituents.const_id)
	+ ' insert Constituents values('
	+ convert(varchar(20),Constituents.const_id) + ','
	+ isnull('''' + replace(Constituents.const_desc, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.created_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_added,120) + '''','null') + ','
	+ isnull('''' + convert(varchar(20),Constituents.date_modified,120) + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_type, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.CAS_code),'null') + ','
	+ isnull('''' + replace(Constituents.TRI, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DHS, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.VOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.HAP, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.const_alpha_desc, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.vapor_pressure),'null') + ','
	+ isnull(convert(varchar(20),Constituents.molecular_weight),'null') + ','
	+ isnull(convert(varchar(20),Constituents.density),'null') + ','
	+ isnull('''' + replace(Constituents.diluent_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.diluent_ppm),'null') + ','
	+ isnull('''' + replace(Constituents.TRI_category, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.DES_flag, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.LDR_id),'null') + ','
	+ isnull('''' + replace(Constituents.DDVOC, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.ww_metal, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(Constituents.generic_unit, '''', '''''') + '''','null') + ','
	+ isnull(convert(varchar(20),Constituents.generic_concentration),'null') + ')' as sql
	 from Constituents, TSDFApprovalConstituent, WorkOrderDetail, WorkOrderHeader, TripConnectLog
	where Constituents.const_id = TSDFApprovalConstituent.const_id
	and TSDFApprovalConstituent.tsdf_approval_id = WorkOrderDetail.tsdf_approval_id
	and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
	and WorkOrderDetail.company_id = WorkOrderHeader.company_id
	and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
	and WorkOrderDetail.resource_type = 'D'
	and WorkOrderDetail.tsdf_approval_id is not null
	and WorkOrderHeader.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
	and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
	and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
	and (Constituents.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')
	     or WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900')
	     or WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900'))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_constituents] TO [EQAI]
    AS [dbo];

