create procedure [dbo].[sp_labpack_sync_upload_workorderdetailitem]
	@trip_sync_upload_id	int,
	@workorder_id			int,
	@company_id				int,
	@profit_ctr_id			int,
	@sequence_id			int,
	@sub_sequence_id		int,
	@item_type_ind			varchar(2),
	@month					int,
	@year					int,
	@pounds					float = null,
	@ounces					float = null,
	@merchandise_id			int = null,
	@merchandise_quantity	int = null,
	@merchandise_code_type	char(1) = null,
	@merchandise_code		varchar(15) = null,
	@manual_entry_desc		varchar(60) = null,
	@note					varchar(255) = null,
	@form_group				int = null,
	@contents				varchar(20) = null,
	@percentage				int = null,
	@DEA_schedule			varchar(2) = null,
	@dea_form_222_number	varchar(9) = null,
	@dosage_type_id			int = null,
	@parent_sub_sequence_id	int = null,
	@const_id				int = null,
	@const_percent			int = null,
	@const_uhc				char(1) = null
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

set @sql = 'if exists (select 1 from WorkOrderDetailItem'
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and sub_sequence_id = ' + convert(varchar(20),@sub_sequence_id) + ')'
 + ' update WorkOrderDetailItem'
+ ' set item_type_ind = ' + '''' + replace(@item_type_ind, '''', '''''') + ''''
+ ', month = ' + convert(varchar(20),@month)
+ ', year = ' + convert(varchar(20),@year)
+ ', pounds = ' + coalesce(convert(varchar(20),@pounds),'null')
+ ', ounces = ' + coalesce(convert(varchar(20),@ounces),'null')
+ ', merchandise_id = ' + coalesce(convert(varchar(20),@merchandise_id),'null')
+ ', merchandise_quantity = ' + coalesce(convert(varchar(20),@merchandise_quantity),'null')
+ ', merchandise_code_type = ' + coalesce('''' + replace(@merchandise_code_type, '''', '''''') + '''','null')
+ ', merchandise_code = ' + coalesce('''' + replace(@merchandise_code, '''', '''''') + '''','null')
+ ', manual_entry_desc = ' + coalesce('''' + replace(@manual_entry_desc, '''', '''''') + '''','null')
+ ', note = ' + coalesce('''' + replace(@note, '''', '''''') + '''','null')
+ ', added_by = ''' + @user + ''''
+ ', date_added = getdate()'
+ ', modified_by = ''' + @user + ''''
+ ', date_modified = getdate()'
+ ', form_group = ' + coalesce(convert(varchar(20),@form_group),'null')
+ ', contents = ' + coalesce('''' + replace(@contents, '''', '''''') + '''','null')
+ ', percentage = ' + coalesce(convert(varchar(20),@percentage),'null')
+ ', DEA_schedule = ' + coalesce('''' + replace(@DEA_schedule, '''', '''''') + '''','null')
+ ', dea_form_222_number = ' + coalesce('''' + replace(@dea_form_222_number, '''', '''''') + '''','null')
+ ', dosage_type_id = ' + coalesce(convert(varchar(20),@dosage_type_id),'null')
+ ', parent_sub_sequence_id = ' + coalesce(convert(varchar(20),@parent_sub_sequence_id),'null')
+ ', const_id = ' + coalesce(convert(varchar(20),@const_id),'null')
+ ', const_percent = ' + coalesce(convert(varchar(20),@const_percent),'null')
+ ', const_uhc = ' + coalesce('''' + replace(@const_uhc, '''', '''''') + '''','null')
+ ' where workorder_id = ' + convert(varchar(20),@workorder_id)
+ ' and company_id = ' + convert(varchar(20),@company_id)
+ ' and profit_ctr_id = ' + convert(varchar(20),@profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(20),@sequence_id)
+ ' and sub_sequence_id = ' + convert(varchar(20),@sub_sequence_id)
+ ' else insert WorkOrderDetailItem ('
+ 'workorder_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', sequence_id'
+ ', sub_sequence_id'
+ ', item_type_ind'
+ ', month'
+ ', year'
+ ', pounds'
+ ', ounces'
+ ', merchandise_id'
+ ', merchandise_quantity'
+ ', merchandise_code_type'
+ ', merchandise_code'
+ ', manual_entry_desc'
+ ', note'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', form_group'
+ ', contents'
+ ', percentage'
+ ', DEA_schedule'
+ ', dea_form_222_number'
+ ', dosage_type_id'
+ ', parent_sub_sequence_id'
+ ', const_id'
+ ', const_percent'
+ ', const_uhc)'
+ ' values (' + convert(varchar(20),@workorder_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ' + convert(varchar(20),@sequence_id)
+ ', ' + convert(varchar(20),@sub_sequence_id)
+ ', ' + '''' + replace(@item_type_ind, '''', '''''') + ''''
+ ', ' + convert(varchar(20),@month)
+ ', ' + convert(varchar(20),@year)
+ ', ' + coalesce(convert(varchar(20),@pounds),'null')
+ ', ' + coalesce(convert(varchar(20),@ounces),'null')
+ ', ' + coalesce(convert(varchar(20),@merchandise_id),'null')
+ ', ' + coalesce(convert(varchar(20),@merchandise_quantity),'null')
+ ', ' + coalesce('''' + replace(@merchandise_code_type, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@merchandise_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@manual_entry_desc, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@note, '''', '''''') + '''','null')
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce(convert(varchar(20),@form_group),'null')
+ ', ' + coalesce('''' + replace(@contents, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@percentage),'null')
+ ', ' + coalesce('''' + replace(@DEA_schedule, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@dea_form_222_number, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@dosage_type_id),'null')
+ ', ' + coalesce(convert(varchar(20),@parent_sub_sequence_id),'null')
+ ', ' + coalesce(convert(varchar(20),@const_id),'null')
+ ', ' + coalesce(convert(varchar(20),@const_percent),'null')
+ ', ' + coalesce('''' + replace(@const_uhc, '''', '''''') + '''','null') + ')'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetailItem'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1