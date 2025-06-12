
create procedure sp_trip_sync_get_profile
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the Profile table on a trip local database

 loads to Plt_ai
 
 02/10/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/27/2010 - rb on a sync after trip initially downloaded, if a new approval was added
              with links to a profile that wasn't already downloaded, the new profile
              related records were not being retrieved. Need to look at WorkOrderDetail's
              date_added instead of WorkOrderHeader's (initial implementation was for new stop)
 04/26/2011 - rb added RQ_threshold column to insert statements
 02/03/2012 - rb Force curr_status_code='A', because when profiles are inactivated to edit them,
		drivers who sync pull the status and then the profile doesn't print
 08/15/2012 - rb Version 3.0 LabPack, pull manifest_dot_sp_number
 04/17/2013 - rb Waste Code conversion...added waste_code_uid for version 3.06 forward
 07/15/2013 - rb Waste Code conversion Phase II...support for new display/status columns
 06/16/2014 - rb Modified ProfileConsistency to retrieve left 20 characters...driver could  not
				download a trip with an approval containing 20 characters (DUST/POWDER:GAS/AEROSOL).
				The MIM needs to be modified to accept more than 20 characters...this is a hotfix
				to prevent the inability to download trips (consistency only used by LabPackers)
 11/05/2014 - rb New state labels for CA and WA...need more fields from ProfileLab
 08/11/2015 - rb DEA flag added, to support extra validation for DEA scheduled drug pickups
 08/26/2015 - rb added dot_sp_permit_text
 04/27/2016 - rb new flag on approvals to indicate "print empty bottle count on manifest"
 05/31/2016 - rb new flag to indicate Pharmaceutical Profile
 10/09/2017	- mm Added new flag, mim_customer_label_flag. Also, GEM 46185 - added WasteType table.
 06/17/2019 - rb GEM 62362 After MSS 2016 migration, trailing space is not automatically trimmed on UN_NA_flag

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

-- rb MAKE curr_status_code Active
select distinct 'delete Profile where profile_id = ' + convert(varchar(20),Profile.profile_id)
+ ' insert Profile values('
+ convert(varchar(20),Profile.profile_id) + ','
+ '''A'',' --isnull('''' + replace(Profile.curr_status_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.customer_id),'null') + ','
+ isnull(convert(varchar(20),Profile.generator_id),'null') + ','
+ 'null' + ','
+ isnull('''' + replace(Profile.waste_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.quote_id),'null') + ','
+ isnull('''' + replace(Profile.approval_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Profile.ap_start_date,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),Profile.ap_expiration_date,120) + '''','null') + ','
+ isnull('''' + replace(Profile.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Profile.date_added,120) + '''','null') + ','
+ isnull('''' + replace(Profile.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),Profile.date_modified,120) + '''','null') + ','
+ isnull(convert(varchar(20),Profile.contact_id),'null') + ','
+ isnull('''' + replace(Profile.tracking_type, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.orig_customer_id),'null') + ','
+ isnull('''' + replace(Profile.broker_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.bulk_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.OTS_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.transship_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.generic_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.labpack_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.reapproval_allowed, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.document_update_status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.urgent_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.one_time_only, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.pending_customer_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.pending_generator_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.purchase_order, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.ap_release, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.cert_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.max_loads),'null') + ','
+ isnull('''' + convert(varchar(20),Profile.max_load_start_date,120) + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.hand_instruct), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.approval_comments), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.comments_1), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.comments_2), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.comments_3), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.schedule_comments), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),Profile.lab_comments), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.reportable_quantity_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.RQ_reason, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.DOT_shipping_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.hazmat, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.subsidiary_haz_mat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(rtrim(Profile.UN_NA_flag), '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.UN_NA_number),'null') + ','
+ isnull('''' + replace(Profile.package_group, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.ERG_number),'null') + ','
+ isnull('''' + replace(Profile.ERG_suffix, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.waste_water_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.LDR_subcategory, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.manifest_handling_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.manifest_wt_vol_unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.manifest_hand_instruct, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.waste_managed_id),'null') + ','
+ isnull('''' + replace(Profile.manifest_container_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.treatment_method, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(Profile.transporter_code_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.transporter_code_2, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.transporter_id_1),'null') + ','
+ isnull(convert(varchar(20),Profile.transporter_id_2),'null') + ','
+ isnull('''' + replace(Profile.SPOC_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.EQ_contact, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.form_id_wcr),'null') + ','
+ isnull('''' + replace(Profile.manifest_waste_desc, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.profile_tracking_id),'null') + ','
+ isnull('''' + convert(varchar(20),Profile.date_approved,120) + '''','null') + ','
+ isnull(convert(varchar(20),Profile.profile_tracking_days),'null') + ','
+ isnull(convert(varchar(20),Profile.profile_tracking_bus_days),'null') + ','
+ isnull(convert(varchar(20),Profile.wastetype_id),'null') + ','
+ isnull('''' + replace(Profile.RCRA_haz_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.EPA_form_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(Profile.EPA_source_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),Profile.disposition_id),'null')
+ case when @version < 2.16 then '' else ',' + isnull(convert(varchar(20),Profile.rq_threshold),'null') end
+ case when @version < 3.0 then '' else ',' + isnull('''' + replace(Profile.manifest_dot_sp_number, '''', '''''') + '''','null') end
+ case when @version < 3.06 then '' else ',' + isnull(convert(varchar(20),Profile.waste_code_uid),'null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(Profile.manifest_message, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(Profile.empty_bottle_flag, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(Profile.residue_pounds_factor, '''', '''''') + '''','null') end
+ case when @version < 3.08 then '' else ',' + isnull('''' + replace(Profile.residue_manifest_print_flag, '''', '''''') + '''','null') end
+ case when @version < 4.18 then '' else ',' + isnull('''' + left(replace(Profile.gen_process, '''', ''''''),255) + '''','null') end
+ case when @version < 4.21 then '' else ',' + isnull('''' + replace(Profile.dea_flag, '''', '''''') + '''','null') end
+ case when @version < 4.25 then '' else ',' + isnull('''' + replace(Profile.dot_sp_permit_text, '''', '''''') + '''','null') end
+ case when @version < 4.33 then '' else ',' + isnull('''' + replace(Profile.manifest_actual_wt_flag, '''', '''''') + '''','null') end
+ case when @version < 4.33 then '' else ',' + isnull('''' + replace(Profile.empty_bottle_count_manifest_print_flag, '''', '''''') + '''','null') end
+ case when @version < 4.35 then '' else ',' + isnull('''' + replace(Profile.pharmaceutical_flag, '''', '''''') + '''','null') end
+ case when @version < 4.42 then '' else ',' + isnull('''' + replace(Profile.mim_customer_label_flag, '''', '''''') + '''','null') end
+ ')' as sql
from Profile, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where Profile.profile_id = WorkOrderDetail.profile_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Profile.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')
union
select case when @version < 3.0 then ''
	when @version > 4.17 then 'delete ProfileLab where profile_id = ' + convert(varchar(20),ProfileLab.profile_id) +
		' insert ProfileLab values (' + convert(varchar(20),ProfileLab.profile_id) + ',' +
		isnull('''' + replace(ProfileLab.consistency, '''', '''''') + '''','null') + ',' +
		isnull('''' + replace(ProfileLab.free_liquid, '''', '''''') + '''','null') + ',' +
		isnull('''' + replace(ProfileLab.ignitability_lt_90, '''', '''''') + '''','null') + ',' +
		isnull('''' + replace(ProfileLab.ignitability_90_139, '''', '''''') + '''','null') + ')'
	else 'delete ProfileConsistency where profile_id = ' + convert(varchar(20),ProfileLab.profile_id) +
		' insert ProfileConsistency values (' + convert(varchar(20),ProfileLab.profile_id) + ',' +
		isnull('''' + left(replace(ProfileLab.consistency, '''', ''''''),20) + '''','null') + ')'
	end as sql
from ProfileLab, Profile, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where ProfileLab.type = 'A'
and ProfileLab.profile_id = WorkOrderDetail.profile_id
and Profile.profile_id = ProfileLab.profile_id
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (Profile.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	ProfileLab.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')
union
select case when @version < 4.42 then '' else 'truncate table WasteType' end as sql
union
select case when @version < 4.42 then '' else  'insert into WasteType values('
+ isnull(convert(varchar(20),WasteType.wastetype_id),'null') + ','
+ isnull('''' + replace(WasteType.category, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WasteType.description, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WasteType.code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WasteType.gl_seg_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WasteType.biennial_description, '''', '''''') + '''','null') + ')' end as sql
 from WasteType
where category = 'Universal Waste'

union
select 'update Profile set UN_NA_flag = ''X'''
+ ' where profile_id = ' + convert(varchar(20),WorkOrderDetail.profile_ID) as sql
from Profile, WorkOrderDetail, WorkOrderHeader, TripConnectLog
where Profile.profile_id = WorkOrderDetail.profile_id
and Profile.UN_NA_flag = 'X '
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'

order by sql desc
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_profile] TO [EQAI]
    AS [dbo];

