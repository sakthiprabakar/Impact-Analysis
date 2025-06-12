
create procedure sp_trip_sync_get_ldrwastemanaged
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the LDRWasteManaged table

 loads to Plt_ai
 
 10/29/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 12/14/2012 - rb have MIM delete any older data before inserting
****************************************************************************************/

select 'truncate table LDRWasteManaged' as sql
union
select 'insert into LDRWasteManaged values('
+ convert(varchar(20),LDRWasteManaged.waste_managed_id) + ','
+ convert(varchar(20),LDRWasteManaged.version) + ','
+ convert(varchar(20),LDRWasteManaged.visible_flag) + ','
+ isnull('''' + replace(LDRWasteManaged.waste_managed_flag, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LDRWasteManaged.contains_listed, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LDRWasteManaged.exhibits_characteristic, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LDRWasteManaged.soil_treatment_standards, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),LDRWasteManaged.underlined_text), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(convert(varchar(4096),LDRWasteManaged.regular_text), '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LDRWasteManaged.created_by, '''', '''''') + '''','null') + ','
+ isnull('''' + replace(LDRWasteManaged.modified_by, '''', '''''') + '''','null') + ','
+ isnull('''' + convert(varchar(20),LDRWasteManaged.date_created,120) + '''','null') + ','
+ isnull('''' + convert(varchar(20),LDRWasteManaged.date_modified,120) + '''','null') + ','
+ isnull(convert(varchar(20),LDRWasteManaged.sort_order),'null') + ')' as sql
 from LDRWasteManaged

order by sql desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_ldrwastemanaged] TO [EQAI]
    AS [dbo];

