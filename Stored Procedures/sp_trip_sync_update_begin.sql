
create procedure sp_trip_sync_update_begin
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure records the beginning of update SQL being sent from field device

 loads to Plt_ai
 
 06/17/2009 - rb created
 03/11/2010 - rb sync rewrite version 2.0, new sync table
****************************************************************************************/

set nocount on

-- remove any messages generated that were generated but not completed for some reason
delete TripConnectLogDetail
where trip_connect_log_id = @trip_connect_log_id
and request_date is null

exec sp_trip_sync_add_connect_detail @trip_connect_log_id, '   Upload modified records.'

END_OF_PROC:
set nocount off
if exists (select 1 from TripSyncUpload where trip_connect_log_id = @trip_connect_log_id)
	select '' as sql
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_update_begin] TO [EQAI]
    AS [dbo];

