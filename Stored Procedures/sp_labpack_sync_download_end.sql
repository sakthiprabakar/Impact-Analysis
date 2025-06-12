create procedure [dbo].[sp_labpack_sync_download_end]
	@trip_connect_log_id	int
as
/***************************************************************************************
 this procedure completes a data sync from lab pack field device

 loads to Plt_ai
 
 11/01/2019 - rwb created

****************************************************************************************/

declare @initial_connect_date datetime,
	@version varchar(40),
	@trip_id int,
	@msg varchar(255),
	@idx int,
	@serial_number varchar(20),
	@tcl2_id int
		
set nocount on

select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

begin transaction

set @msg = 'Downloaded to labpack device'

if not exists (select 1 from TripConnectLogDetail
				where trip_connect_log_id = @trip_connect_log_id
				and request = @msg)
begin
	select @idx = max(sequence_id)
	from TripConnectLogDetail
	where trip_connect_log_id = @trip_connect_log_id

	insert TripConnectLogDetail values (@trip_connect_log_id, COALESCE(@idx,0) + 1, @msg, getdate())

	if @@ERROR <> 0
	begin
		set @msg = 'Error: inserting into TripConnectLogDetail'
		goto ON_ERROR
	end
end

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
set field_download_date = getdate(),
	field_requested_action = null
from WorkOrderHeader
where trip_id = @trip_id
and isnull(field_requested_action,'') = 'R'

if @@ERROR <> 0
begin
	set @msg = 'Error: updating WorkOrderHeader records'
	goto ON_ERROR
end

-- check if this is the first connection to retrieve trip data, if so return the initial connect date
select @initial_connect_date = field_initial_connect_date
from TripHeader
where trip_id = @trip_id

if @initial_connect_date is null
begin
	update WorkOrderHeader
	set field_download_date = getdate()
	where trip_id = @trip_id

	if @@ERROR <> 0
	begin
		set @msg = 'Error: updating WorkOrderHeader records'
		goto ON_ERROR
	end
	
	select @initial_connect_date = convert(datetime,convert(varchar(20),getdate(),120))

	update TripHeader
	set field_initial_connect_date = @initial_connect_date
	where trip_id = @trip_id

	if @@ERROR <> 0
	begin
		set @msg = 'Error: updating TripHeader field_initial_connect_date'
		goto ON_ERROR
	end
end

--ON_SUCCESS
ON_SUCCESS:
commit transaction

set nocount off

select convert(varchar(20),@initial_connect_date,120) as initial_connect_date

return 0

--ON_ERROR
ON_ERROR:
rollback transaction
set nocount off
raiserror (@msg, 16, 1) 
return -1
