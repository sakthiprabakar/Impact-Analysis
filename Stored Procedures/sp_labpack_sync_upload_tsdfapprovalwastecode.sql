use Plt_ai
go

alter procedure [dbo].[sp_labpack_sync_upload_tsdfapprovalwastecode]
	@trip_sync_upload_id	int,
	@TSDF_approval_id		int,
	@company_id				int,
	@profit_ctr_id			int,
	@waste_code_uid			int,
	@waste_code				varchar(4),
	@primary_flag			char(1),
	@sequence_id			int,
	@sequence_flag			char(1)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload profile

 loads to Plt_ai
 
 12/17/2019 - rwb created
 05/21/2025 - CHG0080813 rwb Remove rowguid from the insert, it is being removed from the table

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'insert TSDFApprovalWasteCode ('
+ 'TSDF_approval_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', primary_flag'
+ ', waste_code_uid'
+ ', waste_code'
+ ', added_by'
+ ', date_added'
+ ', sequence_id'
+ ', sequence_flag)'
+ ' values (' + convert(varchar(20),@TSDF_approval_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + '''' + replace(@primary_flag, '''', '''''') + ''''
+ ', ' + convert(varchar(20),@waste_code_uid)
+ ', ' + '''' + replace(@waste_code, '''', '''''') + ''''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce(convert(varchar(20),@sequence_id),'null')
+ ', ' + coalesce('''' + replace(@sequence_flag, '''', '''''') + '''','null') + ')'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for TSDFApprovalWasteCode'
	goto ON_ERROR
end

-- SUCCESS
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
go
