
create procedure sp_trip_sync_get_scandocumenttype
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the ScanDocumentType table

 loads to Plt_ai
 
 07/23/2014 - rb created

****************************************************************************************/

declare	@s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set transaction isolation level read uncommitted

select @s_version = tcca.client_app_version
from TripConnectLog tcl, TripConnectClientApp tcca
where tcl.trip_connect_log_id = @trip_connect_log_id
and tcl.trip_client_app_id = tcca.trip_client_app_id

select @dot = CHARINDEX('.',@s_version)
if @dot < 1
	select @version = CONVERT(int,@s_version)
else
	select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)

select 'if exists (select 1 from ScanDocumentType'
+ ' where type_id = ' + isnull(convert(varchar(20),sdt.type_id),'null') + ')'
 + ' update ScanDocumentType'
+ ' set scan_type = ' + isnull('''' + replace(sdt.scan_type, '''', '''''') + '''','null')
+ ', document_type = ' + isnull('''' + replace(sdt.document_type, '''', '''''') + '''','null')
+ ', document_name_label = ' + isnull('''' + replace(sdt.document_name_label, '''', '''''') + '''','null')
+ ', status = ' + isnull('''' + replace(sdt.status, '''', '''''') + '''','null')
+ ', type_code = ' + isnull('''' + replace(sdt.type_code, '''', '''''') + '''','null')
+ ', customer_billing_flag = ' + isnull('''' + replace(sdt.customer_billing_flag, '''', '''''') + '''','null')
+ ', view_on_web = ' + isnull('''' + replace(sdt.view_on_web, '''', '''''') + '''','null')
+ ', available_on_mim = ' + isnull('''' + replace(sdt.available_on_mim, '''', '''''') + '''','null')
+ ' where type_id = ' + isnull(convert(varchar(20),sdt.type_id),'null')
+ ' else insert ScanDocumentType ('
+ 'type_id'
+ ', scan_type'
+ ', document_type'
+ ', document_name_label'
+ ', status'
+ ', type_code'
+ ', customer_billing_flag'
+ ', view_on_web'
+ ', available_on_mim)'
+ ' values (' + isnull(convert(varchar(20),sdt.type_id),'null')
+ ', ' + isnull('''' + replace(sdt.scan_type, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.document_type, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.document_name_label, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.status, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.type_code, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.customer_billing_flag, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.view_on_web, '''', '''''') + '''','null')
+ ', ' + isnull('''' + replace(sdt.available_on_mim, '''', '''''') + '''','null') + ')' as sql
from Plt_image..ScanDocumentType sdt
where isnull(sdt.status,'I') = 'A'
and isnull(sdt.available_on_mim,'F') = 'T'
and @version > 4.09

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_scandocumenttype] TO [EQAI]
    AS [dbo];

