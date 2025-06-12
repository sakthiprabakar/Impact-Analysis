
create procedure sp_trip_sync_get_ldrsubcategory
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the LDRSubcategory table

 loads to Plt_ai
 
 10/29/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 10/10/2012 - rb incorporate Profile Forms changes
****************************************************************************************/

declare @s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set transaction isolation level read uncommitted

set nocount on

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

set nocount off

select 'delete from LDRSubcategory' as sql
union
select 'insert into LDRSubcategory values('
+ convert(varchar(20),subcategory_id) + ','
+ isnull('''' + replace(case when @version < 3.02 then left(short_desc,80) else short_desc end, '''', '''''') + '''','null') + ')' as sql
from LDRSubcategory
order by sql


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_ldrsubcategory] TO [EQAI]
    AS [dbo];

