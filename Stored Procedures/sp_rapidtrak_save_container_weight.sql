if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_container_weight')
	drop procedure sp_rapidtrak_save_container_weight
go

create procedure sp_rapidtrak_save_container_weight
	@container			varchar(20),
	@container_weight	float,
	@user_id			varchar(10)
as
--
--exec sp_rapidtrak_save_container_weight
--

declare @company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@container_type char,
	@pos int,
	@pos2 int,
	@fingerpr_status char,
	@original_weight float,
	@status varchar(7),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Container weight updated successfully.'

set transaction isolation level read uncommitted

exec dbo.sp_rapidtrak_parse_container @container, @container_type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

-----------------
begin transaction
-----------------

if not exists (select 1 from Container
				where company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and receipt_id = @receipt_id
				and line_id = @line_id
				and container_id = @container_id
				and container_type = @container_type)
begin
	set @status = 'ERROR'
	set @msg = 'Error: Container does not exist.'

	goto RETURN_RESULT
end

if coalesce(@container_weight,0) <= 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Please enter a weight greater than zero.'
	
	goto RETURN_RESULT
end

if coalesce(@container_weight,0) >= 10000000
begin
	set @status = 'ERROR'
	set @msg = 'Error: Please enter a weight less than 10,000,000.'
	
	goto RETURN_RESULT
end

if exists (select 1 from Container
			where company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and receipt_id = @receipt_id
			and line_id = @line_id
			and container_id = @container_id
			and status = 'V')
begin
	set @status = 'ERROR'
	set @msg = 'Error: The scanned container is marked as Void in the system and cannot be managed via the app. Please review this container.'

	goto RETURN_RESULT
end

--Validation for container going into base container
if @receipt_id > 0
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
end

select @original_weight = coalesce(container_weight,0)
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id

if @original_weight <> @container_weight
begin
	insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
							column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
	values (@company_id, @profit_ctr_id, @container_type, @receipt_id, @line_id, @container_id, 1,
			'container_weight', @original_weight, @container_weight, getdate(), @user_id, 'RT', 'Container')

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error inserting into ContainerAudit table.'

		goto RETURN_RESULT
	end

	update Container  
	set container_weight = @container_weight,
		modified_by = @user_id,
		date_modified = getdate()
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id

	if @@ERROR <> 0
	begin
		set @status = 'ERROR'
		set @msg = 'Error updating Container table.'

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

grant execute on sp_rapidtrak_save_container_weight to eqai
go
