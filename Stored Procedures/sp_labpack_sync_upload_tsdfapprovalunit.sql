create procedure [dbo].[sp_labpack_sync_upload_tsdfapprovalunit]
	@trip_sync_upload_id	int,
	@tsdf_approval_id		int,
	@company_id				int,
	@profit_ctr_id			int,
	@bill_unit_code			varchar(4)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload TSDFApproval detail

 loads to Plt_ai
 
 05/14/2020 - rwb created

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'if not exists (select 1 from TSDFApprovalPrice'
+ ' where TSDF_approval_id = ' + convert(varchar(20),@tsdf_approval_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and bill_unit_code = ''' + @bill_unit_code + ''')'
+ ' insert TSDFApprovalPrice ('
+ 'TSDF_approval_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', status'
+ ', record_type'
+ ', sequence_id'
+ ', bill_unit_code'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@tsdf_approval_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ''A'''
+ ', ''D'''
+ ', (select coalesce(max(sequence_id),0) + 1 from TSDFApprovalPrice where TSDF_approval_id = ' + convert(varchar(20),@tsdf_approval_id) + ' and company_id = ' + convert(varchar(20),@company_id)+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id) + ')'
+ ', ' + '''' + replace(@bill_unit_code, '''', '''''') + ''''
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
			' when inserting TripSyncUploadSQL record for TSDFApprovalPrice'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
