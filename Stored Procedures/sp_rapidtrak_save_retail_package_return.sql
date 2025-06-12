if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_retail_package_return')
	drop procedure sp_rapidtrak_save_retail_package_return
go

create procedure sp_rapidtrak_save_retail_package_return
	@barcode_list varchar(max),
	@user_id varchar(10)
as
/*

exec sp_rapidtrak_save_retail_package_return 'insert #t values (''1Z584Y459048233581'', 8, 6.4)', 'ROB_B'
select * from OrderItem where tracking_barcode_returned = '1Z584Y459048233581'
update OrderItem set date_returned = null where tracking_barcode_returned = '1Z584Y459048233581'
select * from OrderAudit where order_id = 11224 and modified_from = 'RT' and date_modified > '09/07/2022 13:00:00'
*/

declare @returned_date datetime,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Return(s) successfully saved.'

create table #t (barcode varchar(100) not null, return_quantity decimal(10,3) null, return_weight decimal(10,3) null)
exec(@barcode_list)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Inserts to temp table failed, shipment(s) were not saved.'

	goto RETURN_STATUS
end

set transaction isolation level read uncommitted

set @returned_date = convert(datetime,convert(varchar(10),getdate(),101))

begin transaction

insert OrderAudit
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'date_returned',
	convert(varchar(10),oi.date_returned,101),
	convert(varchar(10),@returned_date,101),
	'RapidTrak Retail Package Return',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_returned
where coalesce(oi.date_returned,'01/01/1990') <> @returned_date
union
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'quantity_returned',
	convert(varchar(10),oi.quantity_returned),
	case when #t.return_quantity = 0 then null else convert(varchar(20),#t.return_quantity) end,
	'RapidTrak Retail Package Return',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_returned
where coalesce(oi.quantity_returned,0) <> coalesce(#t.return_quantity,0)
union
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'return_weight',
	convert(varchar(10),oi.return_weight),
	case when #t.return_weight = 0 then null else convert(varchar(20),#t.return_weight) end,
	'RapidTrak Retail Package Return',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_returned
where coalesce(oi.return_weight,0) <> coalesce(#t.return_weight,0)

if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Insert into OrderAudit failed.'

	goto RETURN_STATUS
end

update OrderItem
set date_returned = @returned_date,
	quantity_returned = case when #t.return_quantity = 0 then null else #t.return_quantity end,
	return_weight = case when #t.return_weight = 0 then null else #t.return_weight end,
	modified_by = @user_id,
	date_modified = getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_returned
  
if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Update to OrderItem failed, return was not saved.'

	goto RETURN_STATUS
end

commit transaction

RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_save_retail_package_return to EQAI
go
