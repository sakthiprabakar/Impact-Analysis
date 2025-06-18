CREATE OR ALTER PROCEDURE dbo.sp_contact_merge_master
	  @debug INTEGER
	, @merge_ID INTEGER
	, @contact_ID INTEGER
	, @connect_type VARCHAR(10)
	, @merge_rc INTEGER OUTPUT
AS
/* **************************************************************************************************
The purpose of this SP is to merge a duplicate contact INTO the contact record the user wants to keep
the merge id is the source and the contact id is the target of the merge

LOAD TO PLT_AI

10/08/2003 SCC	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
02/03/2006 MK	Fixed update of CustomerNote to set contact_id = @contact_id
02/23/2006 MK	Changed delete of merging contact to deactivate with status = 'X'
05/06/06   RG   modified for contactxref and Note
07/10/07   JPB  Modified ContactXRef/Generator section from type = 'C' to type = 'G' (line 168, 184)
08/15/2007 JPB	Modified: Generator Contact section was using wrong #table at the end of its loop
					and the Primary_contact queries forgot to exclude the contact you're already using.
10/01/2007 WAC	Changed tables with EQAI prefix to EQ prefix.  Added db_type to WHERE clause for eqdatabase query
04/20/2020 ZH	Update to include new tables along with an update to inactive status vs a delete statement  DO:15243
Updated by Blair Christensen for Titan 05/08/2025
					
sp_contact_merge_master 1, 2492, 2767, 'DEV', 0
************************************************************************************************** */
BEGIN
	DECLARE @customer_id INTEGER
	      , @process_count INTEGER
	      , @xref_exists INTEGER
	      , @err_msg VARCHAR(255)
	      , @generator_id INTEGER

	-- Control the merge
	BEGIN TRANSACTION MERGE_TO_CONTACT
	-------------------------------------
	--is null return to stop stored proc 4/20/2020
	-------------------------------------
	IF ISNULL(@merge_id, -1) = -1
		BEGIN
			RETURN
		END
	IF ISNULL(@contact_id, -1) = -1
		BEGIN
			RETURN
		END

	-------------------------------------
	-- ContactXRef table
	-------------------------------------
	-- Check to see if a cross reference record already exists for this contact, per customer
	CREATE TABLE #tmp_custXcontact (
		   customer_ID INTEGER NOT NULL
		 , contact_ID INTEGER NOT NULL
		 , process_flag INTEGER NOT NULL
		 );

	INSERT INTO #tmp_custXcontact (customer_ID, contact_ID, process_flag)
		SELECT customer_ID
			 , contact_ID
			 , 0 as process_flag
		  FROM dbo.ContactXRef
		 WHERE contact_ID = @merge_ID
		   AND [type] = 'C';

	SELECT @process_count = COUNT(customer_ID) FROM #tmp_custXcontact;

	SET @merge_rc = 0
	SET ROWCOUNT 1
	WHILE @process_count > 0 AND @merge_rc = 0
		BEGIN
			SELECT @customer_id = customer_ID
			  FROM #tmp_custXcontact
			 WHERE process_flag = 0;

			SELECT @xref_exists = COUNT(contact_ID)
			  FROM dbo.ContactXRef 
			 WHERE contact_ID = @contact_ID 
			   AND customer_ID = @customer_ID
			   AND [type] = 'C';

			IF @xref_exists > 0 
				BEGIN
					-- Change the merge contact's record
					UPDATE x
					   SET x.[status] = 'I'
					  FROM dbo.ContactXRef x 
					 WHERE x.contact_ID = @merge_ID 
					   AND x.customer_ID = @customer_ID
					   AND [type] = 'C';

					SET @merge_rc = @@ERROR
						IF @merge_rc <> 0
							BEGIN
								SET @err_msg = 'Error deleting ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
								RAISERROR ( @err_msg,16,1)
								IF @debug = 1
									BEGIN
										PRINT @err_msg
									END
							END
				END
			ELSE
				BEGIN
					IF EXISTS (SELECT 1
								 FROM dbo.ContactXref
								WHERE [type] = 'C' AND customer_id = @customer_id
								  AND primary_contact = 'T' AND contact_id <> @merge_id)
						BEGIN 
							-- Change merge ID to contact ID
							UPDATE dbo.ContactXRef 
							   SET contact_ID = @contact_ID
								 , primary_contact = 'F' 
							 WHERE contact_ID = @merge_ID 
							   AND customer_ID = @customer_ID
							   AND [type] = 'C';
						
							SET @merge_rc = @@ERROR
							IF @merge_rc <> 0
								BEGIN
									SET @err_msg = 'Error updating ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
										RAISERROR (@err_msg, 16, 2)
											IF @debug = 1
												BEGIN
													PRINT @err_msg
												END
								END
						END
					ELSE
 						BEGIN 
							-- Change merge ID to contact ID
							UPDATE dbo.ContactXRef 
							   SET contact_ID = @contact_ID 
							 WHERE contact_ID = @merge_ID 
							   AND customer_ID = @customer_ID
							   and [type] = 'C';

							SET @merge_rc = @@ERROR
							IF @merge_rc <> 0
								BEGIN
									SET @err_msg = 'Error updating ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
										RAISERROR ( @err_msg,16,2)
											IF @debug = 1
												BEGIN
													PRINT @err_msg
												END
								END
						END
				END

			UPDATE #tmp_custXcontact
			   SET process_flag = 1
			 WHERE process_flag = 0

			SET @process_count = @process_count - 1
		END 
	SET ROWCOUNT 0

	DROP TABLE IF EXISTS #tmp_custXcontact;

	-------------------------------------
	-- Contact Generators
	-------------------------------------
	DROP TABLE IF EXISTS #tmp_genXcontact;

	CREATE TABLE #tmp_genXcontact (
		   generator_ID			INTEGER
		 , contact_ID			INTEGER
		 , process_flag			INTEGER
	     )

	-- Check to see if a cross reference record already exists for this contact, per customer
	INSERT INTO #tmp_genXcontact (generator_ID, contact_ID, process_flag)
		SELECT generator_ID
			 , contact_ID
			 , 0 as process_flag
		  FROM dbo.ContactXRef
		 WHERE contact_ID = @merge_ID
		   AND [type] = 'G';

	SELECT @process_count = count(*)
	  FROM #tmp_genXcontact

	SET @merge_rc = 0
	SET ROWCOUNT 1
	WHILE @process_count > 0 AND @merge_rc = 0
		BEGIN
			SELECT @generator_id = generator_ID
			  FROM #tmp_genXcontact
			 WHERE process_flag = 0;

			SELECT @xref_exists = count(contact_ID)
			  FROM dbo.ContactXRef 
			 WHERE contact_ID = @contact_ID 
			   AND generator_id = @generator_id
			   AND [type] = 'G';

			IF @xref_exists > 0 
				BEGIN
					-- change to update the status from a delete line (4/20)
					UPDATE dbo.ContactXRef
					   SET [status] = 'I'
					  FROM ContactXRef 
					 WHERE contact_ID = @merge_ID 
					   AND generator_id = @generator_id
					   AND [type] = 'G';

					SET @merge_rc = @@ERROR
					IF @merge_rc <> 0
						BEGIN
							SET @err_msg = 'Error updating ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
							RAISERROR ( @err_msg,16,1)
							IF @debug = 1
								BEGIN
									PRINT @err_msg
								END
						END
				END
			ELSE
				BEGIN
					IF EXISTS (SELECT 1
								 FROM dbo.ContactXref
								 WHERE [type] = 'G' AND generator_id = @generator_id
								   AND primary_contact = 'T' AND contact_id <> @merge_id)
						BEGIN 
							-- Change merge ID to contact ID
							UPDATE dbo.ContactXRef 
							   SET contact_ID = @contact_ID
								 , primary_contact = 'F' 
							 WHERE contact_ID = @merge_ID 
							   AND generator_ID = @generator_id
							   AND [type] = 'G';

							SET @merge_rc = @@ERROR
							IF @merge_rc <> 0
								BEGIN
									SELECT @err_msg =  'Error updating ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
									RAISERROR ( @err_msg,16,2)
									IF @debug = 1
										BEGIN
											PRINT @err_msg
										END
								END
						 END
					ELSE
						BEGIN 
							-- Change merge ID to contact ID
							UPDATE dbo.ContactXRef 
							   SET contact_ID = @contact_ID 
							 WHERE contact_ID = @merge_ID 
							   AND generator_ID = @generator_id
							   and [type] = 'G';

							SET @merge_rc = @@ERROR
							IF @merge_rc <> 0
								BEGIN
									SELECT @err_msg =  'Error updating ContactXRef record: ' + CONVERT(VARCHAR(10), @merge_rc)
									RAISERROR ( @err_msg,16,2)
									IF @debug = 1
										BEGIN
											PRINT @err_msg
										END
								END
						END
				END

			UPDATE #tmp_genXcontact SET process_flag = 1 WHERE process_flag = 0;
			SET @process_count = @process_count - 1;
		END 
	SET ROWCOUNT 0

	DROP TABLE IF EXISTS #tmp_genXcontact;

	-------------------------------------
	-- CustomerNote table
	-------------------------------------
	IF @merge_rc = 0
		BEGIN
			UPDATE dbo.Note
			   SET contact_ID = @contact_ID 
			 WHERE contact_ID IS NOT NULL 
			   AND contact_ID = @merge_ID;

			SET @merge_rc = @@ERROR
			IF @merge_rc <> 0
				BEGIN
					SELECT @err_msg =  'Error updating Customer Note record: ' + CONVERT(VARCHAR(10), @merge_rc)
					RAISERROR ( @err_msg, 16, 1)
					IF @debug = 1
						BEGIN
							PRINT @err_msg
						END
				END
		END

	/*--------------------------------------------------------------------
	-- Change all merge IDs to the contact ID in each table --4/20/2020
	--------------------------------------------------------------------*/
	IF EXISTS (SELECT 1 FROM dbo.Contact x WHERE x.contact_id = @contact_ID)
		BEGIN
			INSERT INTO dbo.ContactAudit (contact_id, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, modified_from, date_modified)
			SELECT @contact_id, 'Contact', 'Contact_id', @merge_ID, @contact_id
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' Merged into New Contact_id:'  + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' and set to Inactive'
				 , SYSTEM_USER, 'EQAI', GETDATE()
			  FROM dbo.Contact
			 WHERE contact_id = @contact_ID;
		END

	IF EXISTS (SELECT 1 FROM dbo.ContactXRole WHERE contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.ContactAudit (contact_id, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, modified_from, date_modified)
			SELECT @contact_id, 'ContactXRole', 'Contact_id', @merge_ID, @contact_id
			     , 'Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' ContactXRole_uid:' + CONVERT(VARCHAR(20), ISNULL(contactxrole_uid,''))
				 , SYSTEM_USER, 'EQAI', GETDATE()
			FROM dbo.ContactXRole x
			WHERE contact_id = @merge_id;
			
			UPDATE dbo.ContactXRole
			   SET contact_id = @contact_id
			  FROM dbo.ContactXRole x
			 WHERE contact_id = @merge_id
			   AND roleid NOT IN (
					SELECT roleid
			          FROM dbo.ContactXrole
					 WHERE contact_id = @contact_id
					   AND roleid = x.roleid
				   );
		END

	IF EXISTS (SELECT 1 FROM dbo.CustomerBillingXContact WHERE contact_id= @merge_id)
		BEGIN
			INSERT INTO dbo.CustomerAudit (customer_id, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, modified_from, date_modified
				 )
			SELECT customer_id, 'CustomerBillingXContact', 'Contact_id', @merge_ID, @contact_id
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,'')) + ' Billing_project_id'
				   + CONVERT(VARCHAR(20), ISNULL(Billing_project_id,''))
				 , SYSTEM_USER, 'EQAI', GETDATE()
			  FROM dbo.CustomerBillingXContact 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.CustomerBillingXContact
			   SET contact_id = @contact_id
			  FROM dbo.CustomerBillingXContact
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM dbo.FormCC WHERE contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.FormAudit (form_id, revision_id, trans_type
			     , [message]
				 , [ip], added_by, date_added
				 )
			SELECT form_id, revision_id, 'Update'
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' Form_id:' + CONVERT(VARCHAR(20), ISNULL(Form_id,''))
				 , CONVERT(VARCHAR(50), ConnectionProperty('client_net_address')), SYSTEM_USER, GETDATE()
			  FROM dbo.FormCC 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.FormCC
			   SET contact_id = @contact_id
			  FROM dbo.FormCC
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM dbo.FormRA	WHERE contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.FormAudit(form_id, revision_id, trans_type
			     , [message]
				 , [ip], added_by, date_added
				 )
			SELECT form_id, revision_id, 'Update'
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' Form_id:' + CONVERT(VARCHAR(20), ISNULL(Form_id,''))
				 , CONVERT(VARCHAR(50), ConnectionProperty('client_net_address')), SYSTEM_USER, GETDATE()
			  FROM dbo.FormRA 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.FormRA
			   SET contact_id = @contact_id
			  FROM dbo.FormRA
			 WHERE contact_id = @merge_id
		END

	IF EXISTS (SELECT 1 FROM dbo.FormSignature WHERE contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.FormAudit (form_id, revision_id, trans_type
			     , [message]
				 , [ip], added_by, date_added
				 )
			SELECT form_id, revision_id, 'Update'
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' Form_id:' + CONVERT(VARCHAR(20), ISNULL(Form_id,''))
				 , CONVERT(VARCHAR(50), ConnectionProperty('client_net_address')), SYSTEM_USER, GETDATE()
			  FROM dbo.FormSignature 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.FormSignature
			   SET contact_id = @contact_id
			  FROM dbo.FormSignature
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM dbo.OrderHeader where contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, modified_from, date_modified)
			SELECT order_id, NULL, NULL, 'OrderHeader', 'Contact_ID', @merge_ID, @contact_ID
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' Order_id:' + CONVERT(VARCHAR(20), ISNULL(Order_id,''))
				 , SYSTEM_USER, 'EQAI', GETDATE()
			  FROM dbo.OrderHeader 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.OrderHeader
			   SET contact_id = @contact_id
			  FROM dbo.OrderHeader
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM dbo.[Profile] WHERE contact_id= @merge_id)
		BEGIN
			INSERT INTO dbo.ProfileAudit (profile_id, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, date_modified)					--NEED TO CHANGE WITH PROFILE (rowguid)
			SELECT profile_id, 'profile', 'Contact_id', @merge_ID, @contact_id
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,'')) + ' New_id:'
				   + CONVERT(VARCHAR(20), ISNULL(@contact_ID,'')) + ' Profile_id:' + CONVERT(VARCHAR(20), ISNULL(Profile_id,''))
				 , SYSTEM_USER, GETDATE()
			  FROM dbo.[Profile] 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.[Profile]
			   SET contact_id= @contact_id
			  FROM dbo.[Profile]
			 WHERE contact_id = @merge_id;
		END
		
	IF EXISTS (SELECT 1 FROM dbo.Schedule WHERE contact_id = @merge_id)
		BEGIN 
			INSERT INTO dbo.ScheduleAudit (confirmation_ID, table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, date_modified)					--NEED TO CHANGE WITH WASTE RECEIPTS - SCHEDULE (rowguid)
			SELECT confirmation_ID, 'Schedule', 'Contact_id', @merge_ID, @contact_id
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' Confirmation_ID:' + CONVERT(VARCHAR(20), ISNULL(confirmation_ID,''))
				 , SYSTEM_USER, GETDATE()
			  FROM dbo.Schedule 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.Schedule
			   SET contact_id = @contact_id
			  FROM dbo.Schedule
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM dbo.WorkorderHeader WHERE contact_id = @merge_id)
		BEGIN
			INSERT INTO dbo.WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id
				 , table_name, column_name, before_value, after_value
			     , audit_reference
				 , modified_by, date_modified)
			SELECT company_id, profit_ctr_ID, workorder_ID, '', 0
				 , 'WorkorderHeader', 'Contact_id', @merge_ID, @contact_id
			     , 'Old Contact_id:' + CONVERT(VARCHAR(20), ISNULL(@merge_ID,''))
				   + ' New_id:' + CONVERT(VARCHAR(20), ISNULL(@contact_ID,''))
				   + ' workorder_ID:' + CONVERT(VARCHAR(20), ISNULL(workorder_ID,''))
				 , SYSTEM_USER, GETDATE()
			  FROM dbo.WorkorderHeader 
			 WHERE contact_id = @merge_id;
			
			UPDATE dbo.WorkorderHeader
			   SET contact_id = @contact_id
			  FROM dbo.WorkorderHeader
			 WHERE contact_id = @merge_id;
		END

	IF EXISTS (SELECT 1 FROM EQWEB.dbo.AccessxPerms WHERE contact_id= @merge_id)
		BEGIN
			INSERT INTO EQWEB.dbo.AccessXPermsAudit (contact_id, record_type, account_id, perm_id
			     , [status], date_added, added_by)
			SELECT @contact_id, record_type, account_id, perm_id
			     , 'I', GETDATE(), CURRENT_USER
			  FROM EQWEB.dbo.AccessxPerms 
			 WHERE contact_id= @merge_id;
			
			UPDATE EQWEB..AccessxPerms
			   SET contact_id = @contact_id
			  FROM EQWEB..AccessxPerms
			 WHERE contact_id = @merge_id;
		END
	
	-------------------------------------
	-- Contact table (last)
	-------------------------------------
	IF @merge_rc = 0
		BEGIN
			-- change to update (4/20)
			UPDATE dbo.Contact
			   SET contact_status = 'I'
			  FROM dbo.Contact
			 WHERE contact_id = @merge_id;

			SET @merge_rc = @@ERROR
			IF @merge_rc <> 0
				BEGIN
					SELECT @err_msg =  'Error deactivating Contact record on delete: ' + CONVERT(VARCHAR(10), @merge_rc)
						RAISERROR(@err_msg,16,1)
						IF @debug = 1
							BEGIN
								PRINT @err_msg
							END
				END
		END

	-- Commit or Rollback
	IF @merge_rc = 0
		BEGIN
			COMMIT TRANSACTION MERGE_TO_CONTACT
			SET @merge_rc = @@ERROR
			IF @merge_rc <> 0
				BEGIN
					SELECT @err_msg =  'Error COMMITTING changes: ' + CONVERT(VARCHAR(10), @merge_rc)
						RAISERROR (@err_msg,16,1)
						IF @debug = 1
							BEGIN
								PRINT @err_msg
							END
				END
		END
	ELSE
		BEGIN
			ROLLBACK TRANSACTION MERGE_TO_CONTACT
			SET @merge_rc = @@ERROR
			IF @merge_rc <> 0
				BEGIN
					SELECT @err_msg = 'Error ROLLBACKING changes: ' + CONVERT(VARCHAR(10), @merge_rc)
						RAISERROR (@err_msg,16,1)
						IF @debug = 1
							BEGIN
								PRINT @err_msg
							END
				END
		END

END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_merge_master] TO [EQAI]
    AS [dbo];

