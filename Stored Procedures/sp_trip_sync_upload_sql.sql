
create procedure sp_trip_sync_upload_sql
	@trip_connect_log_id int,
	@trip_sync_upload_id int,
	@sql_count int,
	@check_rowcount_flag char(1),
	@sql varchar(6000)
as
/***************************************************************************************
 this procedure saves a batch of sql sent from the client

 loads to Plt_ai
 
 03/05/2010 - rb created
 05/04/2010 - rb extra check to see if a stop has already been uploaded and processed
 01/12/2012 - rb For GL Standardization / Profit Center renumbering, don't allow
              uploads from versions earlier than 2.28
 08/14/2012 - rb Temporarily trim update_user to 8 characters bc Profile tables are varchar(8)
****************************************************************************************/

declare @sequence_id int,
	@err int,
	@update_user varchar(10),
	@update_dt datetime,
	@msg varchar(255),
	@trip_id int,
	@trip_sequence_id int,
	@sql_return varchar(255),
	@s_version varchar(10),
	@dot int,
	@version numeric(6,2)

set nocount on

-- rb 01/12/2012 For company / profit center renumbering, uploading SQL is not allowed
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

if @version < 2.28
	goto RETURN_RESULTS



-- rb 05/04/2010
-- see if the stop has been processed, and if so just pass back statement to update that is already was
select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

select @trip_sequence_id = trip_sequence_id
from TripSyncUpload
where trip_sync_upload_id = @trip_sync_upload_id

if exists (select 1 from TripConnectLog tcl, TripSyncUpload tsu
	where tcl.trip_id = @trip_id
	and tcl.trip_connect_log_id = tsu.trip_connect_log_id
	and tsu.trip_sequence_id = @trip_sequence_id
	and tsu.processed_flag = 'T')
begin
	select @sql_return = 'update TripFieldUpload set uploaded_flag=''T'', last_upload_date=getdate() where trip_id=' +
				convert(varchar(20),@trip_id) + ' and trip_sequence_id=' +
				convert(varchar(20),@trip_sequence_id)
	goto RETURN_RESULTS
end
-- rb 05/03/2010 end

-- initialize updated_by variables
select @update_user = 'TCID' + convert(varchar(6),@trip_connect_log_id),
	@update_dt = convert(datetime,convert(varchar(20),getdate(),120))

-- get next sequence id
select @sequence_id = isnull(max(sequence_id),0)+1
from TripSyncUploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

-- insert batch
-- rb 08/14/2012 TEMPORARILY trim @update_user to 8 characters (Profile table is varchar(8))
if charindex('insert Profile',@sql) > 0 or charindex ('insert TSDFApproval',@sql) > 0
	select @update_user = left(@update_user,8)

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag,
				added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sequence_id, replace(@sql,'''FIELDAPP''','''' + @update_user + ''''),
	@sql_count, @check_rowcount_flag, @update_user, @update_dt, @update_user, @update_dt)

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(20),@err) + ' in sp_trip_sync_upload_sql, insert into TripSyncUploadSQL'
	goto ON_ERROR
end


--SUCCESS
goto RETURN_RESULTS


-- FAILURE
ON_ERROR:
-- log error
exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt


-- RETURN
RETURN_RESULTS:
set nocount off
select isnull(@sql_return,'') as sql
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_upload_sql] TO [EQAI]
    AS [dbo];

