create procedure sp_labpack_sync_upload_workordermanifest
	@trip_sync_upload_id	int,
	@workorder_id			int,
	@company_id				int,
	@profit_ctr_id			int,
	@manifest				varchar(15),
	@manifest_state			char(2),
	@generator_sign_name	varchar(40),
	@generator_sign_date	datetime,
	@manifest_flag		char(1)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload manifest

 loads to Plt_ai
 
 12/17/2019 - rwb created

****************************************************************************************/

declare @sequence_id	int,
		@sql			varchar(6000),
		@user			varchar(10),
		@err			int,
		@msg			varchar(255)

set @user = 'LP'

set @sql = 'if exists (select 1 from WorkOrderManifest'
+ ' where workorder_ID = ' + convert(varchar(20),@workorder_ID)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_ID = ' + convert(varchar(20),@profit_ctr_ID)
+ ' and manifest = ' + coalesce('''' + replace(@manifest, '''', '''''') + '''','null') + ')'
+ ' update WorkOrderManifest'
+ ' set generator_sign_name = ' + coalesce('''' + replace(@generator_sign_name, '''', '''''') + '''','null')
+ ', generator_sign_date = ' + coalesce('''' + convert(varchar(20),@generator_sign_date,120) + '''','null')
+ ', manifest_flag = ' + coalesce('''' + replace(@manifest_flag, '''', '''''') + '''','null')
+ ', modified_by = ''' + @user + ''''
+ ', date_modified = getdate()'
+ ' where workorder_ID = ' + convert(varchar(20),@workorder_ID)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_ID = ' + convert(varchar(20),@profit_ctr_ID)
+ ' and manifest = ' + coalesce('''' + replace(@manifest, '''', '''''') + '''','null')
+ ' else insert WorkOrderManifest ('
+ 'workorder_ID'
+ ', company_id'
+ ', profit_ctr_ID'
+ ', manifest'
+ ', manifest_flag'
+ ', EQ_flag'
+ ', manifest_state'
+ ', gen_manifest_doc_number'
+ ', discrepancy_flag'
+ ', discrepancy_desc'
+ ', discrepancy_resolution'
+ ', continuation_flag'
+ ', site_id'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', generator_sign_name'
+ ', generator_sign_date)'
+ ' values (' + convert(varchar(20),@workorder_ID)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_ID)
+ ', ' + coalesce('''' + replace(@manifest, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@manifest_flag, '''', '''''') + '''','null')
+ ', ''T'''
+ ', ' + coalesce('''' + replace(@manifest_state, '''', '''''') + '''','null')
+ ', '''''
+ ', ''F'''
+ ', '''''
+ ', '''''
+ ', ''T'''
+ ', 1'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@generator_sign_name, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + convert(varchar(20),@generator_sign_date,120) + '''','null') + ')'

select @sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, @sql, 2, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderManifest'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
