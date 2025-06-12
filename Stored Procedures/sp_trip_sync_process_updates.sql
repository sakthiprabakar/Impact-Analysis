
create procedure sp_trip_sync_process_updates
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure updates data changes sent from a field device

 loads to Plt_ai
 
 06/17/2009 - rb created
 10/30/2009 - rb check for null numeric with empty string in value
 11/03/2009 - rb need to stop quotes wrapping around insert statements
 12/04/2009 - rb add support for new WorkOrderDetailItem table
 12/29/2009 - rb update workorderheader start_date/end_date with trip_act_arrive and trip_act_departure
 01/06/2010 - rb support updating negative sequence_ids when approvals are copied on device
 02/03/2010 - rb support workordermanifest table
 02/08/2010 - rb support triplocalinformation table
 02/15/2010 - rb don't process if status is not C or U (original implementation wanted = D)
 02/16/2010 - rb need to uppercase WorkOrderDetailUnit.bill_code_unit if it came as lower case
 02/18/2010 - rb a new Undo button that blanks out the arrival date wasn't handled in this proc,
		 and check for existence of record in WorkOrderDetailCC instead of blindly inserting
 02/24/2010 - rb add support for new TripFieldUpdate table, add other columns to where clause to allow duplicate sequence_id
****************************************************************************************/

set nocount on

declare @trip_id int,
			@customer_id int,
			@trip_sequence_id int,
			@seq_id int,
			@abs_seq_id int,
			@other_sequence_id int,
			@sub_sequence_id varchar(10),
			@sync_table varchar(60),
			@table_name varchar(60),
			@column_name varchar(60),
			@column_type varchar(4),
			@value varchar(4096),
			@sql varchar(4096),
			@err int,
			@update_user varchar(10),
			@update_date varchar(22),
			@update_dt datetime,
			@last_trip_sequence_id int,
			@last_table_name varchar(50),
			@bill_unit_code varchar(4),
			@percentage varchar(4),
			@idx int,
			@count int,
			@msg varchar(255)

-- initialize updated_by variables
select @update_user = 'TCID' + convert(varchar(6),@trip_connect_log_id),
	@last_trip_sequence_id = -999,
	@last_table_name = ' ',
	@update_dt = convert(datetime,convert(varchar(20),getdate(),120))


-- get Trip ID for trip connect log ID paramater
select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

-- rb 02/15/2010 original implementation wanted = D, now we just want <> C and <> U
-- check that the trip status is still Dispatched
if exists (select 1 from TripHeader where trip_id = @trip_id and trip_status in ('C','U'))
begin
	select @msg = '   Error: Updates can not be processed if the trip status is ''Unloading'' or ''Completed''.'
	exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt
	set nocount off
	return 0
end

-- loop through updates
-- rb 02/24/2010 add new TripFieldUpdate table
declare c_loop cursor for
select 'TripFieldUpdates', trip_sequence_id, sequence_id, abs(sequence_id), other_sequence_id, table_name, column_name, substring(column_type,1,4), value
from TripFieldUpdates
where trip_id = @trip_id
and processed_flag <> 'T'

union

select 'TripFieldUpdate', trip_sequence_id, sequence_id, abs(sequence_id), other_sequence_id, table_name, column_name, substring(column_type,1,4), value
from TripFieldUpdate
where trip_id = @trip_id
and processed_flag <> 'T'

order by trip_sequence_id, table_name, abs(sequence_id)
for read only

open c_loop
fetch c_loop
into @sync_table,
	@trip_sequence_id,
	@seq_id,
	@abs_seq_id,
	@other_sequence_id,
	@table_name,
	@column_name,
	@column_type,
	@value
	

while @@FETCH_STATUS = 0
begin
	-- use same modified_date for groups of columns for the same record, so they're grouped in Audit screen
	if @last_trip_sequence_id <> @trip_sequence_id or @last_table_name <> @table_name
	begin
		select @update_date = '''' + convert(varchar(20),getdate(),120) + '''',
			@last_trip_sequence_id = @trip_sequence_id,
			@last_table_name = @table_name
	end

	-- store value in quotes or as the word 'null'
	-- rb 10/30/2009 check for type long that is empty string, if so use word 'null' as well
	-- rb 02/04/2010 add check for real type
	if @value is null or ((@column_type = 'long' or @column_type = 'real') and datalength(@value) < 1)
		select @value = 'null'

	-- rb 11/03/2009 don't wrap insert statements in quotes
	else if substring(@column_name,1,8) <> '<insert>' and substring(@column_name,1,8) <> '<update>' and
		(@column_type = 'char' or @column_type = 'varc' or @column_type = 'date' or @column_type = 'time')
		select @value = '''' + replace(@value,'''','''''') + ''''

	-- generate sql based on table
	select @sql = null
	
	-- WorkOrderHeader
	if @table_name = 'workorderheader'
	begin
		select @sql = 'insert WorkOrderAudit select company_id, profit_ctr_id, workorder_id, '' '', 0,' +
				' ''WorkOrderHeader'', ''' + @column_name + ''',' +
				' isnull(convert(varchar(255),' + @column_name + ',120),''(blank)''), ' +
				case @value when 'null' then ''' + (blank) + ''' else @value end +
				', null, ''' + @update_user + ''', ' + @update_date +
				' from WorkOrderHeader' +
				' where trip_id = ' + convert(varchar(10),@trip_id) + 
				' and trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

		select @sql = @sql + ' insert TripAudit select trip_id, ''WorkOrderHeader'', ''' + @column_name +
				''', isnull(convert(varchar(255),' + @column_name + ',120),''(blank)''), ' +
				case @value when 'null' then ''' + (blank) + ''' else @value end +
				', null, ''MOBILE'', ''' + @update_user + ''', ' + @update_date +
				' from WorkOrderHeader' +
				' where trip_id = ' + convert(varchar(10),@trip_id) + 
				' and trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

		-- rb 02/18/2010 manage blank arrival date
		if @value = '''00/00/0000 00:00:00'''
			select @value = 'null'

		select @sql = @sql + ' update WorkOrderHeader set ' + @column_name + ' = ' + @value

		-- rb 02/18/2010 added check for @value <> null, for Undo arrival date, but pickup date has validation, can't be null
		-- rb 12/29/2009 adjust pickup date fields
		if @column_name = 'trip_act_arrive' and @value <> 'null'
			select @sql = @sql + ', start_date = convert(datetime,convert(varchar(10),' + @value + ',120))'


		else if @column_name = 'trip_act_departure' and @value <> 'null'
			select @sql = @sql + ', end_date = convert(datetime,convert(varchar(20),' + @value + ',120))'


		select @sql = @sql + ', date_modified = ' + @update_date  +
				', modified_by = ''' + @update_user + '''' +
				', field_upload_date = ' + @update_date + 
				' where trip_id = ' + convert(varchar(10),@trip_id) + 
				' and trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

	end

	-- WorkOrderDetail
	else if @table_name = 'workorderdetail'
	begin
		-- if approval inserted on field device, insert statement was passed
		if @column_name = '<insert>'
			select @sql = @value

		-- rb 01/06/2010 support updating negative sequence_ids
		else if @column_name = '<update>'
			select @sql = @value

		else
		begin
			select @sql = 'insert WorkOrderAudit select wod.company_id, wod.profit_ctr_id, wod.workorder_id, wod.resource_type, wod.sequence_id,' +
					' ''WorkOrderDetail'', ''' + @column_name + ''',' +
					' isnull(convert(varchar(255),' + @column_name + ',120),''(blank)''), ' +
					case @value when 'null' then ''' + (blank) + ''' else @value end +
					', null, ''' + @update_user + ''', ' + @update_date +
					' from WorkOrderDetail wod, WorkOrderHeader woh' +
					' where wod.workorder_id = woh.workorder_id and wod.company_id = woh.company_id' +
					' and wod.profit_ctr_id = woh.profit_ctr_id' + 
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

			select @sql = @sql + ' insert TripAudit select woh.trip_id, ''WorkOrderDetail'', ''' + @column_name +
					''', isnull(convert(varchar(255),' + @column_name + ',120),''(blank)''), ' +
					case @value when 'null' then ''' + (blank) + ''' else @value end +
					', null, ''MOBILE'', ''' + @update_user + ''', ' + @update_date +
					' from WorkOrderDetail wod, WorkOrderHeader woh' +
					' where wod.workorder_id = woh.workorder_id and wod.company_id = woh.company_id' +
					' and wod.profit_ctr_id = woh.profit_ctr_id' + 
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

			-- if manifest column updated, update the WorkOrderManifest table
			if @column_name = 'manifest'
		
				select @sql = @sql + ' update WorkOrderManifest set manifest = ' + @value + ', ' +
						'date_modified = ' + @update_date  +
						', modified_by = ''' + @update_user + '''' +
						' from WorkOrderManifest wom, WorkOrderDetail wod, WorkOrderHeader woh' +
						' where wom.workorder_id = wod.workorder_id' +
						' and wom.company_id = wod.company_id' + 
						' and wom.profit_ctr_id = wod.profit_ctr_id' +
						' and wom.manifest = wod.manifest' +
						' and wod.resource_type = ''D''' +
						' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
						' and wod.workorder_id = woh.workorder_id' + 
						' and wod.company_id = woh.company_id' + 
						' and wod.profit_ctr_id = woh.profit_ctr_id' +
						' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
						' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)
							
			select @sql = @sql + ' update WorkOrderDetail set ' + @column_name + ' = ' + @value + ', ' +
					'date_modified = ' + @update_date  +
					', modified_by = ''' + @update_user + '''' +
					' from WorkOrderDetail wod, WorkOrderHeader woh' +
					' where wod.workorder_id = woh.workorder_id' + 
					' and wod.company_id = woh.company_id' + 
					' and wod.profit_ctr_id = woh.profit_ctr_id' +
					' and wod.resource_type = ''D'''

			if @other_sequence_id is not null
				select @sql = @sql + ' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id)

			select @sql = @sql + ' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)
		end
	end

	-- rb 02/03/2010 support workordermanifest table
	-- WorkOrderManifest
	else if @table_name = 'workordermanifest'
	begin
		-- just straight inserts and updates for now

		-- if new manifest entered on field device
		if @column_name = '<insert>'
			select @sql = @value

		-- if updating a MANIFEST_1 record (all approvals had quantities entered)
		else if @column_name = '<update>'
			select @sql = @value
	end

	-- WorkOrderDetailUnit
	else if @table_name = 'workorderdetailunit'
	begin
		-- workorderdetailunit table potentially has only inserts or updates.
		select @idx = charindex('/',@column_name)
		select @bill_unit_code = substring(@column_name,1,@idx-1)
		select @column_name = substring(@column_name,@idx+1,datalength(@column_name)-@idx)

		-- rb 02/16/2010 un-lowercase the bill unit code
		if @column_name = 'bill_quantity'
			select @bill_unit_code = upper(@bill_unit_code)

		if exists (select 1 from BillUnit
					where bill_unit_code = @bill_unit_code
					and container_flag = 'T')
			or exists (select 1 from WorkOrderHeader woh, WorkOrderDetail wod, TSDF t, TSDFApproval ta, TSDFApprovalPrice tap
						where woh.trip_id = @trip_id
						and woh.trip_sequence_id = @trip_sequence_id
						and woh.workorder_id = wod.workorder_id
						and woh.company_id = wod.company_id
						and woh.profit_ctr_id = wod.profit_ctr_id
						and wod.sequence_id = @other_sequence_id
						and wod.resource_type = 'D'
						and wod.tsdf_code = t.tsdf_code
						and isnull(t.eq_flag,'F') = 'F'
						and wod.tsdf_approval_id = ta.tsdf_approval_id
						and ta.tsdf_approval_status = 'A'
						and ta.tsdf_approval_id = tap.tsdf_approval_id
						and tap.bill_unit_code = @bill_unit_code
						and tap.record_type = 'D')
			or exists (select 1 from WorkOrderHeader woh, WorkOrderDetail wod, TSDF t, ProfileQuoteDetail pqd
						where woh.trip_id = @trip_id
						and woh.trip_sequence_id = @trip_sequence_id
						and woh.workorder_id = wod.workorder_id
						and woh.company_id = wod.company_id
						and woh.profit_ctr_id = wod.profit_ctr_id
						and wod.sequence_id = @other_sequence_id
						and wod.resource_type = 'D'
						and wod.tsdf_code = t.tsdf_code
						and isnull(t.eq_flag,'F') = 'T'
						and wod.profile_id = pqd.profile_id
						and pqd.bill_unit_code = @bill_unit_code
						and pqd.record_type = 'D'
						and pqd.status = 'A')
		begin
			select @sql = 'if exists (select 1 from WorkOrderDetailUnit wodu, WorkOrderDetail wod, WorkOrderHeader woh'+
						' where wodu.workorder_id = wod.workorder_id' +
						' and wodu.company_id = wod.company_id' +
						' and wodu.profit_ctr_id = wod.profit_ctr_id' +
						' and wodu.sequence_id = wod.sequence_id' +
						' and wodu.size = ''' + @bill_unit_code + '''' +
						' and wod.resource_type = ''D''' +
						' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
						' and wod.workorder_id = woh.workorder_id' +
						' and wod.company_id = woh.company_id' +
						' and wod.profit_ctr_id = woh.profit_ctr_id' +
						' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
						' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
						') update WorkOrderDetailUnit ' +
						' set ' + @column_name + ' = ' + @value +
						', date_modified = ' + @update_date  +
						', modified_by = ''' + @update_user + '''' +
						' from WorkOrderDetailUnit wodu, WorkOrderDetail wod, WorkOrderHeader woh' +
						' where wodu.workorder_id = wod.workorder_id' +
						' and wodu.company_id = wod.company_id' +
						' and wodu.profit_ctr_id = wod.profit_ctr_id' +
						' and wodu.sequence_id = wod.sequence_id' +
						' and wodu.size = ''' + @bill_unit_code + '''' +
						' and wod.resource_type = ''D''' +
						' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
						' and wod.workorder_id = woh.workorder_id' +
						' and wod.company_id = woh.company_id' +
						' and wod.profit_ctr_id = woh.profit_ctr_id' +
						' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
						' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
						' else insert WorkOrderDetailUnit select wod.workorder_id, wod.company_id,' +
						' wod.profit_ctr_id, wod.sequence_id, ''' + @bill_unit_code + ''', ' +
						' ''' + @bill_unit_code + ''', ' + @value + ',' +
						' ''' + @update_user + ''', ' + @update_date + ',' +
						' ''' + @update_user + ''', ' + @update_date + 
						' from WorkOrderHeader woh, WorkOrderDetail wod' +
						' where woh.trip_id = ' + convert(varchar(10),@trip_id) +
						' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
						' and woh.workorder_id = wod.workorder_id' +
						' and woh.company_id = wod.company_id' +
						' and woh.profit_ctr_id = wod.profit_ctr_id' +
						' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
						' and wod.resource_type = ''D'''
		end
	end
	
	-- WorkOrderDetailCC
	else if @table_name = 'workorderdetailcc'
	begin
		-- WorkOrderDetailCC table could start with a <delete> command, then insert all values again
		select @idx = charindex('/',@column_name)
		if @idx is not null and @idx > 0
			select @column_name = substring(@column_name,1,@idx-1)
		
		if @column_name = '<delete>'
			select @sql = 'delete WorkOrderDetailCC from WorkOrderDetailCC wodcc, WorkOrderDetail wod, WorkOrderHeader woh'+
					' where wodcc.workorder_id = wod.workorder_id' +
					' and wodcc.company_id = wod.company_id' +
					' and wodcc.profit_ctr_id = wod.profit_ctr_id' +
					' and wodcc.sequence_id = wod.sequence_id' +
					' and wod.resource_type = ''D''' +
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wod.workorder_id = woh.workorder_id' +
					' and wod.company_id = woh.company_id' +
					' and wod.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)
		else
		begin
			-- value will be 'consolidated_container_id/percentage'
			select @idx = charindex('/',@value)
			select @percentage = substring(@value,@idx+1,datalength(@value)-@idx)
			select @value = substring(@value,1,@idx-1)
			
			-- rb 02/18/2010 the following comment was nice in theory but occasionally not true, added if exists()
			-- always insert, field device will always send a <delete> first
			select @sql = 'if exists (select 1 from WorkOrderDetailCC wodcc, WorkOrderDetail wod, WorkOrderHeader woh'+
					' where wodcc.workorder_id = wod.workorder_id' +
					' and wodcc.company_id = wod.company_id' +
					' and wodcc.profit_ctr_id = wod.profit_ctr_id' +
					' and wodcc.sequence_id = wod.sequence_id' +
					' and wodcc.consolidated_container_id = ' + @value +
					' and wod.resource_type = ''D''' +
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wod.workorder_id = woh.workorder_id' +
					' and wod.company_id = woh.company_id' +
					' and wod.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
					') update WorkOrderDetailCC set percentage = ' + @percentage +
					' from WorkOrderHeader woh, WorkOrderDetail wod, WorkOrderDetailCC wodcc' +
					' where wodcc.workorder_id = wod.workorder_id' +
					' and wodcc.company_id = wod.company_id' +
					' and wodcc.profit_ctr_id = wod.profit_ctr_id' +
					' and wodcc.sequence_id = wod.sequence_id' +
					' and wodcc.consolidated_container_id = ' + @value +
					' and wod.resource_type = ''D''' +
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wod.workorder_id = woh.workorder_id' +
					' and wod.company_id = woh.company_id' +
					' and wod.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
					' else insert WorkOrderDetailCC select wod.workorder_id, wod.company_id,' +
					' wod.profit_ctr_id, wod.sequence_id, ' + @value + ',' + @percentage + ',' +
					' ''' + @update_user + ''', ' + @update_date + ',' +
					' ''' + @update_user + ''', ' + @update_date + ', null' +
					' from WorkOrderHeader woh, WorkOrderDetail wod' +
					' where woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) +
					' and woh.workorder_id = wod.workorder_id' +
					' and woh.company_id = wod.company_id' +
					' and woh.profit_ctr_id = wod.profit_ctr_id' +
					' and wod.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wod.resource_type = ''D'''
		end
	end

	-- WorkOrderDetailItem
	else if @table_name = 'workorderdetailitem'
	begin
		if substring(@column_name,1,8) = '<insert>'
			select @sql = @value

		else if substring(@column_name,1,8) = '<delete>'
		begin
			select @sql = 'delete WorkOrderDetailItem from WorkOrderDetailItem wodi, WorkOrderHeader woh'+
					' where wodi.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wodi.workorder_id = woh.workorder_id' +
					' and wodi.company_id = woh.company_id' +
					' and wodi.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

			if @value = 'M'
				select @sql = @sql + ' and wodi.merchandise_id is null'
			else if @value = 'I'
				select @sql = @sql + ' and wodi.merchandise_id is not null'
			else if datalength(ltrim(@value)) > 0
				select @sql = @sql + ' and wodi.sub_sequence_id = ' + @value
		end
		else
		begin
			select @idx = charindex('/',@column_name)
			select @sub_sequence_id = substring(@column_name,@idx+1,datalength(@column_name)-@idx)
			select @column_name = substring(@column_name,1,@idx-1)

			select @idx = charindex('/',isnull(@value,''))
			if @idx is not null and @idx > 0
				select @value = substring(@value,@idx+1,datalength(@value)-@idx)

			-- update if exists,
			select @sql = 'if exists (select 1 from WorkOrderDetailItem wodi, WorkOrderHeader woh' +
					' where wodi.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wodi.workorder_id = woh.workorder_id' +
					' and wodi.company_id = woh.company_id' +
					' and wodi.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id) + ')' +
					' update WorkOrderDetailItem set ' + @column_name + ' = ' + @value +
					' from WorkOrderDetailItem wodi, WorkOrderHeader woh' +
					' where wodi.sequence_id = ' + convert(varchar(10),@other_sequence_id) +
					' and wodi.workorder_id = woh.workorder_id' +
					' and wodi.company_id = woh.company_id' +
					' and wodi.profit_ctr_id = woh.profit_ctr_id' +
					' and woh.trip_id = ' + convert(varchar(10),@trip_id) +
					' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

			if @sub_sequence_id is not null and @sub_sequence_id > 0
				select @sql = @sql + ' and wodi.sub_sequence_id = ' + @sub_sequence_id
		end
	end

	-- TripQuestion
	else if @table_name = 'tripquestion'
	begin
		select @sql = 'insert TripAudit select woh.trip_id, ''TripQuestion'', ''' + @column_name +
				''', isnull(convert(varchar(255),' + @column_name + ',120),''(blank)''), ' +
				case @value when 'null' then ''' + (blank) + ''' else @value end +
				', null, ''MOBILE'', ''' + @update_user + ''', ' + @update_date +
				' from TripQuestion tq, WorkOrderHeader woh' +
				' where tq.workorder_id = woh.workorder_id ' + 
				' and tq.company_id = woh.company_id ' + 
				' and tq.profit_ctr_id = woh.profit_ctr_id ' + 
				' and tq.question_sequence_id = ' + convert(varchar(10),@other_sequence_id) +
				' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
				' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)

		select @sql = @sql + ' update TripQuestion set ' + @column_name + ' = ' + @value + ', ' +
				'date_modified = ' + @update_date  +
				', modified_by = ''' + @update_user + '''' +
				' from TripQuestion tq, WorkOrderHeader woh' +
				' where tq.workorder_id = woh.workorder_id ' + 
				' and tq.company_id = woh.company_id ' + 
				' and tq.profit_ctr_id = woh.profit_ctr_id ' + 
				' and tq.question_sequence_id = ' + convert(varchar(10),@other_sequence_id) +
				' and woh.trip_id = ' + convert(varchar(10),@trip_id) + 
				' and woh.trip_sequence_id = ' + convert(varchar(10),@trip_sequence_id)
	end

	-- rb 02/08/2010 support for TripLocalInformation table
	else if @table_name = 'triplocalinformation'
	begin
		-- just straight inserts and updates for now
		if @column_name = '<insert>'
			select @sql = @value

		else if @column_name = '<update>'
			select @sql = @value
	end


	-- execute the sql
	select @err = 0
	begin transaction
	if @sql is not null and datalength(isnull(@sql,'')) > 2 and @sql <> 'null'
		exec(@sql)

	select @err = @@error

	if @err <> 0 or @sql is null or datalength(isnull(@sql,'')) < 2 or @sql = 'null'
	begin
		-- log error
		rollback transaction

		select @msg = '   Error processing field update for Stop #' + convert(varchar(10),@trip_sequence_id) +
				', Table=' + @table_name + ', + Column=' + @column_name + ', Value=' + @value,
				@update_dt = convert(datetime,convert(varchar(20),getdate(),120))

		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt

		select @msg = '   SQL: ' + isnull(@sql,'')
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt
	end

	else
	begin
		-- rb 02/24/2010 new sync table
		if @sync_table = 'TripFieldUpdates'

			update TripFieldUpdates
			set processed_flag = 'T'
			where trip_id = @trip_id
			and sequence_id = @seq_id
			and trip_sequence_id = @trip_sequence_id
			and other_sequence_id = @other_sequence_id
			and table_name = @table_name
			and column_name like '%' + @column_name + '%'

		else if @sync_table = 'TripFieldUpdate'

			update TripFieldUpdate
			set processed_flag = 'T',
				date_processed = getdate()
			where trip_id = @trip_id
			and sequence_id = @seq_id
			and trip_sequence_id = @trip_sequence_id
			and other_sequence_id = @other_sequence_id
			and table_name = @table_name
			and column_name like '%' + @column_name + '%'

		commit transaction
	end

	-- fetch next record
	fetch c_loop
	into @sync_table,
		@trip_sequence_id,
		@seq_id,
		@abs_seq_id,
		@other_sequence_id,
		@table_name,
		@column_name,
		@column_type,
		@value
end

close c_loop
deallocate c_loop

set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_process_updates] TO [EQAI]
    AS [dbo];

