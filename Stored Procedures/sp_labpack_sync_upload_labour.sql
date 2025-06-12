create procedure sp_labpack_sync_upload_labour
	@trip_sync_upload_id		int,
	@workorder_id				int,
	@company_id					int,
	@profit_ctr_id				int,
	@resource_class_code		varchar(10),
	@chemist_name				varchar(10),
	@quantity			float
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload labour

 loads to Plt_ai
 
 05/05/2019 - rwb created

 exec sp_labpack_sync_upload_labour 466938, 25287900, 14, 6, 'CHEMLABPCK', 'STEVELEE'
 
****************************************************************************************/

declare @sequence_id		int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

if @resource_class_code is null
begin
	set @msg = 'sp_labpack_sync_upload_labour: Resource class passed as null'
	goto ON_ERROR
end

if @chemist_name is null
begin
	set @msg = 'sp_labpack_sync_upload_labour: Chemist name passed as null'
	goto ON_ERROR
end

if not exists (select 1 from ResourceClass where company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_class_code = @resource_class_code and status = 'A')
begin
	set @msg = 'sp_labpack_sync_upload_labour: Resource class ' + @resource_class_code + ' is not active for ' + right('0' + convert(varchar(10),@company_id),2) + '-' + right('0' + convert(varchar(10),@profit_ctr_id),2)
	goto ON_ERROR
end

if not exists (select 1 from ResourceClassDetail where company_id = @company_id and profit_ctr_id = @profit_ctr_id and resource_class_code = @resource_class_code and status = 'A')
begin
	set @msg = 'sp_labpack_sync_upload_labour: Resource class detail ' + @resource_class_code + ' is not active for ' + right('0' + convert(varchar(10),@company_id),2) + '-' + right('0' + convert(varchar(10),@profit_ctr_id),2)
	goto ON_ERROR
end

set transaction isolation level read uncommitted

set @user = 'LP'

select @sql = 'insert WorkOrderDetail ('
+ 'workorder_ID'
+ ', company_id'
+ ', profit_ctr_ID'
+ ', resource_type'
+ ', sequence_ID'

+ ', resource_class_code'
+ ', resource_assigned'
+ ', bill_unit_code'
+ ', price'
+ ', cost'
+ ', quantity'
+ ', quantity_used'

+ ', bill_rate'
+ ', description'

+ ', price_class'
+ ', price_source'
+ ', cost_class'
+ ', cost_source'
+ ', priced_flag'
+ ', group_instance_id'
+ ', group_code'

+ ', billing_sequence_id'

+ ', extended_price'
+ ', extended_cost'
+ ', print_on_invoice_flag'

+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', currency_code)'

+ ' values (' + convert(varchar(20),@workorder_ID)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_ID)
+ ', ''L'''
+ ', coalesce((select min(sequence_id)-1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id < 0 and resource_type = ''L''),(select coalesce((max(sequence_id)+1) * -1,-1) from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id > 0 and resource_type = ''L''))'

+ ', ''' + rc.resource_class_code + ''''
+ ', ''' + @chemist_name + ''''
+ ', ''' + rcd.bill_unit_code + ''''
+ ', 0'					----------------------------------------------------?
+ ', ' + convert(varchar(20),rcd.cost)
+ ', ' + coalesce(convert(varchar(20),@quantity),'1')
+ ', ' + coalesce(convert(varchar(20),@quantity),'1')

+ ', ' + coalesce(convert(varchar(20),rcd.bill_rate),'null')
+ ', ' + coalesce('''' + replace(rc.description, '''', '''''') + '''','null')

+ ', ''' + rc.resource_class_code + ''''
+ ', ''Base Rate'''		----------------------------------------------------?
+ ', ''' + rc.resource_class_code + ''''
+ ', null'
+ ', 0'
+ ', 0'
+ ', '''''

+ ', coalesce((select min(sequence_id)-1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id < 0 and resource_type = ''L''),(select coalesce((max(sequence_id)+1) * -1,-1) from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id > 0 and resource_type = ''L''))'

+ ', 0'					----------------------------------------------------?
+ ', ' + convert(varchar(20),rcd.cost)
+ ', ''T'''

+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''USD'')'

from ResourceClass rc
join ResourceClassDetail rcd
	on rcd.company_id = rc.company_id
	and rcd.profit_ctr_id = rc.profit_ctr_id
	and rcd.resource_class_code = rc.resource_class_code
	and rcd.status = 'A'
where rc.company_id = @company_id
and rc.profit_ctr_id = @profit_ctr_id
and rc.resource_class_code = @resource_class_code
and rc.status = 'A'

select @sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, @sql, 2, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetail (Labour)'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1