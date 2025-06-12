use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_begin')
	drop procedure sp_ss_get_trip_begin
go

create procedure sp_ss_get_trip_begin
	@trip_id int,
	@trip_pass_code varchar(20),
	@trip_sequence_id int
as
/************************************
 *
 * 10/16/2019 rwb Created
 * 05/14/2021 rwb ADO 20860 Removed logging when called in TripConnectLogDetail, because it is called often by the TruckSiS application server
 *
 --select * from TripHeader where trip_id = 79814
 --select * from TripConnectLogStop
 --exec sp_ss_get_trip_begin 79814, 'JT79814', 27
 --exec sp_ss_get_trip_begin 79814, 'JT79814', 0
 --
 *
 ************************************/
declare @trip_connect_log_id int,
		@app_id int,
		@results varchar(max)

set transaction isolation level read uncommitted

if not exists (select 1 from TripHeader
				where trip_id = @trip_id
				and trip_pass_code = @trip_pass_code)
begin
	raiserror('No trips exist with TripID and TripPassCode combination',16,1)
	return -1
end

-- check if trip is meant for Smarter Sorting TruckSiS
if not exists (select 1 from TripHeader where trip_id = @trip_id and technical_equipment_type = 'T')
begin
		raiserror('ERROR: This trip has been assigned to a US Ecology MIM device. If you believe this trip should be allowed to be downloaded to TruckSiS, please contact your trip coordinator.',16,1)
		return -1
end

if not exists (select 1 from WorkOrderHeader
				where trip_id = @trip_id
				and workorder_status = 'V')
and not exists (select 1 from TripHeader
				where trip_id = @trip_id
				and trip_pass_code = @trip_pass_code
				and trip_status = 'D')
begin
	raiserror('Trip is not in Dispatched status, and therefore cannot be downloaded',16,1)
	return -1
end

begin transaction

--create connection
if not exists (select 1 from TripConnectLog where trip_id = @trip_id)
begin
	exec @trip_connect_log_id = sp_sequence_silent_next 'TripConnectLog.trip_connect_log_id'

	if @@error <> 0
	begin
		set @results = 'ERROR: sp_sequence_next failed for TripConnectLog.trip_connect_log_id'
		goto ON_ERROR
	end

	select @app_id = trip_client_app_id
	from TripConnectClientApp
	where client_app_name = 'Smarter Sorting'
	and client_app_version = 1.0

	insert TripConnectLog (trip_connect_log_id, trip_id, client_ip_address, trip_client_app_id, last_download_date)
	values (@trip_connect_log_id, @trip_id, '127.0.0.1', @app_id, getdate())

	if @@error <> 0
	begin
		set @results = 'ERROR: Could not insert into TripConnectLog table'
		goto ON_ERROR
	end
end


--manage connection per stop
if @trip_sequence_id = 0
begin
	insert TripConnectLogStop
	select wh.trip_id, wh.trip_sequence_id, tcl.last_download_date, null
	from WorkOrderHeader wh
	join TripConnectLog tcl
		on tcl.trip_id = wh.trip_id
		and tcl.trip_connect_log_id = (select max(trip_connect_log_id) from TripConnectLog where trip_id = @trip_id)
	where wh.trip_id = @trip_id
	and not exists (select 1 from TripConnectLogStop
					where trip_id = wh.trip_id
					and trip_sequence_id = wh.trip_sequence_id)

	if @@error <> 0
	begin
		set @results = 'ERROR: Could not insert into TripConnectLogStop table'
		goto ON_ERROR
	end
end
else if not exists (select 1 from TripConnectLogStop where trip_id = @trip_id and trip_sequence_id = @trip_sequence_id)
begin
	insert TripConnectLogStop
	values (@trip_id, @trip_sequence_id, null, null)

	if @@error <> 0
	begin
		set @results = 'ERROR: Could not insert into TripConnectLogStop table'
		goto ON_ERROR
	end
end


ON_SUCCESS:
commit transaction
return 0

ON_ERROR:
rollback transaction
raiserror(@results,16,1)
return -1
go

grant execute on sp_ss_get_trip_begin to EQAI, TRIPSERV
go
