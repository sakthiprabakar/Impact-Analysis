if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_retail_move_staging_area')
	drop procedure sp_rapidtrak_save_retail_move_staging_area
go

create procedure sp_rapidtrak_save_retail_move_staging_area
	@co_pc varchar(4),
	@current_staging_row varchar(5),
	@new_staging_row varchar(5),
	@user_id varchar(10)
as
/*
ADO 29420

exec sp_rapidtrak_save_retail_move_staging_area '1409', 'ROW3', 'ROW2', 'ROB_B'
select * from OrderItem where staging_row = 'ROW2'
*/

declare @company_id int,
	@profit_ctr_id int,
	@err int,
	@rc int,
	@status varchar(5),
	@msg varchar(255)

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set @status = 'OK'
set @msg = 'been moved to staging row ' + @new_staging_row + '.'

begin transaction

insert OrderAudit
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'staging_row',
	staging_row,
	@new_staging_row,
	'RapidTrak Retail Move Entire Staging Area',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join OrderDetail od
	on od.order_id = oi.order_id
	and od.line_id = oi.line_id
	and od.company_id = @company_id
	and od.profit_ctr_id = @profit_ctr_id
where oi.staging_row = @current_staging_row
and oi.outbound_receipt_id is null
and oi.outbound_receipt_line_id is null
and oi.date_outbound_receipt is null

if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Insert into OrderAudit failed.'

	goto RETURN_STATUS
end

update OrderItem
set staging_row = @new_staging_row,
	modified_by = @user_id,
	date_modified = getdate()
from OrderItem oi
join OrderDetail od
	on od.order_id = oi.order_id
	and od.line_id = oi.line_id
	and od.company_id = @company_id
	and od.profit_ctr_id = @profit_ctr_id
where oi.staging_row = @current_staging_row
and oi.outbound_receipt_id is null
and oi.outbound_receipt_line_id is null
and oi.date_outbound_receipt is null

select @err = @@ERROR,
		@rc = @@ROWCOUNT

if @err <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Update to OrderItem failed.'

	goto RETURN_STATUS
end

commit transaction

if @rc = 1
	set @msg = convert(varchar(10),@rc) + ' order has ' + @msg
else
	set @msg = convert(varchar(10),@rc) + ' orders have ' + @msg


RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_save_retail_move_staging_area to EQAI
go
