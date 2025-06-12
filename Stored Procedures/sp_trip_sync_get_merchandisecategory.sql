
create procedure sp_trip_sync_get_merchandisecategory
	@trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the MerchandiseCategory table on a trip local database

 loads to Plt_ai
 
 04/01/2010 - rb created
 05/06/2010 - rb compare modified_date to new TripConnectLog last_merchandise_download_date column
 08/18/2011 - rb Serial number, incremental merchandise download
 10/21/2011 - rb Remove requirement that upload_merchandise_ind be set in order to download DEA
 02/29/2012 - rb with new category_id link in TripMerchandiseDownloadLog, this should use regular DL date
****************************************************************************************/


select 'delete MerchandiseCategory where category_id = ' + convert(varchar(10),MerchandiseCategory.category_id)
+ ' insert into MerchandiseCategory values('
+ convert(varchar(20),MerchandiseCategory.category_id) + ','
+ '''' + replace(MerchandiseCategory.category_desc, '''', '''''') + '''' + ','
+ '''' + replace(MerchandiseCategory.category_status, '''', '''''') + '''' + ','
+ isnull(convert(varchar(20),MerchandiseCategory.default_disposition_id),'null') + ')' as sql
from MerchandiseCategory, TripConnectLog
where TripConnectLog.trip_connect_log_id = @trip_connect_log_id
and MerchandiseCategory.date_modified > isnull(TripConnectLog.last_download_date,'01/01/1900')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_merchandisecategory] TO [EQAI]
    AS [dbo];

