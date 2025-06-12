create procedure sp_labpack_sync_upload_workorderdetail
	@trip_sync_upload_id		int,
	@workorder_id				int,
	@company_id					int,
	@profit_ctr_id				int,
	@sequence_id				int,
	@tsdf_code					varchar(15),
	@profile_id					int,
	@tsdf_approval_id			int,
	@waste_stream				varchar(10),
	@tsdf_approval_code			varchar(40),
	@description				varchar(100),
	@reportable_quantity_flag	char(1),
	@RQ_reason					varchar(50),
	@DOT_shipping_name			varchar(255),
	@management_code			varchar(4),
	@hazmat						char(1),
	@hazmat_class				varchar(15),
	@subsidiary_haz_mat_class	varchar(15),
	@UN_NA_flag					char(2),
	@UN_NA_number				int,
	@package_group				varchar(3),
	@erg_number					int,
	@erg_suffix					char(2),
	@manifest_dot_sp_number		varchar(20),
	@manifest					varchar(15),
	@manifest_page_num			int,
	@manifest_line				int,
	@container_count			float,
	@container_code				varchar(15),
	@DOT_waste_flag			char(1),
	@DOT_shipping_desc_additional varchar(255)
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload workorderdetail

 loads to Plt_ai
 
 12/17/2019 - rwb created
 02/23/2021 - rwb Added currency_code
 03/29/2021 - rwb removed bill_rate=-1 from the update
 10/28/2021 - rwb populate waste_stream with left-most 10 characters of @waste_desc if null

****************************************************************************************/

declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255),
		@profile_company_id			int,
		@profile_profit_ctr_id		int

set @user = 'LP'

select @profile_company_id = eq_company,
	@profile_profit_ctr_id = eq_profit_ctr
from TSDF
where tsdf_code = @TSDF_code
and tsdf_status = 'A'

if coalesce(@waste_stream,'') = ''
	set @waste_stream = left(@description,10)


set @sql = 'if exists (select 1 from WorkOrderDetail'
+ ' where workorder_ID = ' + convert(varchar(20),@workorder_ID)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_ID = ' + convert(varchar(20),@profit_ctr_ID)
+ ' and resource_type = ''D'''
+ ' and sequence_ID = ' + convert(varchar(20),@sequence_ID) + ')'
 + ' update WorkOrderDetail'
+ ' set description = ' + coalesce('''' + replace(@description, '''', '''''') + '''','null')
+ ', manifest_waste_desc = ' + coalesce('''' + replace(left(@description,50), '''', '''''') + '''','null')
+ ', TSDF_code = ' + coalesce('''' + replace(@TSDF_code, '''', '''''') + '''','null')
+ ', TSDF_approval_code = ' + coalesce('''' + replace(@TSDF_approval_code, '''', '''''') + '''','null')
+ ', manifest = ' + coalesce('''' + replace(@manifest, '''', '''''') + '''','null')
+ ', manifest_page_num = ' + coalesce(convert(varchar(20),@manifest_page_num),'null')
+ ', manifest_line = ' + coalesce(convert(varchar(20),@manifest_line),'null')
+ ', container_count = ' + coalesce(convert(varchar(20),@container_count),'null')
+ ', container_code = ' + coalesce('''' + replace(@container_code, '''', '''''') + '''','null')
+ ', waste_stream = ' + coalesce('''' + replace(@waste_stream, '''', '''''') + '''','null')
+ ', billing_sequence_id = ' + coalesce(convert(varchar(20),abs(@sequence_id)),'null')
+ ', profile_id = ' + coalesce(convert(varchar(20),@profile_id),'null')
+ ', profile_company_id = ' + coalesce(convert(varchar(20),@profile_company_id),'null')
+ ', profile_profit_ctr_id = ' + coalesce(convert(varchar(20),@profile_profit_ctr_id),'null')
+ ', TSDF_approval_id = ' + coalesce(convert(varchar(20),@TSDF_approval_id),'null')
+ ', DOT_shipping_name = ' + coalesce('''' + replace(@DOT_shipping_name, '''', '''''') + '''','null')
+ ', management_code = ' + coalesce('''' + replace(@management_code, '''', '''''') + '''','null')
+ ', reportable_quantity_flag = ' + coalesce('''' + replace(@reportable_quantity_flag, '''', '''''') + '''','null')
+ ', RQ_reason = ' + coalesce('''' + replace(@RQ_reason, '''', '''''') + '''','null')
+ ', hazmat = ' + coalesce('''' + replace(@hazmat, '''', '''''') + '''','null')
+ ', hazmat_class = ' + coalesce('''' + replace(@hazmat_class, '''', '''''') + '''','null')
+ ', subsidiary_haz_mat_class = ' + coalesce('''' + replace(@subsidiary_haz_mat_class, '''', '''''') + '''','null')
+ ', UN_NA_flag = ' + coalesce('''' + replace(@UN_NA_flag, '''', '''''') + '''','null')
+ ', UN_NA_number = ' + coalesce(convert(varchar(20),@UN_NA_number),'null')
+ ', package_group = ' + coalesce('''' + replace(@package_group, '''', '''''') + '''','null')
+ ', ERG_number = ' + coalesce(convert(varchar(20),@ERG_number),'null')
+ ', ERG_suffix = ' + coalesce('''' + replace(@ERG_suffix, '''', '''''') + '''','null')
+ ', manifest_dot_sp_number = ' + coalesce('''' + replace(@manifest_dot_sp_number, '''', '''''') + '''','null')
+ ', added_by = ''' + @user + ''''
+ ', date_added = getdate()'
+ ', modified_by = ''' + @user + ''''
+ ', date_modified = getdate()'
+ ', DOT_waste_flag = ' + coalesce('''' + replace(@DOT_waste_flag, '''', '''''') + '''','null')
+ ', DOT_shipping_desc_additional = ' + coalesce('''' + replace(@DOT_shipping_desc_additional, '''', '''''') + '''','null')
+ ' where workorder_ID = ' + convert(varchar(20),@workorder_ID)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_ID = ' + convert(varchar(20),@profit_ctr_ID)
+ ' and resource_type = ''D'''
+ ' and sequence_ID = ' + convert(varchar(20),@sequence_ID)
+ ' and resource_type = ''D'''
+ ' else insert WorkOrderDetail ('
+ 'workorder_ID'
+ ', company_id'
+ ', profit_ctr_ID'
+ ', resource_type'
+ ', sequence_ID'
+ ', bill_rate'
+ ', description'
+ ', manifest_waste_desc'
+ ', TSDF_code'
+ ', TSDF_approval_code'
+ ', manifest'
+ ', manifest_page_num'
+ ', manifest_line'
+ ', container_count'
+ ', container_code'
+ ', waste_stream'
+ ', billing_sequence_id'
+ ', profile_id'
+ ', profile_company_id'
+ ', profile_profit_ctr_id'
+ ', TSDF_approval_id'
+ ', DOT_shipping_name'
+ ', management_code'
+ ', reportable_quantity_flag'
+ ', RQ_reason'
+ ', hazmat'
+ ', hazmat_class'
+ ', subsidiary_haz_mat_class'
+ ', UN_NA_flag'
+ ', UN_NA_number'
+ ', package_group'
+ ', ERG_number'
+ ', ERG_suffix'
+ ', manifest_dot_sp_number'
+ ', currency_code'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', DOT_waste_flag'
+ ', DOT_shipping_desc_additional)'
+ ' values (' + convert(varchar(20),@workorder_ID)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_ID)
+ ', ' + '''D'''
+ ', ' + convert(varchar(20),@sequence_ID)
+ ', -1'
+ ', ' + coalesce('''' + replace(@description, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(left(@description,50), '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@TSDF_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@TSDF_approval_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@manifest, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@manifest_page_num),'null')
+ ', ' + coalesce(convert(varchar(20),@manifest_line),'null')
+ ', ' + coalesce(convert(varchar(20),@container_count),'null')
+ ', ' + coalesce('''' + replace(@container_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@waste_stream, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),abs(@sequence_id)),'null')
+ ', ' + coalesce(convert(varchar(20),@profile_id),'null')
+ ', ' + coalesce(convert(varchar(20),@profile_company_id),'null')
+ ', ' + coalesce(convert(varchar(20),@profile_profit_ctr_id),'null')
+ ', ' + coalesce(convert(varchar(20),@TSDF_approval_id),'null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_name, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@management_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@reportable_quantity_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@RQ_reason, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@subsidiary_haz_mat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@UN_NA_flag, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@UN_NA_number),'null')
+ ', ' + coalesce('''' + replace(@package_group, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@ERG_number),'null')
+ ', ' + coalesce('''' + replace(@ERG_suffix, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@manifest_dot_sp_number, '''', '''''') + '''','null')
+ ', (select currency_code from WorkOrderHeader where workorder_id = ' + convert(varchar(20),@workorder_ID) + ' and company_id = ' + convert(varchar(20),@company_id) + ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_ID) + ')'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@DOT_waste_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_desc_additional, '''', '''''') + '''','null') + ')'

select @sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, @sql, 2, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetail'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1