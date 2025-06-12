DROP PROCEDURE IF EXISTS sp_trip_sync_get_workorderheader;
GO

CREATE PROCEDURE sp_trip_sync_get_workorderheader
	@trip_connect_log_id int
AS
/***************************************************************************************
 this procedure synchronizes the WorkOrderHeader table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 01/20/2011 - rb Column changes to all Workorder-related tables
 06/15/2011 - rb Return any updated workorder status values (for toggling between void and active)
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance
 04/20/2015 - rb modification to support Kroger Invoicing requirements (add trip_stop_rate_flag and generator_sublocation_id)
 06/02/2015 - rb pull trip_eq_comment for per-stop notes to the drivers
 05/31/2016 - rb pull offschedule_service_flag for Rite-Aid specific docs
 10/12/2017 - mm Added union to get WorkOrderTypeHeader table.
 03/08/2018 - mm Added workorder_type_id to the 'update' statement.
 09/05/2023 - mm DevOps 64054/64055/64056 - Added union to get Configuration table.

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


select 'if not exists (select 1 from WorkOrderHeader where workorder_id = ' + convert(varchar(20), WorkOrderHeader.workorder_id) + ' and company_id = ' + isnull(convert(varchar(20), WorkOrderHeader.company_id),'null') + ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderHeader.profit_ctr_ID)
+ ') insert into WorkOrderHeader values('
+ convert(varchar(20),WorkOrderHeader.workorder_ID) + ','
+ isnull(convert(varchar(20),WorkOrderHeader.company_id),'null') + ','
+ convert(varchar(20),WorkOrderHeader.profit_ctr_ID) + ','
+ convert(varchar(20),WorkOrderHeader.revision) + ','
+ isnull('''' + replace(WorkOrderHeader.workorder_status, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.workorder_type, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.submitted_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.customer_ID),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.generator_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.billing_project_id),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.fixed_price_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.priced_flag),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.total_price),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.total_cost),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.description, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.template_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.emp_arrive_time, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.cust_arrive_time, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderHeader.start_date,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderHeader.end_date,120) + '''','null') + ','
-- rb 01/20/2011 + isnull(convert(varchar(20),WorkOrderHeader.est_time_amount),'null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.est_time_unit, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.urgency_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.project_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.project_name, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.project_location, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.contact_ID),'null') + ','
-- rb 01/20/2011 + isnull(convert(varchar(20),WorkOrderHeader.station_ID),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.quote_ID),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.purchase_order, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.release_code, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.milk_run, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_haz),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_nonhaz),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_3),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_4_1),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_5_1),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_6_1),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_8),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.label_class_9),'null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderHeader.void_date,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.void_operator, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.void_reason, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.comments, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.clean_tanker, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.confined_space, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.fresh_air, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.load_count),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.cust_discount),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_comment_1, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_comment_2, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_comment_3, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_comment_4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_comment_5, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.ae_comments, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.site_directions, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.invoice_break_value, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.problem_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.project_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.project_record_id),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.include_cost_report_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.po_sequence_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.billing_link_id),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.other_submit_required_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.submit_on_hold_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.submit_on_hold_reason, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.trip_id),'null') + ','
+ isnull(convert(varchar(20),WorkOrderHeader.trip_sequence_id),'null') + ','
+ isnull('''' + replace(WorkOrderHeader.trip_eq_comment, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + convert(varchar(20),WorkOrderHeader.trip_est_arrive,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + convert(varchar(20),WorkOrderHeader.trip_est_departure,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + convert(varchar(20),WorkOrderHeader.trip_act_arrive,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + convert(varchar(20),WorkOrderHeader.trip_act_departure,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.created_by, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + 'null' + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.modified_by, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + 'null' + ','
+ isnull('''' + replace(WorkOrderHeader.submitted_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderHeader.date_submitted,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + convert(varchar(20),WorkOrderHeader.confirmation_date,120) + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.schedule_contact, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.schedule_contact_title, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.pickup_contact, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.pickup_contact_title, '''', '''''') + '''','null') + ','
-- rb 01/20/2011 + isnull(convert(varchar(20),WorkOrderHeader.decline_id),'null') + ','
-- rb 01/20/2011 + isnull('''' + replace(WorkOrderHeader.waste_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.consolidated_pickup_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.field_download_date, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.field_upload_date, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.field_requested_action, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.tractor_trailer_number, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.ltl_title_comment, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderHeader.created_by, '''', '''''') + '''','null') + ','
+ 'null' + ','
+ isnull('''' + replace(WorkOrderHeader.modified_by, '''', '''''') + '''','null') + ','
+ 'null'
+ case when @version < 4.16 then '' else ',' + isnull(convert(varchar(20),WorkOrderHeader.workorder_type_id),'null') end
+ case when @version < 4.16 then '' else ',' + isnull('''' + replace(WorkOrderHeader.reference_code, '''', '''''') + '''','null') end
+ case when @version < 4.16 then '' else ',' + isnull('''' + replace(WorkOrderHeader.trip_stop_rate_flag, '''', '''''') + '''','null') end
+ case when @version < 4.16 then '' else ',' + isnull(convert(varchar(20),WorkOrderHeader.generator_sublocation_ID),'null') end
+ case when @version < 4.35 then '' else ',' + coalesce('''' + WorkOrderHeader.offschedule_service_flag + '''','null') end
+ ')' as sql
 from WorkOrderHeader, TripConnectLog
where WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
and (WorkOrderHeader.date_added > isnull(TripConnectLog.last_download_date,'01/01/1900') or
	 WorkOrderHeader.field_requested_action = 'R')
union
select 'update workorderheader set workorder_status='
+ coalesce('''' + replace(WorkOrderHeader.workorder_status, '''', '''''') + '''','null')
+ ', trip_eq_comment = ' + coalesce('''' + replace(WorkOrderHeader.trip_eq_comment, '''', '''''') + '''','null')
+ case when @version < 4.16 then '' else ', generator_sublocation_id=' + coalesce(convert(varchar(20),WorkOrderHeader.generator_sublocation_ID),'null') end
+ case when @version < 4.35 then '' else ', offschedule_service_flag=' + coalesce('''' + WorkOrderHeader.offschedule_service_flag + '''','null') end
+ case when @version < 4.52 then '' else ', workorder_type_id=' + coalesce(convert(varchar(20),WorkOrderHeader.workorder_type_ID),'null') end
+ ' where workorder_id = ' + convert(varchar(20), WorkOrderHeader.workorder_id)
+ ' and company_id = ' + coalesce(convert(varchar(20), WorkOrderHeader.company_id),'null')
+ ' and profit_ctr_id = ' + convert(varchar(20), WorkOrderHeader.profit_ctr_ID) as sql
 from WorkOrderHeader, TripConnectLog
where WorkOrderHeader.trip_id = TripConnectLog.trip_id
and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and isnull(WorkOrderHeader.field_requested_action,'') <> 'D'
and (WorkOrderHeader.field_upload_date is null or TripConnectLog.last_download_date is null)
union
select case when @version < 4.42 then '' else 'truncate table WorkOrderTypeHeader' end as sql
union
select case when @version < 4.42 then '' else 'insert into WorkOrderTypeHeader values('
+ convert(varchar(20),WorkOrderTypeHeader.workorder_type_id) + ','
+ '''' + replace(WorkOrderTypeHeader.account_desc, '''', '''''') + '''' + ','
+ isnull('''' + replace(WorkOrderTypeHeader.gl_seg_4, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(WorkOrderTypeHeader.added_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderTypeHeader.date_added,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderTypeHeader.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),WorkOrderTypeHeader.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(WorkOrderTypeHeader.gl_object_prefix, '''', '''''') + '''','null') + ')' end as sql
from WorkOrderTypeHeader
union
select case when @version < 4.87 then '' else 'truncate table Configuration' end as sql
union
select case when @version < 4.87 then '' else 'insert into Configuration values('
+ '''' + replace(Configuration.config_key, '''', '''''') + '''' + ','
+ '''' + replace(Configuration.config_value, '''', '''''') + '''' + ','
+ '''' + replace(Configuration.added_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),Configuration.date_added,120) + '''' + ','
+ '''' + replace(Configuration.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),Configuration.date_modified,120) + '''' + ')' end as sql
from Configuration

order by sql desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderheader] TO [EQAI];

