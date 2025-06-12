create procedure [dbo].[sp_labpack_sync_upload_workorderwastecode]
	@trip_sync_upload_id	int,
	@workorder_id			int,
	@company_id				int,
	@profit_ctr_id			int,
	@workorder_sequence_id	int,
	@waste_code_uid			int,
	@waste_code				varchar(4),
	@sequence_id			int
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload detail items

 loads to Plt_ai
 
 12/17/2019 - rwb created

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'if exists (select 1 from WorkOrderWasteCode'
+ ' where company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and workorder_sequence_id = ' + coalesce(convert(varchar(20),@workorder_sequence_id),'null')
+ ' and waste_code_uid = ' + convert(varchar(20),@waste_code_uid) + ')'
 + ' update WorkOrderWasteCode'
+ ' set waste_code = ' + coalesce('''' + replace(@waste_code, '''', '''''') + '''','null')
+ ', sequence_id = ' + coalesce(convert(varchar(20),@sequence_id),'null')
+ ', added_by = ''' + @user + ''''
+ ', date_added = getdate()'
+ ' where company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and workorder_sequence_id = ' + coalesce(convert(varchar(20),@workorder_sequence_id),'null')
+ ' and waste_code_uid = ' + convert(varchar(20),@waste_code_uid)
+ ' else insert WorkOrderWasteCode ('
+ 'company_id'
+ ', profit_ctr_id'
+ ', workorder_id'
+ ', workorder_sequence_id'
+ ', waste_code_uid'
+ ', waste_code'
+ ', sequence_id'
+ ', added_by'
+ ', date_added)'
+ ' values (' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@workorder_id)
+ ', ' + coalesce(convert(varchar(20),@workorder_sequence_id),'null')
+ ', ' + convert(varchar(20),@waste_code_uid)
+ ', ' + coalesce('''' + replace(@waste_code, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@sequence_id),'null')
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
			' when inserting TripSyncUploadSQL record for WorkOrderWasteCode'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
