
create procedure dbo.sp_trip_sync_device_initial_connect
	@serial_number varchar(20)
as
/***************************************************************************************
 this procedure was created to clear out the Merchandise Download log, but can grow if necessary

 03/02/2012 - rb Created.

 ***************************************************************************************/

if (select COUNT(*) from TripMerchandiseDownloadLog
	where serial_number = @serial_number) > 0

	delete TripMerchandiseDownloadLog
	where serial_number = @serial_number

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_device_initial_connect] TO [EQAI]
    AS [dbo];

