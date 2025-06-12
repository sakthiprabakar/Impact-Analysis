
create procedure sp_trip_sync_add_connect_detail
	@trip_connect_log_id	int,
	@request				varchar(255),
	@request_date		datetime = null
as
/***************************************************************************************
 this procedure adds a detail record for activity from a field device

 loads to Plt_ai
 
 06/17/2009 - rb created
****************************************************************************************/

declare @sequence_id int,
		@results varchar(255)

set nocount on

-- get max sequence_id for connection log
select @sequence_id = max(sequence_id)
from TripConnectLogDetail
where trip_connect_log_id = @trip_connect_log_id

if @sequence_id is null or @sequence_id < 0
	select @sequence_id = 0

-- insert detail
insert TripConnectLogDetail
values (@trip_connect_log_id, @sequence_id+1, @request, @request_date)
if @@error <> 0
begin
	select @results = 'ERROR: Could not insert record into TripConnectLogDetail'
	goto END_OF_PROC
end

-- end, return results
END_OF_PROC:
set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_add_connect_detail] TO [EQAI]
    AS [dbo];

