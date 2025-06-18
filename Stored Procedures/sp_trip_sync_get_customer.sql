
drop procedure if exists sp_trip_sync_get_customer
go

create procedure sp_trip_sync_get_customer
   @trip_connect_log_id INTEGER
AS
/***************************************************************************************
 this procedure synchronizes the Customer table on a trip local database

 loads to Plt_ai
 
 02/09/2009 - rb created
 12/31/2009 - rb modified where clause to compare last_modifed_date to last_download_date
                 static table, so delete then insert
 06/21/2011 - rb add EQ approved offerer columns
 08/15/2012 - rb discovered that forced refresh was not being checked
 04/20/2015 - rb modifications to support Kroger Invoicing requirements (pull GeneratorSubLocation table)
 09/04/2015 - rb added consolidate_container_flag
 11/24/2015 - rb new pickup_report_flag in CustomerBilling table
 11/22/2021 - mm DevOps 19701 - Added new CustomerBilling columns for "approved offeror".
 04/09/2025 - <rb> it appears that along with a change for Helios (removal of rowguid from Customer table),
					a bug was introduced adding a comma before the first columns for all 3 INSERT statements.
					There was no comment for the change, not sure how it happened, so I am adding this one.
 04/15/2025 - rb No MIM has been able to download a trip since the prefixed comma was deployed, deploying a fix
 04/21/2025 - mm Rally TA537272 - Modified to align with changes to the GeneratorSubLocation table.

****************************************************************************************/
BEGIN

DECLARE @s_version VARCHAR(10)
      , @dot INTEGER
	  , @version NUMERIC(6,2)

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT @s_version = tcca.client_app_version
	  FROM TripConnectLog tcl
	       JOIN TripConnectClientApp tcca on tcl.trip_client_app_id = tcca.trip_client_app_id
	 WHERE tcl.trip_connect_log_id = @trip_connect_log_id;

	SET @dot = CHARINDEX('.', @s_version)
	IF @dot < 1
		BEGIN
			SET @version = CONVERT(INTEGER, @s_version)
		END
	ELSE
		BEGIN
			SET @version = CONVERT(NUMERIC(6,2), SUBSTRING(@s_version, 1, @dot-1)) +
						(CONVERT(NUMERIC(6,2), SUBSTRING(@s_version, @dot+1, DATALENGTH(@s_version))) / 100)
		END

	SELECT 'DELETE FROM Customer WHERE customer_id = ' + CONVERT(VARCHAR(20), c.customer_id)
         + ' INSERT INTO Customer '
		 + ' VALUES('
               + CONVERT(VARCHAR(20), c.customer_ID)
         + ',' + ISNULL('''' + REPLACE(c.cust_name, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.customer_type, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_addr1, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_addr2, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_addr3, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_addr4, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_addr5, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_city, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_state, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_zip_code, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_country, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_sic_code, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_phone, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_fax, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.mail_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(CONVERT(VARCHAR(4096), c.cust_directions), '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.terms_code, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(LEFT(c.added_by,10), '''', '''''') + '''', 'NULL')				--<
         + ',' + ISNULL('''' + REPLACE(LEFT(c.modified_by,10), '''', '''''') + '''', 'NULL')			--<
         + ',' + ISNULL('''' + CONVERT(VARCHAR(20), c.date_added,120) + '''', 'NULL')
         + ',' + ISNULL('''' + CONVERT(VARCHAR(20), c.date_modified,120) + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.designation, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.generator_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.web_access_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.next_WCR), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_category, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_website, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.cust_parent_ID), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_prospect_flag, '''', '''''') + '''', 'NULL')
         + ', ''''' --+ ',' + '''' + REPLACE(Customer.rowguid, '''', '''''') + ''''
         + ',' + ISNULL('''' + REPLACE(c.eq_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.eq_company), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.customer_cost_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.cust_naics_code), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.cust_status, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.eq_profit_ctr), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.SPOC_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_cust_name, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_addr1, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_addr2, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_addr3, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_addr4, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_addr5, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_city, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_state, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_zip_code, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.bill_to_country, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL(CONVERT(VARCHAR(20), c.credit_limit), 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.labpack_trained_flag, '''', '''''') + '''', 'NULL')
         + ',' + ISNULL('''' + REPLACE(c.national_account_flag, '''', '''''') + '''', 'NULL')
         + CASE WHEN @version < 2.18 THEN '' ELSE ',' + ISNULL('''' + REPLACE(c.eq_approved_offerer_flag, '''', '''''') + '''', 'NULL')
         	+ ',' + ISNULL('''' + REPLACE(c.eq_approved_offerer_desc, '''', '''''') + '''', 'NULL')
         	+ ',' + ISNULL('''' + CONVERT(VARCHAR(20), c.eq_offerer_effective_dt,120) + '''', 'NULL') END
         + CASE WHEN @version < 4.26 THEN '' ELSE ',' + ISNULL('''' + REPLACE(c.consolidate_containers_flag, '''', '''''') + '''', 'NULL') END
         + ')' as [sql]
	  FROM Customer c
	       JOIN WorkOrderHeader h on c.customer_id = h.customer_id
	       JOIN TripConnectLog tcl on h.trip_id = tcl.trip_id
	 WHERE tcl.trip_connect_log_id = @trip_connect_log_id
	   AND ISNULL(h.field_requested_action,'') <> 'D'
	   AND (c.date_modified > ISNULL(tcl.last_download_date,'01/01/1900')
            OR h.date_added > ISNULL(tcl.last_download_date,'01/01/1900')
            OR h.field_requested_action = 'R')

	UNION
	SELECT DISTINCT 'DELETE FROM GeneratorSubLocation WHERE customer_id = ' + CONVERT(VARCHAR(20), g.customer_id)
	     + ' and generator_sublocation_id = ' + CONVERT(VARCHAR(20), g.generator_sublocation_id)
         + ' INSERT INTO GeneratorSubLocation '
		 + ' VALUES ('
		 + CONVERT(VARCHAR(20),g.customer_ID)
		 + ','+ CONVERT(VARCHAR(20),g.generator_sublocation_ID)
		 + ','+ '''' + REPLACE(g.[status], '''', '''''') + ''''
		 + ','+ '''' + REPLACE(g.code, '''', '''''') + ''''
		 + ','+ '''' + REPLACE(g.[description], '''', '''''') + ''''
		 + ','+ ISNULL('''' + REPLACE(LEFT(g.added_by, 10), '''', '''''') + '''', 'NULL')
		 + ','+ ISNULL('''' + CONVERT(VARCHAR(20),g.date_added,120) + '''', 'NULL')
		 + ','+ ISNULL('''' + REPLACE(LEFT(g.modified_by, 10), '''', '''''') + '''', 'NULL')
		 + ','+ ISNULL('''' + CONVERT(VARCHAR(20), g.date_modified,120) + '''', 'NULL')
		 + ')' as [sql]
	  FROM GeneratorSubLocation g
	       JOIN WorkOrderHeader h on g.customer_id = h.customer_id
		   JOIN TripConnectLog tcl on h.trip_id = tcl.trip_id
	 WHERE tcl.trip_connect_log_id = @trip_connect_log_id
	   AND (h.field_upload_date IS NULL OR tcl.last_download_date IS NULL)
	   AND h.field_requested_action <> 'D'
	   AND @version >= 4.16

	UNION
	SELECT DISTINCT 'DELETE FROM CustomerBilling WHERE customer_id = ' + CONVERT(VARCHAR(20), h.customer_id)
	     + ' and billing_project_id = ' + CONVERT(VARCHAR(20), h.billing_project_id)
		 + ' INSERT INTO CustomerBilling VALUES('
		 + CONVERT(VARCHAR(20),h.customer_ID)
		 + ',' + CONVERT(VARCHAR(20),h.billing_project_ID)
		 + ',' + ISNULL('''' + REPLACE(b.pickup_report_flag, '''', '''''') + '''', 'NULL')
		 + CASE WHEN @version < 4.81 THEN '' 
		        ELSE ',' + ISNULL('''' + REPLACE(b.eq_offeror_bp_override_flag, '''', '''''') + '''', 'NULL')
		 	       + ',' + ISNULL('''' + REPLACE(b.eq_approved_offeror_flag, '''', '''''') + '''', 'NULL')
		 	       + ',' + ISNULL('''' + REPLACE(b.eq_approved_offeror_desc, '''', '''''') + '''', 'NULL')
		 	       + ',' + ISNULL('''' + CONVERT(VARCHAR(20),b.eq_offeror_effective_dt,120) + '''', 'NULL')
			END
		 + ')' as [sql]
	  FROM CustomerBilling b
	       JOIN WorkOrderHeader h on b.customer_id = h.customer_id
		        and b.billing_project_id = h.billing_project_id
	       JOIN TripConnectLog tcl on h.trip_id = tcl.trip_id
	 WHERE tcl.trip_connect_log_id = @trip_connect_log_id
	   AND (h.field_upload_date IS NULL OR tcl.last_download_date IS NULL)
	   AND h.workorder_status <> 'V'
	   AND h.billing_project_id IS NOT NULL
	   AND h.field_requested_action <> 'D'
	   AND @version >= 4.29;
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_customer] TO [EQAI];

