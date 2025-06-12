DROP PROCEDURE IF EXISTS sp_billing_unsubmit
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_billing_unsubmit]
	@debug			int,
	@company_id		int,
	@profit_ctr_id	int,
	@source_id		int,
	@trans_source	char(1),
	@user_code		varchar(20)
AS
/***************************************************************************************
UnSubmit Receipt and Workorders from the Billing table

Filename:	L:\Apps\SQL\EQAI\sp_billing_unsubmit.sql

LOAD TO PLT_AI database

03/01/2007 SCC	Created
05/15/2007 SCC	Added status of 'N' to be unsubmitted.
08/05/2007 SCC	Added support for workorder unsubmitted from an adjustment
10/18/2007 SCC	Updated to set a problem ID on workorders when unsubmitted from an adjustment and
		to insert a note
01/14/2008 WAC	Unsubmitting no longer sets the billing_link_id field to null, but instead leaves
		the field as is.  This way when the user edits the unsubmitted transaction the
		invoice together checkbox will look the same as it did when submitted.  In addition,
		the value of this field no longer matters for a transaction that is unsubmitted then
		resubmitted to be invoiced on the same invoice.  Also, an unsubmitted transaction
		that will be resubmitted to appear on a new invoice will no longer be held up
		from invoicing when some of its related (linked) transactions have already been
		invoiced due to some logic improvements.
02/27/2008 WAC	Added 'V' to the billing.status_code IN where clause so that voided records are 
		processed as part of the unsubmit.  Without this change voided billing records are
		left behind and if the user was to resubmit a workorder new sequenced billing line
		ids might not get created in the Billing table because the submit stored procedure
		would find that the line id already exists.
03/05/2008 WAC	In some cases when a receipt or workorder is submitted there are no billing records
		created.  Logic in this procedure would only unset the submitted_flag when there was
		a successful join to the billing table for the receipt/workorder.  Of course this join
		fails when there are no billing records.  The join was replaced with a NOT EXISTS
		sub-query so that the submitted_flag will get set to 'F' when there are no billing
		records.
05/15/08 rg added logic to update related(linked) transactions to 'S'ubmitted status so that when the 
        receipt/workorder is resubmitted it will validate with its linked transactions.
04/26/2010 KAM  Moved to PLT_AI
10/12/2010 JDB	Added code to delete from new BillingDetail table
08/08/2012 JDB	Added a SQL transaction to the procedure so that records aren't removed from
				BillingDetail but not Billing.
06/15/2022 MPM	DevOps 41806 - Modified to remove a "Completed" record from the WorkOrderTracking table (if one exists)
				when a work order is unsubmitted.
11/26/2024 Sailaja Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024
12/06/2024 KS	Rally US127045 - Billing Adjustment > Receipt Unsubmission from Billing Adjustment Screen
				Added logic to update Receipt.problem_id and invoice_id, invoice_code, invoice_date in BillingComment table for Receipt 
				and we will not delete this record from BillingComment table if Billing.invoice_id IS NOT NULL, if
				Receipt is being unsubmitted from Adjustment screen with Remove from Invoice checkbox unchecked.
02/04/2025 KS	Rally US141341 - Invoice Processing - Customer Change should result in new Invoice.
				Added logic to populate BillingComment.customer_id to enable comparison with Receipt.customer_id. 
				This helps determine whether to create a new invoice or revise an existing one.

sp_billing_unsubmit 1, 21, 0, 856610, 'R', 'JASON_B'
****************************************************************************************/
SET NOCOUNT ON

DECLARE
	@update_count	int,
	@billing_count	int,
	@today		datetime,
	@audit_id	int,
	@invoice_id	int,
	@invoice_code	varchar(16),
	@invoice_date	datetime,
	@note		varchar(50),
	@note_id	int,
	@wo_problem_id	int,
	@rc_problem_id	int,
	@link_count int,
	@error_var	int,
	@comp_tracking_id		int,
	@prior_tracking_id		int,
	@comp_tracking_contact	varchar(10),
	@prior_tracking_contact varchar(10),
	@tracking_days			int,
	@tracking_bus_days		int,
	@trans_mode				char(1),
	@customer_id			int
	
BEGIN TRANSACTION UnsubmitFromBilling

-- used for backing linked transaction to the receipt/workorder that is being unsubmitted
-- if the receipt/workorder is part of a link and any of the linked transactions are in billing
--  and have not been invoiced tehn set linked transaction back to 'S' - submitted.
CREATE TABLE #linked ( 
   	billing_link_id int NULL,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
	link_submitted_date datetime null,
    link_status char(1) null )
	
	 

SET @update_count = 0
SET @billing_count = 0
SELECT @today = GETDATE()

IF @trans_source = 'R'
BEGIN
	-- In a second associated billing records (if any) will be deleted.  The sub-query of this
	-- update will ensure that if in some rare case a billing record remains the submitted_flag 
	-- would not be unset.
	UPDATE Receipt SET 
		submitted_flag = 'F'
	WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_id = @source_id
	AND NOT EXISTS (SELECT 1 FROM Billing
			WHERE Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.receipt_id = @source_id
			AND Billing.trans_source = @trans_source
			AND Billing.status_code NOT IN ('H','S','N','V'))

	SELECT @error_var = @@ERROR, @update_count = @@ROWCOUNT

	IF @debug = 1 
	BEGIN
		PRINT '@@ROWCOUNT after Updating Receipt.submitted_flag: ' + CONVERT(VARCHAR(10), @update_count)
	END 

	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Updating Receipt.submitted_flag.', 16, 1)
		RETURN
	END

	-- Get the invoice information from the Billing lines being removed for a Receipt
	SELECT @invoice_id = MAX(Billing.invoice_id),  
	@invoice_code = MAX(Billing.invoice_code),  
	@invoice_date = MAX(Billing.invoice_date),
	@customer_id = MAX(Billing.customer_id) 
	FROM Billing  
	WHERE Billing.company_id = @company_id  
	AND Billing.profit_ctr_id = @profit_ctr_id  
	AND Billing.receipt_id = @source_id  
	AND Billing.trans_source = @trans_source  
	AND Billing.status_code IN ('H','S','N','V')  
  
	-- IF there is an invoice ID, then this Receipt is being adjusted.  We need to set  
	-- a problem ID showing that it needs to be resubmitted.  The reason this is a separate  
	-- update statement is because we don't want to overwrite a different problem set for the  
	-- Receipt when it is being unsubmitted from Billing for a different reason  
	IF @invoice_id IS NOT NULL  
	BEGIN  
	SET @rc_problem_id = 15  
	UPDATE Receipt   
	SET problem_id = @rc_problem_id  
	WHERE Receipt.company_id = @company_id  
	AND Receipt.profit_ctr_id = @profit_ctr_id  
	AND Receipt.receipt_id = @source_id  
     
	SELECT @error_var = @@ERROR  
   
	-- Rollback the transaction if there were any errors  
	IF @error_var <> 0  
	BEGIN  
	-- Rollback the transaction  
	ROLLBACK TRANSACTION UnsubmitFromBilling  
  
	-- Raise an error and return  
	RAISERROR ('Error Updating Receipt.problem_id.', 16, 1)  
	RETURN  
	END  
  
	-- Save the invoice information in the BillingComment record to link the Invoiced  
	-- Receipt Billing lines to the resubmitted Receipt as a result of an adjustment  
	UPDATE BillingComment  
	SET invoice_id = @invoice_id, invoice_code = @invoice_code, invoice_date = @invoice_date
		, customer_id = @customer_id
	WHERE BillingComment.company_id = @company_id  
	AND BillingComment.profit_ctr_id = @profit_ctr_id  
	AND BillingComment.receipt_id = @source_id  
	AND BillingComment.trans_source = @trans_source  
      
	SELECT @error_var = @@ERROR  
    
	-- Rollback the transaction if there were any errors  
	IF @error_var <> 0  
	BEGIN  
	-- Rollback the transaction  
	ROLLBACK TRANSACTION UnsubmitFromBilling  
  
	-- Raise an error and return  
	RAISERROR ('Error Updating BillingComment invoice fields.', 16, 1)  
	RETURN  
	END  
	END

	-- Sailaja - Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024 - start

	IF @update_count > 0
	BEGIN
		SELECT Distinct @trans_mode = trans_mode
			FROM Receipt
			WHERE Receipt.company_id = @company_id
			AND Receipt.profit_ctr_id = @profit_ctr_id
			AND Receipt.receipt_id = @source_id
		IF @trans_mode = 'I' 
		Begin
			/*
			If there is a "Completed" record in the ReceiptTracking table for this receipt, we need to:
				1. Remove the "Completed" record, 
				2. Clear out the "tracking days" columns in the Receipt table, 
				3. Update the tracking_id and tracking_contact in the receipt table to point to the prior tracking record (if there is a prior tracking record)
				4. Write all changes to the ReceiptAudit table.
			*/

			SELECT @tracking_days = tracking_days,
				@tracking_bus_days = tracking_bus_days
			FROM Receipt
			WHERE Receipt.company_id = @company_id
			AND Receipt.profit_ctr_id = @profit_ctr_id
			AND Receipt.receipt_id = @source_id
			AND trans_mode = 'I'

			IF EXISTS (SELECT 1
						FROM ReceiptTracking t
						WHERE t.company_id = @company_id
						AND t.profit_ctr_id = @profit_ctr_id
						AND t.receipt_id = @source_id
						AND t.tracking_status = 'COMP')
			BEGIN
				SELECT @comp_tracking_id = MAX(tracking_id)
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @source_id
				AND t.tracking_status = 'COMP'

				SELECT @comp_tracking_contact = tracking_contact
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @source_id
				AND t.tracking_id = @comp_tracking_id
			
				DELETE FROM ReceiptTracking
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @source_id
				AND t.tracking_id = @comp_tracking_id

				SELECT @error_var = @@ERROR
	
				-- Rollback the transaction if there were any errors
				IF @error_var <> 0
				BEGIN
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error deleting from ReceiptTracking.', 16, 1)
					RETURN
				END
			
				INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
						table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
				VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0, 'ReceiptTracking', 'tracking_id', CAST(@comp_tracking_id AS VARCHAR(255)), 
						'(record deleted)', 'Deleted row with tracking_id = ' + CAST(@comp_tracking_id AS VARCHAR(255)), @user_code, 'SB', @today)

				SELECT @error_var = @@ERROR
		
				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error inserting into ReceiptAudit for delete of Completed record from ReceiptTracking.', 16, 1)
					RETURN
				END

				-- There may or may not be a prior tracking id.  If there is, update the Receipt tracking_id to the values in that row.
				-- If there isn't, clear out the receipt tracking id and tracking contact.
				-- In either case, clear out the tracking_days and tracking_bus_days values, if they are populated.
				SELECT @prior_tracking_id = MAX(tracking_id)
				FROM ReceiptTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.receipt_id = @source_id
				AND t.tracking_id < @comp_tracking_id

				IF @prior_tracking_id > 0
				BEGIN
					SELECT @prior_tracking_contact = tracking_contact
					FROM ReceiptTracking t
					WHERE t.company_id = @company_id
					AND t.profit_ctr_id = @profit_ctr_id
					AND t.receipt_id = @source_id
					AND t.tracking_id = @prior_tracking_id

					UPDATE Receipt
					SET tracking_id = @prior_tracking_id,
						tracking_contact = @prior_tracking_contact,
						tracking_days = NULL,
						tracking_bus_days = NULL,
						modified_by = @user_code,
						date_modified = @today
					WHERE Receipt.company_id = @company_id
					AND Receipt.profit_ctr_id = @profit_ctr_id
					AND Receipt.receipt_id = @source_id
					AND Receipt.trans_mode = 'I'

					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error updating Receipt with prior tracking record info.', 16, 1)
						RETURN
					END
				
					INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
						table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,'Receipt', 'tracking_id', 
							CAST(@comp_tracking_id AS VARCHAR(255)),  CAST(@prior_tracking_id AS VARCHAR(255)), NULL, @user_code, 'SB', @today)

					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into ReceiptAudit for update of Receipt with prior tracking_id.', 16, 1)
						RETURN
					END
				
					INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
						table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0, 'Receipt', 'tracking_contact', 
							@comp_tracking_contact, @prior_tracking_contact, NULL, @user_code, 'SB', @today)

					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into ReceiptAudit for update of Receipt with prior tracking_contact.', 16, 1)
						RETURN
					END

					IF @tracking_days IS NOT NULL
					BEGIN
						INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
							table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
						VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
								'Receipt', 'tracking_days', CAST(@tracking_days AS VARCHAR(255)), '(blank)', NULL, @user_code, 'SB', @today)
								
						SELECT @error_var = @@ERROR
		
						IF @error_var <> 0
						BEGIN		
							-- Rollback the transaction
							ROLLBACK TRANSACTION UnsubmitFromBilling

							-- Raise an error and return
							RAISERROR ('Error inserting into ReceiptAudit for update of Receipt.tracking_days.', 16, 1)
							RETURN
						END
					END
	
					IF @tracking_bus_days IS NOT NULL
					BEGIN
				
						INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
								table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
						VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
								'Receipt', 'tracking_bus_days', CAST(@tracking_bus_days AS VARCHAR(255)), '(blank)', NULL, @user_code, 'SB', @today)
	
						SELECT @error_var = @@ERROR
		
						IF @error_var <> 0
						BEGIN		
							-- Rollback the transaction
							ROLLBACK TRANSACTION UnsubmitFromBilling

							-- Raise an error and return
							RAISERROR ('Error inserting into ReceiptAudit for update of Receipt.tracking_bus_days.', 16, 1)
							RETURN
						END
					END
				END
				ELSE
				BEGIN
					-- There is no tracking record prior to the Completed tracking record, so we only need to update tracking_id and tracking_contact in Receipt
					UPDATE Receipt
					SET tracking_id = NULL,
						tracking_contact = NULL,
						tracking_days = NULL,
						tracking_bus_days = NULL,
						modified_by = @user_code,
						date_modified = @today
					WHERE Receipt.company_id = @company_id
					AND Receipt.profit_ctr_id = @profit_ctr_id
					AND Receipt.receipt_id = @source_id
					AND Receipt.trans_mode = 'I'

					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error updating Receipt with NULL tracking record info.', 16, 1)
						RETURN
					END
				
					INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
								table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
							'Receipt', 'tracking_id', CAST(@comp_tracking_id AS VARCHAR(255)), '(blank)', NULL, @user_code, 'SB', @today)
						
					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into ReceiptAudit for update of Receipt with NULL tracking_id.', 16, 1)
						RETURN
					END

					INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
								table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
							'Receipt', 'tracking_contact', @comp_tracking_contact, '(blank)', NULL, @user_code, 'SB', @today)
						
					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into ReceiptAudit for update of Receipt with NULL tracking_contact.', 16, 1)
						RETURN
					END
				
					IF @tracking_days IS NOT NULL
					BEGIN
						INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
							table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
						VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
								'Receipt', 'tracking_days', CAST(@tracking_days AS VARCHAR(255)), '(blank)', NULL, @user_code, 'SB', @today)
								
						SELECT @error_var = @@ERROR
		
						IF @error_var <> 0
						BEGIN		
							-- Rollback the transaction
							ROLLBACK TRANSACTION UnsubmitFromBilling

							-- Raise an error and return
							RAISERROR ('Error inserting into ReceiptAudit for update of Receipt.tracking_days.', 16, 1)
							RETURN
						END
					END
	
					IF @tracking_bus_days IS NOT NULL
					BEGIN
				
						INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
								table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
						VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
								'Receipt', 'tracking_bus_days', CAST(@tracking_bus_days AS VARCHAR(255)), '(blank)', NULL, @user_code, 'SB', @today)
	
						SELECT @error_var = @@ERROR
		
						IF @error_var <> 0
						BEGIN		
							-- Rollback the transaction
							ROLLBACK TRANSACTION UnsubmitFromBilling

							-- Raise an error and return
							RAISERROR ('Error inserting into ReceiptAudit for update of Receipt.tracking_bus_days.', 16, 1)
							RETURN
						END
					END
				END
			END
		END
	END
	-- Sailaja - Rally #US127391 - EQAI Tracking feature addition in Inbound Receipt Screen - 11/26/2024  -End
END
ELSE IF @trans_source = 'W'
BEGIN
	-- In a second associated billing records (if any) will be deleted.  The sub-query of this
	-- update will ensure that if in some rare case a billing record remains the submitted_flag 
	-- would not be unset.

	UPDATE WorkorderHeader SET 
		submitted_flag = 'F', 
		workorder_status = 'C'
	WHERE WorkorderHeader.company_id = @company_id
	AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
	AND WorkorderHeader.workorder_id = @source_id
	AND NOT EXISTS (SELECT 1 FROM Billing
			WHERE Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.receipt_id = @source_id
			AND Billing.trans_source = @trans_source
			AND Billing.status_code NOT IN ('H','S','N','I','V'))
	
	SELECT @error_var = @@ERROR, @update_count = @@ROWCOUNT
	
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Updating WorkOrderHeader.submitted_flag.', 16, 1)
		RETURN
	END

	IF @update_count > 0
	BEGIN

		/* MPM - 6/15/2022 - DevOps 41806
		
		If there is a "Completed" record in the WorkOrderTracking table for this work order, we need to:
			1. Remove the "Completed" record, 
			2. Clear out the "tracking days" columns in the WorkOrderHeader table, 
			3. Update the tracking_id and tracking_contact in the WOH table to point to the prior tracking record (if there is a prior tracking record)
			4. Write all changes to the WorkOrderAudit table.
		*/

		SELECT @tracking_days = tracking_days,
			@tracking_bus_days = tracking_bus_days
		FROM WorkOrderHeader
		WHERE WorkorderHeader.company_id = @company_id
		AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
		AND WorkorderHeader.workorder_id = @source_id

		IF EXISTS (SELECT 1
					FROM WorkOrderTracking t
					WHERE t.company_id = @company_id
					AND t.profit_ctr_id = @profit_ctr_id
					AND t.workorder_id = @source_id
					AND t.tracking_status = 'COMP')
		BEGIN
			SELECT @comp_tracking_id = MAX(tracking_id)
			FROM WorkOrderTracking t
			WHERE t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
			AND t.workorder_id = @source_id
			AND t.tracking_status = 'COMP'

			SELECT @comp_tracking_contact = tracking_contact
			FROM WorkOrderTracking t
			WHERE t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
			AND t.workorder_id = @source_id
			AND t.tracking_id = @comp_tracking_id
			
			DELETE FROM WorkOrderTracking
			FROM WorkOrderTracking t
			WHERE t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
			AND t.workorder_id = @source_id
			AND t.tracking_id = @comp_tracking_id

			SELECT @error_var = @@ERROR
	
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error deleting from WorkOrderTracking.', 16, 1)
				RETURN
			END

			INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderTracking', 'tracking_id', CAST(@comp_tracking_id AS VARCHAR(255)), '(record deleted)', 'Deleted row with tracking_id = ' + CAST(@comp_tracking_id AS VARCHAR(255)), @user_code, @today)

			SELECT @error_var = @@ERROR
		
			IF @error_var <> 0
			BEGIN		
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error inserting into WorkOrderAudit for delete of Completed record from WorkOrderTracking.', 16, 1)
				RETURN
			END

			-- There may or may not be a prior tracking id.  If there is, update the WOH tracking_id to the values in that row.
			-- If there isn't, clear out the WOH tracking id and tracking contact.
			-- In either case, clear out the tracking_days and tracking_bus_days values, if they are populated.
			SELECT @prior_tracking_id = MAX(tracking_id)
			FROM WorkOrderTracking t
			WHERE t.company_id = @company_id
			AND t.profit_ctr_id = @profit_ctr_id
			AND t.workorder_id = @source_id
			AND t.tracking_id < @comp_tracking_id

			IF @prior_tracking_id > 0
			BEGIN
				SELECT @prior_tracking_contact = tracking_contact
				FROM WorkOrderTracking t
				WHERE t.company_id = @company_id
				AND t.profit_ctr_id = @profit_ctr_id
				AND t.workorder_id = @source_id
				AND t.tracking_id = @prior_tracking_id

				UPDATE WorkOrderHeader
				SET tracking_id = @prior_tracking_id,
					tracking_contact = @prior_tracking_contact,
					tracking_days = NULL,
					tracking_bus_days = NULL,
					modified_by = @user_code,
					date_modified = @today
				WHERE WorkorderHeader.company_id = @company_id
				AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
				AND WorkorderHeader.workorder_id = @source_id

				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error updating WorkOrderHeader with prior tracking record info.', 16, 1)
					RETURN
				END

				INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
				VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_id', CAST(@comp_tracking_id AS VARCHAR(255)), CAST(@prior_tracking_id AS VARCHAR(255)), NULL, @user_code, @today)

				SELECT @error_var = @@ERROR
		
				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader with prior tracking_id.', 16, 1)
					RETURN
				END

				INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
				VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_contact', @comp_tracking_contact, @prior_tracking_contact, NULL, @user_code, @today)

				SELECT @error_var = @@ERROR
		
				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader with prior tracking_contact.', 16, 1)
					RETURN
				END

				IF @tracking_days IS NOT NULL
				BEGIN
					INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_days', CAST(@tracking_days AS VARCHAR(255)), '(blank)', NULL, @user_code, @today)

					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader.tracking_days.', 16, 1)
						RETURN
					END
				END
	
				IF @tracking_bus_days IS NOT NULL
				BEGIN
					INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
					VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_bus_days', CAST(@tracking_bus_days AS VARCHAR(255)), '(blank)', NULL, @user_code, @today)

					SELECT @error_var = @@ERROR
		
					IF @error_var <> 0
					BEGIN		
						-- Rollback the transaction
						ROLLBACK TRANSACTION UnsubmitFromBilling

						-- Raise an error and return
						RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader.tracking_bus_days.', 16, 1)
						RETURN
					END
				END
			END
			ELSE
			BEGIN
				-- There is no tracking record prior to the Completed tracking record, so we only need to update tracking_id and tracking_contact in WOH
				UPDATE WorkOrderHeader
				SET tracking_id = NULL,
					tracking_contact = NULL,
					modified_by = @user_code,
					date_modified = @today
				WHERE WorkorderHeader.company_id = @company_id
				AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
				AND WorkorderHeader.workorder_id = @source_id

				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error updating WorkOrderHeader with NULL tracking record info.', 16, 1)
					RETURN
				END

				INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
				VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_id', CAST(@comp_tracking_id AS VARCHAR(255)), '(blank)', NULL, @user_code, @today)

				SELECT @error_var = @@ERROR
		
				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader with NULL tracking_id.', 16, 1)
					RETURN
				END

				INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
				VALUES (@company_id, @profit_ctr_id, @source_id, '', 0, 'WorkOrderHeader', 'tracking_contact', @comp_tracking_contact, '(blank)', NULL, @user_code, @today)

				SELECT @error_var = @@ERROR
		
				IF @error_var <> 0
				BEGIN		
					-- Rollback the transaction
					ROLLBACK TRANSACTION UnsubmitFromBilling

					-- Raise an error and return
					RAISERROR ('Error inserting into WorkOrderAudit for update of WorkOrderHeader with NULL tracking_contact.', 16, 1)
					RETURN
				END
			END
		END

		-- Get the invoice information from the Billing lines being removed for a Work Order
		SELECT @invoice_id = MAX(Billing.invoice_id),
			@invoice_code = MAX(Billing.invoice_code),
			@invoice_date = MAX(Billing.invoice_date)
		FROM Billing
		WHERE Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.receipt_id = @source_id
			AND Billing.trans_source = @trans_source
			AND Billing.status_code IN ('H','S','N','I','V')

		-- IF there is an invoice ID, then this Workorder is being adjusted.  We need to set
		-- a problem ID showing that it needs to be resubmitted.  The reason this is a separate
		-- update statement is because we don't want to overwrite a different problem set for the
		-- workorder when it is being unsubmitted from Billing for a different reason
		IF @invoice_id IS NOT NULL
		BEGIN
			SET @wo_problem_id = 15
			UPDATE WorkorderHeader 
			SET problem_id = @wo_problem_id
			WHERE WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @source_id
			
			SELECT @error_var = @@ERROR
	
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Updating WorkOrderHeader.problem_id.', 16, 1)
				RETURN
			END

			-- Save the invoice information in the BillingComment record to link the Invoiced
			-- Work Order Billing lines to the resubmitted Work Order as a result of an adjustment
			UPDATE BillingComment
				SET invoice_id = @invoice_id, invoice_code = @invoice_code, invoice_date = @invoice_date
			WHERE BillingComment.company_id = @company_id
				AND BillingComment.profit_ctr_id = @profit_ctr_id
				AND BillingComment.receipt_id = @source_id
				AND BillingComment.trans_source = @trans_source
				
			SELECT @error_var = @@ERROR
		
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Updating BillingComment invoice fields.', 16, 1)
				RETURN
			END
		END
	END
END

IF @update_count > 0
BEGIN
	-- Remove Billing Comments.  If this is a Work Order Billing Line and the invoice ID is pop'd, leave it.
	-- A Workorder Billing line with an invoice ID means that this work order was sent back from an adjustment. 
	DELETE FROM BillingComment
		FROM Billing 
	WHERE Billing.company_id = @company_id
		AND Billing.profit_ctr_id = @profit_ctr_id
		AND Billing.receipt_id = @source_id
		AND Billing.trans_source = @trans_source
		AND Billing.company_id = BillingComment.company_id
		AND Billing.profit_ctr_id = BillingComment.profit_ctr_id
		AND Billing.receipt_id = BillingComment.receipt_id
		AND ((Billing.trans_source = 'R' AND Billing.status_code IN ('H','S','N','V') AND Billing.invoice_id IS NULL) 
		  OR (Billing.trans_source = 'W' AND Billing.status_code IN ('H','S','N','I','V') AND Billing.invoice_id IS NULL))
		  
	SELECT @error_var = @@ERROR, @billing_count = @@ROWCOUNT
		
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Deleting from BillingComment.', 16, 1)
		RETURN
	END
	
	IF @billing_count > 0
	BEGIN
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, @company_id, @profit_ctr_id, @trans_source, @source_id,
			0, 0, 0, 'X', 'BillingComment', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
			
		SELECT @error_var = @@ERROR
		
		-- Rollback the transaction if there were any errors
		IF @error_var <> 0
		BEGIN
			-- Rollback the transaction
			ROLLBACK TRANSACTION UnsubmitFromBilling

			-- Raise an error and return
			RAISERROR ('Error Inserting BillingAudit Record for Delete from BillingComment.', 16, 1)
			RETURN
		END
	END
	
	
	-- Remove BillingDetail records
	DELETE BillingDetail
	FROM BillingDetail
	JOIN Billing ON Billing.company_id = BillingDetail.company_id
		AND Billing.profit_ctr_id = BillingDetail.profit_ctr_id
		AND Billing.receipt_id = BillingDetail.receipt_id
	WHERE Billing.company_id = @company_id
	AND Billing.profit_ctr_id = @profit_ctr_id
	AND Billing.receipt_id = @source_id
	AND Billing.trans_source = @trans_source
	AND ((Billing.trans_source = 'R' AND Billing.status_code IN ('H','S','N','V')) 
		OR (Billing.trans_source = 'W' AND Billing.status_code IN ('H','S','N','I','V')))
		
	SELECT @error_var = @@ERROR, @billing_count = @@ROWCOUNT
		
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Deleting from BillingDetail.', 16, 1)
		RETURN
	END
	
	IF @billing_count > 0
	BEGIN
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, @company_id, @profit_ctr_id, @trans_source, @source_id,
			0, 0, 0, 'X', 'BillingDetail', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
			
		SELECT @error_var = @@ERROR
		
		-- Rollback the transaction if there were any errors
		IF @error_var <> 0
		BEGIN
			-- Rollback the transaction
			ROLLBACK TRANSACTION UnsubmitFromBilling

			-- Raise an error and return
			RAISERROR ('Error Inserting BillingAudit Record for Delete from BillingDetail.', 16, 1)
			RETURN
		END
	END


	-- Remove Billing records.  Billing lines are removed for lines on Hold, Submitted, or New.
	-- For Workorder Billing Lines, Invoiced lines can be also be removed.
	DELETE FROM Billing
	WHERE Billing.company_id = @company_id
		AND Billing.profit_ctr_id = @profit_ctr_id
		AND Billing.receipt_id = @source_id
		AND Billing.trans_source = @trans_source
		AND ((Billing.trans_source = 'R' AND Billing.status_code IN ('H','S','N','V')) 
		  OR (Billing.trans_source = 'W' AND Billing.status_code IN ('H','S','N','I','V')))
	
	SELECT @error_var = @@ERROR, @billing_count = @@ROWCOUNT
		
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Deleting from Billing.', 16, 1)
		RETURN
	END

	IF @billing_count > 0 OR @update_count > 0
	BEGIN
		-- Either we just deleted some billing records or updated a receipt or workorderheader record
		-- in any case we need to write an audit
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, @company_id, @profit_ctr_id, @trans_source, @source_id,
			0, 0, 0, 'X', 'Billing', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
			
		SELECT @error_var = @@ERROR
		
		-- Rollback the transaction if there were any errors
		IF @error_var <> 0
		BEGIN
			-- Rollback the transaction
			ROLLBACK TRANSACTION UnsubmitFromBilling

			-- Raise an error and return
			RAISERROR ('Error Inserting BillingAudit Record for Delete from Billing.', 16, 1)
			RETURN
		END

		-- Get a new note ID
		SELECT @note_id = next_value FROM Sequence WHERE name = 'Note.note_id'
		UPDATE Sequence SET next_value = @note_id + 1 WHERE name = 'Note.note_id'
		
		SELECT @error_var = @@ERROR
		
		-- Rollback the transaction if there were any errors
		IF @error_var <> 0
		BEGIN
			-- Rollback the transaction
			ROLLBACK TRANSACTION UnsubmitFromBilling

			-- Raise an error and return
			RAISERROR ('Error Updating Sequence.next_value for Note.note_id.', 16, 1)
			RETURN
		END

		-- Setup the note text
		IF @wo_problem_id IS NOT NULL
			SELECT @note = problem_desc FROM WorkOrderProblem WHERE problem_id = @wo_problem_id
		IF @note IS NULL OR LTRIM(RTRIM(@note)) = ''
			SET @note = 'Unsubmitted from Billing'

		-- Write a note for receipts
		IF @trans_source = 'R'
		BEGIN
			INSERT Note (note_id, note_source, company_id, profit_ctr_id, note_date, 
				subject, status, note_type, note, customer_id, generator_id, 
				receipt_id, added_by, date_added, modified_by, date_modified, app_source)
			SELECT @note_id, 'Receipt', @company_id, @profit_ctr_id, @today, 
				'Unsubmitted from Billing', 'C', 'AUDIT', @note, 
				MAX(customer_id), MAX(generator_id),
				@source_id, @user_code, @today, @user_code, @today, 'EQAI'
			FROM Receipt 
			WHERE Receipt.company_id = @company_id
				AND Receipt.profit_ctr_id = @profit_ctr_id
				AND Receipt.receipt_id = @source_id
				
			SELECT @error_var = @@ERROR
		
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Inserting Receipt Note.', 16, 1)
				RETURN
			END


			-- Write an audit record
			INSERT ReceiptAudit(company_id, profit_ctr_id, receipt_id, line_id, price_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @source_id, 0, 0,
					'Receipt', 'submitted_flag', 'T', 'F', 'Unsubmitted from Billing',
					@user_code, 'SB', @today)
		
			SELECT @error_var = @@ERROR
			
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Inserting ReceiptAudit Record.', 16, 1)
				RETURN
			END
		END
		
		-- Write a note for work orders
		ELSE	
		BEGIN
			INSERT Note (note_id, note_source, company_id, profit_ctr_id, note_date, subject, status, 
				note_type, note, customer_id, generator_id, workorder_id,  
				added_by, date_added, modified_by, date_modified, app_source)
			SELECT @note_id, 'Workorder', @company_id, @profit_ctr_id, @today, 
				'Unsubmitted from Billing', 'C', 'AUDIT', @note,
				WorkOrderHeader.customer_id, WorkOrderHeader.generator_id,
				@source_id, @user_code, @today, @user_code, @today, 'EQAI'
			FROM WorkOrderHeader 
			WHERE WorkOrderHeader.company_id = @company_id
				AND WorkOrderHeader.profit_ctr_id = @profit_ctr_id
				AND WorkOrderHeader.workorder_id = @source_id
		
			SELECT @error_var = @@ERROR
			
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Inserting Work Order Note.', 16, 1)
				RETURN
			END
			

			-- Write an audit record
			INSERT WorkOrderAudit(company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @source_id, '', 0,
					'WorkOrderHeader', 'submitted_flag', 'T', 'F', 'Unsubmitted from Billing',
					@user_code, @today)
		
			SELECT @error_var = @@ERROR
			
			-- Rollback the transaction if there were any errors
			IF @error_var <> 0
			BEGIN
				-- Rollback the transaction
				ROLLBACK TRANSACTION UnsubmitFromBilling

				-- Raise an error and return
				RAISERROR ('Error Inserting WorkOrderAudit Record.', 16, 1)
				RETURN
			END
		END
	END
END 

-- see if there are any links to process.  we need to use plt_ai for this as the billing table is a view
-- in the company db and will not see billing records outside of the company.  Links can be to 
-- transactions outside of the current company.

-- get the non group billing links if any
-- receipts will only have one 
IF @trans_source = 'R'
BEGIN
 INSERT #linked
  SELECT b.billing_link_id,
        b.trans_source,
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
        b.billing_date,
		b.status_code
	FROM Billing b, Billinglinklookup bl
	WHERE bl.receipt_id = @source_id
	AND bl.profit_ctr_id = @profit_ctr_id
	AND bl.company_id = @company_id
	AND bl.trans_source in ('I','O')
	AND bl.source_type = b.trans_source
	AND bl.source_id = b.receipt_id
	AND bl.source_company_id = b.company_id
	AND bl.source_profit_ctr_id = b.profit_ctr_id
    AND bl.billing_link_id = 0
 UNION
 -- get groups to 
	SELECT b.billing_link_id,
        b.trans_source,
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
        b.billing_date,
		b.status_code
	FROM Billing b
    WHERE b.billing_link_id in  (SELECT bx.billing_link_id FROM Billing bx
								WHERE bx.receipt_id = @source_id
								AND bx.profit_ctr_id = @profit_ctr_id
								AND bx.company_id = @company_id
								AND bx.trans_source = @trans_source
								AND bx.billing_link_id > 0 )
	AND ( b.receipt_id <> @source_id
	 OR b.trans_source <> @trans_source
	 OR b.company_id <> @company_id
	 OR b.profit_ctr_id <> @profit_ctr_id )
END

-- get the non group billing links if any
-- workorders may have more than one 
IF @trans_source = 'W'
BEGIN
INSERT #linked
  SELECT b.billing_link_id,
        b.trans_source,
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
        b.billing_date,
		b.status_code
	FROM Billing b, Billinglinklookup bl
	WHERE bl.source_id = @source_id
	AND bl.source_profit_ctr_id = @profit_ctr_id
	AND bl.source_company_id = @company_id
	AND bl.source_type  = @trans_source
	AND bl.trans_source IN ('I', 'O') 
	AND b.trans_source = 'R'
	AND bl.receipt_id = b.receipt_id
	AND bl.company_id = b.company_id
	AND bl.profit_ctr_id = b.profit_ctr_id
    AND bl.billing_link_id = 0
 UNION
 -- get groups to 
	SELECT b.billing_link_id,
        b.trans_source,
		b.company_id,
		b.profit_ctr_id,
		b.receipt_id,
        b.billing_date,
		b.status_code
	FROM Billing b
    WHERE b.billing_link_id in  (SELECT bx.billing_link_id FROM Billing bx
								WHERE bx.receipt_id = @source_id
								AND bx.profit_ctr_id = @profit_ctr_id
								AND bx.company_id = @company_id
								AND bx.trans_source = @trans_source
								AND bx.billing_link_id > 0 )
	AND ( b.receipt_id <> @source_id
	 OR b.trans_source <> @trans_source
	 OR b.company_id <> @company_id
	 OR b.profit_ctr_id <> @profit_ctr_id )
END

SELECT @link_count = (SELECT COUNT(*) FROM #linked )

IF  @link_count > 0 
BEGIN 
-- we have linked transactions so we need to reset their status back to 'S'
	UPDATE Billing
	SET status_code = 'S',
	    invoice_code = null,
		invoice_date = null
	FROM Billing b, #linked l
	WHERE b.receipt_id = l.source_id
	  AND b.company_id = l.source_company_id
	  AND b.profit_ctr_id = l.source_profit_ctr_id
	  AND b.trans_source = l.source_type
	  AND b.status_code = 'N'
	
	SELECT @error_var = @@ERROR
		
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Updating Billing.status_code to ''S'' and clearing invoice fields.', 16, 1)
		RETURN
	END
    
	-- create an audit record
	IF @audit_id IS NULL 
	BEGIN 
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
	END 
	
	INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
		line_id, price_id, billing_summary_id, transaction_code, 
		table_name, column_name, before_value, after_value, 
		date_modified, modified_by, audit_reference )
	SELECT @audit_id, l.source_company_id, l.source_profit_ctr_id, l.source_type, l.source_id,
			0, 0, 0, 'U', 'Billing', 'status_code', l.link_status, 'S',
		@today, @user_code, 'set status back on linked transaction'
	FROM #linked l
	WHERE l.link_status = 'N'
	
	SELECT @error_var = @@ERROR
	
	-- Rollback the transaction if there were any errors
	IF @error_var <> 0
	BEGIN
		-- Rollback the transaction
		ROLLBACK TRANSACTION UnsubmitFromBilling

		-- Raise an error and return
		RAISERROR ('Error Inserting BillingAudit Record for Linked Transactions.', 16, 1)
		RETURN
	END
END

IF @debug = 1 
BEGIN
	PRINT 'update_count: ' + STR(@update_count) + ' and billing_count: ' + STR(@billing_count)
	SELECT * FROM #linked
END 

COMMIT TRANSACTION UnsubmitFromBilling
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_unsubmit] TO [EQAI]
GO
