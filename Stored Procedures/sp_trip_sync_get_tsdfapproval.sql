
create procedure sp_trip_sync_get_tsdfapproval
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TSDFApproval table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
 02/06/2012 - rb Force status to active, when approval inactivated for pricing
 08/15/2012 - rb Version 3.0 LabPack, added manifest_dot_sp_number
 12/06/2012 - rb Version 3.03, added RQ_threshold column
 04/17/2013 - rb Waste Code conversion...added waste_code_uid for version 3.06 forward
 07/15/2013 - rb Waste Code conversion Phase II...support for new display/status columns
 08/26/2015 - rb added print_dot_sp_flag and dot_sp_permit_text
 09/08/2015 - rb added consolidate_containers_flag, and treatment_id
 04/27/2016 - rb new flag on approvals to indicate "print empty bottle count on manifest"
 10/26/2016 - rb new AESOP-related columns required for Consolidated Load Cover

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


select 'delete from TSDFApproval where TSDF_approval_id = ' + convert(varchar(10),TSDFApproval.TSDF_approval_id)
+ ' insert into TSDFApproval values('
+ convert(varchar(20),TSDFApproval.TSDF_approval_id) + ','
+ convert(varchar(20),TSDFApproval.company_id) + ','
+ isnull(convert(varchar(20),TSDFApproval.profit_ctr_id),'null') + ','
+ '''' + replace(TSDFApproval.TSDF_code, '''', '''''') + '''' + ','
+ '''' + replace(TSDFApproval.TSDF_approval_code, '''', '''''') + '''' + ','
+ '''' + replace(TSDFApproval.waste_stream, '''', '''''') + '''' + ','
+ convert(varchar(20),TSDFApproval.customer_id) + ','
+ isnull(convert(varchar(20),TSDFApproval.generator_id),'null') + ','
+ isnull('''' + replace(TSDFApproval.waste_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.waste_desc, '''', '''''') + '''','null') + ','
+ '''A'',' --isnull('''' + replace(TSDFApproval.TSDF_approval_status, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApproval.TSDF_approval_start_date,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),TSDFApproval.TSDF_approval_expire_date,120) + '''','null') + ','
+ '''' + replace(TSDFApproval.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),TSDFApproval.date_added,120) + '''' + ','
+ '''' + replace(TSDFApproval.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),TSDFApproval.date_modified,120) + '''' + ','
+ isnull('''' + replace(TSDFApproval.bulk_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.release_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.generating_process, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.comments, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.reportable_quantity_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.RQ_reason, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.DOT_shipping_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.hazmat, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.subsidiary_haz_mat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.UN_NA_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApproval.UN_NA_number),'null') + ','
+ isnull('''' + replace(TSDFApproval.package_group, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApproval.ERG_number),'null') + ','
+ isnull('''' + replace(TSDFApproval.ERG_suffix, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.waste_water_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.LDR_subcategory, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.manifest_handling_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.manifest_wt_vol_unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.hand_instruct, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApproval.waste_managed_id),'null') + ','
+ isnull('''' + replace(TSDFApproval.placard_text, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.manifest_container_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.management_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.land_ban_ref, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.LDR_required, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.gen_waste_stream_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.consistency, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.pH_range, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.treatment_method, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.regulatory_body_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.EPA_form_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.EPA_source_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.EPA_haz_list_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(TSDFApproval.export_code, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(TSDFApproval.m_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApproval.convert_EQ_profile_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApproval.convert_EQ_company_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApproval.convert_EQ_profit_ctr_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApproval.wastetype_id),'null') + ','
+ isnull('''' + replace(TSDFApproval.RCRA_haz_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),TSDFApproval.treatment_process_id),'null') + ','
+ isnull(convert(varchar(20),TSDFApproval.disposal_service_id),'null') + ','
+ isnull('''' + replace(TSDFApproval.disposal_service_other_desc, '''', '''''') + '''','null')
+ case when @version < 3.0 then '' else ',' + isnull('''' + replace(TSDFApproval.manifest_dot_sp_number, '''', '''''') + '''','null') end
+ case when @version < 3.03 then '' else ',' + isnull(convert(varchar(20),TSDFApproval.rq_threshold),'null') end
+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),TSDFApproval.waste_code_uid),'null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(TSDFApproval.manifest_message, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(TSDFApproval.empty_bottle_flag, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(TSDFApproval.residue_pounds_factor, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(TSDFApproval.residue_manifest_print_flag, '''', '''''') + '''','null') end
+ case when @version < 4.25 then '' else ',' + isnull('''' + replace(TSDFApproval.print_dot_sp_flag, '''', '''''') + '''','null') end
+ case when @version < 4.25 then '' else ',' + isnull('''' + replace(TSDFApproval.dot_sp_permit_text, '''', '''''') + '''','null') end
+ case when @version < 4.26 then '' else ',' + '''F''' end --isnull('''' + replace(TSDFApproval.consolidate_containers_flag, '''', '''''') + '''','null') end
+ case when @version < 4.26 then '' else ',' + isnull(convert(varchar(20),Treatment.treatment_id),'null') end
+ case when @version < 4.33 then '' else ',' + isnull('''' + replace(TSDFApproval.manifest_actual_wt_flag, '''', '''''') + '''','null') end
+ case when @version < 4.33 then '' else ',' + isnull('''' + replace(TSDFApproval.empty_bottle_count_manifest_print_flag, '''', '''''') + '''','null') end
+ case when @version < 4.38 then '' else ',' + isnull(convert(varchar(20),TSDFApproval.AESOP_profile_id),'null') end
+ case when @version < 4.38 then '' else ',' + isnull('''' + replace(TSDFApproval.AESOP_waste_stream, '''', '''''') + '''','null') end
+ ')' as sql
from TSDFApproval
join WorkOrderDetail
	on TSDFApproval.TSDF_approval_id = WorkOrderDetail.TSDF_approval_id
join WorkOrderHeader
	on WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
	and WorkOrderDetail.company_id = WorkOrderHeader.company_id
	and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
	and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
join TripConnectLog
	on WorkOrderHeader.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
left outer join Treatment
	on TSDFApproval.company_id = Treatment.company_id
	and TSDFApproval.profit_ctr_id = Treatment.profit_ctr_id
	and TSDFApproval.wastetype_id = Treatment.wastetype_id
	and TSDFApproval.treatment_process_id = Treatment.treatment_process_id
	and TSDFApproval.disposal_service_id = Treatment.disposal_service_id
where (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	TSDFApproval.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900'))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tsdfapproval] TO [EQAI]
    AS [dbo];

