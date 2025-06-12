if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_upload_begin')
	drop procedure sp_labpack_sync_upload_begin
go

create procedure sp_labpack_sync_upload_begin
	@trip_connect_log_id		int,
	@trip_sequence_id		int,
	@workorder_id			int,
	@company_id			int,
	@profit_ctr_id			int,
	@date_act_arrive		datetime,
	@date_act_depart		datetime,
	@consolidated_pickup_flag	char(1),
	@pickup_contact			varchar(40),
	@pickup_contact_title		varchar(40),
	@waste_flag			char(1),
	@decline_id			int
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload

 loads to Plt_ai
 
 12/17/2019 - rwb created
 01/31/2022 - rwb delete existing records in WorkOrderWasteCode

****************************************************************************************/

declare @update_user varchar(10),
	@update_dt datetime,
	@trip_sync_upload_id int,
	@err int,
	@sql varchar(6000),
	@msg varchar(255)

set nocount on

-- initialize updated_by variables
select @update_user = 'TCID' + convert(varchar(6),@trip_connect_log_id),
	@update_dt = convert(datetime,convert(varchar(20),getdate(),120))

if not exists (select 1 from TripConnectLog tcl join TripHeader th on th.trip_id = tcl.trip_id and th.technical_equipment_type = 'L' where trip_connect_log_id = @trip_connect_log_id)
begin
		set @msg = 'ERROR: This trip is not currently assigned for a LPx device to download. If you believe this trip should be linked to a LPx device, please contact your trip coordinator.'
		goto ON_ERROR
end

-- get unique ID for TripSyncUpload
exec @trip_sync_upload_id = sp_sequence_silent_next 'TripSyncUpload.trip_sync_upload_id'
select @err = @@error
if @err <> 0
begin
	select @msg = '   Error: sp_sequence_next failed for TripSyncUpload.trip_sync_upload_id.'
	goto ON_ERROR
end

-- insert record
insert TripSyncUpload (trip_sync_upload_id, trip_connect_log_id, trip_sequence_id, sql_statement_count,
			processed_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @trip_connect_log_id, @trip_sequence_id, 2,
	'F', @update_user, @update_dt, @update_user, @update_dt)

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUpload record for Stop #' + convert(varchar(10),@trip_sequence_id)
	goto ON_ERROR
end

-- generate initial SQL for the stop
set @sql = 'update WorkOrderHeader set start_date=''' + convert(varchar(10),@date_act_arrive,101) + ''','
		+ 'end_date=''' + convert(varchar(10),@date_act_depart,101) + ''','
		+ 'consolidated_pickup_flag=''' + coalesce(@consolidated_pickup_flag,'F') + ''','
		+ 'modified_by=''' + @update_user + ''', date_modified=''' + convert(varchar(20),@update_dt,120) + ''''
		+ ' where workorder_id=' + convert(varchar(10),@workorder_id) + ' and company_id=' + convert(varchar(10),@company_id) + ' and profit_ctr_id=' + convert(varchar(10),@profit_ctr_id)

		+ ' update WorkOrderStop set date_act_arrive=''' + convert(varchar(20),@date_act_arrive,120) + ''','
		+ 'date_act_depart=''' + convert(varchar(20),@date_act_depart,120) + ''','
		+ 'pickup_contact=''' + coalesce(@pickup_contact,'') + ''','
		+ 'pickup_contact_title=''' + coalesce(@pickup_contact_title,'') + ''','
		+ 'decline_id=' + convert(char(1),coalesce(@decline_id,0)) + ','
		+ 'waste_flag=''' + coalesce(@waste_flag,'F') + ''','
		+ 'modified_by=''' + @update_user + ''', date_modified=''' + convert(varchar(20),@update_dt,120) + ''''
		+ ' where workorder_id=' + convert(varchar(10),@workorder_id) + ' and company_id=' + convert(varchar(10),@company_id) + ' and profit_ctr_id=' + convert(varchar(10),@profit_ctr_id)

		+ ' delete WorkOrderWasteCode'
		+ ' where workorder_id=' + convert(varchar(10),@workorder_id) + ' and company_id=' + convert(varchar(10),@company_id) + ' and profit_ctr_id=' + convert(varchar(10),@profit_ctr_id)


insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, 1, @sql, 2, 'F', @update_user, @update_dt, @update_user, @update_dt)

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for Stop #' + convert(varchar(10),@trip_sequence_id)
	goto ON_ERROR
end


-- SUCCESS return the ID
return @trip_sync_upload_id

-- FAILURE
ON_ERROR:
-- log error and return a -1 ID
exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt

raiserror(@msg,18,-1) with seterror
return -1
GO

grant execute on sp_labpack_sync_upload_begin to eqai
go
