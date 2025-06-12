if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_consolidation')
	drop procedure dbo.sp_rapidtrak_validate_consolidation
go

create procedure dbo.sp_rapidtrak_validate_consolidation
	@base_container varchar(20),
	@container varchar(20),
	@user_id varchar(10),
	@override_treatment_mismatch char
as
--
--Receipt:			exec sp_rapidtrak_validate_consolidation '1406-65332-1-1', '', ''
--Stock Container:	exec sp_rapidtrak_validate_consolidation 'DL-2200-057641', '', ''
--

declare @pos int,
		@pos2 int,
		@type char,
		@company_id int,
		@profit_ctr_id int,
		@receipt_id int,
		@line_id int,
		@container_id int,
		@base_type char,
		@base_company_id int,
		@base_profit_ctr_id int,
		@base_receipt_id int,
		@base_line_id int,
		@base_container_id int,
		@fingerpr_status char,
		@base_treatment_id int,
		@cont_treatment_id int,
		@container_sequence_id int,
		@base_date datetime,
		@cont_date datetime,
		@status varchar(10),
		@msg varchar(255)

set transaction isolation level read uncommitted

--Default to Valid
set @status = 'OK'
set @msg = 'Consolidation is valid.'

--Base
if coalesce(@base_container,'') <> ''
begin
	exec dbo.sp_rapidtrak_parse_container @base_container, @base_type out, @base_company_id out, @base_profit_ctr_id out, @base_receipt_id out, @base_line_id out, @base_container_id out

	-- Check if container exists
	if not exists (select 1
				from Container
				where company_id = @base_company_id
				and profit_ctr_id = @base_profit_ctr_id
				and container_type = @base_type
				and receipt_id = @base_receipt_id
				and line_id = @base_line_id
				and container_id = @base_container_id)
	begin
		set @status = 'ERROR'
		set @msg = 'Error: Base container ' + @base_container + ' does not exist'
		goto RETURN_RESULT
	end

	if not exists (select 1
					from Container
					where company_id = @base_company_id
					and profit_ctr_id = @base_profit_ctr_id
					and container_type = @base_type
					and receipt_id = @base_receipt_id
					and line_id = @base_line_id
					and container_id = @base_container_id
					and status = 'N')
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The container you selected to consolidate waste into is not in a valid status to accept waste.  Please review the container.'
		goto RETURN_RESULT
	end
end

--Container
if coalesce(@container,'') <> ''
begin
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
		set @msg = 'Error: Container ' + @base_container + ' does not exist'
		goto RETURN_RESULT
	end

	if not exists (select 1
					from Container
					where company_id = @company_id
					and profit_ctr_id = @profit_ctr_id
					and container_type = @type
					and receipt_id = @receipt_id
					and line_id = @line_id
					and container_id = @container_id
					and status = 'N')
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The container you selected to consolidate is not in a valid status to be consolidated.  Please review the container.'
		goto RETURN_RESULT
	end
end

--Validation for container going into base container
if coalesce(@container,'') <> '' and @receipt_id > 0
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

	if @fingerpr_status <> 'A'
	begin
		set @status = 'ERROR'
		set @msg = 'Error:  The scanned container is not signed off by the Lab and cannot be managed via the app.  Please review this container.'
		goto RETURN_RESULT
	end
end

--Validation for consolidating a container into itself
if coalesce(@container,'') = coalesce(@base_container,'')
begin
	set @status = 'ERROR'
	set @msg = 'Error:  A container cannot be consolidated into itself.  Please review the selected container and base container.'
	goto RETURN_RESULT
end

-----------------
begin transaction
-----------------

--Validate treatments
if coalesce(@base_container,'') <> '' and coalesce(@container,'') <> ''
begin
	--get container date
	select @cont_date = date_added
	from Container
	where receipt_id = @receipt_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and line_id = @line_id
	and container_id = @container_id

	--get base date
	select @base_date = date_added
	from Container
	where receipt_id = @base_receipt_id
	and company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and line_id = @base_line_id
	and container_id = @base_container_id

	if @cont_date < @base_date
	begin
		if @base_type = 'R'
		begin
		set @status = 'ERROR'
			set @msg = 'Error: The container you are attempting to consolidate is older than the base container and cannot be consolidated into this container.'
			goto RETURN_RESULT
		end
		else
		begin
			update Container
			set date_added = @cont_date,
				modified_by = @user_id,
				date_modified = getdate()
			where receipt_id = @base_receipt_id
			and company_id = @base_company_id
			and profit_ctr_id = @base_profit_ctr_id
			and line_id = @base_line_id
			and container_id = @base_container_id
			and container_type = @base_type

			if @@ERROR <> 0
			begin
				set @status = 'ERROR'
				set @msg = 'Error: Updating Container date_added'
				goto RETURN_RESULT
			end
		end
	end

	--get container treatment
	select @container_sequence_id = max(sequence_id)
	from ContainerDestination
	where receipt_id = @receipt_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and line_id = @line_id
	and container_id = @container_id
	and container_type = @type

	select @cont_treatment_id = treatment_id
	from ContainerDestination
	where receipt_id = @receipt_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and line_id = @line_id
	and container_id = @container_id
	and container_type = @type
	and sequence_id = @container_sequence_id

	--get base treatment
	select @container_sequence_id = max(sequence_id)
	from ContainerDestination
	where receipt_id = @base_receipt_id
	and company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and line_id = @base_line_id
	and container_id = @base_container_id
	and container_type = @base_type

	select @base_treatment_id = treatment_id
	from ContainerDestination
	where receipt_id = @base_receipt_id
	and company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and line_id = @base_line_id
	and container_id = @base_container_id
	and container_type = @base_type
	and sequence_id = @container_sequence_id

	if @base_treatment_id is null
	begin
		update ContainerDestination
		set treatment_id = @cont_treatment_id,
			modified_by = @user_id,
			date_modified = getdate()
		where receipt_id = @base_receipt_id
		and company_id = @base_company_id
		and profit_ctr_id = @base_profit_ctr_id
		and line_id = @base_line_id
		and container_id = @base_container_id
		and container_type = @base_type
		and sequence_id = @container_sequence_id

		if @@ERROR <> 0
		begin
			set @status = 'ERROR'
			set @msg = 'Error: Updating Container date_added'
			goto RETURN_RESULT
		end

		set @msg = 'The base container''s treatment option was set, please re-print labels for the base container.'
	end
	else if @base_treatment_id <> coalesce(@cont_treatment_id,0) and coalesce(@override_treatment_mismatch,'') <> 'T'
	begin
		set @status = 'WARNING'
		set @msg = 'Warning: The treatment on the base container does not match this container.  Do you want to consolidate?'
	end
end


--Return result
RETURN_RESULT:
if @@trancount > 0
begin
	if @status = 'OK'
		commit transaction
	else
		rollback transaction
end

select @status as status, @msg as message
return 0
go

grant execute on dbo.sp_rapidtrak_validate_consolidation to EQAI
go
