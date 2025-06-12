if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_retail_barcode_exists')
	drop procedure sp_rapidtrak_validate_retail_barcode_exists
go

create procedure sp_rapidtrak_validate_retail_barcode_exists
	@package_barcode varchar(100),
	@barcode_type char(1)
as
/*

@barcode_type:
	'S': A shipment label exists, and is not void
	'R': Return label exists, and is not void
	'E': Either label type exists, and is not void

exec sp_rapidtrak_validate_retail_barcode_exists '1Z584Y450346805577', 'S'
exec sp_rapidtrak_validate_retail_barcode_exists '1Z584Y450346805577', 'R'
exec sp_rapidtrak_validate_retail_barcode_exists '1Z584Y450346805577', 'E'

*/

declare @ostatus char(1),
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Barcode is valid.'

set transaction isolation level read uncommitted

select @ostatus = coalesce(status,'')
from OrderItem
where (tracking_barcode_shipped = @package_barcode
	or tracking_barcode_returned = @package_barcode)

if @ostatus = 'V'
begin
	set @status = 'ERROR'
	set @msg = 'Error: The order you scanned has been voided.'

	goto RETURN_STATUS
end

if @barcode_type = 'S'
begin
	if not exists (select 1 from OrderItem
					where tracking_barcode_shipped = @package_barcode)
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The barcode you scanned is not a shipping label.'

		goto RETURN_STATUS
	end
end

else if @barcode_type = 'R'
begin
	if not exists (select 1 from OrderItem
					where tracking_barcode_returned = @package_barcode)
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The barcode you scanned is not a return shipping label.'

		goto RETURN_STATUS
	end
end

else
begin
	if not exists (select 1 from OrderItem
					where tracking_barcode_shipped = @package_barcode
						or tracking_barcode_returned = @package_barcode)
	begin
		set @status = 'ERROR'
		set @msg = 'Error: The barcode you scanned does not exist.'

		goto RETURN_STATUS
	end
end


RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_retail_barcode_exists to EQAI
go
