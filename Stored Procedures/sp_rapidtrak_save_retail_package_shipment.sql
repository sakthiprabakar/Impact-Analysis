if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_retail_package_shipment')
	drop procedure sp_rapidtrak_save_retail_package_shipment
go

create procedure sp_rapidtrak_save_retail_package_shipment
	@barcode_list varchar(max),
	@user_id varchar(10)
as
/*
select * from OrderItem where date_shipped is null

exec sp_rapidtrak_save_retail_package_shipment 'insert #t values (''1Z584Y450341344173'')', 'ROB_B'
select * from OrderItem where order_id = 7840
update OrderItem set date_shipped = null where order_id = 7840
select * from OrderAudit where order_id = 7840 and modified_from = 'RT'
*/

declare @package_barcode varchar(100),
	@order_id int,
	@shipped_count int,
	@shipped_date datetime,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Shipment(s) successfully saved.'

create table #t (barcode varchar(100) not null)
exec(@barcode_list)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Inserts to temp table failed, shipment(s) were not saved.'

	goto RETURN_STATUS
end

set transaction isolation level read uncommitted

set @shipped_date = convert(datetime,convert(varchar(10),getdate(),101))

begin transaction

insert OrderAudit
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'date_shipped',
	convert(varchar(10),oi.date_shipped,101),
	convert(varchar(10),@shipped_date,101),
	'RapidTrak Retail Package Shipment',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_shipped
where coalesce(oi.date_shipped,'01/01/1990') <> @shipped_date

if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Insert into OrderAudit failed.'

	goto RETURN_STATUS
end

update OrderItem
set date_shipped = @shipped_date,
	modified_by = @user_id,
	date_modified = getdate()
from OrderItem oi
join #t
	on #t.barcode = oi.tracking_barcode_shipped

if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Update to OrderItem failed, shipment(s) were not saved.'

	goto RETURN_STATUS
end

declare c_loop cursor forward_only read_only for
select barcode from #t

open c_loop
fetch c_loop into @package_barcode

while @@FETCH_STATUS = 0
begin
	select @order_id = order_id
	from OrderItem
	where tracking_barcode_shipped = @package_barcode

	select @shipped_count = count(*) 
	from OrderItem 
	where order_id = @order_id
	and date_shipped is null

	if @shipped_count = 0
	begin
		exec dbo.sp_retail_email_shipment_confirm @order_id, @shipped_date

		if @@ERROR <> 0
		begin
			rollback transaction

			set @status = 'ERROR'
			set @msg = 'Error: Attempt to create confirmation e-mail failed, shipment was not saved.'

			goto RETURN_STATUS
		end
	end

	fetch c_loop into @package_barcode
end

close c_loop
deallocate c_loop

commit transaction

RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_save_retail_package_shipment to EQAI
go
