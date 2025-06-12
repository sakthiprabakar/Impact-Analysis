create procedure [dbo].[sp_labpack_sync_upload_workordertransporter]
	@trip_sync_upload_id		int,
	@workorder_id				int,
	@company_id					int,
	@profit_ctr_id				int,
	@manifest					varchar(15),
	@transporter_sequence_id	int,
	@transporter_code			varchar(15),
	@transporter_sign_name		varchar(40),
	@transporter_sign_date		datetime,
	@transporter_license_nbr	varchar(20)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload transporter

 loads to Plt_ai
 
 12/17/2019 - rwb created

****************************************************************************************/

declare @sequence_id	int,
		@sql			varchar(6000),
		@user			varchar(10),
		@err			int,
		@msg			varchar(255)

set @user = 'LP'

set @sql = 'if not exists (select 1 from WorkOrderTransporter'
+ ' where company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and manifest = ' + '''' + replace(@manifest, '''', '''''') + ''''
+ ' and transporter_sequence_id = ' + convert(varchar(20),@transporter_sequence_id) + ')'
+ ' insert WorkOrderTransporter ('
+ 'company_id'
+ ', profit_ctr_id'
+ ', workorder_id'
+ ', manifest'
+ ', transporter_sequence_id'
+ ', transporter_code'
+ ', transporter_sign_name'
+ ', transporter_sign_date'
+ ', transporter_license_nbr'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@workorder_id)
+ ', ' + '''' + replace(@manifest, '''', '''''') + ''''
+ ', ' + convert(varchar(20),@transporter_sequence_id)
+ ', ' + coalesce('''' + replace(@transporter_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@transporter_sign_name, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + convert(varchar(20),@transporter_sign_date,120) + '''','null')
+ ', ' + coalesce('''' + replace(@transporter_license_nbr, '''', '''''') + '''','null')
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate())'

select @sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderTransporter'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1