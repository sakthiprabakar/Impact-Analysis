create procedure [dbo].[sp_labpack_sync_upload_profilewastecode]
	@trip_sync_upload_id	int,
	@profile_id				int,
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

 NOTE:
 If more than one bill unit needs to be added, create a separate proc like for waste codes

****************************************************************************************/

-- add a check to ensure @profile_id < 0... profiles can only be inserted
declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'insert ProfileWasteCode ('
+ 'profile_id'
+ ', primary_flag'
+ ', waste_code_uid'
+ ', waste_code'
+ ', added_by'
+ ', date_added'
+ ', rowguid'
+ ', sequence_id'
+ ', sequence_flag)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ' + '''' + replace(@primary_flag, '''', '''''') + ''''
+ ', ' + convert(varchar(20),@waste_code_uid)
+ ', ' + '''' + replace(@waste_code, '''', '''''') + ''''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', newid()'
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
			' when inserting TripSyncUploadSQL record for ProfileWasteCode'
	goto ON_ERROR
end

-- SUCCESS
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1