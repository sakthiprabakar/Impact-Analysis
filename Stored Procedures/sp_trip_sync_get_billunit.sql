
create procedure sp_trip_sync_get_billunit
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the BillUnit table

 loads to Plt_ai
 
 03/17/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 08/22/2012 - rb While deploying LabPack, just added 'set transaction isolation level' for performance

****************************************************************************************/

declare @last_download_date datetime

set transaction isolation level read uncommitted

select @last_download_date = last_download_date
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select 'delete from BillUnit where bill_unit_code = ''' + BillUnit.bill_unit_code + ''''
+ ' insert into BillUnit values('
+ '''' + replace(BillUnit.bill_unit_code, '''', '''''') + '''' + ','
+ isnull('''' + replace(BillUnit.bill_unit_desc, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.disposal_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.tran_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.service_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.project_flag, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),BillUnit.gal_conv),'null') + ','
+ isnull(convert(varchar(20),BillUnit.yard_conv),'null') + ','
+ isnull(convert(varchar(20),BillUnit.kg_conv),'null') + ','
+ isnull(convert(varchar(20),BillUnit.pound_conv),'null') + ','
+ isnull('''' + replace(BillUnit.gm_bill_unit_code, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),BillUnit.date_added,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),BillUnit.date_modified,120) + '''','null') + ','
+ isnull('''' + replace(BillUnit.modified_by, '''', '''''') + '''','null') + ','
+ isnull(convert(varchar(20),BillUnit.sched_conv_bulk),'null') + ','
+ isnull('''' + replace(BillUnit.container_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.MDEQ_uom, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(BillUnit.manifest_unit, '''', '''''') + '''','null') + ','
+ '''' + replace(BillUnit.rowguid, '''', '''''') + '''' + ')' as sql
from BillUnit
where date_modified > isnull(@last_download_date,'01/01/1900')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_billunit] TO [EQAI]
    AS [dbo];

