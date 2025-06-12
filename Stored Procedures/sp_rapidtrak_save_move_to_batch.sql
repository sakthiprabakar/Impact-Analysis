if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_move_to_batch')
	drop procedure sp_rapidtrak_save_move_to_batch
go

create procedure sp_rapidtrak_save_move_to_batch
	@co_pc					varchar(4),
	@staging_row			varchar(15),
	@location			varchar(15),
	@batch_tracking_num		varchar(15),
	@user_id				varchar(10)
as
--
--exec sp_rapidtrak_save_move_to_batch '4500', 'TP8', 'PAN 2', '32022', 'ROB_B'
--select * from ContainerDestination where company_id = 21 and profit_ctr_id = 0 and status = 'N' and date_added > '01/01/2021' and tracking_num
--select * from ContainerDestination where company_id = 21 and profit_ctr_id = 0 and status = 'N' and location = 'RINECO'
--select * from ContainerAudit where company_id = 21 and profit_ctr_id = 0 and receipt_id = 0 and line_id = 394868 and container_id = 394868 and container_type = 'S'
--

declare @status varchar(7),
		@msg varchar(255),
		@company_id int,
		@profit_ctr_id int,
		@cycle int

set @status = 'OK'
set @msg = 'Move to batch was successful.'

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

select @cycle = cycle
from Batch
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and location = @location
and tracking_num = @batch_tracking_num


begin transaction

--create audit records
insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'location_type', coalesce(cd.location_type,''), 'P', getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and coalesce(cd.location_type,'') <> 'P'
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'location', coalesce(cd.location,''), @location, getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and coalesce(cd.location,'') <> @location
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'tracking_num', coalesce(cd.tracking_num,''), @batch_tracking_num, getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and coalesce(cd.tracking_num,'') <> @batch_tracking_num
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'cycle', coalesce(convert(varchar(10),cd.cycle),''), convert(varchar(10),@cycle), getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and coalesce(cd.cycle,0) <> coalesce(@cycle,0)
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'disposal_date', coalesce(convert(varchar(10),cd.disposal_date,101),''), convert(varchar(10),getdate(),101), getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and coalesce(convert(varchar(10),cd.disposal_date,101),'') <> convert(varchar(10),getdate(),101)
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select cd.company_id, cd.profit_ctr_id, cd.container_type, cd.receipt_id, cd.line_id, cd.container_id, cd.sequence_id,
		'status', coalesce(cd.status,''), 'C', getdate(), @user_id, 'RT', 'ContainerDestination'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select c.company_id, c.profit_ctr_id, c.container_type, c.receipt_id, c.line_id, c.container_id,
		'status', coalesce(c.status,''), 'C', getdate(), @user_id, 'RT', 'Container'
from Container c
where c.company_id = @company_id
and c.profit_ctr_id = @profit_ctr_id
and c.staging_row = @staging_row
and c.status = 'N'

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

update ContainerDestination
set location_type = 'P',
	location = @location,
	tracking_num = @batch_tracking_num,
	cycle = @cycle,
	disposal_date = convert(varchar(10),getdate(),101),
	status = 'C',
	date_modified = getdate(),
	modified_by = @user_id,
	modified_from = 'RT'
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and c.profit_ctr_id = cd.profit_ctr_id
	and c.receipt_id = cd.receipt_id
	and c.line_id = cd.line_id
	and c.container_id = cd.container_id
	and c.container_type = cd.container_type
	and c.staging_row = @staging_row
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id
and cd.status = 'N'
and not (coalesce(cd.location,'') = @location and coalesce(cd.tracking_num,'') = @batch_tracking_num)
and cd.sequence_id = (select max(sequence_id)
					from ContainerDestination
					where company_id = cd.company_id
					and profit_ctr_id = cd.profit_ctr_id
					and receipt_id = cd.receipt_id
					and line_id = cd.line_id
					and container_id = cd.container_id)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Update ContainerDestination failed.'
end

update Container
set status = 'C',
	modified_by = @user_id,
	date_modified = getdate()
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and staging_row = @staging_row
and status = 'N'

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Update Container failed.'
end


RETURN_RESULT:
if @status = 'OK'
	commit transaction
else
	rollback transaction

select @status as status, @msg as message
go

grant execute on sp_rapidtrak_save_move_to_batch to EQAI
go
