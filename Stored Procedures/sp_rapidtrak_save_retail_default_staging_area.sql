if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_retail_default_staging_area')
	drop procedure sp_rapidtrak_save_retail_default_staging_area
go

create procedure sp_rapidtrak_save_retail_default_staging_area
	@product_id int,
	@staging_row varchar(5),
	@user_id varchar(10)
as
/*
ADO 29430

exec sp_rapidtrak_save_retail_default_staging_area 854, 'ROW1', 'ROB_B'
select default_staging_row, * from Product where product_id = 854

*/

declare @status varchar(5),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Default staging row saved.'

update Product
set default_staging_row = @staging_row,
	modified_by = @user_id,
	date_modified = getdate()
where product_id = @product_id

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error: Update to Product failed.'

	goto RETURN_STATUS
end


RETURN_STATUS:
select @status as status, @msg as message
return 0
go

grant execute on sp_rapidtrak_save_retail_default_staging_area to EQAI
go
