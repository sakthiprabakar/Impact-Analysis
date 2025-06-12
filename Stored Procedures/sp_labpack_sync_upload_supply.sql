if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_upload_supply')
	drop procedure sp_labpack_sync_upload_supply
go

create procedure [dbo].[sp_labpack_sync_upload_supply]
	@trip_sync_upload_id		int,
	@workorder_id				int,
	@company_id					int,
	@profit_ctr_id				int,
	@resource_class_code		varchar(10),
	@supply_desc				varchar(10),
	@quantity					float,
	@quantity_billable			float
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload supply

 loads to Plt_ai
 
 05/11/2019 - rwb created
 08/04/2022 - rwb ADO - added @quantity_billable argument

 exec sp_labpack_sync_upload_supply 569558, 28359300, 14, 6, 'AIRCOMP', 'Air comp', 200, 150

****************************************************************************************/

declare @sequence_id		int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set transaction isolation level read uncommitted

if not exists (select 1 from ResourceClass rc
				where rc.company_id = @company_id
				and rc.profit_ctr_id = @profit_ctr_id
				and rc.resource_class_code = @resource_class_code
				and rc.status = 'A')
begin
	set @msg = 'ERROR: ' + @resource_class_code + ' does not exist in ResourceClass table for ' + right('0' + convert(varchar(20),@company_id),2) + '-' + right('0' + convert(varchar(20),@profit_ctr_id),2)
	goto ON_ERROR
end

if not exists (select 1 from ResourceClassDetail rc
				where rc.company_id = @company_id
				and rc.profit_ctr_id = @profit_ctr_id
				and rc.resource_class_code = @resource_class_code
				and rc.status = 'A')
begin
	set @msg = 'ERROR: ' + @resource_class_code + ' does not exist in ResourceClassDetail table for ' + right('0' + convert(varchar(20),@company_id),2) + '-' + right('0' + convert(varchar(20),@profit_ctr_id),2)
	goto ON_ERROR
end


set @user = 'LP'
set @sql = ''

if coalesce(@quantity_billable,0) > 0
begin
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
	+ ', ''S'''
	+ ', coalesce((select max(sequence_id)+1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id >= 0 and resource_type = ''S''),1)'

	+ ', ''' + rc.resource_class_code + ''''
	+ ', ''' + @supply_desc + ''''
	+ ', ''' + rcd.bill_unit_code + ''''
	+ ', 0'					----------------------------------------------------?
	+ ', ' + convert(varchar(20),rcd.cost)
	+ ', ' + coalesce(convert(varchar(20),@quantity_billable),'1')
	+ ', ' + coalesce(convert(varchar(20),@quantity_billable),'1')

	+ ', 1'
	+ ', ' + coalesce('''' + replace(rc.description, '''', '''''') + '''','null')

	+ ', ''' + rc.resource_class_code + ''''
	+ ', ''Base Rate'''		----------------------------------------------------?
	+ ', ''' + rc.resource_class_code + ''''
	+ ', null'
	+ ', 0'
	+ ', 0'
	+ ', '''''

	+ ', coalesce((select max(sequence_id)+1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id >= 0 and resource_type = ''S''),1)'

	+ ', 0'
	+ ', ' + convert(varchar(20),rcd.cost * coalesce(@quantity,1))
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
end

if coalesce(@quantity_billable,0) < coalesce(@quantity,0)
begin
	select @sql = @sql + ' insert WorkOrderDetail ('
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
	+ ', ''S'''
	+ ', coalesce((select max(sequence_id)+1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id >= 0 and resource_type = ''S''),1)'

	+ ', ''' + rc.resource_class_code + ''''
	+ ', ''' + @supply_desc + ''''
	+ ', ''' + rcd.bill_unit_code + ''''
	+ ', 0'					----------------------------------------------------?
	+ ', ' + convert(varchar(20),rcd.cost)
	+ ', ' + coalesce(convert(varchar(20),coalesce(@quantity,0) - coalesce(@quantity_billable,0)),'1')
	+ ', ' + coalesce(convert(varchar(20),coalesce(@quantity,0) - coalesce(@quantity_billable,0)),'1')

	+ ', 0'
	+ ', ' + coalesce('''' + replace(rc.description, '''', '''''') + '''','null')

	+ ', ''' + rc.resource_class_code + ''''
	+ ', ''Base Rate'''		----------------------------------------------------?
	+ ', ''' + rc.resource_class_code + ''''
	+ ', null'
	+ ', 0'
	+ ', 0'
	+ ', '''''

	+ ', coalesce((select max(sequence_id)+1 from WorkOrderDetail where workorder_id=' + convert(varchar(20),@workorder_id) + ' and company_id=' + convert(varchar(2),@company_id) + ' and profit_ctr_id=' + convert(varchar(2),@profit_ctr_id) + ' and sequence_id >= 0 and resource_type = ''S''),1)'

	+ ', 0'
	+ ', ' + convert(varchar(20),rcd.cost * coalesce(@quantity,1))
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
end

select @sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, @sql, 2, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for WorkOrderDetail (Supply)'
	goto ON_ERROR
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
GO

grant execute on sp_labpack_sync_upload_supply to eqai
go
