
create procedure sp_trip_sync_version_updates
	@current_version_id int,
	@current_subversion_id int,
	@currently_between_trips int
as

/************
 * 10/01/2009 RB Created for initial 1.0 release
 *
 * 07/21/2014 RB For version 4.0 relase, only return 3.X updates to any version prior to version 4.0
 * 08/11/2014 RB Discovered that the @currently_between_trips flag should be igonored
 * 10/15/2015 RB Modified to return only SQL updates except for the max version (to reduce SQL size)
 *
 ************/

declare @sql varchar(4096),
	@version_id int,
	@subversion_id int,
	@deploy_date datetime,
	@update_type char(1),
	@app_file varchar(255),
	@sql_file varchar(255),
	@max_version_id int,
	@max_subversion_id int

select @max_version_id = max(trip_field_version_id)
from TripFieldVersion
where ((@current_version_id >= 4 and trip_field_version_id > @current_version_id) or
		(trip_field_version_id = @current_version_id and trip_field_subversion_id > @current_subversion_id))

select @max_subversion_id = max(trip_field_subversion_id)
from TripFieldVersion
where trip_field_version_id = @max_version_id

if @max_version_id = @current_version_id and @max_subversion_id = @current_subversion_id
	goto END_OF_PROC

set @sql = 'delete TripFieldVersion where trip_field_version_id > ' + convert(varchar(10),@current_version_id)
		+ ' or (trip_field_version_id = ' + convert(varchar(10),@current_version_id)
		+ ' and trip_field_subversion_id > ' + convert(varchar(10),@current_subversion_id) + ')'

-- loop through more recent versions, breaking if not currently between trips but updated version requires so
declare c_loop cursor for
select trip_field_version_id,
	trip_field_subversion_id,
	deploy_date,
	update_type,
	app_file_name,
	sql_file_name
from TripFieldVersion
where ((@current_version_id >= 4 and trip_field_version_id > @current_version_id) or
		(trip_field_version_id = @current_version_id and trip_field_subversion_id > @current_subversion_id))
and not (trip_field_version_id = @max_version_id and trip_field_subversion_id = @max_subversion_id)
and isnull(ltrim(sql_file_name),'') <> ''
order by trip_field_version_id asc, trip_field_subversion_id asc

open c_loop
fetch c_loop into @version_id, @subversion_id, @deploy_date, @update_type, @app_file, @sql_file

while (@@FETCH_STATUS = 0)
begin
--	if @currently_between_trips = 0 and @update_type = 'I'
--		break

	select @sql = @sql + ' insert TripFieldVersion values (' +
			convert(varchar(10),@version_id) + ', ' +
			convert(varchar(10),@subversion_id) + ', ''' +
			convert(varchar(20),@deploy_date,120) + ''', null, ' +
			'''' + @sql_file + ''', ''F'', ''F'')'

	fetch c_loop into @version_id, @subversion_id, @deploy_date, @update_type, @app_file, @sql_file
end
close c_loop
deallocate c_loop

select @app_file = app_file_name, 
		@sql_file = sql_file_name,
		@deploy_date = deploy_date
from TripFieldVersion
where trip_field_version_id = @max_version_id
and trip_field_subversion_id = @max_subversion_id

if isnull(ltrim(@app_file),'') = ''
	set @app_file = 'null'
else
	set @app_file = '''' + @app_file + ''''

if isnull(ltrim(@sql_file),'') = ''
	set @sql_file = 'null'
else
	set @sql_file = '''' + @sql_file + ''''

set @sql = @sql + ' insert TripFieldVersion values (' +
			convert(varchar(10),@max_version_id) + ', ' +
			convert(varchar(10),@max_subversion_id) + ', ''' +
			convert(varchar(20),@deploy_date,120) + ''', ' +
			@app_file + ', ' + @sql_file + ', ''F'', ''F'')'

-- return sql
END_OF_PROC:
select isnull(@sql,'') as sql

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_version_updates] TO [EQAI]
    AS [dbo];

