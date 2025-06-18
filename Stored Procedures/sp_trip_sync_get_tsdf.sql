ALTER PROCEDURE dbo.sp_trip_sync_get_tsdf
      @trip_connect_log_id INTEGER
AS
/***************************************************************************************
 this procedure synchronizes the TSDF table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 04/01/2010 - rb new column, DEA_ID
 04/30/2010 - rb need to pull TSDF information when approval added to trip already downloaded
 05/13/2011 - rb new column, DEA_phone
 08/15/2012 - rb Version 3.0 LabPack .. pull entire table for LabPack trip
 06/13/2018 - rb GEM:51542 add support to sync TSDF_codes renamed in EQAI
 09/11/2018 - rb Correction made for GEM:51542 to correct duplicate TSDFs after downloading a trip, before first sync
 01/20/2025 - BC adjustments for Titan
 01/23/2025 - MPM - Rally US139807 - Since we're removing the rowguid column from the Plt_ai 
					version of the TSDF table, and because the MIM version of this table 
					will still have this column (which is nullable), modified this stored
					procedure to insert a NULL value in that MIM table column.
 02/11/2025 - MPM - Rally US139807 - Per Blair, added GO statement at end.
 ****************************************************************************************/
BEGIN

declare @s_version VARCHAR(10)
      ,	@dot INTEGER
	  ,	@version NUMERIC(6,2)
	  ,	@lab_pack_flag CHAR(1)
	  ,	@last_download_date DATETIME

set transaction isolation level read uncommitted;

SELECT @s_version = tcca.client_app_version
  FROM TripConnectLog tcl
       JOIN TripConnectClientApp tcca on tcl.trip_client_app_id = tcca.trip_client_app_id
 WHERE tcl.trip_connect_log_id = @trip_connect_log_id
;

SELECT @dot = CHARINDEX('.',@s_version)

IF @dot < 1
	SELECT @version = CONVERT(INTEGER,@s_version)
ELSE
	SELECT @version = CONVERT(NUMERIC(6,2),SUBSTRING(@s_version,1,@dot-1)) +
						(CONVERT(NUMERIC(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)

SELECT @lab_pack_flag = ISNULL(th.lab_pack_flag,'F')
  FROM TripHeader th
       JOIN TripConnectLog tcl on tcl.trip_id = th.trip_id
 WHERE tcl.trip_connect_log_id = @trip_connect_log_id

SELECT @last_download_date = last_download_date
  FROM TripConnectLog
 WHERE trip_connect_log_id = @trip_connect_log_id


-- for labpack, pull entire table
IF @lab_pack_flag = 'T'
	AND (@last_download_date IS NULL OR EXISTS (
	     SELECT 1
		   FROM TripConnectLog tcl
				JOIN WorkOrderHeader wh on tcl.trip_id = wh.trip_id
					 AND wh.field_requested_action = 'R'
		  WHERE tcl.trip_connect_log_id = @trip_connect_log_id))
	BEGIN
		SELECT 'truncate table TSDF' as [sql]
		 UNION
		SELECT 'insert into TSDF values('
		     + '''' + REPLACE(TSDF.TSDF_code, '''', '''''') + ''''
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_status, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_name, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr1, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr2, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr3, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_EPA_ID, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_phone, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_fax, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_contact, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_contact_phone, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_city, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_state, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_zip_code, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.state_regulatory_id, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.facility_type, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.emergency_contact_phone, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.eq_flag, '''', '''''') + '''','null')
		     + ',' + ISNULL(CONVERT(VARCHAR(20),TSDF.eq_company),'null')
		     + ',' + ISNULL(CONVERT(VARCHAR(20),TSDF.eq_profit_ctr),'null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.directions, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.comments, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(LEFT(TSDF.added_by,10), '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),TSDF.date_added,120) + '''','null')
		     + ',' + ISNULL('''' + REPLACE(LEFT(TSDF.modified_by,10), '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),TSDF.date_modified,120) + '''','null')
		     --+ ',' + '''' + REPLACE(TSDF.rowguid, '''', '''''') + ''''
			 + ', NULL'
		     + ',' + ISNULL('''' + REPLACE(TSDF.DEA_ID, '''', '''''') + '''','null')
		     + ',' + ISNULL('''' + REPLACE(TSDF.DEA_phone, '''', '''''') + '''','null')
			 + ')' as [sql]
		  FROM TSDF
		 ORDER BY [sql] DESC													
	END
ELSE
	BEGIN

	SELECT DISTINCT 'delete from TSDF where TSDF_code = ''' + wd.tsdf_code + '''' as [sql]
	  FROM WorkOrderDetail wd
	       JOIN WorkOrderHeader wh on wh.workorder_id = wd.workorder_id
		        AND wh.company_id = wd.company_id
		        AND wh.profit_ctr_id = wd.profit_ctr_id
	       JOIN TripConnectLog tcl on tcl.trip_id = wh.trip_id
		        AND tcl.trip_connect_log_id = @trip_connect_log_id
	 WHERE wd.resource_type = 'D'
	   AND wd.tsdf_code <> ''
	 UNION
	SELECT DISTINCT 'insert into TSDF values('
	     + '''' + REPLACE(TSDF.TSDF_code, '''', '''''') + ''''
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_status, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_name, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr1, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr2, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_addr3, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_EPA_ID, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_phone, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_fax, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_contact, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_contact_phone, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_city, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_state, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.TSDF_zip_code, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.state_regulatory_id, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.facility_type, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.emergency_contact_phone, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.eq_flag, '''', '''''') + '''','null')
	     + ',' + ISNULL(CONVERT(VARCHAR(20),TSDF.eq_company),'null')
	     + ',' + ISNULL(CONVERT(VARCHAR(20),TSDF.eq_profit_ctr),'null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.directions, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(TSDF.comments, '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + REPLACE(LEFT(TSDF.added_by,10), '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),TSDF.date_added,120) + '''','null')
	     + ',' + ISNULL('''' + REPLACE(LEFT(TSDF.modified_by,10), '''', '''''') + '''','null')
	     + ',' + ISNULL('''' + CONVERT(VARCHAR(20),TSDF.date_modified,120) + '''','null')
	     --+ ',' + '''' + REPLACE(TSDF.rowguid, '''', '''''') + ''''
		 + ', NULL'
	     + CASE WHEN @version < 2.02 THEN '' ELSE ',' + ISNULL('''' + REPLACE(TSDF.DEA_ID, '''', '''''') + '''','null') END
	     + CASE WHEN @version < 2.16 THEN '' ELSE ',' + ISNULL('''' + REPLACE(TSDF.DEA_phone, '''', '''''') + '''','null') END
	     + ')' as [sql]
	  FROM TSDF
	       JOIN WorkOrderDetail d on TSDF.TSDF_code = d.TSDF_code
	       JOIN WorkOrderHeader h on d.workorder_id = h.workorder_id
	            AND d.company_id = h.company_id
	            AND d.profit_ctr_id = h.profit_ctr_id
	       JOIN TripConnectLog tcl on h.trip_id = tcl.trip_id
	 WHERE d.resource_type = 'D'
	   AND tcl.trip_connect_log_id = @trip_connect_log_id
	 ORDER BY [sql] ASC;
	END;

END;
GO