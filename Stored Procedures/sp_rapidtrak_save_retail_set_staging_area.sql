if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_retail_set_staging_area')
	drop procedure sp_rapidtrak_save_retail_set_staging_area
go

create procedure sp_rapidtrak_save_retail_set_staging_area
	@barcode_list varchar(max),
	@staging_row varchar(5),
	@user_id varchar(10)
as
/*
ADO 29421

exec sp_rapidtrak_save_retail_set_staging_area ' insert #t values (''1Z584Y450341344173'') insert #t values (''1Z584Y459048233581'')', 'ROW2', 'ROB_B'
select staging_row, * from OrderItem where tracking_barcode_shipped in ('1Z584Y450341344173','1Z584Y459048233581') or tracking_barcode_returned in ('1Z584Y450341344173','1Z584Y459048233581')
select * from OrderAudit where order_id in (7840,11224) and modified_from = 'RT'
*/

declare @err int,
	@rc int,
	@status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'been moved to staging area ' + @staging_row + '.'

create table #t (barcode varchar(100) not null)
exec (@barcode_list)

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Inserts to temp table failed, shipment(s) were not saved.'

	goto RETURN_STATUS
end

set transaction isolation level read uncommitted

begin transaction

insert OrderAudit
select distinct oi.order_id,
	null,
	null,
	'OrderItem',
	'staging_row',
	oi.staging_row,
	@staging_row,
	'RapidTrak Retail Set Staging Area',
	@user_id,
	'RT',
	getdate()
from OrderItem oi
join #t
	on (#t.barcode = oi.tracking_barcode_shipped or
		#t.barcode = oi.tracking_barcode_returned)
and coalesce(oi.staging_row,'') <> @staging_row

if @@ERROR <> 0
begin
	rollback transaction

	set @status = 'ERROR'
	set @msg = 'Error: Insert into OrderAudit failed.'

	goto RETURN_STATUS
end

update OrderItem
set staging_row = @staging_row,
	modified_by = @user_id,
	date_modified = getdate()
from OrderItem oi
join #t
	on (#t.barcode = oi.tracking_barcode_shipped or
		#t.barcode = oi.tracking_barcode_returned)
where coalesce(staging_row,'') <> @staging_row

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

grant execute on sp_rapidtrak_save_retail_set_staging_area to EQAI
go
