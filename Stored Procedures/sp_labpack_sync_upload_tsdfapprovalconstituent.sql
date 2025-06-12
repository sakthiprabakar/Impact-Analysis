create procedure [dbo].[sp_labpack_sync_upload_tsdfapprovalconstituent]
	@trip_sync_upload_id	int,
	@TSDF_approval_id		int,
	@company_id				int,
	@profit_ctr_id			int,
	@const_id				int,
	@concentration			float,
	@unit					varchar(10),
	@UHC					char(1)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload TSDFApproval constituent

 loads to Plt_ai
 
 12/17/2019 - rwb created

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'insert TSDFApprovalConstituent ('
+ 'TSDF_approval_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', const_id'
+ ', concentration'
+ ', unit'
+ ', UHC'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', rowguid)'
+ ' values (' + convert(varchar(20),@TSDF_approval_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@const_id)
+ ', ' + coalesce(convert(varchar(20),@concentration),'null')
+ ', ' + coalesce('''' + replace(@unit, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@UHC, '''', '''''') + '''','null')
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', newid())'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for TSDFApprovalConstituent'
	goto ON_ERROR
end

-- SUCCESS
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1