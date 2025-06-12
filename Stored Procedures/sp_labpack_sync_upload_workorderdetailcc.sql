create procedure [dbo].[sp_labpack_sync_upload_workorderdetailcc]
	@trip_sync_upload_id		int,
	@workorder_id				int,
	@company_id					int,
	@profit_ctr_id				int,
	@sequence_id				int,
	@consolidated_container_id	int,
	@percentage					int,
	@container_type				varchar(2),
	@container_size				varchar(4)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload consolidated containers

 loads to Plt_ai
 
 12/17/2019 - rwb created

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'if exists (select 1 from WorkOrderDetailCC'
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and consolidated_container_id = ' + coalesce(convert(varchar(20),@consolidated_container_id),'null') + ')'
 + ' update WorkOrderDetailCC'
+ ' set percentage = ' + coalesce(convert(varchar(20),@percentage),'null')
+ ', added_by = ''' + @user + ''''
+ ', date_added = getdate()'
+ ', modified_by = ''' + @user + ''''
+ ', date_modified = getdate()'
+ ', container_type = ' + coalesce('''' + replace(@container_type, '''', '''''') + '''','null')
+ ', container_size = ' + coalesce('''' + replace(@container_size, '''', '''''') + '''','null')
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and consolidated_container_id = ' + coalesce(convert(varchar(20),@consolidated_container_id),'null')
+ ' else insert WorkOrderDetailCC ('
+ 'workorder_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', sequence_id'
+ ', consolidated_container_id'
+ ', percentage'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', container_type'
+ ', container_size)'
+ ' values (' + convert(varchar(20),@workorder_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@sequence_id)
+ ', ' + coalesce(convert(varchar(20),@consolidated_container_id),'null')
+ ', ' + coalesce(convert(varchar(20),@percentage),'null')
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@container_type, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@container_size, '''', '''''') + '''','null') + ')'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetailCC'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1