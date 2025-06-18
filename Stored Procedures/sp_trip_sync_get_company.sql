ALTER PROCEDURE dbo.sp_trip_sync_get_company
      @trip_connect_log_id INTEGER
as
/***************************************************************************************
 this procedure synchronizes the Company table on a trip local database

 loads to Plt_ai
 
 03/04/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 01/22/2025 - MPM - Rally US139807 - Since we're removing the rowguid column from the Plt_ai 
					version of the Company table, and because the MIM version of this table 
					will still have this column (which is nullable), modified this stored
					procedure to insert a NULL value in that MIM table column.
02/11/2025 - MPM - Rally US139807 - Per Blair, corrected a table alias issue; added GO 
 					statement at end.
****************************************************************************************/
BEGIN

select 'DELETE FROM Company WHERE company_id = ' + CONVERT(VARCHAR(20), c.company_id)
     + ' INSERT INTO Company VALUES ('
     + CONVERT(VARCHAR(20),c.company_id)
     + ',' + '''' + REPLACE(c.company_name, '''', '''''') + ''''
     + ',' + ISNULL('''' + REPLACE(c.dunn_and_bradstreet_id, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.remit_to, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.address_1, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.address_2, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.address_3, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.phone, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.fax, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.EPA_ID, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + convert(VARCHAR(20),c.date_added,120) + '''','NULL')
     + ',' + ISNULL('''' + convert(VARCHAR(20),c.date_modified,120) + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(LEFT(c.modified_by,8), '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),c.insurance_surcharge_percent),'NULL')
     + ',' + ISNULL('''' + REPLACE(c.phone_customer_service, '''', '''''') + '''','NULL')
     + ',' + ISNULL(CONVERT(VARCHAR(20),c.next_project_id),'NULL')
     + ',' + ISNULL('''' + REPLACE(c.payroll_company_id, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.view_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.view_invoicing_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.view_aging_on_web, '''', '''''') + '''','NULL')
     + ',' + ISNULL('''' + REPLACE(c.view_survey_on_web, '''', '''''') + '''','NULL')
     --+ ',' + '''' + REPLACE(c.rowguid, '''', '''''') + ''''
	 + ', NULL'
	 + ')' as [sql]
  FROM Company c
       JOIN WorkOrderHeader h on c.company_id = h.company_id
	   JOIN TripConnectLog tcl on h.trip_id = tcl.trip_id
 where tcl.trip_connect_log_id = @trip_connect_log_id
   and ISNULL(h.field_requested_action,'') <> 'D'
   and (c.date_modified > ISNULL(tcl.last_download_date,'01/01/1900')
        or h.date_added > ISNULL(tcl.last_download_date,'01/01/1900'))

END;
GO