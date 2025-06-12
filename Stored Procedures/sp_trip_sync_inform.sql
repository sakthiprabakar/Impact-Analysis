
create procedure sp_trip_sync_inform
	@trip_connect_log_id int,
	@msg varchar(255)
as
/***************************************************************************************
 this procedure allows a field device to send informational data (ie refuse deleting a stop)

 loads to Plt_ai
 
 06/17/2009 - rb created
****************************************************************************************/

declare @stop_number varchar(10)

set nocount on

select @msg = ltrim(rtrim(isnull(@msg,'')))

-- look for command at beginning of string
if substring(@msg, 1, 9) = 'NODELETE '
begin
	select @stop_number = ltrim(rtrim(substring(@msg,10,datalength(@msg))))

	update TripConnectLogDetail
	set request = request + ' - DEVICE REFUSED DELETION'
	where trip_connect_log_id = @trip_connect_log_id
	and request like '%Delete Stop #' + @stop_number
	and request_date is null
end

else if substring(@msg, 1, 10) = 'NOREFRESH '
begin
	select @stop_number = ltrim(rtrim(substring(@msg,10,datalength(@msg))))

	update TripConnectLogDetail
	set request = request + ' - DEVICE REFUSED REFRESH'
	where trip_connect_log_id = @trip_connect_log_id
	and request like '%Refresh Stop #' + @stop_number
	and request_date is null
end

set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_inform] TO [EQAI]
    AS [dbo];

