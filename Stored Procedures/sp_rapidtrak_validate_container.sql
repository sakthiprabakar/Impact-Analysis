if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_container')
	drop procedure sp_rapidtrak_validate_container
go

create procedure dbo.sp_rapidtrak_validate_container
	@container varchar(20),
	@validation_type char,
	@location varchar(15) = null,
	@batch_tracking_num varchar(15) = null
as
--@validation_type: 'C' - Validate for Container Size/Weight
--					'P'	- Validate for Process Pre-Assign/Final
--
--Receipt:			exec sp_rapidtrak_validate_container '1406-65332-1-1', 'C'
--Stock Container:	exec sp_rapidtrak_validate_container 'DL-2200-057641', 'P', 'PIT', '926'

declare @pos int,
		@pos2 int,
		@type char,
		@company_id int,
		@profit_ctr_id int,
		@receipt_id int,
		@line_id int,
		@container_id int,
		@container_sequence_id int,
		@container_status char,
		@fingerpr_status char,
		@validate_wc char,
		@waste_code_uid int,
		@display_name varchar(10),
		@treatment_id int,
		@status varchar(5),
		@msg varchar(1024)

--Default to Valid
set @status = 'OK'
set @msg = ''

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

-- Check if container exists
if not exists (select 1
			from Container
			where company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and container_type = @type
			and receipt_id = @receipt_id
			and line_id = @line_id
			and container_id = @container_id)
begin
	set @status = 'ERROR'
	set @msg = 'Error: Container ' + @container + ' does not exist'
	goto RETURN_RESULT
end

-- Check container status
select @container_status = coalesce(status,'')
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and container_type = @type
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id

if @container_status in ('C','V')
begin
	set @status = 'ERROR'
	set @msg = 'Error: Container ' + @container + ' cannot be processed because its status is ' + case @container_status when 'C' then 'Complete' else 'Void' end + '.'
	goto RETURN_RESULT
end

--Validate fingerprint status
if @type = 'R' and @validation_type in ('C','P')
begin
	select @fingerpr_status = fingerpr_status
	from Receipt
	where receipt_id = @receipt_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and line_id = @line_id

	if @fingerpr_status = 'V'
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The scanned container is marked as Void in the system and cannot be managed via the app. Please review this container.'
		goto RETURN_RESULT
	end

	if @fingerpr_status = 'R'
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The scanned container is in Rejected status and cannot be managed via the app. Please review this container.'
		goto RETURN_RESULT
	end

	if @fingerpr_status = 'C'
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The scanned container is in Completed status and cannot be managed. Please review this container.'
		goto RETURN_RESULT
	end

	if @validation_type = 'P'
	begin
		if @fingerpr_status = 'N'
		begin
			set @status = 'ERROR'
			set @msg = 'Error: The scanned container is in New status and cannot be managed via the app until the lab has signed off on the material. Please review this container.'
			goto RETURN_RESULT
		end

		if @fingerpr_status = 'W'
		begin
			set @status = 'ERROR'
			set @msg = 'Error: The scanned container is in Waiting for the Lab status and cannot be managed via the app. Please review this container.'
			goto RETURN_RESULT
		end
	end
end

--Validate for Process
if @validation_type = 'P'
begin
	select @container_sequence_id = max(sequence_id)
	from ContainerDestination
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id
	and container_type = @type

	--validate waste codes if flag is set
	select @validate_wc = validate_wastecode_flag
	from Batch
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and location = @location
	and tracking_num = @batch_tracking_num

	if coalesce(@validate_wc,'') = ''
		set @validate_wc = 'F'

	if @validate_wc = 'T'
	begin
		declare c_loop_wc cursor forward_only read_only for
		select cwc.waste_code_uid, wc.display_name
		from ContainerWasteCode cwc
		join WasteCode wc
			on wc.waste_code_uid = cwc.waste_code_uid
			and wc.display_name <> 'NONE'
		where cwc.company_id = @company_id
		and cwc.profit_ctr_id = @profit_ctr_id
		and cwc.receipt_id = @receipt_id
		and cwc.line_id = @line_id
		and cwc.container_id = @container_id
		and cwc.container_type = @type
		and cwc.sequence_id = @container_sequence_id
		union
		select rwc.waste_code_uid, wc2.display_name
		from ReceiptWasteCode rwc
		join WasteCode wc2
			on wc2.waste_code_uid = rwc.waste_code_uid
			and wc2.display_name <> 'NONE'
		where rwc.company_id = @company_id
		and rwc.profit_ctr_id = @profit_ctr_id
		and rwc.receipt_id = @receipt_id
		and rwc.line_id = @line_id
		and not exists (select 1 from ContainerWasteCode
						where company_id = rwc.company_id
						and profit_ctr_id = rwc.profit_ctr_id
						and receipt_id = rwc.receipt_id
						and line_id = rwc.line_id
						and container_id = @container_id
						and sequence_id = @container_sequence_id
						and container_type = @type)

		open c_loop_wc
		fetch c_loop_wc into @waste_code_uid, @display_name

		while @@FETCH_STATUS = 0
		begin
			if not exists (select 1 from BatchWasteCode
							where status = 'L' 
							and location = @location 
							and company_id = @company_id
							and profit_ctr_id = @profit_ctr_id 
							and tracking_num = @batch_tracking_num 
							and waste_code_uid = @waste_code_uid)
			begin
				if coalesce(@msg,'') = ''
					set @msg = 'Error: The following waste codes are invalid for ' + @location + '/' + @batch_tracking_num + ':'

				set @status = 'ERROR'
				set @msg = @msg + ' ' + @display_name
			end

			fetch c_loop_wc into @waste_code_uid, @display_name
		end

		close c_loop_wc
		deallocate c_loop_wc
	end

	-- validate treatment
	select @treatment_id = treatment_id
	from ContainerDestination
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id
	and container_type = @type
	and sequence_id = @container_sequence_id

	if @treatment_id is not null
	begin
		if not exists (select 1 from BatchTreatment
						where company_id = @company_id
						and profit_ctr_id = @profit_ctr_id
						and location = @location
						and tracking_num = @batch_tracking_num
						and treatment_id = @treatment_id)
		begin
			if coalesce(@msg,'') <> ''
				set @msg = @msg + ' '

			set @status = 'ERROR'
			set @msg = coalesce(@msg,'') + 'Error: Treatment ID ' + convert(varchar(10),@treatment_id) + ' is invalid for ' + @location + '/' + @batch_tracking_num + '.'

			goto RETURN_RESULT
		end
	end
end

if @status = 'OK'
	set @msg = 'Container is valid.'

--Return result
RETURN_RESULT:
select @status as status, @msg as message
return 0

go

grant execute on sp_rapidtrak_validate_container to eqai
go
