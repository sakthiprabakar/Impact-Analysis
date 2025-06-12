if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_process')
	drop procedure sp_rapidtrak_save_process
go

create procedure sp_rapidtrak_save_process
	@container				varchar(20),
	@container_sequence_id	int,
	@location				varchar(15),
	@batch_tracking_num		varchar(15),
	@final_or_pre_assign	char,
	@user_id				varchar(10)
as
--
--exec sp_rapidtrak_save_process 'DL-2100-415308', 1, '701', '25888', 'P', 'ROB_B'
--exec sp_rapidtrak_save_process 'DL-2100-415308', 1, '701', '25888', 'F', 'ROB_B'
--

declare @company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@container_type char,
	@base varchar(15),
	@pos int,
	@pos2 int,
	@orig_location_type char,
	@orig_location varchar(15),
	@orig_tracking_num varchar(15),
	@cycle int,
	@orig_cycle int,
	@status varchar(7),
	@msg varchar(1024)

set @status = 'OK'
set @msg = 'Container successfully updated.'

set transaction isolation level read uncommitted

exec dbo.sp_rapidtrak_parse_container @container, @container_type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

if not exists (select 1 from Container
				where company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and receipt_id = @receipt_id
				and line_id = @line_id
				and container_id = @container_id
				and container_type = @container_type)
begin
	select 'ERROR' as status, 'Container does not exist.' as message
	return 0
end

-----------------
begin transaction
-----------------

-- if Final, check fingerprint status
if @final_or_pre_assign = 'F'
begin
	if exists (select 1 from Receipt
				where receipt_id = @receipt_id
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and line_id = @line_id
				and fingerpr_status <> 'A')
	begin
		set @status = 'ERROR'
		set @msg = 'Error: Receipt Fingerprint Status is not Accepted.'

		goto RETURN_RESULT
	end
end


--Audit
select @orig_location_type = coalesce(location_type,''),
		@orig_location = coalesce(location,''),
		@orig_tracking_num = coalesce(tracking_num,''),
		@orig_cycle = cycle
from ContainerDestination
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and container_type = @container_type
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id
and sequence_id = @container_sequence_id

if @orig_location <> @location
begin
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
							column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
	values (@company_id, @profit_ctr_id, @container_type, @receipt_id, @line_id, @container_id, @container_sequence_id,
			'location', @orig_location, @location, getdate(), @user_id, 'RT', 'ContainerDestination')

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error inserting into ContainerAudit table.'

		goto RETURN_RESULT
	end
end

if @orig_tracking_num <> @batch_tracking_num
begin
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
							column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
	values (@company_id, @profit_ctr_id, @container_type, @receipt_id, @line_id, @container_id, @container_sequence_id,
			'tracking_num', @orig_tracking_num, @batch_tracking_num, getdate(), @user_id, 'RT', 'ContainerDestination')

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error inserting into ContainerAudit table.'

		goto RETURN_RESULT
	end
end

if @final_or_pre_assign = 'P'
begin
	if @orig_location_type <> 'P'
	begin
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
								column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
		values (@company_id, @profit_ctr_id, @container_type, @receipt_id, @line_id, @container_id, @container_sequence_id,
				'location_type', @orig_location_type, 'P', getdate(), @user_id, 'RT', 'ContainerDestination')

		if @@ERROR <> 0
		begin
			set @status = 'ERROR'
			set @msg = 'Error inserting into ContainerAudit table.'

			goto RETURN_RESULT
		end
	end

	update ContainerDestination
	set location_type = 'P',
		location = @location,
		tracking_num = @batch_tracking_num,
		date_modified = getdate(),
		modified_by = @user_id,
		modified_from = 'RT'
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and container_type = @container_type
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id
	and sequence_id = @container_sequence_id

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error: Update ContainerDestination failed.'

		goto RETURN_RESULT
	end
end
else
begin
	select @cycle = cycle
	from Batch
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and location = @location
	and tracking_num = @batch_tracking_num

	if coalesce(@cycle,0) <> coalesce(@orig_cycle,0)
	begin
		insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
							column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
		values (@company_id, @profit_ctr_id, @container_type, @receipt_id, @line_id, @container_id, @container_sequence_id,
				'cycle', coalesce(convert(varchar(10),@orig_cycle),''), coalesce(convert(varchar(10),@cycle),''), getdate(), @user_id, 'RT', 'ContainerDestination')

		if @@ERROR <> 0
		begin
			set @status = 'ERROR'
			set @msg = 'Error inserting into ContainerAudit table.'

			goto RETURN_RESULT
		end
	end

	update ContainerDestination
	set location = @location,
		tracking_num = @batch_tracking_num,
		cycle = @cycle,
		date_modified = getdate(),
		modified_by = @user_id,
		modified_from = 'RT'
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and container_type = @container_type
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id
	and sequence_id = @container_sequence_id

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error: Update ContainerDestination failed.'

		goto RETURN_RESULT
	end
end


RETURN_RESULT:
if @status = 'OK'
	commit transaction
else
	rollback transaction

select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_save_process to eqai
go
