if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_move_to_batch')
	drop procedure sp_rapidtrak_validate_move_to_batch
go

create procedure sp_rapidtrak_validate_move_to_batch
	@co_pc					varchar(4),
	@staging_row			varchar(15),
	@batch_tracking_num		varchar(15),
	@expected_count			int
as
--
--exec sp_rapidtrak_validate_move_to_batch
--exec sp_rapidtrak_validate_move_to_batch
--

declare @company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@count int,
	@validate_wc char,
	@waste_code_uid int,
	@display_name varchar(10),
	@fingerpr_status char,
	@status varchar(7),
	@msg varchar(max)

set @status = 'OK'
set @msg = ''

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted

select @count = count(*)
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id 
and staging_row = @staging_row
and status = 'N'

if @count <> @expected_count
begin
	set @status = 'ERROR'
	set @msg = 'Expected count of ' + convert(varchar(10),@expected_count) + ' does not equal the actual count of ' + convert(varchar(10),@count) + '.'
	goto RETURN_RESULT
end

--validate waste codes if flag is set
select @validate_wc = coalesce(validate_wastecode_flag,'F')
from Batch
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and location = @staging_row
and tracking_num = @batch_tracking_num

if @validate_wc = 'T'
begin
	declare c_loop_wc cursor forward_only read_only for
	select cwc.waste_code_uid, wc.display_name
	from ContainerWasteCode cwc
	join Container c
		on c.company_id = cwc.company_id
		and c.profit_ctr_id = cwc.profit_ctr_id
		and c.receipt_id = cwc.receipt_id
		and c.line_id = cwc.line_id
		and c.container_id = cwc.container_id
		and c.container_type = cwc.container_type
		and c.staging_row = @staging_row
	join WasteCode wc
		on wc.waste_code_uid = cwc.waste_code_uid
		and wc.display_name <> 'NONE'
	where cwc.sequence_id = (select max(sequence_id)
							from ContainerDestination
							where company_id = c.company_id
							and profit_ctr_id = c.profit_ctr_id
							and receipt_id = c.receipt_id
							and line_id = c.line_id
							and container_id = c.container_id)
	union
	select rwc.waste_code_uid, wc2.display_name
	from ReceiptWasteCode rwc
	join Container c
		on c.company_id = rwc.company_id
		and c.profit_ctr_id = rwc.profit_ctr_id
		and c.receipt_id = rwc.receipt_id
		and c.line_id = rwc.line_id
		and c.container_type = 'R'
		and c.staging_row = @staging_row
	join WasteCode wc2
		on wc2.waste_code_uid = rwc.waste_code_uid
		and wc2.display_name <> 'NONE'
	where not exists (select 1 from ContainerWasteCode
					where company_id = rwc.company_id
					and profit_ctr_id = rwc.profit_ctr_id
					and receipt_id = rwc.receipt_id
					and line_id = rwc.line_id
					and container_type = 'R')

	open c_loop_wc
	fetch c_loop_wc into @waste_code_uid, @display_name

	while @@FETCH_STATUS = 0
	begin
		if not exists (select 1 from BatchWasteCode
						where status = 'L' 
						and location = @staging_row
						and company_id = @company_id
						and profit_ctr_id = @profit_ctr_id 
						and tracking_num = @batch_tracking_num 
						and waste_code_uid = @waste_code_uid)
		begin
			if coalesce(@msg,'') = ''
				set @msg = 'Error: The following waste codes are invalid for ' + @staging_row + '/' + @batch_tracking_num + ':'

			set @msg = @msg + ' ' + @display_name
		end

		fetch c_loop_wc into @waste_code_uid, @display_name
	end

	close c_loop_wc
	deallocate c_loop_wc
end

if coalesce(@msg,'') <> ''
begin
	set @status = 'ERROR'
	goto RETURN_RESULT
end

declare c_cont cursor read_only forward_only for
select receipt_id, line_id, container_id
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and staging_row = @staging_row
and status = 'N'
and receipt_id > 0

open c_cont
fetch c_cont into @receipt_id, @line_id, @container_id

while @@FETCH_STATUS = 0
begin
	select @fingerpr_status = fingerpr_status
	from Receipt
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and receipt_id = @receipt_id
	and line_id = @line_id

	if @fingerpr_status = 'V'
	begin
		set @status = 'ERROR'

		if coalesce(@msg,'') = ''
			set @msg = 'Error: The following container(s) have invalid fingerprint statuses and cannot be moved:'
		else
			set @msg = @msg + ','

		set @msg = ' ' + right('0' + convert(varchar(10),@company_id),2) + right('0' + convert(varchar(10),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@receipt_id) + '-' + convert(varchar(10),@line_id) + ' - Void'
	end

	if @fingerpr_status = 'R'
	begin
		set @status = 'ERROR'

		if coalesce(@msg,'') = ''
			set @msg = 'Error: The following container(s) have invalid fingerprint statuses and cannot be moved:'
		else
			set @msg = @msg + ','

		set @msg = ' ' + right('0' + convert(varchar(10),@company_id),2) + right('0' + convert(varchar(10),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@receipt_id) + '-' + convert(varchar(10),@line_id) + ' - Rejected'
	end

	if @fingerpr_status = 'C'
	begin
		set @status = 'ERROR'

		if coalesce(@msg,'') = ''
			set @msg = 'Error: The following container(s) have invalid fingerprint statuses and cannot be moved:'
		else
			set @msg = @msg + ','

		set @msg = ' ' + right('0' + convert(varchar(10),@company_id),2) + right('0' + convert(varchar(10),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@receipt_id) + '-' + convert(varchar(10),@line_id) + ' - Completed'
	end

	if @fingerpr_status = 'N'
	begin
		set @status = 'ERROR'

		if coalesce(@msg,'') = ''
			set @msg = 'Error: The following container(s) have invalid fingerprint statuses and cannot be moved:'
		else
			set @msg = @msg + ','

		set @msg = ' ' + right('0' + convert(varchar(10),@company_id),2) + right('0' + convert(varchar(10),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@receipt_id) + '-' + convert(varchar(10),@line_id) + ' - New'
	end

	if @fingerpr_status = 'W'
	begin
		set @status = 'ERROR'

		if coalesce(@msg,'') = ''
			set @msg = 'Error: The following container(s) have invalid fingerprint statuses and cannot be moved:'
		else
			set @msg = @msg + ','

		set @msg = ' ' + right('0' + convert(varchar(10),@company_id),2) + right('0' + convert(varchar(10),@profit_ctr_id),2)
				+ '-' + convert(varchar(10),@receipt_id) + '-' + convert(varchar(10),@line_id) + ' - Waiting for the Lab'
	end

	fetch c_cont into @receipt_id, @line_id, @container_id
end

close c_cont
deallocate c_cont

if coalesce(@msg,'') <> ''
	goto RETURN_RESULT

set @msg = 'Move to batch is valid.'

RETURN_RESULT:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_move_to_batch to eqai
go
