if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_validate_retail_set_staging_area')
	drop procedure sp_rapidtrak_validate_retail_set_staging_area
go

create procedure sp_rapidtrak_validate_retail_set_staging_area
	@co_pc varchar(4),
	@package_barcode varchar(100),
	@staging_row varchar(5)
as
/*
ADO 29421

exec sp_rapidtrak_validate_retail_set_staging_area '1409', '1Z584Y450346805577', 'ROW2'

*/

declare @company_id int,
	@profit_ctr_id int,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Set staging area is valid.'

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

set transaction isolation level read uncommitted


if not exists (select 1 from OrderItem where (tracking_barcode_shipped = @package_barcode or tracking_barcode_returned = @package_barcode))
begin
	set @status = 'ERROR'
	set @msg = 'Error:  The package was not found in the database. Please review this package.'

	goto RETURN_STATUS
end

if exists (select 1 from OrderItem where (tracking_barcode_shipped = @package_barcode or tracking_barcode_returned = @package_barcode)
			and outbound_receipt_id is not null and outbound_receipt_line_id is not null and date_outbound_receipt is not null)
begin
	set @status = 'ERROR'
	set @msg = 'Error: The package has already been flagged as outbounded.'

	goto RETURN_STATUS
end


RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_validate_retail_set_staging_area to EQAI
go
