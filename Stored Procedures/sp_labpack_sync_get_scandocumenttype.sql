CREATE procedure [dbo].[sp_labpack_sync_get_scandocumenttype]
  -- @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the ScanDocumentType details

 loads to Plt_ai
 
 11/04/2019 - rb created

****************************************************************************************/

set transaction isolation level read uncommitted

select scan_type,
		document_type,
		document_name_label,
		type_code
from Plt_image..ScanDocumentType
where isnull(status,'I') = 'A'
and isnull(available_on_mim,'F') = 'T'
