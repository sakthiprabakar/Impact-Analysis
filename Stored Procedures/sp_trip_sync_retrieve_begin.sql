
create procedure sp_trip_sync_retrieve_begin
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure records the beginning of a field device retrieving trip data

 loads to Plt_ai
 
 06/17/2009 - rb created
 02/02/2010 - rb patch to check for missing updates and force a resend
 02/17/2010 - rb remove patch released on 02/02/2010
 02/22/2010 - rb made patch more efficient to update processed_flag
 03/02/2010 - rb changed the processed_flag patch to force tripfieldupdate to brute-force
                 update the new tripfieldupdate table.
 03/09/2010 - rb don't process tripfieldupdate if version is 2.0 or higher
 03/11/2010 - rb sync rewrite version 2.0, return null date_added and date_modified
 08/24/2011 - rb add code to support CustomerTypeEmptyBottleApproval, for version >= 2.21
 11/16/2011 - rb new logic for CustomerTypeEmptyBottleApproval, for version >= 2.25
 11/28/2011 - rb bug when updating new empty bottle approval, was rounding to 4 places which ended up zero
 09/02/2020 - rb Added set transaction isolation statement
****************************************************************************************/

declare @initial_connect_date datetime,
	@sequence_id int,
	@count int,
	@count2 int,
	@msg varchar(255),
	@trip_id int,

	@seq_id int,
	@sort_id int,
	@sql varchar(2048),
	@sql2 varchar(2048),
	@version varchar(40)

set transaction isolation level read uncommitted

set nocount on

-- get trip_id
select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

-- remove any messages generated that were generated but not completed for some reason
delete TripConnectLogDetail
where trip_connect_log_id = @trip_connect_log_id
and request_date is null

-- log if this is the first connection to retrieve trip data
select @initial_connect_date = field_initial_connect_date
from TripHeader
where trip_id = @trip_id

if @initial_connect_date is null
begin
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, '   First connection to retrieve all trip data.'
	goto END_OF_PROC
end
else
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, '   Query for new records and/or EQ requested actions.'

-- log stops to be deleted
declare c_loop cursor for
select trip_sequence_id
from WorkOrderHeader
where trip_id = @trip_id
and field_requested_action = 'D'
order by trip_sequence_id
for read only

open c_loop
fetch c_loop into @sequence_id

while @@FETCH_STATUS = 0
begin
	select @msg = '      Delete Stop #' + convert(varchar(3),@sequence_id)
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg

	fetch c_loop into @sequence_id
end

close c_loop
deallocate c_loop


-- log stops to be refreshed
declare c_loop cursor for
select trip_sequence_id
from WorkOrderHeader
where trip_id = @trip_id
and field_requested_action = 'R'
order by trip_sequence_id
for read only

open c_loop
fetch c_loop into @sequence_id

while @@FETCH_STATUS = 0
begin
	select @msg = '      Refresh Stop #' + convert(varchar(3),@sequence_id)
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg

	fetch c_loop into @sequence_id
end

close c_loop
deallocate c_loop


-- determine # of individual approvals to be deleted
select @count = count(*)
from WorkOrderDetail wod, WorkOrderHeader woh
where wod.workorder_id = woh.workorder_id
and wod.company_id = woh.company_id
and wod.profit_ctr_id = woh.profit_ctr_id
and woh.trip_id = @trip_id
and wod.resource_type = 'D'
and wod.field_requested_action = 'D'

if @count > 0
begin
	select @msg = '      Delete ' + convert(varchar(3),@count) + ' individual approval records.'
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg
end


END_OF_PROC:

--set nocount off
--select '' as sql

-- rb 03/09/2010 get version
select @version = tcca.client_app_version
from TripConnectLog tcl, TripConnectClientApp tcca
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_client_app_id = tcca.trip_client_app_id

-- rb 03/09/2010 the following block of code is only processed for version 1.X of the application
if substring(@version,1,1) = '1'
begin
	create table #sql (
	sort_id int,
	sql varchar(2048))

	-- tripfieldupdates (old sync table)
	select 	@sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdates'')' +
			' update tripfieldupdates set processed_flag=''F''' +
			' where trip_id=' + CONVERT(varchar(20),@trip_id)
	insert #sql values (0, @sql)

	select @count=0,
		@sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdate'')' +
			' update tripfieldupdate set processed_flag = ''T''' +
			' where trip_id=' + CONVERT(varchar(20),@trip_id) +
			' and sequence_id in ('

	-- rb 03/02/2010 brute force, first time this was deployed all of tripfieldupdates should have been placed into
	--               tripfieldupdate. Found a trip that had some scragglers, it won't hurt to force this, it fixed a trip
	select @count2=0,
		@sql2 = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdates'')' +
			' update tripfieldupdates set processed_flag = ''T''' +
			' where trip_id=' + CONVERT(varchar(20),@trip_id) +
			' and sequence_id in ('

	declare c_loop cursor for
	select sequence_id
	from tripfieldupdates tfu
	where trip_id = @trip_id
	order by sequence_id

	open c_loop
	fetch c_loop into @seq_id

	while (@@FETCH_STATUS = 0)
	begin
		if @count > 0
			select @sql = @sql + ','

		select @count = @count + 1,
			@sql = @sql + CONVERT(varchar(20),@seq_id)
	
		if DATALENGTH(@sql) > 1800
		begin
			select @sql = @sql + ')'
			insert #sql values (1,@sql)
			select @count = 0,
				@sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdates'')' +
					' update tripfieldupdates set processed_flag = ''T''' +
					' where trip_id=' + CONVERT(varchar(20),@trip_id) +
					' and sequence_id in ('
		end


		-- rb 03/02/2010 
		if @count2 > 0
			select @sql2 = @sql2 + ','

		select @count2 = @count2 + 1,
			@sql2 = @sql2 + CONVERT(varchar(20),@seq_id)
	
		if DATALENGTH(@sql2) > 1800
		begin
			select @sql2 = @sql2 + ')'
			insert #sql values (1,@sql2)
			select @count2 = 0,
				@sql2 = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdate'')' +
					' update tripfieldupdate set processed_flag = ''T''' +
					' where trip_id=' + CONVERT(varchar(20),@trip_id) +
					' and sequence_id in ('
		end

		fetch c_loop into @seq_id
	end

	close c_loop
	deallocate c_loop

	if RIGHT(@sql,1) <> '('
	begin
		select @sql = @sql + ')'
		insert #sql values (1, @sql)
	end

	if RIGHT(@sql2,1) <> '('
	begin
		select @sql2 = @sql2 + ')'
		insert #sql values (1, @sql2)
	end


	-- tripfieldupdate (newer sync table)
	select @sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdate'')' +
			' update tripfieldupdate set processed_flag=''F''' +
			' where trip_id=' + CONVERT(varchar(20),@trip_id)
	insert #sql values (0, @sql)

	select @count=0,
		@sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdate'')' +
			' update tripfieldupdate set processed_flag = ''T''' +
			' where trip_id=' + CONVERT(varchar(20),@trip_id) +
			' and sequence_id in ('

	declare c_loop cursor for
	select sequence_id
	from tripfieldupdate tfu
	where trip_id = @trip_id
	order by sequence_id

	open c_loop
	fetch c_loop into @seq_id

	while (@@FETCH_STATUS = 0)
	begin
		if @count > 0
			select @sql = @sql + ','

		select @count = @count + 1,
			@sql = @sql + CONVERT(varchar(20),@seq_id)
	
		if DATALENGTH(@sql) > 1800
		begin
			select @sql = @sql + ')'
			insert #sql values (1,@sql)
			select @count = 0,
				@sql = 'if exists (select 1 from sysobjects where type = ''U'' and name = ''tripfieldupdate'')' +
					' update tripfieldupdate set processed_flag = ''T''' +
					' where trip_id=' + CONVERT(varchar(20),@trip_id) +
					' and sequence_id in ('
		end

		fetch c_loop into @seq_id
	end

	close c_loop
	deallocate c_loop

	if RIGHT(@sql,1) <> '('
	begin
		select @sql = @sql + ')'
		insert #sql values (1, @sql)
	end


	set nocount off

	select sql from #sql
	order by sort_id

	drop table #sql
	-- rb 02/22/2010 end
end

-- rb 08/24/2011 support for empty bottle weights
else if convert(numeric(4,2),@version) >= 2.21
begin
	set nocount off

	if convert(numeric(4,2),@version) < 2.25

		select distinct 'if exists (select 1 from CustomerTypeEmptyBottleApproval'
		+ ' where customer_type=''' + cteba.customer_type + ''')'
		+ ' update CustomerTypeEmptyBottleApproval'
		+ ' set approval_code=''' + cteba.approval_code + ''','
		+ ' pound_conv=' + convert(varchar(20),round(cteba.pound_conv,4)) + ','
		+ ' modified_by=' + isnull('''' + replace(cteba.modified_by, '''', '''''') + '''','null') + ','
		+ ' date_modified=' + isnull('''' + convert(varchar(20),cteba.date_modified,120) + '''','null')
		+ ' where customer_type=''' + cteba.customer_type + ''''
		+ ' else'
		+ ' insert CustomerTypeEmptyBottleApproval values ('
		+ '''' + cteba.customer_type + ''','
		+ '''' + cteba.approval_code + ''','
		+ convert(varchar(20),round(cteba.pound_conv,4)) + ','
		+ isnull('''' + replace(cteba.added_by, '''', '''''') + '''','null') + ','
		+ isnull('''' + convert(varchar(20),cteba.date_added,120) + '''','null') + ','
		+ isnull('''' + replace(cteba.modified_by, '''', '''''') + '''','null') + ','
		+ isnull('''' + convert(varchar(20),cteba.date_modified,120) + '''','null') + ')'
		as sql
		from TripConnectLog tcl, WorkOrderHeader woh, Customer c, CustomerTypeEmptyBottleApproval cteba
		where tcl.trip_connect_log_id = @trip_connect_log_id
		and tcl.trip_id = woh.trip_id
		and woh.customer_id = c.customer_id
		and c.customer_type = cteba.customer_type
		and cteba.approval_code = 'WMPHW01U'
	else
		select distinct 'if exists (select 1 from CustomerTypeEmptyBottleApproval'
		+ ' where customer_type=''' + cteba.customer_type + ''''
		+ ' and approval_code=''' + cteba.approval_code + ''')'
		+ ' update CustomerTypeEmptyBottleApproval'
		+ ' set pound_conv=' + convert(varchar(20),round(cteba.pound_conv,9)) + ','
		+ ' modified_by=' + isnull('''' + replace(cteba.modified_by, '''', '''''') + '''','null') + ','
		+ ' date_modified=' + isnull('''' + convert(varchar(20),cteba.date_modified,120) + '''','null')
		+ ' where customer_type=''' + cteba.customer_type + ''''
		+ ' and approval_code=''' + cteba.approval_code + ''''
		+ ' else'
		+ ' insert CustomerTypeEmptyBottleApproval values ('
		+ '''' + cteba.customer_type + ''','
		+ '''' + cteba.approval_code + ''','
		+ convert(varchar(20),round(cteba.pound_conv,9)) + ','
		+ isnull('''' + replace(cteba.added_by, '''', '''''') + '''','null') + ','
		+ isnull('''' + convert(varchar(20),cteba.date_added,120) + '''','null') + ','
		+ isnull('''' + replace(cteba.modified_by, '''', '''''') + '''','null') + ','
		+ isnull('''' + convert(varchar(20),cteba.date_modified,120) + '''','null') + ')'
		as sql
		from TripConnectLog tcl, WorkOrderHeader woh, Customer c, CustomerTypeEmptyBottleApproval cteba
		where tcl.trip_connect_log_id = @trip_connect_log_id
		and tcl.trip_id = woh.trip_id
		and woh.customer_id = c.customer_id
		and c.customer_type = cteba.customer_type

end

-- rb 03/09/2010 version 2.x and later, do nothing for now
else
begin
	set nocount off
	select '' as sql
end

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_retrieve_begin] TO [EQAI]
    AS [dbo];

