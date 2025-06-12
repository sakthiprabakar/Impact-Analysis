create procedure sp_labpack_sync_upload_tsdfapproval
	@trip_sync_upload_id	int,
	@TSDF_approval_id		int,
	@company_id				int,
	@profit_ctr_id			int,
	@TSDF_code				varchar(15),
	@TSDF_approval_code		varchar(40),
	@waste_desc				varchar(50),
	@customer_id			int,
	@generator_id			int,

	@bill_unit_code			varchar(4),
	@consistency			varchar(50),
	@DOT_shipping_name		varchar(255),
	@ERG_number				int,
	@ERG_suffix				char(2),
	@hazmat					char(1),
	@hazmat_class			varchar(15),
	@subsidiary_haz_mat_class varchar(15),
	@management_code		varchar(4),
	@manifest_dot_sp_number	varchar(20),
	@package_group			varchar(3),
	@reportable_quantity_flag char(1),
	@RQ_reason				varchar(50),
	@UN_NA_flag				char(2),
	@UN_NA_number			int,
	@waste_code_uid			int,
	@waste_code				varchar(4),
	@DOT_waste_flag			char(1),
	@DOT_shipping_desc_additional varchar(255)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload tsdf approval

 loads to Plt_ai
 
 12/17/2019 - rwb created
 12/11/2020 - rwb added @DOT_waste_flag and @DOT_shipping_desc_additional arguments
 10/28/2021 - rwb populate waste_stream with left-most 10 characters of @waste_desc
 11/11/2021 - rwb populate TSDF_approval_start_date and TSDF_approval_expire_date based on getdate()

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

set @sql = 'insert TSDFApproval ('
+ 'TSDF_approval_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', TSDF_code'
+ ', TSDF_approval_code'
+ ', waste_stream'
+ ', TSDF_approval_status'
+ ', TSDF_approval_start_date'
+ ', TSDF_approval_expire_date'
+ ', customer_id'
+ ', generator_id'
+ ', waste_code'
+ ', bill_unit_code'
+ ', waste_desc'
+ ', bulk_flag'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', reportable_quantity_flag'
+ ', RQ_reason'
+ ', DOT_shipping_name'
+ ', hazmat'
+ ', hazmat_class'
+ ', subsidiary_haz_mat_class'
+ ', UN_NA_flag'
+ ', UN_NA_number'
+ ', package_group'
+ ', ERG_number'
+ ', ERG_suffix'
+ ', management_code'
+ ', manifest_dot_sp_number'
+ ', waste_code_uid'
+ ', DOT_waste_flag'
+ ', DOT_shipping_desc_additional)'
+ ' values (' + convert(varchar(20),@TSDF_approval_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + coalesce('''' + replace(@TSDF_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@TSDF_approval_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(left(@waste_desc,10), '''', '''''') + '''','null')
+ ', ''I'''
+ ', ''' + convert(varchar(10),convert(date,getdate())) + ''''
+ ', ''' + convert(varchar(10),dateadd(yy,1,convert(date,getdate()))) + ''''
+ ', ' + coalesce(convert(varchar(20),@customer_id),'null')
+ ', ' + coalesce(convert(varchar(20),@generator_id),'null')
+ ', ' + coalesce('''' + replace(@waste_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@waste_desc, '''', '''''') + '''','null')
+ ', ''F'''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@reportable_quantity_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@RQ_reason, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_name, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@subsidiary_haz_mat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@UN_NA_flag, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@UN_NA_number),'null')
+ ', ' + coalesce('''' + replace(@package_group, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@ERG_number),'null')
+ ', ' + coalesce('''' + replace(@ERG_suffix, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@management_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@manifest_dot_sp_number, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@waste_code_uid),'null')
+ ', ' + coalesce('''' + replace(@DOT_waste_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_desc_additional, '''', '''''') + '''','null') + ')'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for TSDFApproval'
	goto ON_ERROR
end


set @sql = 'insert TSDFApprovalPrice ('
+ 'TSDF_approval_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', status'
+ ', sequence_id'
+ ', record_type'
+ ', bill_unit_code'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@TSDF_approval_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ''A'''
+ ', 1'
+ ', ''D'''
+ ', ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate())'

set @sql_sequence_id = @sql_sequence_id + 1

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