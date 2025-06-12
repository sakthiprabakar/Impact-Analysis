

CREATE PROCEDURE [dbo].[sp_customer_update] (
	@customer_id      int,
	@cust_parent_id   int,
	@cust_name        varchar (40),
	@customer_type    varchar (10),
	@cust_addr1       varchar (40),
	@cust_addr2       varchar (40),
	@cust_addr3       varchar (40),
	@cust_city        varchar (40),
	@cust_state       varchar ( 2),
	@cust_zip_code    varchar (15),
	@cust_country     varchar (40),
	@cust_phone       varchar (255),
	@cust_fax         varchar (10),
	@designation      char    ( 1),
	@cust_category    varchar (30),
	@cust_website     varchar (100),
	@cust_sic_code	  varchar (5),
	@cust_naics_code  int,
	@cust_status      char    ( 1),
	@territory_code	  char(3),
	@added_by         varchar (10)
)
AS
BEGIN
/* ======================================================
Description: Inserts or Updates a Customer Record, including CustomerXCompany and Note as needed.
Parameters : 
Requires   : PLT_AI*
Modified    Author            Notes
----------  ----------------  -----------------------
05/16/2006  Jonathan Broome   Initial Development
05/09/2007  JPB               Converted for Central Invoicing (CustomerXCompany -> CustomerBilling)
08/20/2007  JPB               Updated per recent Central Invoicing Changes.
10/03/2007  WAC               Removed references to CustomerBilling.invoice_copies
03/17/2008  JPB               Modified to use eqsp_CustomerAudit to create audits
                             This removes problems when input fields contain apostrophes
                             One catch: '' = NULL in this sp, so an update of a field from NULL to '' will not get recorded in CustomerAudit as a change.
05/19/2008  JPB               Resized columnname variable "@field" to 60 from 30.
09/09/2008  JPB               Added initialization of new ensr_flag field in CustomerBilling
11/19/2008  Chris Allen       Added category and designation to INSERT; per GID 9480. (Update & parameter list already accomodated these fields.) 
                           - Formatted  
09/17/2012 JPB					Removed sp_columns calls as they were hanging up the SP and timing out the web site.
								Replaced with hardcoded column lists. Poof it works.
                                                          
08/22/2018 AM - EQAI-52810  Customer - Increase length of phone number column? 
			Modified customer_phone to 255

06/28/2023 Dipankar - DevOps 60196 - Increased the width of the argument @cust_website & 
                                     corresponding column in table #customer_update_input from 50 to 100

 sp_customer_update 90003998, null, 'Test Company JB', null, '123 Street', 'Test', 'Test', 'WAYNE', 'MI', '48184', '', '', '', null, null, null, null, null, 'A', '01', 'jonathan';
 sp_customer_update null, null, 'Test Company JB', null, '123 Street', 'Test', 'Test', 'WAYNE', 'MI', '48184', '', '', '', null, null, null, null, null, 'A', null, 'jonathan';
 sp_customer_update 90004252, null, 'Fuss & O''Neill, Inc.', '', '317 Iron Horse Way, Suite 204', '', '', 'Providence', 'RI', '02908', '', '4018613070', '4018613076', '', '', '', '', null, 'A', '26', 'glenn_t';

====================================================== */
	SET NOCOUNT ON

	DECLARE @customer_found int,
		@field_list varchar(500),
		@field varchar(60),
		@insert1 varchar(500), 
		@insert2 varchar(100),
		@result	int,
		@change_count	int,
		@before_value varchar(255),
		@after_value varchar(255),
		@reference varchar(50),
		@customer_id_text varchar(20)

	/*
	9/17/2012 - Users reporting this was timing out. Dev proved it true. Seems related to using sp_columns on the fly. Let's just use a simpler method for this, since
		the tables involved don't change THAT often.  IF CUSTOMER OR CUSTOMERBILLING IS ALTERED, NEED TO REFRESH THE LOGIC HERE!

	-- Need a holder for sp_columns output
	CREATE TABLE #spcolumns (
		TABLE_QUALIFIER varchar(40),
		TABLE_OWNER varchar(40),
		TABLE_NAME varchar(400),
		COLUMN_NAME varchar(60),
		DATA_TYPE smallint,
		TYPE_NAME varchar(40),
		PRECIS int,
		LENGTH int,
		SCALE smallint,
		RADIX smallint,
		NULLABLE smallint,
		REMARKS varchar(254),
		COLUMN_DEF varchar(4000),
		SQL_DATA_TYPE smallint,
		SQL_DATETIME_SUB smallint,
		CHAR_OCTET_LENGTH int,
		ORDINAL_POSITION int,
		IS_NULLABLE varchar(254),
		SS_DATA_TYPE tinyint
	)
	
	*/
	create table #customer_columns (column_name	varchar(60), ordinal_position int)
	insert #customer_columns select row, idx from dbo.fn_splitXSVText(',', 1, 'customer_ID, cust_name, customer_type, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_addr5, cust_city, cust_state, cust_zip_code, cust_country, cust_sic_code, cust_phone, cust_fax, mail_flag, cust_directions, terms_code, added_by, modified_by, date_added, date_modified, designation, generator_flag, web_access_flag, next_WCR, cust_category, cust_website, cust_parent_ID, cust_prospect_flag, rowguid, eq_flag, eq_company, customer_cost_flag, cust_naics_code, cust_status, eq_profit_ctr, SPOC_flag, bill_to_cust_name, bill_to_addr1, bill_to_addr2, bill_to_addr3, bill_to_addr4, bill_to_addr5, bill_to_city, bill_to_state, bill_to_zip_code, bill_to_country, credit_limit, labpack_trained_flag, national_account_flag, eq_approved_offerer_flag, eq_approved_offerer_desc, eq_offerer_effective_dt')

	create table #customerbilling_columns (column_name	varchar(60), ordinal_position int)
	insert #customerbilling_columns select row, idx from dbo.fn_splitXSVText(',', 1, 'customer_id, billing_project_id, project_name, record_type, status, distribution_method, invoice_flag, insurance_surcharge_flag, PO_required_flag, PO_validation, COR_required_flag, COPD_required_flag, weight_ticket_required_flag, internal_review_flag, intervention_required_flag, intervention_desc, region_id, collections_id, customer_service_id, salesperson_id, NAM_id, cust_discount, mail_to_bill_to_address_flag, all_facilities_flag, submit_on_hold_flag, break_code_1, break_code_2, break_code_3, sort_code_1, sort_code_2, sort_code_3, sort_code_4, sort_code_5, added_by, date_added, modified_by, date_modified, rowguid, territory_code, reference_code, release_required_flag, release_validation, other_submit_required_flag, other_submit_required_desc, NAS_id, invoice_package_content, invoice_comment_1, invoice_comment_2, invoice_comment_3, invoice_comment_4, invoice_comment_5, billing_project_comment, mail_flag, po_release_required_flag_DONOTUSE, po_release_validation_DONOTUSE, terms_code, submit_on_hold_reason, link_required_flag, link_required_validation, retail_flag, ensr_flag')

	create table #customer_update_input_columns (column_name varchar(60), ordinal_position int)
	insert #customer_update_input_columns select row, idx from dbo.fn_splitXSVText(',', 1, 'cust_parent_id, cust_name, customer_type, cust_addr1, cust_addr2, cust_addr3, cust_city, cust_state, cust_zip_code, cust_country, cust_phone, cust_fax, designation, cust_category, cust_website, cust_sic_code, cust_naics_code, cust_status, territory_code')
		
	-- Need a handy table to store all the new inputs
	CREATE TABLE #customer_update_input (
		cust_parent_id   int,
		cust_name        varchar (40),
		customer_type    varchar (10),
		cust_addr1       varchar (40),
		cust_addr2       varchar (40),
		cust_addr3       varchar (40),
		cust_city        varchar (40),
		cust_state       varchar ( 2),
		cust_zip_code    varchar (15),
		cust_country     varchar (40),
		cust_phone       varchar (10),
		cust_fax         varchar (10),
		designation      char    ( 1),
		cust_category    varchar (30),
		cust_website     varchar (100),
		cust_sic_code	 varchar (5),
		cust_naics_code  int,
		cust_status      char(1),
		territory_code	 char(3),
	)
	
	INSERT #customer_update_input (cust_parent_id, cust_name, customer_type, cust_addr1, cust_addr2, cust_addr3, cust_city, cust_state, cust_zip_code, cust_country, cust_phone, cust_fax, designation, cust_category, cust_website, cust_sic_code, cust_naics_code, cust_status, territory_code)
	VALUES (@cust_parent_id, @cust_name, @customer_type, @cust_addr1, @cust_addr2, @cust_addr3, @cust_city, @cust_state, @cust_zip_code, @cust_country, @cust_phone, @cust_fax, @designation, @cust_category, @cust_website, @cust_sic_code, @cust_naics_code, @cust_status, @territory_code)

	-- Need a temp table to hold 1 value at a time for audit-creating.
	CREATE TABLE #pop (v varchar(255))
	
	CREATE TABLE #ufields (field varchar(60), progress int)
	CREATE TABLE #ifields (field varchar(60), progress int)
	CREATE TABLE #i2fields (field varchar(60), progress int)

	-- Test: Is this a new customer or an edit to an existing one?
	IF @customer_id IS NOT NULL AND Len(@customer_id) > 0
		SELECT @customer_found = 1 FROM customer WHERE customer_id = @customer_id
	
	IF @customer_found = 1 BEGIN  
	
		BEGIN  TRAN c_update

			SET @customer_id_text = Convert(varchar(20), @customer_id)
		
			-- Need a text list of the fields to loop over for creating audits
			INSERT INTO #ufields SELECT column_name AS field, 0 AS progress FROM #customer_columns WHERE column_name NOT IN ('date_added', 'date_modified') ORDER BY   ordinal_position

			DECLARE @tname varchar(255)
			SELECT @tname = name FROM tempdb..sysobjects WHERE name like '#customer_update_input%'
			
			-- Create a cursor over the list of fields
			DECLARE field_cursor CURSOR FOR 
			SELECT field
			FROM #ufields
			WHERE progress = 0

			OPEN field_cursor

			FETCH NEXT FROM field_cursor 
			INTO @field

			-- ReSET change_count
			SET @change_count = 0
			
			-- SET reference
			SET @reference = 'customer_id: ' + @customer_id_text
			
			-- For every field...
			WHILE @@FETCH_STATUS = 0
			BEGIN  
				-- Check to see IF this customer field was given AS sp input:
				IF EXISTS (SELECT column_name FROM #customer_update_input_columns WHERE column_name = @field) BEGIN  
			
					-- Grab the original value INTO a generic variable
					EXEC ('INSERT #pop (v) SELECT Convert(varchar(255), ' + @field + ') FROM customer WHERE customer_id = ' + @customer_id)
					SELECT @before_value = IsNull(v, '') FROM #pop
					DELETE FROM #pop
					
					-- Grab the new value INTO a generic variable
					EXEC ('INSERT #pop (v) SELECT Convert(varchar(255), ' + @field + ') FROM #customer_update_input')
					SELECT @after_value = IsNull(v, '') FROM #pop
					DELETE FROM #pop
				
					-- Call eqsp_CustomerAudit for this field with the before/after values
					SET @result = 0
					IF @before_value <> @after_value COLLATE SQL_Latin1_General_Cp1_CS_AS
						EXEC @result = eqsp_CustomerAudit @customer_id, 'Customer', @field, @before_value, @after_value, @reference, 'WEB', @added_by
					SET @change_count = @change_count + @result
					
				END
				-- Reload for the next loop through
			   FETCH NEXT FROM field_cursor
			   INTO @field
			END
			
			CLOSE field_cursor
			DEALLOCATE field_cursor

			-- SET reference
			SET @reference = 'customer_id: ' + @customer_id_text + ' billing_project_id: 0'

			-- Handle any non-Customer homed fields that could be updated
			-- territory_code
				SELECT @field = 'territory_code'
	
				-- Grab the original value INTO a generic variable
				SELECT @before_value = Convert(varchar(255), territory_code) FROM CustomerBilling WHERE customer_id = @customer_id AND billing_project_id = 0
				
				-- Grab the new value INTO a generic variable
				SELECT @after_value = Convert(varchar(255), territory_code) FROM #customer_update_input
			
				-- Call eqsp_CustomerAudit for this field with the before/after values
				SET @result = 0
				IF @before_value <> @after_value COLLATE SQL_Latin1_General_Cp1_CS_AS
					EXEC @result = eqsp_CustomerAudit @customer_id, 'CustomerBilling', @field, @before_value, @after_value, @reference, 'WEB', @added_by
				SET @change_count = @change_count + @result

			IF @change_count > 0
				BEGIN  
					UPDATE Customer SET
						cust_parent_id = @cust_parent_id,
						cust_name = @cust_name,
						customer_type = @customer_type,
						cust_addr1 = @cust_addr1,
						cust_addr2 = @cust_addr2,
						cust_addr3 = @cust_addr3,
						cust_city = @cust_city,
						cust_state = @cust_state,
						cust_zip_code = @cust_zip_code,
						cust_country = @cust_country,
						cust_phone = @cust_phone,
						cust_fax = @cust_fax,
						designation = @designation,
						cust_category = @cust_category,
						cust_website = @cust_website,
						cust_sic_code = @cust_sic_code,
						cust_naics_code = @cust_naics_code,
						cust_status = @cust_status,
						modified_by = @added_by,
						date_modified = GetDate()
					WHERE
						customer_id = @customer_id

					UPDATE CustomerBilling SET
						territory_code = @territory_code
					WHERE
						customer_id = @customer_id
						AND billing_project_id = 0
						
					COMMIT TRAN c_update
						
				END
			ELSE
				BEGIN  
					ROLLBACK TRAN c_update
				END
	END
ELSE
	BEGIN  

		BEGIN TRAN c_insert

			-- Grab a few handy VALUES to have around for later
			DECLARE @csr_id int, @ae_id int, @nam_id int
			SELECT	@csr_id = (SELECT top 1 type_id FROM UsersXEQContact WHERE territory_code = @territory_code AND EQContact_Type = 'CSR'),
					@ae_id = (SELECT top 1 type_id FROM UsersXEQContact WHERE territory_code = @territory_code AND EQContact_Type = 'AE'),
					@nam_id = (SELECT top 1 type_id FROM UsersXEQContact WHERE territory_code = @territory_code AND EQContact_Type = 'NAM')

			-- Need a text list of the fields to loop over for creating audits
			INSERT INTO #ifields SELECT column_name AS field, 0 AS progress FROM #customer_columns WHERE column_name NOT IN ('date_added', 'date_modified') ORDER BY   ordinal_position
		
			EXEC @customer_id = sp_sequence_next 'Customer.Prospect_ID', 0

			SET @customer_id_text = Convert(varchar(20), @customer_id)

			INSERT Customer (
				customer_id,
				cust_name,
				cust_addr1,
				cust_addr2,
				cust_addr3,
				cust_city,
				cust_state,
				cust_zip_code,
				cust_country,
				cust_phone,
				cust_fax,
				designation, --11/19/2008 CMA Added per GID 9480
				cust_category, --11/19/2008 CMA Added per GID 9480
				cust_sic_code,
				cust_naics_code,
				cust_status,
				added_by,
				date_added,
				modified_by,
				date_modified,
				cust_prospect_flag,
				rowguid
			) VALUES (
				@customer_id,
				@cust_name,
				@cust_addr1,
				@cust_addr2,
				@cust_addr3,
				@cust_city,
				@cust_state,
				@cust_zip_code,
				@cust_country,
				@cust_phone,
				@cust_fax,
        @designation, --11/19/2008 CMA Added per GID 9480
        @cust_category, --11/19/2008 CMA Added per GID 9480
				@cust_sic_code,
				@cust_naics_code,
				'A',
				@added_by,
				GetDate(),
				@added_by,
				GetDate(),
				'P',
				NewId()
			)

			-- Create a cursor over the list of fields
			DECLARE field_cursor CURSOR FOR 
			SELECT field
			FROM #ifields
			WHERE progress = 0

			OPEN field_cursor

			FETCH NEXT FROM field_cursor 
			INTO @field

			-- ReSET change_count
			SET @change_count = 0

			-- SET reference
			SET @reference = 'customer_id: ' + @customer_id_text
			
			-- Grab the original value INTO a generic variable
			SELECT @before_value = NULL
			
			-- For every field...
			WHILE @@FETCH_STATUS = 0
			BEGIN  
			
				-- Grab the new value INTO a generic variable
				EXEC ('INSERT #pop (v) SELECT Convert(varchar(255), ' + @field + ') FROM customer WHERE customer_id = ' + @customer_id_text)
				SELECT @after_value =  IsNull(v, '') FROM #pop
				DELETE FROM #pop
			
				-- Call eqsp_CustomerAudit for this field with the before/after values
				SET @result = 0
				IF @before_value <> @after_value COLLATE SQL_Latin1_General_Cp1_CS_AS
					EXEC @result = eqsp_CustomerAudit @customer_id, 'Customer', @field, @before_value, @after_value, @reference, 'WEB', @added_by
				SET @change_count = @change_count + @result

				-- Reload for the next loop through
			   FETCH NEXT FROM field_cursor
			   INTO @field
			END
			
			CLOSE field_cursor
			DEALLOCATE field_cursor
			DROP TABLE #ifields

			-- Need a text list of the fields to loop over for creating audits
			INSERT INTO #i2fields SELECT column_name AS field, 0 AS progress  FROM #customerbilling_columns WHERE column_name NOT IN ('date_added', 'date_modified') ORDER BY   ordinal_position
			
			INSERT CustomerBilling (
				customer_id,
				billing_project_id,
				project_name,
				record_type,
				status,
				distribution_method,
				invoice_flag,
				insurance_surcharge_flag,
				ensr_flag,
				PO_required_flag,
				PO_validation,
				COR_required_flag,
				COPD_required_flag,
				weight_ticket_required_flag,
				internal_review_flag,
				intervention_required_flag,
				intervention_desc,
				region_id,
				collections_id,
				customer_service_id,
				salesperson_id,
				NAM_id,
				cust_discount,
				mail_to_bill_to_address_flag,
				all_facilities_flag,
				submit_on_hold_flag,
				break_code_1,
				break_code_2,
				break_code_3,
				sort_code_1,
				sort_code_2,
				sort_code_3,
				sort_code_4,
				sort_code_5,
				added_by,
				date_added,
				modified_by,
				date_modified,
				reference_code,
				territory_code,
				release_required_flag,
				release_validation,
				other_submit_required_flag,
				other_submit_required_desc,
				NAS_id,
				invoice_package_content,
				invoice_comment_1,
				invoice_comment_2,
				invoice_comment_3,
				invoice_comment_4,
				invoice_comment_5,
				billing_project_comment
			) VALUES (
				@customer_id,									
				0,
				'Standard',
				'C',
				'A',
				'M',
				'S',
				'T',
				'T',
				'F',
				'W',
				'F',
				'F',
				'F',
				'F',
				'F',
				NULL,
				NULL,
				NULL,
				@csr_id,
				@ae_id,
				@nam_id,
				0.00,
				'T',
				'T',
				'F',
				'C',
				'N',
				'N',
				'N',
				'N',
				'N',
				'N',
				'N',
				@added_by,
				GETDATE(),
				@added_by,
				GETDATE(),
				NULL,
				@territory_code,
				'F',
				'W',
				'F',
				NULL,
				NULL,
				'I', -- I per Sheila, but may need to be 'A'.
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL
			)

			-- Create a cursor over the list of fields
			DECLARE field_cursor CURSOR FOR 
			SELECT field
			FROM #i2fields
			WHERE progress = 0

			OPEN field_cursor

			FETCH NEXT FROM field_cursor 
			INTO @field

			-- ReSET change_count
			SET @change_count = 0

			-- SET reference
			SET @reference = 'customer_id: ' + @customer_id_text + ' billing_project_id: 0'
			
			-- Grab the original value INTO a generic variable
			SELECT @before_value = NULL
			
			-- For every field...
			WHILE @@FETCH_STATUS = 0
			BEGIN  
				-- Grab the new value INTO a generic variable
				EXEC ('INSERT #pop (v) SELECT Convert(varchar(255), ' + @field + ') FROM CustomerBilling WHERE customer_id = ' + @customer_id_text + ' AND billing_project_id = 0')
				SELECT @after_value = IsNull(v, '') FROM #pop
				DELETE FROM #pop
			
				-- Call eqsp_CustomerAudit for this field with the before/after values
				SET @result = 0
				IF @before_value <> @after_value COLLATE SQL_Latin1_General_Cp1_CS_AS
					EXEC @result = eqsp_CustomerAudit @customer_id, 'CustomerBilling', @field, @before_value, @after_value, @reference, 'WEB', @added_by
				SET @change_count = @change_count + @result

				-- Reload for the next loop through
			   FETCH NEXT FROM field_cursor
			   INTO @field
			END
			
			CLOSE field_cursor
			DEALLOCATE field_cursor

		COMMIT TRAN c_insert

	END
	SET NOCOUNT OFF

	SELECT @customer_id AS customer_id

END	--CREATE PROCEDURE sp_customer_update

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_update] TO [EQAI]
    AS [dbo];

