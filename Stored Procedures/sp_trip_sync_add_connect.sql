if exists (select 1 from sysobjects where type = 'P' and name = 'sp_trip_sync_add_connect')
	drop procedure sp_trip_sync_add_connect
go
create procedure sp_trip_sync_add_connect
	@client_ip_address	varchar(15),
	@app_name			varchar(20),
	@app_version		varchar(20),
	@cpu_desc			varchar(80),
	@cpu_speed_mhz		int,
	@os_desc			varchar(80),
	@os_major_version	int,
	@os_minor_version	int,
	@os_build_number	int,
	@trip_id			int,
	@trip_pass_code		varchar(15),
	@initial_connect	varchar(20),
	@serial_number		varchar(20) = null
as
/***************************************************************************************
 this procedure records a connection from field device

 loads to Plt_ai
 
 06/17/2009 - rb created
 01/05/2010 - rb add detail to trip connect log if initial connect date doesn't match
 03/02/2010 - rb create a record every time connected, even if same version etc
 04/07/2010 - rb query max connect log id for trip, bug after 03/02/2010 change
 05/06/2010 - rb add last_merchandise_download_date, to keep separate from trip last_download_date
 05/20/2010 - rb add @serial_number parameter to record serial # connecting to trip
 01/21/2013 - rb Profit Center renumbering 22-02 -> 14-04 post-fix...force update to 3.04
 03/14/2013 - rb Management Code update...force update to version 3.05
 10/14/2014 - rb Allow development test trip 26670 to be downloaded repeatedly (ignore check against field_initial_connect_date)
 10/15/2015 - rb Changed error message to reference US Ecology instead of EQ
 09/09/2016 - rb Appended message to call trip coordinator when trip is not in dispatched status
 08/31/2020 - rb Return an error message if the trip is linked to Smarter Sorting TruckSiS
 11/17/2020 - rb DevOps 17986 - Changed error message to specifically mention the MIM since Labpack is now a possibility as well

****************************************************************************************/

declare @trip_connect_log_id	int,
		@trip_client_app_id		int,
		@os_type_id				int,
		@cpu_type_id			int,
		@connect_date			datetime,
		@today				datetime,
		@last_download_date		datetime,
		@last_upload_date		datetime,
		@last_merch_download_date	datetime,
		@results			varchar(255),
		@msg				varchar(255),
		@version_dec			numeric(5,2)

set nocount on

-- rb check if trip is meant for MIM
if not exists (select 1 from TripHeader where trip_id = @trip_id and coalesce(technical_equipment_type,'M') = 'M')
begin
	set @trip_connect_log_id = null
	set @results = 'ERROR: This trip is not currently assigned for a MIM device to download. If you believe this trip should be linked to a MIM, please contact your trip coordinator.'
	goto END_OF_PROC
end

-- rb 02/04/2011 major table changes with EQAI 6.0 rollout, don't allow versions prior to 2.14
select @version_dec = CONVERT(numeric(5,2),left(@app_version,CHARINDEX('.',@app_version) - 1) + '.'
				+ right('0' + SUBSTRING(@app_version,charindex('.',@app_version) + 1,2),2))

if @version_dec < 3.05
begin
		select @results = 'ERROR: You are running MIM version ' + @app_version + ', which is out of date and must be updated before synchronizing. Please exit the application and relaunch it to get the latest update.'
		goto END_OF_PROC
end

-- record current datetime
select @today = getdate()

-- if previously logged in, return existing connect id
if @initial_connect is not null and datalength(ltrim(@initial_connect)) > 18
	select @connect_date = convert(datetime,@initial_connect)

if @connect_date is null
begin
	if @trip_id <> 26670
	begin
		if exists (select 1 from TripHeader
					where trip_id = @trip_id
					and field_initial_connect_date is not null)
		begin
			select @results = 'ERROR: This trip has already been downloaded by another user and has not been authorized to be downloaded by another.'
			+ char(13) + char(10) + char(13) + char(10) + 'If you think that this Trip ID should be available for you to use, please contact your trip coordinator.'
			goto END_OF_PROC
		end
	end
end
else
begin
	if not exists (select 1 from TripHeader
			where trip_id = @trip_id
			and trip_pass_code = @trip_pass_code)
	begin
		select @results = 'ERROR: The Passcode entered does not match what is associated with the trip at US Ecology.'
		goto END_OF_PROC
	end

	-- rb query for max() ID instead of just the id
	select @trip_connect_log_id = max(tcl.trip_connect_log_id)
	from TripConnectLog tcl, TripHeader th
	where tcl.trip_id = @trip_id
	and tcl.trip_id = th.trip_id
	and th.trip_pass_code = @trip_pass_code
	and th.field_initial_connect_date = @connect_date


	if @trip_connect_log_id is null
	begin
		-- rb 01/05/2010 attempt to log that date didn't match
		select @trip_connect_log_id = tcl.trip_connect_log_id
		from TripConnectLog tcl, TripHeader th
		where tcl.trip_id = @trip_id
		and tcl.trip_id = th.trip_id
		and th.trip_pass_code = @trip_pass_code

		if @trip_connect_log_id is not null
		begin
			select @results = 'Client connected with correct Trip ID and Passcode, but Initial Connect Date was ''' + @initial_connect + ''''
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @results, @today
		end

		select @results = 'ERROR: The Initial Connect date recorded on the server is out of sync with this device.'

		goto END_OF_PROC -- rb 03/02/2010 added this now that we don't jump to the end immediately after this code block
	end

	-- rb if we have an ID, carry the last_download_date and last_upload_date forward
	else
		select @last_download_date = last_download_date,
			@last_upload_date = last_upload_date,
			@last_merch_download_date = last_merchandise_download_date
		from TripConnectLog
		where trip_connect_log_id = @trip_connect_log_id

	-- rb 03/02/2010 don't reuse connect_log_ids anymore
	--goto END_OF_PROC
end

-- if trip and passcode combination doesn't exist, return error message
if not exists (select 1 from TripHeader
					where trip_id = @trip_id
					and trip_pass_code = @trip_pass_code)
begin
	select @results = 'ERROR: The Trip ID and Trip Pass Code combination entered does not exist.'
	goto END_OF_PROC
end

-- make sure trip status is Dispatched
if not exists (select 1 from TripHeader
					where trip_id = @trip_id
					and trip_status = 'D')
begin
	select @results = 'ERROR: The trip does not have a status of Dispatched, connection not allowed.'
			+ char(13) + char(10) + char(13) + char(10) + 'If you think that this Trip ID should be available for you to use, please contact your trip coordinator.'
	goto END_OF_PROC
end

-- lookup client app
select @trip_client_app_id = trip_client_app_id
from TripConnectClientApp
where client_app_name = @app_name
and client_app_version = @app_version

if @trip_client_app_id is null or @trip_client_app_id < 1
begin
	select @trip_client_app_id = max(trip_client_app_id)
	from TripConnectClientApp

	if @trip_client_app_id is null or @trip_client_app_id < 1
		select @trip_client_app_id = 1
	else
		select @trip_client_app_id = @trip_client_app_id + 1

	insert TripConnectClientApp
	values (@trip_client_app_id, @app_name, @app_version, @today)
end

-- lookup CPU Type
select @cpu_type_id = cpu_type_id
from TripConnectCPUType
where cpu_desc = @cpu_desc

if @cpu_type_id is null or @cpu_type_id < 1
begin
	select @cpu_type_id = max(cpu_type_id)
	from TripConnectCPUType

	if @cpu_type_id is null or @cpu_type_id < 1
		select @cpu_type_id = 1
	else
		select @cpu_type_id = @cpu_type_id + 1

	insert TripConnectCPUType
	values (@cpu_type_id, @cpu_desc, @today)
end

-- lookup OS Type
select @os_type_id = os_type_id
from TripConnectOSType
where os_desc = @os_desc

if @os_type_id is null or @os_type_id < 1
begin
	select @os_type_id = max(os_type_id)
	from TripConnectOSType

	if @os_type_id is null or @os_type_id < 1
		select @os_type_id = 1
	else
		select @os_type_id = @os_type_id + 1

	insert TripConnectOSType
	values (@os_type_id, @os_desc, @today)
end

-- insert parameters (don't insert dates, it will be updated when trip retrieved)
select @connect_date = convert(datetime,convert(varchar(20),@today,120))

-- get connection log id
exec @trip_connect_log_id = sp_sequence_next 'TripConnectLog.trip_connect_log_id'


insert TripConnectLog
values (@trip_connect_log_id, @trip_id, @client_ip_address,
		@trip_client_app_id, @cpu_type_id, @cpu_speed_mhz, @os_type_id,
		@os_major_version, @os_minor_version, @os_build_number,
		@last_download_date, @last_upload_date, @last_merch_download_date) -- rb 04/07/2010 carry forward last log record values
			
if @@error <> 0
begin
	select @results = 'ERROR: Could not insert record into TripConnectLog'
	goto END_OF_PROC
end

-- rb 05/20/2010 record the serial # that connected to trip, if downloading first time
if datalength(ltrim(rtrim(isnull(@initial_connect,'')))) < 1 and datalength(ltrim(rtrim(isnull(@serial_number,'')))) > 0
begin
	if substring(@serial_number,1,4) = 'USER'
		select @serial_number = substring(@serial_number,5,datalength(@serial_number)-4)

	select @msg = 'Trip downloaded by Field Device with Serial # ' + @serial_number

	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @today
end


-- return results
END_OF_PROC:

-- log message if connection was successful
if @trip_connect_log_id is not null and @trip_connect_log_id > 0 and @results is null
begin
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, 'Field device connected to EQ Server.', @today

	select @results = convert(varchar(20),@trip_connect_log_id)
end

set nocount off

select @results as results
return 0
go

grant execute on sp_trip_sync_add_connect to eqai
go
