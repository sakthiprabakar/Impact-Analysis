
create procedure sp_trip_sync_retrieve_end
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure records the end of a field device retrieving trip data

 loads to Plt_ai
 
 06/17/2009 - rb created
 02/08/2010 - rb push SQL to collect information about trips on local databases,
		but only if the client app is running version 1.15 or higher
 02/24/2010 - rb use TripFieldUpdate if version is 1.17 or higher
 03/09/2010 - rb don't process TripFieldUpdate for version 2.0 or higher
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 05/06/2010 - rb update new TripConnectLog last_merchandise_download_date column if merchandise retrieved
 05/20/2010 - rb if first download of trip, and serial # was recorded, store that info to TripLocalInformation
 08/19/2011 - rb Serial number, incremental merchandise download
 10/21/2011 - rb Remove requirement that upload_merchandise_ind be set in order to download DEA
 02/29/2012 - rb We now record merchandise download date by categories downloaded
 09/02/2020 - rb This was caught blocking, added set transaction isolation statement
****************************************************************************************/

declare @initial_connect_date datetime,
	@version varchar(40),
	@trip_id int,
	@msg varchar(255),
	@idx int,
	@serial_number varchar(20),
	@tcl2_id int

set transaction isolation level read uncommitted

set nocount on

-- rb 08/24/2011 record serial # if it can be determined
select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select @tcl2_id = max(tcl.trip_connect_log_id)
from TripConnectLog tcl, TripConnectLogDetail tcld
where tcl.trip_id = @trip_id
and tcl.trip_connect_log_id = tcld.trip_connect_log_id
and tcld.request like 'Trip%Serial #%'

select @msg = request
from TripConnectLogDetail
where trip_connect_log_id = @tcl2_id
and request like 'Trip%Serial #%'

if datalength(ltrim(rtrim(isnull(@msg,'')))) > 0
begin
	select @idx = charindex (' Serial ',@msg,1)
	select @serial_number = ltrim(rtrim(substring (@msg, @idx + 9,DATALENGTH(@msg) - @idx - 8)))

	select @msg = 'Downloaded to Serial # ' + @serial_number

	if not exists (select 1 from TripLocalInformation
					where trip_id = @trip_id
					and information = @msg)
		insert TripLocalInformation values (@trip_id, GETDATE(), @msg)
end

-- update any messages generated that retrieve completed
update TripConnectLogDetail
set request_date = getdate()
where trip_connect_log_id = @trip_connect_log_id
and request_date is null

-- update retrieved workorderheader records
update WorkOrderHeader
set field_download_date = getdate()
from WorkOrderHeader woh, TripConnectLog tcl
where woh.trip_id = tcl.trip_id
and tcl.trip_connect_log_id = @trip_connect_log_id
and isnull(woh.field_requested_action,'') <> 'D'
and (woh.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	 woh.field_requested_action = 'R')

-- update workorderheader refresh flags to null
update WorkOrderHeader
set field_requested_action = null
from WorkOrderHeader
where trip_id = @trip_id
and field_requested_action = 'R'

-- update last retrieved
update TripConnectLog
set last_download_date = getdate(),
	last_merchandise_download_date = getdate() --this field is no longer references
where trip_connect_log_id = @trip_connect_log_id

-- 05/06/2010 update last_merchandise_download_date, if merchandise was downloaded
-- rb 02/29/2012 we need to record by category_id, for when multiple trips are on a single device
/***
	-- rb 08/19/2011 log for incremental merchandise downloads
	if exists (select 1 from TripMerchandiseDownloadLog
			where serial_number = @serial_number)

		update TripMerchandiseDownloadLog
		set last_download_date = getdate()
		where serial_number = @serial_number
	else
		insert TripMerchandiseDownloadLog
		values (@serial_number, getdate())
***/
select distinct pxmc.category_id
into #categories
from ProfileXMerchandiseCategory pxmc
join WorkOrderDetail wd on pxmc.profile_id = wd.profile_id and wd.resource_type = 'D'
join WorkOrderHeader wh on wd.workorder_ID = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_ID = wh.profit_ctr_ID
where wh.trip_id = @trip_id

update TripMerchandiseDownloadLog
set last_download_date = GETDATE()
where serial_number = @serial_number
and category_id in (select category_id from #categories)

insert TripMerchandiseDownloadLog
select @serial_number, c.category_id, GETDATE()
from #categories c
where not exists (select 1 from TripMerchandiseDownloadLog
					where serial_number = @serial_number
					and category_id = c.category_id)

drop table #categories

-- check if this is the first connection to retrieve trip data, if so return the initial connect date
select @initial_connect_date = field_initial_connect_date
from TripHeader
where trip_id = @trip_id

if @initial_connect_date is null
begin
	update WorkOrderHeader
	set field_download_date = getdate()
	where trip_id = @trip_id
	
	select @initial_connect_date = convert(datetime,convert(varchar(20),getdate(),120))

	update TripHeader
	set field_initial_connect_date = @initial_connect_date
	where trip_id = @trip_id

	select 'update tripheader set field_initial_connect_date=''' +
		convert(varchar(20),@initial_connect_date,120) + 
		''' where trip_id = ' + convert(varchar(10),@trip_id) as sql
end
else
begin
	-- rb 03/09/2010 get version
	select @version = tcca.client_app_version
	from TripConnectLog tcl, TripConnectClientApp tcca
	where tcl.trip_connect_log_id = @trip_connect_log_id
	and tcl.trip_client_app_id = tcca.trip_client_app_id

	-- rb 03/09/2010 only do the following for version 1.X of the application
	if substring(@version,1,1) = '1'
	begin
		-- rb 02/08/2010 push SQL to collect information about trips on local databases
		select 'if exists (select 1 from tripfieldversion where processed_flag = ''T'' and (trip_field_version_id > 1'
		+ ' or (trip_field_version_id = 1 and trip_field_subversion_id >= 17)))'
		+ ' insert tripfieldupdate select distinct ' + CONVERT(varchar(10),trip_id)
		+ ', (select isnull(max(sequence_id),0)+1 from tripfieldupdate where trip_id=' + CONVERT(varchar(10),trip_id) + ' and sequence_id < 1000000),'
		+ '-1,-1,''triplocalinformation'',''<insert>'',''char(4096)'',''if not exists (select 1 from triplocalinformation '
		+ 'where trip_id = ' + convert(varchar(10),trip_id)
		+ ' and information=''''Local DB contains '' + server + '' trip '' + convert(varchar(10),trip_id) + '''''')'
		+ ' insert triplocalinformation values ('
		+ convert(varchar(10),trip_id) + ',getdate(),''''Local DB contains '' + server + '' trip '' + '
		+ 'convert(varchar(10),trip_id) + '''''')'',''F'',''MOBILE'',getdate(),''MOBILE'',getdate() '
		+ 'from tripserver where not exists (select 1 from tripfieldupdate'
		+ ' where trip_id=' + CONVERT(varchar(10),trip_id) + ' and table_name=''triplocalinformation'''
		+ ' and column_name=''<insert>'' and value like ''%DB contains%'' + server + ''%trip%'' + '
		+ 'convert(varchar(10),trip_id) + ''%'')'
		+ ' else if exists (select 1 from tripfieldversion where processed_flag = ''T'' and (trip_field_version_id > 1'
		+ ' or (trip_field_version_id = 1 and trip_field_subversion_id >= 15)))'
		+ ' insert tripfieldupdates select distinct ' + CONVERT(varchar(10),trip_id)
		+ ', (select isnull(max(sequence_id),0)+1 from tripfieldupdates where trip_id=' + CONVERT(varchar(10),trip_id) + ' and sequence_id < 1000000),'
		+ '-1,-1,''triplocalinformation'',''<insert>'',''char(4096)'',''if not exists (select 1 from triplocalinformation '
		+ 'where trip_id = ' + convert(varchar(10),trip_id)
		+ ' and information=''''Local DB contains '' + server + '' trip '' + convert(varchar(10),trip_id) + '''''')'
		+ ' insert triplocalinformation values ('
		+ convert(varchar(10),trip_id) + ',getdate(),''''Local DB contains '' + server + '' trip '' + '
		+ 'convert(varchar(10),trip_id) + '''''')'',''F'',getdate() '
		+ 'from tripserver where not exists (select 1 from tripfieldupdates'
		+ ' where trip_id=' + CONVERT(varchar(10),trip_id) + ' and table_name=''triplocalinformation'''
		+ ' and column_name=''<insert>'' and value like ''%DB contains%'' + server + ''%trip%'' + '
		+ 'convert(varchar(10),trip_id) + ''%'')' as sql
		from TripConnectLog
		where trip_connect_log_id = @trip_connect_log_id
	end
	else
		select '' as sql
end


set nocount off
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_retrieve_end] TO [EQAI]
    AS [dbo];

