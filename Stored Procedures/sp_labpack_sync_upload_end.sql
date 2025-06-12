create procedure [dbo].[sp_labpack_sync_upload_end]
	@trip_sync_upload_id		int
as
/***************************************************************************************
 this procedure completes the upload from a lab pack field device

 loads to Plt_ai
 
 12/17/2019 - rwb created
 11/11/2021 - rwb if LPx uploaded a manifest unit different from the one downloaded, update the old unit's manifest_flag
 01/04/2022 - rwb for the LPx uploaded manifest unit different from the one downloaded, removed check on quantity in the update

****************************************************************************************/

declare @trip_connect_log_id int,
		@sql varchar(4096)

set nocount on

select @trip_connect_log_id = trip_connect_log_id
from TripSyncUpload
where trip_sync_upload_id = @trip_sync_upload_id

update TripSyncUpload
set sql_statement_count = (select sum(sql_statement_count) from TripSyncUploadSQL where trip_sync_upload_id = @trip_sync_upload_id)
where trip_sync_upload_id = @trip_sync_upload_id

create table #t (sql varchar(4096) null)

insert #t
exec sp_trip_sync_upload_execute @trip_connect_log_id, @trip_sync_upload_id

set rowcount 1
select @sql = coalesce(sql,'') from #t
set rowcount 0

set nocount off

if charindex('update TripFieldUpload set uploaded_flag=''T''',@sql) > 0
begin
	update TripConnectLog
	set last_upload_date = getdate()
	where trip_connect_log_id = @trip_connect_log_id

	update WorkOrderHeader
	set field_upload_date = getdate()
	from WorkOrderHeader wh
	join TripConnectLog tcl
		on tcl.trip_id = wh.trip_id
	join TripSyncUpload tsu
		on tsu.trip_connect_log_id = tcl.trip_connect_log_id
		and tsu.trip_sequence_id = wh.trip_sequence_id
		and tsu.trip_sync_upload_id = @trip_sync_upload_id

	update WorkOrderDetail
	set bill_rate = -2
	from WorkOrderDetail wd
	join WorkOrderHeader wh
		on wh.workorder_id = wd.workorder_id
		and wh.company_id = wd.company_id
		and wh.profit_ctr_id = wd.profit_ctr_id
	join TripConnectLog tcl
		on tcl.trip_id = wh.trip_id
	join TripSyncUpload tsu
		on tsu.trip_connect_log_id = tcl.trip_connect_log_id
		and tsu.trip_sequence_id = wh.trip_sequence_id
		and tsu.trip_sync_upload_id = @trip_sync_upload_id
	where wd.manifest like 'MANIFEST%'

	update WorkOrderDetailUnit
	set manifest_flag = 'F', modified_by = 'LP', date_modified = getdate()
	from WorkOrderDetailUnit wdu
	join WorkOrderHeader wh
		on wh.workorder_id = wdu.workorder_id
		and wh.company_id = wdu.company_id
		and wh.profit_ctr_id = wdu.profit_ctr_id
	join TripConnectLog tcl
		on tcl.trip_id = wh.trip_id
	join TripSyncUpload tsu
		on tsu.trip_connect_log_id = tcl.trip_connect_log_id
		and tsu.trip_sequence_id = wh.trip_sequence_id
		and tsu.trip_sync_upload_id = @trip_sync_upload_id
	where wdu.manifest_flag = 'T'
	and wdu.added_by <> 'LP'
	and exists (select 1 from WorkOrderDetailUnit
				where workorder_id = wdu.workorder_id
				and company_id = wdu.company_id
				and profit_ctr_id = wdu.profit_ctr_id
				and sequence_id = wdu.sequence_id
				and manifest_flag = 'T'
				and quantity > 0
				and added_by = 'LP')
	return 0
end
else
begin
	raiserror(@sql,18,-1) with seterror
	return -1
end