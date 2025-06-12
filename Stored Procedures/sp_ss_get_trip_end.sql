use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_end')
	drop procedure sp_ss_get_trip_end
go

create procedure sp_ss_get_trip_end
	@trip_id int,
	@trip_sequence_id int
as
/************************
 *
 * 12/10/2019 rwb Created
 * 04/27/2021 rwb ADO 17520 Removed SQL that sets WorkOrderHeader.field_download_date (TruckSiS will set it by calling our web service)
 * 05/14/2021 rwb ADO 20860 Removed SQL that logs call to TripConnectLogDetail because it is called often by the TruckSiS application server
 *
 --select * from TripConnectLogStop
 --exec sp_ss_get_trip_end 79814, 27
 --exec sp_ss_get_trip_end 79814, 0
 --
 *
 ************************/
declare @trip_connect_log_id int,
		@idx int,
		@initial_connect_date datetime,
		@msg varchar(max)

select @trip_connect_log_id = max(trip_connect_log_id)
from TripConnectLog
where trip_id = @trip_id

set @msg = 'Downloaded to TruckSiS application server'

begin transaction

if not exists (select 1 from TripLocalInformation
				where trip_id = @trip_id
				and information = @msg)
begin
	insert TripLocalInformation values (@trip_id, GETDATE(), @msg)

	if @@ERROR <> 0
	begin
		set @msg = 'Error: inserting into TripLocalInformation'
		goto ON_ERROR
	end
end

-- update retrieved workorderheader records
update WorkOrderHeader
set field_requested_action = null
from WorkOrderHeader
where trip_id = @trip_id
and trip_sequence_id = @trip_sequence_id

if @@ERROR <> 0
begin
	set @msg = 'Error: updating WorkOrderHeader record'
	goto ON_ERROR
end

--update trip connect log
update TripConnectLog
set last_download_date = getdate()
where trip_connect_log_id = @trip_connect_log_id

if @@ERROR <> 0
begin
	set @msg = 'Error: updating TripConnectLog last_download_date'
	goto ON_ERROR
end

--update connect log per stop
if @trip_sequence_id = 0
begin
	update TripConnectLogStop
	set last_download_date = getdate()
	where trip_id = @trip_id

	if @@ERROR <> 0
	begin
		set @msg = 'Error: updating TripConnectLogStop last_download_date'
		goto ON_ERROR
	end
end
else
begin
	update TripConnectLogStop
	set last_download_date = getdate()
	where trip_id = @trip_id
	and trip_sequence_id = @trip_sequence_id

	if @@ERROR <> 0
	begin
		set @msg = 'Error: updating TripConnectLogStop last_download_date'
		goto ON_ERROR
	end
end


--ON_SUCCESS
ON_SUCCESS:
commit transaction
set nocount off
return 0

--ON_ERROR
ON_ERROR:
rollback transaction
set nocount off
raiserror (@msg, 16, 1) 
return -1
go

grant execute on sp_ss_get_trip_end to EQAI, TRIPSERV
go
