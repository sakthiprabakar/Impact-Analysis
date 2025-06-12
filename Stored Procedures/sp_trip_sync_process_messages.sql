
create procedure sp_trip_sync_process_messages
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure processes messages sent from a field device

 loads to Plt_ai
 
 07/09/2009 - rb created
****************************************************************************************/

set nocount on

declare @trip_id int,
			@customer_id int,
			@trip_sequence_id int,
			@seq_id int,
			@other_sequence_id int,
			@message_text varchar(255),
			@err int,
			@dt datetime


select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

declare c_loop cursor for
select trip_sequence_id, sequence_id, other_sequence_id, message_text
from TripFieldMessage
where trip_id = @trip_id
and processed_flag <> 'T'
order by trip_sequence_id, sequence_id
for read only

open c_loop
fetch c_loop
into @trip_sequence_id,
		@seq_id,
		@other_sequence_id,
		@message_text

while @@FETCH_STATUS = 0
begin
	select @dt = convert(datetime, convert(varchar(20),getdate(),120))

	begin transaction

	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @message_text, @dt

	select @err = @@error

	if @err = 0
	begin
		update TripFieldMessage
		set processed_flag = 'T'
		where trip_id = @trip_id
		and sequence_id = @seq_id

		commit transaction
	end
	else
	begin
		-- log error
		rollback transaction
	end


	-- fetch next record
	fetch c_loop
	into @trip_sequence_id,
			@seq_id,
			@other_sequence_id,
			@message_text
end

close c_loop
deallocate c_loop

set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_process_messages] TO [EQAI]
    AS [dbo];

