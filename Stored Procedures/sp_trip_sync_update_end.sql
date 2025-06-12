
create procedure sp_trip_sync_update_end
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure records the end of update SQL being sent from field device, and
 launches the process updates procedure

 loads to Plt_ai
 
 06/17/2009 - rb created
 02/24/2010 - rb new TripFieldUpdate table
 03/11/2010 - rb new TripFieldUpload table, version 2.0 sync rewrite
****************************************************************************************/

declare @sequence_id int,
	@count int,
	@msg varchar(255),
	@trip_sync_upload_id int

set nocount on

select @trip_sync_upload_id = max(trip_sync_upload_id)
from TripSyncUpload
where trip_connect_log_id = @trip_connect_log_id

if @trip_sync_upload_id < 1
	select @trip_sync_upload_id = null

if @trip_sync_upload_id is null
begin
	-- log how many fields have been modified
	select @count = count(*)
	from TripConnectLog tcl, TripFieldUpdates tfu
	where tcl.trip_connect_log_id = @trip_connect_log_id
	and tcl.trip_id = tfu.trip_id
	and tfu.processed_flag = 'F'

	-- rb 02/24/2010
	select @count = @count + count(*)
	from TripConnectLog tcl, TripFieldUpdate tfu
	where tcl.trip_connect_log_id = @trip_connect_log_id
	and tcl.trip_id = tfu.trip_id
	and tfu.processed_flag = 'F'
end
else
begin
	select @count = sql_statement_count
	from TripSyncUpload
	where trip_sync_upload_id = @trip_sync_upload_id
end

select @msg = '      # of values modified: ' + convert(varchar(5),@count)
exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg

-- insert detail messages for any stops that have been completed for this sync
if @trip_sync_upload_id is null
begin
	declare c_loop cursor for
	select tfu.trip_sequence_id
	from TripConnectLog tcl, TripFieldUpdates tfu
	where tcl.trip_connect_log_id = @trip_connect_log_id
	and tcl.trip_id = tfu.trip_id
	and tfu.processed_flag = 'F'
	and tfu.table_name = 'workorderheader'
	and tfu.column_name = 'trip_act_departure'

	-- rb 02/24/2010
	union

	select tfu.trip_sequence_id
	from TripConnectLog tcl, TripFieldUpdate tfu
	where tcl.trip_connect_log_id = @trip_connect_log_id
	and tcl.trip_id = tfu.trip_id
	and tfu.processed_flag = 'F'
	and tfu.table_name = 'workorderheader'
	and tfu.column_name = 'trip_act_departure'

	order by tfu.trip_sequence_id
	for read only

	open c_loop
	fetch c_loop into @sequence_id

	while @@FETCH_STATUS = 0
	begin
		select @msg = '      Stop #' + convert(varchar(3),@sequence_id) + ' has been completed.'
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg

		fetch c_loop into @sequence_id
	end

	close c_loop
	deallocate c_loop

	-- process the updates
	exec sp_trip_sync_process_updates @trip_connect_log_id
end
else
begin
	select @msg = '      Stop #' + convert(varchar(3),trip_sequence_id) + ' has been completed.'
	from TripSyncUpload
	where trip_sync_upload_id = @trip_sync_upload_id

	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg

	update WorkOrderHeader
	set field_upload_date = getdate()
	from WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu
	where woh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = tsu.trip_connect_log_id
	and woh.trip_sequence_id = tsu.trip_sequence_id
	and tsu.trip_sync_upload_id = @trip_sync_upload_id
end


-- update timestamps on messages so they will display
update TripConnectLogDetail
set request_date = getdate()
where trip_connect_log_id = @trip_connect_log_id
and request_date is null

-- update last upload date
update TripConnectLog
set last_upload_date = getdate()
where trip_connect_log_id = @trip_connect_log_id

END_OF_PROC:
set nocount off
select '' as sql
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_update_end] TO [EQAI]
    AS [dbo];

