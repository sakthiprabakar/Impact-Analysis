if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_rx')
	drop procedure sp_ss_get_trip_rx
go

create procedure sp_ss_get_trip_rx
	@compare_date varchar(20) = 'incremental'
with recompile
as
declare @trip_id int,
		@trip_connect_log_id int,
		@app_id int,
		@dt_snapshot datetime

set transaction isolation level read uncommitted

--with only one device downloading data, we will use a single global record with trip_connect_log_id=0 to record last download date
set @trip_id = 0
set @trip_connect_log_id = 0

--set the timestamp of the Rx data snapshot that was given to Smarter Sorting
set @dt_snapshot = '2020-05-07 12:30:00'

if @compare_date = 'incremental'
	set @compare_date = null

if not exists (select 1 from TripConnectLog where trip_id = @trip_connect_log_id)
begin
	select @app_id = trip_client_app_id
	from TripConnectClientApp
	where client_app_name = 'Smarter Sorting'
	and client_app_version = 1.0

	insert TripConnectLog (trip_connect_log_id, trip_id, client_ip_address, trip_client_app_id, last_merchandise_download_date)
	values (@trip_connect_log_id, @trip_id, '127.0.0.1', @app_id, @dt_snapshot)

	if @@error <> 0
	begin
		rollback transaction
		raiserror('ERROR: Could not insert into TripConnectLog table',16,1)
		return -1
	end
end

select distinct m.merchandise_id,
	m.merchandise_desc,
	m.merchandise_status,
	m.category_id,
	coalesce(m.dea_schedule,'') dea_schedule,
	coalesce(m.strength,'') strength,
	coalesce(m.unit,'') unit,
	coalesce(m.package_size,'') package_size,
	mc.customer_id,
	mct.code_description code_type,
	mc.merchandise_code
from Merchandise m
join MerchandiseCode mc
	on mc.merchandise_id = m.merchandise_id
join MerchandiseCodeType mct
	on mct.code_type = mc.code_type
join TripConnectLog tcl
	on tcl.trip_connect_log_id = @trip_connect_log_id
where m.merchandise_status = 'A'
and (m.date_added > coalesce(@compare_date,tcl.last_merchandise_download_date,@dt_snapshot)
	or m.date_modified > coalesce(@compare_date,tcl.last_merchandise_download_date,@dt_snapshot)
	or mc.date_added > coalesce(@compare_date,tcl.last_merchandise_download_date,@dt_snapshot)
	or mc.date_modified > coalesce(@compare_date,tcl.last_merchandise_download_date,@dt_snapshot))
union
select distinct m.merchandise_id,
	m.merchandise_desc,
	m.merchandise_status,
	m.category_id,
	coalesce(m.dea_schedule,'') dea_schedule,
	coalesce(m.strength,'') strength,
	coalesce(m.unit,'') unit,
	coalesce(m.package_size,'') package_size,
	convert(int,null) customer_id,
	'' code_type,
	'' merchandise_code
from Merchandise m
left outer join TripConnectLog tcl
	on tcl.trip_connect_log_id = coalesce(@trip_connect_log_id,0)
where m.merchandise_id = 408901
and m.date_modified > coalesce(@compare_date,tcl.last_merchandise_download_date,@dt_snapshot)
order by m.merchandise_id

update TripConnectLog
set last_merchandise_download_date = getdate()
where trip_connect_log_id = @trip_connect_log_id
go

grant execute on sp_ss_get_trip_rx to EQAI, TRIPSERV
go
