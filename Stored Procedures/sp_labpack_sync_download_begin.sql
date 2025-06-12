create procedure [dbo].[sp_labpack_sync_download_begin]
	@client_ip_address		varchar(15),
	@client_version			numeric(6,2),
	@trip_id				int,
	@trip_pass_code			varchar(15),
	@initial_connect_date	datetime = null
as
/***************************************************************************************
 this procedure records a connection from lab pack field device

 loads to Plt_ai
 
 11/01/2019 - rwb created

****************************************************************************************/

declare @trip_connect_log_id	int,
		@sequence_id			int,
		@trip_client_app_id		int,
		@last_download_date		datetime,
		@last_upload_date		datetime,
		@last_merch_download_date	datetime,
		@results			varchar(max),
		@msg				varchar(255)

set nocount on

--get id for Labpack version
select @trip_client_app_id = max(trip_client_app_id) from TripConnectClientApp where client_app_name = 'Labpack'

begin transaction

if not exists (select 1 from TripHeader where trip_id = @trip_id and technical_equipment_type = 'L')
begin
		set @results = 'ERROR: This trip is not currently assigned for a LPx device to download. If you believe this trip should be linked to a LPx device, please contact your trip coordinator.'
		goto ON_ERROR
end

--check that trip wasn't already downloaded
if @initial_connect_date is null
begin
	if exists (select 1 from TripHeader
				where trip_id = @trip_id
				and field_initial_connect_date is not null)
	begin
		select @results = 'ERROR: This trip has already been downloaded by another device and has not been authorized to be downloaded by another.'
		+ char(13) + char(10) + char(13) + char(10) + 'If you think that this Trip ID should be available for you, please contact your trip coordinator.'
		goto ON_ERROR
	end
end
else
begin
	if not exists (select 1 from TripHeader
					where trip_id = @trip_id
					and field_initial_connect_date = @initial_connect_date)
	begin
		select @results = 'ERROR: The Initial Connect Date recorded on the server for this device does not match, so it appears that another device has downloaded it.'
		+ char(13) + char(10) + char(13) + char(10) + 'If you think that this Trip ID should be available for you, please contact your trip coordinator.'
		goto ON_ERROR
	end
end

--validate trip pass code
if not exists (select 1 from TripHeader where trip_id = @trip_id and trip_pass_code = @trip_pass_code)
begin
	select @results = 'ERROR: The trip_id and trip_pass_code combination entered does not exists. Please double-check and try again.'
	goto ON_ERROR
end

-- make sure trip status is Dispatched
if not exists (select 1 from TripHeader
					where trip_id = @trip_id
					and trip_status = 'D')
begin
	select @results = 'ERROR: The trip does not have a status of Dispatched, connection not allowed.'
			+ char(13) + char(10) + char(13) + char(10) + 'If you think that this Trip ID should be available for you to use, please contact your trip coordinator.'
	goto ON_ERROR
end

--create connection
if exists (select 1 from TripConnectLog where trip_id = @trip_id)
begin
	select @trip_connect_log_id = max(trip_connect_log_id)
	from TripConnectLog
	where trip_id = @trip_id

	select @sequence_id = max(sequence_id) + 1
	from TripConnectLogDetail 
	where trip_connect_log_id = @trip_connect_log_id
end
else
begin
	exec @trip_connect_log_id = sp_sequence_silent_next 'TripConnectLog.trip_connect_log_id'

	if @@error <> 0
	begin
		set @results = 'ERROR: sp_sequence_next failed for TripConnectLog.trip_connect_log_id'
		goto ON_ERROR
	end

	insert TripConnectLog (trip_connect_log_id, trip_id, client_ip_address, trip_client_app_id, last_download_date)
	values (@trip_connect_log_id, @trip_id, @client_ip_address, @trip_client_app_id, getdate())

	if @@error <> 0
	begin
		set @results = 'ERROR: Could not insert into TripConnectLog table'
		goto ON_ERROR
	end

	set @sequence_id = 1
end

insert TripConnectLogDetail values (@trip_connect_log_id, @sequence_id, 'Device connected to sync data', getdate())

if @@error <> 0
begin
	set @results = 'ERROR: Could not insert into TripConnectLogDetail table'
	goto ON_ERROR
end

/*
--ensure initial connect date is set
if exists (select 1 from TripHeader
			where trip_id = @trip_id
			and field_initial_connect_date is null)
begin
	update TripHeader
	set field_initial_connect_date = convert(varchar(20),getdate(),120)
	where trip_id = @trip_id

	if @@error <> 0
	begin
		set @results = 'ERROR: Could not update TripHeader.field_initial_connect_date'
		goto ON_ERROR
	end
end
*/

ON_SUCCESS:
commit transaction

set nocount off

select @trip_connect_log_id as trip_connect_log_id

return 0

--ON_ERROR
ON_ERROR:
rollback transaction
set nocount off
raiserror (@results, 16, 1) 
return -1