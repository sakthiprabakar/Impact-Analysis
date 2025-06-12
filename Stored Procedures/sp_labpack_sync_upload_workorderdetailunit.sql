create procedure sp_labpack_sync_upload_workorderdetailunit
	@trip_sync_upload_id	int,
	@workorder_id			int,
	@company_id				int,
	@profit_ctr_id			int,
	@sequence_id			int,
	@bill_unit_code			varchar(4),
	@quantity				float,
	@manifest_flag			char(1),
	@billing_flag			char(1)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload manifest

 loads to Plt_ai
 
 12/17/2019 - rwb created
 12/08/2020 - rwb Added insertion of monthly weight records
 02/23/2021 - rwb Added currency_code

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'if exists (select 1 from WorkOrderDetailUnit'
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and bill_unit_code = ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null') + ')'
 + ' update WorkOrderDetailUnit'
+ ' set size = ' + '''' + replace(@bill_unit_code, '''', '''''') + ''''
+ ', quantity = ' + coalesce(convert(varchar(20),@quantity),'null')
+ ', manifest_flag = ' + coalesce('''' + replace(@manifest_flag, '''', '''''') + '''','null')
+ ', billing_flag = ' + coalesce('''' + replace(@billing_flag, '''', '''''') + '''','null')
+ ', added_by = ''' + @user + ''''
+ ', date_added = getdate()'
+ ', modified_by = ''' + @user + ''''
+ ', date_modified = getdate()'
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and bill_unit_code = ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ' else insert WorkOrderDetailUnit ('
+ 'workorder_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', sequence_id'
+ ', size'
+ ', bill_unit_code'
+ ', quantity'
+ ', manifest_flag'
+ ', billing_flag'
+ ', currency_code'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@workorder_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@sequence_id)
+ ', ' + '''' + replace(@bill_unit_code, '''', '''''') + ''''
+ ', ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@quantity),'null')
+ ', ' + coalesce('''' + replace(@manifest_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@billing_flag, '''', '''''') + '''','null')
+ ', (select currency_code from WorkOrderHeader where workorder_id = ' + convert(varchar(20),@workorder_id) + ' and company_id = ' + convert(varchar(20),@company_id) + ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_ID) + ')'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate())'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetailUnit'
	goto ON_ERROR
end

--Monthly weights
if @bill_unit_code = 'LBS'
begin
	set @sql = ' if not exists (select 1 from workorderdetailitem'
	+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
	+ ' and company_id = ' + convert(varchar(20),@company_id)
	+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
	+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
	+ ' and item_type_ind = ''MW'')'
    + ' insert workorderdetailitem (workorder_id,company_id,profit_ctr_id,sequence_id,sub_sequence_id'
    + ',item_type_ind,month,year,pounds,ounces,added_by,date_added,modified_by,date_modified)'
    + ' values (' + convert(varchar(20),@workorder_id)
    + ',' + convert(varchar(20),@company_id)
    + ',' + convert(varchar(20),@profit_ctr_id)
    + ',' + convert(varchar(20),@sequence_id)
    + ', (select coalesce(max(sub_sequence_id),0)+1 from workorderdetailitem'
		+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
		+ ' and company_id = ' + convert(varchar(20),@company_id)
		+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
		+ ' and sequence_id = ' + convert(varchar(20),@sequence_id) + ')'
    + ',''MW'''
    + ',' + convert(varchar(2),datepart(mm,getdate()))
    + ',' + convert(varchar(4),datepart(yyyy,getdate()))
    + ',' + convert(varchar(10),@quantity)
    + ',0'
    + ',''' + @user + ''',getdate(),''' + @user + ''',getdate())'

	select @sql_sequence_id = max(sequence_id) + 1
	from TripSyncuploadSQL
	where trip_sync_upload_id = @trip_sync_upload_id

	insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
	values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

	select @err = @@error
	if @err <> 0
	begin
		select @msg = '   DB Error ' + convert(varchar(10),@err) +
				' when inserting TripSyncUploadSQL record for WorkOrderDetailUnit monthly weights'
		goto ON_ERROR
	end
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1