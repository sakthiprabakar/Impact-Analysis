if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_staging_move')
	drop procedure sp_rapidtrak_save_staging_move
go

create procedure sp_rapidtrak_save_staging_move
	@co_pc					varchar(4),
	@current_staging_row	varchar(15),
	@new_staging_row		varchar(15),
	@user_id				varchar(10)
as
--
--exec sp_rapidtrak_save_staging_move '2100', 'CR78A', 'FX19', 'ROB_B'
--select * from Container where company_id = 21 and profit_ctr_id = 0 and status = 'N' and staging_row = 'CR78A'
--select * from Container where company_id = 21 and profit_ctr_id = 0 and status = 'N' and staging_row = 'FX19'
--select * from ContainerAudit where company_id = 21 and profit_ctr_id = 0 and column_name = 'staging_row' and before_value = 'CR78A' and after_value = 'FX19'
--

declare @company_id int,
	@profit_ctr_id int,
	@status varchar(7),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'Containers updated successfully.'

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

begin transaction

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
select company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, 1,
		'staging_row', coalesce(staging_row,''), @new_staging_row, getdate(), @user_id, 'RT', 'Container'
from Container
WHERE staging_row = @current_staging_row
AND profit_ctr_id = @profit_ctr_id
AND status = 'N'
AND company_id = @company_id
AND coalesce(staging_row,'') <> @new_staging_row

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

UPDATE Container  
SET staging_row = @new_staging_row,
	modified_by = @user_id,
	date_modified = getdate()
WHERE staging_row = @current_staging_row
AND profit_ctr_id = @profit_ctr_id
AND status = 'N'
AND company_id = @company_id

if @@ERROR <> 0
begin
	set @status = 'ERROR'
	set @msg = 'Error updating Container table.'

	goto RETURN_RESULT
end


RETURN_RESULT:
if @status = 'OK'
	commit transaction
else
	rollback transaction

select @status as status, @msg as message
go

grant execute on sp_rapidtrak_save_staging_move to eqai
go
