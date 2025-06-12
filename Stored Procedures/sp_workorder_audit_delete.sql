
create procedure sp_workorder_audit_delete
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int,
	@user_id varchar(10),
	@debug int = 0
as
/****************************************************************************************
This stored procedure is used to insert delete Audit of Work order records from trip screen

PB Object(s):	w_trip


02/19/2014 SM&RB   Created 

--exec sp_workorder_audit_delete 19869200, 14, 0, 'SAGAR_M', 1
--exec sp_workorder_audit_delete 19840000, 14, 0, 'SAGAR_M', 1

****************************************************************************************/

declare @initial_trancount int,
		@table_name varchar(60),
		@col_name varchar(60),
		@dt datetime,
		@sql varchar(max),
		@msg varchar(255)

-- tables to audit
create table #tables (
	table_name varchar(60) not null
)
insert #tables values ('WorkOrderDetailItem')
insert #tables values ('WorkOrderDetailUnit')
insert #tables values ('WorkOrderDetail')

-- record initial trancount
set @initial_trancount = @@TRANCOUNT
set @dt = GETDATE()

-- loop through tables
begin transaction
declare c_tables cursor forward_only read_only for
select table_name from #tables

open c_tables
fetch c_tables into @table_name

while @@FETCH_STATUS = 0
begin
	-- loop through columns
	declare c_cols cursor forward_only read_only for
	select name from syscolumns (nolock)
	where id = OBJECT_ID(@table_name)
	and name not in ('workorder_id', 'company_id', 'profit_ctr_id', 'added_by', 'date_added', 'modified_by', 'date_modified','billing_sequence_uid')

	open c_cols
	fetch c_cols into @col_name

	while @@FETCH_STATUS = 0
	begin
		set @sql = 'insert WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name,'
				+ ' column_name, before_value, after_value, audit_reference, modified_by, date_modified)'
				+ ' select company_id, profit_ctr_id, workorder_id, '

		if @table_name = 'WorkOrderDetail'
			set @sql = @sql + 'resource_type'
		else
			set @sql = @sql + ''''''

		set @sql = @sql + ', sequence_id, ''' + @table_name + ''','
				+ ' ''' + @col_name + ''', convert(varchar(255),' + @col_name + '), ''(deleted)'', ''Delete Workorder'','
				+ ' ''' + @user_id + ''', ''' + convert(varchar(20),@dt,120) + ''''
				+ ' from ' + @table_name + ' (nolock)'
				+ ' where workorder_id = ' + convert(varchar(10),@workorder_id)
				+ ' and company_id = ' + convert(varchar(10),@company_id)
				+ ' and profit_ctr_id = ' + convert(varchar(10),@profit_ctr_id)
				+ ' and ltrim(rtrim(isnull(convert(varchar(255),' + @col_name + '),''''))) <> '''''

		if isnull(@debug,0) = 1
			print 'SQL to execute: ' + @sql

		execute (@sql)
		if @@error <> 0
		begin
			set @msg = 'Error inserting audit for ' + @table_name + '.' + @col_name
			goto ON_ERROR
		end

		fetch c_cols into @col_name
	end

	close c_cols
	deallocate c_cols

	fetch c_tables into @table_name
end

close c_tables
deallocate c_tables

--SUCCESS
if @@TRANCOUNT > @initial_trancount
	commit transaction
return 0

--ERROR
ON_ERROR:
if @@TRANCOUNT > @initial_trancount
	rollback transaction

raiserror(@msg,16,1)
return -1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_workorder_audit_delete] TO [EQAI]
    AS [dbo];

