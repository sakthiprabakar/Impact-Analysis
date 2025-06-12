if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_batch')
	drop procedure sp_rapidtrak_validate_batch
go

create procedure sp_rapidtrak_validate_batch
	@co_pc		varchar(4),
	@location	varchar(15),
	@batch_tracking_num varchar(15)
as
--
--exec sp_rapidtrak_validate_batch '2100', 'A-1', '2016'
--

declare @company_id 	int,
	@profit_ctr_id	int,
	@batch_status char,
	@status varchar(5),
	@msg varchar(255)

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set @status = 'OK'
set @msg = 'Batch is valid.'

select @batch_status = coalesce(status,'')
from Batch
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and location = @location
and tracking_num = @batch_tracking_num

if not exists (select 1 from Batch
			where company_id = @company_id
			and profit_ctr_id = @profit_ctr_id
			and location = @location
			and tracking_num = @batch_tracking_num)
begin
	set @status = 'ERROR'
	set @msg = 'Error: Batch ' + @location + '/' + @batch_tracking_num + ' does not exist.'
end
else if @batch_status = 'R'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Closed for Treatment status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'T'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Closed for Testing status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'D'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Closed for Digging status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'C'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Closed status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'V'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Void status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'P'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Pending Recipe Review status and cannot be selected.  Please review the batch information.'
end
else if @batch_status = 'A'
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The batch you selected is in Ready for Treatment status and cannot be selected.  Please review the batch information.'
end
else if @batch_status <> 'O'
begin
	set @status = 'ERROR'
	set @msg = 'Error: The batch status of "' + @batch_status + '" is invalid.'
end


select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_batch to eqai
go
