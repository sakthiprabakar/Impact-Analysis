if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_retail_package_shipment')
	drop procedure sp_rapidtrak_validate_retail_package_shipment
go

create procedure sp_rapidtrak_validate_retail_package_shipment
	@package_barcode varchar(100),
	@product_id int
as
/*

exec sp_rapidtrak_validate_retail_package_shipment '1Z584Y450346805577', 840

*/

declare @dt_shipped datetime,
	@ostatus char(1),
	@oproduct_id int,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Shipment is valid.'

set transaction isolation level read uncommitted

select @ostatus = coalesce(oi.status,''),
	@oproduct_id = coalesce(od.product_id,0),
	@dt_shipped = oi.date_shipped
from OrderItem oi
join OrderDetail od
	on od.order_id = oi.order_id
	and od.line_id = oi.line_id
where oi.tracking_barcode_shipped = @package_barcode


if exists (select 1 from OrderItem where tracking_barcode_returned = @package_barcode)
begin
	set @status = 'ERROR'
	set @msg = 'Error: The barcode you scanned is the return shipping label.  Please scan the ship out to customer label.'

	goto RETURN_STATUS
end

if @ostatus = 'V'
begin
	set @status = 'ERROR'
	set @msg = 'Error: The order you scanned has been voided.'

	goto RETURN_STATUS
end

if @oproduct_id <> @product_id
begin
	set @status = 'ERROR'
	set @msg = 'Error: Selected product (' + convert(varchar(10),@product_id) + ') and product from label (' + convert(varchar(10),@oproduct_id) + ') do not match.'

	goto RETURN_STATUS
end

if @dt_shipped is not null
begin
	set @status = 'ERROR'
	set @msg = 'Error: The order you scanned was shipped on ' + convert(varchar(10),@dt_shipped,101) + '.'

	goto RETURN_STATUS
end

if not exists (select 1 from OrderItem where tracking_barcode_shipped = @package_barcode)
begin
	set @status = 'ERROR'
	set @msg = 'Error: The barcode you scanned does not exist.'

	goto RETURN_STATUS
end

RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_retail_package_shipment to EQAI
go
