if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_save_container_staging_move')
	drop procedure sp_rapidtrak_save_container_staging_move
go

create procedure sp_rapidtrak_save_container_staging_move
	@container		varchar(20),
	@staging_row	varchar(15),
	@user_id		varchar(10)
as
--
--exec sp_rapidtrak_save_container_staging_move '2200-286283-1-1', '81263', 'ROB_B'
--select * from Container where company_id = 22 and profit_ctr_id = 0 and receipt_id = 286283 and line_id = 1 and container_id = 1
--select * from ContainerAudit where company_id = 22 and profit_ctr_id = 0 and receipt_id = 286283 and line_id = 1 and container_id = 1
--

set transaction isolation level read uncommitted

declare @pos int,
		@pos2 int,
		@msg varchar(255),
		@company_id int,
		@profit_ctr_id int,
		@type char(1),
		@receipt_id int,
		@line_id int,
		@container_id int,
		@orig_staging_row varchar(15),
		@status varchar(10)

set nocount on

set @status = 'OK'
set @msg = 'Container staging move was successful.'

-- validate arguments
if substring(@container,1,2) = 'P-'
begin
	set @status = 'ERROR'
	set @msg = 'Error: Container ''' + isnull(@container,'') + ''' is not a valid container.'
	goto RETURN_RESULT
end

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

if not exists (select 1 from Container
				where company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and receipt_id = @receipt_id
				and line_id = @line_id
				and container_id = @container_id
				and container_type = @type)
begin
	set @status = 'ERROR'
	set @msg = 'Error: Container does not exist.'

	goto RETURN_RESULT
end


begin transaction

select @orig_staging_row = coalesce(staging_row,'')
from Container
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and container_type = @type
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id

insert ContainerAudit (company_id, profit_ctr_id, container_type, receipt_id, line_id, container_id, sequence_id,
						column_name, before_value, after_value, date_modified, modified_by, modified_from, table_name)  
values (@company_id, @profit_ctr_id, @type, @receipt_id, @line_id, @container_id, 1,
		'staging_row', @orig_staging_row, @staging_row, getdate(), @user_id, 'RT', 'Container')

if @@ERROR <> 0
begin
	rollback transaction
	set @status = 'ERROR'
	set @msg = 'Error inserting into ContainerAudit table.'

	goto RETURN_RESULT
end

update Container
set staging_row = @staging_row,
	modified_by = @user_id,
	date_modified = getdate()
where company_id = @company_id
and profit_ctr_id = @profit_ctr_id
and container_type = @type
and receipt_id = @receipt_id
and line_id = @line_id
and container_id = @container_id

if @@ERROR <> 0
begin
	rollback transaction
	set @status = 'ERROR'
	set @msg = 'Error updating Container table.'

	goto RETURN_RESULT
end

commit transaction

RETURN_RESULT:
select @status as status, @msg as message
go

grant execute on sp_rapidtrak_save_container_staging_move to eqai
go
