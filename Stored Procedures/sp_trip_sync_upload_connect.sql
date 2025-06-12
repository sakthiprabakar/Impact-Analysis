if exists (select 1 from sysobjects where type = 'P' and name = 'sp_trip_sync_upload_connect')
	drop procedure sp_trip_sync_upload_connect
go

create procedure sp_trip_sync_upload_connect
	@trip_connect_log_id int,
	@trip_sequence_id int,
	@sql_count int
as
/***************************************************************************************
 this procedure initiates an upload of sql batches from the client

 loads to Plt_ai
 
 03/05/2010 - rb created
 11/17/2020 - rb DevOps 17986 - Check that trip is assigned to a MIM
 12/16/2020 - rb Prior change broke upload from SmarterSorting, this is called my both

****************************************************************************************/

set nocount on

declare @update_user varchar(10),
	@update_dt datetime,
	@trip_sync_upload_id int,
	@err int,
	@msg varchar(255),
	@return_id varchar(20)

-- initialize updated_by variables
select @update_user = 'TCID' + convert(varchar(6),@trip_connect_log_id),
	@update_dt = convert(datetime,convert(varchar(20),getdate(),120))

if not exists (select 1 from TripConnectLog tcl join TripHeader th on th.trip_id = tcl.trip_id and coalesce(th.technical_equipment_type,'M') in ('M','T') where trip_connect_log_id = @trip_connect_log_id)
begin
	set @msg = 'ERROR: This trip is not currently assigned for either a MIM device or TruckSiS to download. If you believe this trip should be linked to one, please contact your trip coordinator.'
	goto ON_ERROR
end

-- get unique ID for TripSyncUpload
exec @trip_sync_upload_id = sp_sequence_next 'TripSyncUpload.trip_sync_upload_id'
select @err = @@error
if @err <> 0
begin
	select @msg = '   Error: sp_sequence_next failed for TripSyncUpload.trip_sync_upload_id.'
	goto ON_ERROR
end

-- insert record
insert TripSyncUpload (trip_sync_upload_id, trip_connect_log_id, trip_sequence_id, sql_statement_count,
			processed_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @trip_connect_log_id, @trip_sequence_id, @sql_count,
	'F', @update_user, @update_dt, @update_user, @update_dt)

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUpload record for Stop #' + convert(varchar(10),@trip_sequence_id)
	goto ON_ERROR
end

-- SUCCESS return the ID
select @return_id = convert(varchar(20),@trip_sync_upload_id)
goto RETURN_RESULTS

-- FAILURE
ON_ERROR:
-- log error and return a -1 ID
exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt
select @return_id = '-1'

RETURN_RESULTS:
set nocount off
select @return_id as return_id
return 0
go

grant execute on sp_trip_sync_upload_connect to eqai
go