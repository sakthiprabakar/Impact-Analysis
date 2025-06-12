drop procedure if exists sp_trip_sync_get_workorderdetail
go

create procedure sp_trip_sync_get_workorderdetail
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderDetail table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 01/19/2011 - rb Column changes to all Workorder-related tables
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 08/22/2012 - rb While deploying LabPack, added 'set transaction isolation level' for performance
 07/02/2015 - rb Update bill rate so approvals can be voided/unvoided
 06/13/2018 - rb GEM:51542 add support to sync TSDF_codes renamed in EQAI
 06/22/2018 - rb GEM:51542 We need to update the TSDF_Code for WorkOrderDetail records on prior stops
 06/17/2019 - rb GEM 62362 After MSS 2016 migration, trailing space is not automatically trimmed on UN_NA_flag
 02/18/2021 - mm DevOps 16236 - Added dot_shipping_desc_additional.
 05/19/2022 - mm DevOps 30391 - Added class_7_additional_desc, plus a null value for the exclusive_use_shipment_flag 
				 column, which exists in the MIM's WorkOrderDetail table, but doesn't exist in EQAI's WorkOrderDetail table.
				 Also added @version.

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

select 'if not exists (select 1 from WorkOrderDetail where workorder_id = ' + convert(varchar(20), WorkOrderDetail.workorder_id) + ' and company_id = ' + convert(varchar(20), WorkOrderDetail.company_id) + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderDetail.profit_ctr_id) + ' and sequence_id = ' + convert(varchar(20), WorkOrderDetail.sequence_id)
+ ') insert into WorkOrderDetail values('
+ convert(varchar(20),WorkOrderDetail.workorder_ID) + ','
+ isnull(convert(varchar(20),WorkOrderDetail.company_id),'null') + ','
+ convert(varchar(20),WorkOrderDetail.profit_ctr_ID) + ','
+ '''' + replace(WorkOrderDetail.resource_type, '''', '''''') + '''' + ','
+ convert(varchar(20),WorkOrderDetail.sequence_ID) + ','
+ isnull('''' + replace(WorkOrderDetail.resource_class_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.resource_assigned, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.price),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.cost),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.quantity),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.quantity_used),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.bill_rate),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.description, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.description_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.price_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.price_source, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.cost_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.cost_source, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.priced_flag),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.group_instance_id),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.group_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.requested_by, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.TSDF_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.TSDF_approval_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.manifest_page_num),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.manifest_line),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_line_id, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.container_count),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.container_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.waste_stream, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.confirmation_number, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.scheduled_time, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.disposal_scheduled, '''', '''''') + '''','null') + ','
--rb 01/19/2011 + isnull(convert(varchar(20),WorkOrderDetail.pounds),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.disposal_sequence_ID),'null') + ','
--rb 01/19/2011 + isnull(convert(varchar(20),WorkOrderDetail.manifest_quantity),'null') + ','
--rb 01/19/2011 + isnull('''' + replace(WorkOrderDetail.manifest_unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.requisition, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.TSDF_approval_bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.billing_sequence_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.profile_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.profile_company_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.profile_profit_ctr_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.TSDF_approval_id),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.DOT_shipping_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_hand_instruct, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_waste_desc, '''', '''''') + '''','null') + ','
--rb 01/19/2011 + isnull('''' + replace(WorkOrderDetail.waste_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.management_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.reportable_quantity_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.RQ_reason, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.hazmat, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.hazmat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.subsidiary_haz_mat_class, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(rtrim(WorkOrderDetail.UN_NA_flag), '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.UN_NA_number),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.package_group, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.ERG_number),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.ERG_suffix, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_handling_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_wt_vol_unit, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.extended_price),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.extended_cost),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.print_on_invoice_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.drmo_clin_num),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.drmo_hin_num),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.drmo_doc_num),'null') + ','
--rb 01/19/2011 + 'null' + ','
--rb 01/19/2011 + isnull('''' + replace(WorkOrderDetail.modified_by, '''', '''''') + '''','null') + ','
--rb 01/19/2011 + 'null' + ','
+ isnull('''' + replace(WorkOrderDetail.transfer_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.transfer_company_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderDetail.transfer_profit_ctr_id),'null') + ','
+ isnull('''' + replace(WorkOrderDetail.field_requested_action, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderDetail.manifest_dot_sp_number, '''', '''''') + '''','null') + ','
--rb 01/19/2011 added/modified fields moved to end of table, 'added_by' added to table
+ 'null' + ','
+ 'null' + ','
+ isnull('''' + replace(WorkOrderDetail.modified_by, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(WorkOrderDetail.dot_shipping_desc_additional, '''', '''''') + '''','null') 
+ case when @version < 4.82 then '' else ',' + isnull('''' + replace(WorkOrderDetail.class_7_additional_desc, '''', '''''') + '''','null')
	+ ', null' end -- for exclusive_use_shipment_flag column, which exists in the MIM's WorkOrderDetail table, but doesn't exist in EQAI's WorkOrderDetail table
+ ')' as sql
from WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderDetail.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

union
select 'update WorkOrderDetail set bill_rate = ' + isnull(convert(varchar(20),WorkOrderDetail.bill_rate),'null')
+ ', tsdf_code = ''' + isnull(WorkOrderDetail.tsdf_code,'null') + ''''
+ ' where workorder_id = ' + convert(varchar(20),WorkOrderDetail.workorder_ID)
+ ' and company_id = ' + isnull(convert(varchar(20),WorkOrderDetail.company_id),'null')
+ ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderDetail.profit_ctr_ID)
+ ' and resource_type = ''' + replace(WorkOrderDetail.resource_type, '''', '''''') + ''''
+ ' and sequence_id = ' + convert(varchar(20),WorkOrderDetail.sequence_ID) as sql
from WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
/*** rwb we can restore this after all TSDF_codes have been renamed
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
***/
and (WorkOrderDetail.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	WorkOrderHeader.field_requested_action = 'R')

union
select 'update WorkOrderDetail set UN_NA_flag = ''X'''
+ ' where workorder_id = ' + convert(varchar(20),WorkOrderDetail.workorder_ID)
+ ' and company_id = ' + isnull(convert(varchar(20),WorkOrderDetail.company_id),'null')
+ ' and profit_ctr_id = ' + convert(varchar(20),WorkOrderDetail.profit_ctr_ID)
+ ' and resource_type = ''' + replace(WorkOrderDetail.resource_type, '''', '''''') + ''''
+ ' and sequence_id = ' + convert(varchar(20),WorkOrderDetail.sequence_ID) as sql
from WorkOrderDetail, WorkOrderHeader, TripConnectLog
where WorkOrderDetail.resource_type = 'D'
and WorkOrderDetail.workorder_id = WorkOrderHeader.workorder_id
and WorkOrderDetail.company_id = WorkOrderHeader.company_id
and WorkOrderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
and WorkOrderDetail.UN_NA_flag = 'X '
and WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderDetail.field_requested_action,'') <> 'D'
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'

order by sql
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderdetail] TO [EQAI]
    AS [dbo];

