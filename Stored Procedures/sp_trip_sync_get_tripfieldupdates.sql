
create procedure sp_trip_sync_get_tripfieldupdates
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the TripFieldUpdates table on a trip local database.
 This one is different from all others, only returns records if its the first connect.

 loads to Plt_ai
 
 06/10/2009 - rb created
 02/02/2010 - rb patch to force a resend of lost sync records
 02/24/2010 - rb remove patch, select from new TripFieldUpdate table
****************************************************************************************/

declare @trip_id int,
	@initial_connect_dt datetime,
	@count int,
	@max_seq int

set nocount on

-- get trip_id
select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

-- get initial connect date
select @initial_connect_dt = field_initial_connect_date
from TripHeader
where trip_id = @trip_id

if @initial_connect_dt is null
	-- rb 02/02/2010 rb now just return the max seq record, so local db knows what seq to start at
	select 'if not exists (select 1 from TripFieldUpdates where trip_id = ' + convert(varchar(20),TripFieldUpdates.trip_id) + ' and sequence_id = ' + convert(varchar(20),TripFieldUpdates.sequence_id) + ' and trip_sequence_id = ' + convert(varchar(20),TripFieldUpdates.trip_sequence_id) + ' and other_sequence_id = ' + convert(varchar(20),TripFieldUpdates.other_sequence_id) + ' and table_name = ''' + TripFieldUpdates.table_name + ''' and column_name = ''' + TripFieldUpdates.column_name + ''''
	+ ') insert into TripFieldUpdates values('
	+ convert(varchar(20),TripFieldUpdates.trip_id) + ','
	+ convert(varchar(20),TripFieldUpdates.sequence_id) + ','
	+ isnull(convert(varchar(20),TripFieldUpdates.trip_sequence_id),'null') + ','
	+ isnull(convert(varchar(20),TripFieldUpdates.other_sequence_id),'null') + ','
	+ '''' + replace(TripFieldUpdates.table_name, '''', '''''') + '''' + ','
	+ '''' + replace(TripFieldUpdates.column_name, '''', '''''') + '''' + ','
	+ '''' + replace(TripFieldUpdates.column_type, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TripFieldUpdates.value, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TripFieldUpdates.processed_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TripFieldUpdates.date_created,120) + '''','null') + ')' as sql
	from TripFieldUpdates, TripConnectLog
	where TripFieldUpdates.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id

	union

	select 'if not exists (select 1 from TripFieldUpdate where trip_id = ' + convert(varchar(20),TripFieldUpdate.trip_id) + ' and sequence_id = ' + convert(varchar(20),TripFieldUpdate.sequence_id) + ' and trip_sequence_id = ' + convert(varchar(20),TripFieldUpdate.trip_sequence_id) + ' and other_sequence_id = ' + convert(varchar(20),TripFieldUpdate.other_sequence_id) + ' and table_name = ''' + TripFieldUpdate.table_name + ''' and column_name = ''' + TripFieldUpdate.column_name + ''''
	+ ') insert into TripFieldUpdate values('
	+ convert(varchar(20),TripFieldUpdate.trip_id) + ','
	+ convert(varchar(20),TripFieldUpdate.sequence_id) + ','
	+ isnull(convert(varchar(20),TripFieldUpdate.trip_sequence_id),'null') + ','
	+ isnull(convert(varchar(20),TripFieldUpdate.other_sequence_id),'null') + ','
	+ '''' + replace(TripFieldUpdate.table_name, '''', '''''') + '''' + ','
	+ '''' + replace(TripFieldUpdate.column_name, '''', '''''') + '''' + ','
	+ '''' + replace(TripFieldUpdate.column_type, '''', '''''') + '''' + ','
	+ isnull('''' + replace(TripFieldUpdate.value, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TripFieldUpdate.processed_flag, '''', '''''') + '''','null') + ','
	+ isnull('''' + replace(TripFieldUpdate.added_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TripFieldUpdate.date_added,120) + '''','null') + ','
	+ isnull('''' + replace(TripFieldUpdate.modified_by, '''', '''''') + '''','null') + ','
	+ isnull('''' + convert(varchar(20),TripFieldUpdate.date_modified,120) + '''','null') + ')' as sql
	from TripFieldUpdate, TripConnectLog
	where TripFieldUpdate.trip_id = TripConnectLog.trip_id
	and TripConnectLog.trip_connect_log_id = @trip_connect_log_id
else
	select '' as sql


set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_tripfieldupdates] TO [EQAI]
    AS [dbo];

