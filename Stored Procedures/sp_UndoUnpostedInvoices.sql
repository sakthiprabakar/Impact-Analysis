CREATE PROCEDURE dbo.sp_UndoUnpostedInvoices 
			@as_userid	varchar(10),
			@as_dbtype 	varchar(4),
			@ai_debug 	int = 0
AS
/***********************************************************************
This SP is called from w_invoice_processing.  It is called to undo invoices that were 
exported to the Epicor financial system, but not yet posted.  Since the user can export 
multiple invoices that do not necessarily fit into a neat range of values a temp table
#InvoiceRecordsToUndo table will be created and populated by the invoice undo process 
prior to the execution of this procedure.  This table will be used as an input parameters
to populate work tables and subsequent processing for this procedure.

This table is defined as follows:
			invoice_id int,
			revision_id int,
			invoice_code varchar(16)
and will be populated with the invoices that the user has selected for undoing.  

NOTE:  The invoice processing window will only allow the user to undo revision 1 invoices.

This sp is loaded to Plt_AI.

04/23/2007 WAC	Created
09/11/2007 WAC	Modified to no longer attempt to delete invoices from e01 since we are no longer
		exporting invoices to e01.
10/03/2007 WAC	Changed EQAI prefixed tables to EQ.  Incorporated NTSQLFINANCE alias.
11/06/2007 WAC	PDF image records are now deleted from plt_image..InvoiceImage when the invoice is
		undone.  NOTE: Not working yet due to view issues.
11/29/2007 WAC	Now ignoring e14.arinptmp because it is causing "OLE DB Provider could not support a 
		row lookup position" in production.  This error is not happening for dev or test.
		In addition, this error does not occur if this procedure is executed from a SQL
		query analyzer window.  Will we ever get a cash application through this procedure??
01/14/2008 WAC	Incorporated logic to delete the invoice and attachment PDF blobs from the image 
		database to get rid of clutter that we don't need.
06/26/2008 JDB	Added a condition before attempting to delete from arinptmp:  if there are no rows,
				then don't attempt to delete.  (This will address the comment on 11/29/07 as well
				as the Wal-Mart issues in June 2008.)
10/04/2010 JDB	Modified to delete from new BillingDetail table.
09/01/2011 JDB	Modified to NOT delete from the BillingDetail table.
04/18/2012 JDB	Added logic to void out any un-sent Messages so that customers won't get the
				invoice notification if we undo the unposted invoice.
03/08/2013 JDB	Added support for JDE, by deleting from InvoiceBillingDetail, JDEInvoicePayItem, and JDEInvoiceGL
03/05/2015 SK	Modified to use the "@sync_invoice_epicor" variable to control whether the EPICOR related code executes
03/06/2017 RB	Fixed SQL for AX cleanup

To Test:

CREATE TABLE #InvoiceRecordsToUndo(invoice_id int, revision_id int, invoice_code varchar(16))
INSERT INTO #InvoiceRecordsToUndo 
VALUES( 431334, 1, '40001186' )

EXEC sp_UndoUnpostedInvoices 'JASON_B', 'TEST', 1
***********************************************************************/

BEGIN

DECLARE @tablename	varchar(50)
DECLARE @arinpchgtablename varchar(50)
DECLARE @finance_server varchar(20)
DECLARE @finance_db 	varchar(20)
DECLARE @audit_key	int
DECLARE @execute_sql	varchar(8000)
DECLARE @invoice_image_id	int
DECLARE @attachment_image_id	int
DECLARE @image_DB	varchar(50)
DECLARE @invoice_code	varchar(16)
DECLARE @message_id		int
DECLARE @message_status char(1)
DECLARE @date_undone	DATETIME
DECLARE @axinvoiceheader_uid int

DECLARE @sync_invoice_epicor	tinyint,
		@sync_invoice_jde		tinyint,
		@sync_invoice_ax		tinyint
		
	
---------------------------------------------------------------
-- Do we export invoices/adjustments to Epicor?
---------------------------------------------------------------
SELECT @sync_invoice_epicor = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'Epicor'

---------------------------------------------------------------
-- Do we export invoices/adjustments to JDE?
---------------------------------------------------------------
SELECT @sync_invoice_jde = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'JDE'

---------------------------------------------------------------
-- Do we export invoices/adjustments to AX?
---------------------------------------------------------------
SELECT @sync_invoice_ax = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'AX'

SELECT @date_undone = GETDATE()

IF @sync_invoice_epicor = 1 
BEGIN
	CREATE TABLE #EpicorDatabases (
		company_id	smallint null,
		epicor_db_name	varchar(20) null )

	SET NOCOUNT ON

	--	Lookup the appropriate epicor server name
	--SELECT @finance_server = server_name FROM eqserver WHERE server_type = 'Epicor' + @db_type
	SELECT @finance_server = 'NTSQLFINANCE'

	-- EQAI doesn't have the trx_ctrl_num values for the invoices being undone because the
	-- invoice could be posted in multiple companies which would give it multiple trx_ctrl_num.
	-- EQAI also does not have the full doc_ctrl_num either due to the fact that each invoice created
	-- at the company level has a doc_ctrl_num suffix of rrccpp where rr = 2 digit revision_id, cc = 
	-- 2 digit company_id and pp is 2 digit profit_center_id.
	-- The glue that keeps all of the invoices together for a given invoice is the doc_desc
	-- field in arinpchg.  For the centralized invoice project this field has been redefined 
	-- to hold the invoice_code and 'EQAI-IV', which will identify an invoice that was
	-- created by EQAI, is now stored in comment_code of arinpchg.

	-- Figure out what epcior databases exist and assume that the invoices we are undoing have
	-- pieces in every Epicor database.

	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Populating table of Epicor databases...'
	INSERT INTO #EpicorDatabases (
		company_id,
		epicor_db_name )
	SELECT company_id,
		db_name_epic
	  FROM eqconnect 
	 WHERE db_type = @as_dbtype AND company_id <> 1
	 ORDER BY company_id DESC

	--------- No longer need to worry about e01 -----------
	--IF NOT EXISTS( SELECT 1 FROM #EpicorDatabases WHERE company_id = 1 )
	--BEGIN
	--	-- 01 company was not retrieved from the table so add it now so it can get processed
	--	-- with all other companies.
	--	INSERT INTO #EpicorDatabases (
	--		company_id,
	--		epicor_db_name )
	--	VALUES (1, 'e01')
	--END
	------------------------------------

	DECLARE Company_Cursor CURSOR FOR
	SELECT epicor_db_name FROM #EpicorDatabases
	OPEN Company_Cursor
	--	prime the pump
	FETCH NEXT FROM Company_Cursor INTO @finance_db

	--	loop through all companies and delete any trace of invoices in #InvoiceRecordsToUndo
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SET @arinpchgtablename = @finance_server + '.' + @finance_db + '.dbo.arinpchg'

		SET @tablename = @finance_server + '.' + @finance_db + '.dbo.arinpage'
		SET @execute_sql = 
			'DELETE ' + @tablename + ' FROM ' + @tablename + ' A ' +
				' INNER JOIN ' + @arinpchgtablename + ' B ' +
				' ON A.trx_ctrl_num = B.trx_ctrl_num' +
				' WHERE B.comment_code = ''EQAI-IV'' AND B.doc_desc IN ' +
				' (SELECT invoice_code FROM #InvoiceRecordsToUndo)'
		IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
		EXEC (@execute_sql)

		SET @tablename = @finance_server + '.' + @finance_db + '.dbo.arinptax'
		SET @execute_sql = 
			'DELETE ' + @tablename + ' FROM ' + @tablename + ' A ' +
				' INNER JOIN ' + @arinpchgtablename + ' B ' +
				' ON A.trx_ctrl_num = B.trx_ctrl_num' +
				' WHERE B.comment_code = ''EQAI-IV'' AND B.doc_desc IN ' +
				' (SELECT invoice_code FROM #InvoiceRecordsToUndo)'
		IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
		EXEC (@execute_sql)



	-- don't process arinptmp for e14 until we figure out what the issue is.  Most likely the table doesn't have data anyhow.
	--	IF @finance_db <> 'e14'
	--	BEGIN

		-- Added new IF statement here to make sure there are records in arinptmp before deleting.  6/26/08 JDB
	--	SET @tablename = @finance_server + '.' + @finance_db + '.dbo.arinptmp'
	--	SET @execute_sql = 
	--		'IF (SELECT COUNT(*) FROM ' + @tablename + ') > 0 ' + 
	--			' DELETE ' + @tablename + ' FROM ' + @tablename + ' A ' +
	--			' INNER JOIN ' + @arinpchgtablename + ' B ' +
	--			' ON A.trx_ctrl_num = B.trx_ctrl_num' +
	--			' WHERE B.comment_code = ''EQAI-IV'' AND B.doc_desc IN ' +
	--			' (SELECT invoice_code FROM #InvoiceRecordsToUndo)'
	--	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
	--	EXEC (@execute_sql)
	--	END



		SET @tablename = @finance_server + '.' + @finance_db + '.dbo.arinpcdt'
		SET @execute_sql = 
			'DELETE ' + @tablename + ' FROM ' + @tablename + ' A ' +
				' INNER JOIN ' + @arinpchgtablename + ' B ' +
				' ON A.trx_ctrl_num = B.trx_ctrl_num' +
				' WHERE B.comment_code = ''EQAI-IV'' AND B.doc_desc IN ' +
				' (SELECT invoice_code FROM #InvoiceRecordsToUndo)'
		IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
		EXEC (@execute_sql)

		--	 now remove the arinpchg record
		SET @execute_sql = 
			'DELETE ' + @arinpchgtablename + ' FROM ' + @arinpchgtablename + 
				' WHERE comment_code = ''EQAI-IV'' AND doc_desc IN ' +
				' (SELECT invoice_code FROM #InvoiceRecordsToUndo)'
		IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
		EXEC (@execute_sql)

		-- aractcus is updated during the export process but has not been updated as part of the
		-- unposting process and still is not part of the centralized invoice export.  If customer
		-- balance issues exist in Epicor this could be the reason why.

		-- get next company in this posting session
		FETCH NEXT FROM Company_Cursor INTO @finance_db
	END

	CLOSE Company_Cursor
	DEALLOCATE Company_Cursor
	
	DROP TABLE #EpicorDatabases
	
END

-- At this point there are no traces of the specified invoices in Epicor
-- Now it is time to fix EQAI

-- Before we start clearing out invoice records we need to create BillingAudit records for
-- the affected invoices

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Creating BillingAudit Records ...'
-- Create a temporary table that looks like the BillingAudit table.  A false where clause will get 
-- us an identical table schema with no data
SELECT * INTO #BillAudit FROM BillingAudit WHERE 1 = 0

INSERT INTO #BillAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, line_id, price_id, 
			billing_summary_id, transaction_code, table_name, column_name, before_value, 
			after_value, date_modified, modified_by, audit_reference )
SELECT 
	1,	-- stuff in 1 (non-null) for now and we will give it a unique key with an update next
	IDT.company_id,
	IDT.profit_ctr_id,
	IDT.trans_source, 
	IDT.receipt_id, 
	IDT.line_id, 
	IDT.price_id, 
	0, 	-- billing_summary_id can't be null, but we have nothing to put here so 0 will have to do
	'U', 
	'Billing', 
	'Invoice Undone', 
	IH.invoice_code, 
	NULL, 
	@date_undone, 
	@as_userid, 
	'Invoice Processing'
FROM InvoiceHeader IH
JOIN InvoiceDetail IDT ON IDT.invoice_id = IH.invoice_id 
	AND IDT.revision_id = IH.revision_id
JOIN #InvoiceRecordsToUndo ITU ON ITU.invoice_id = IH.invoice_id 
	AND ITU.revision_id = IH.revision_id
	

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceImage (PDF), Message Records ...'

DECLARE ImageID_Cursor CURSOR FOR
SELECT InvoiceHeader.invoice_code, invoice_image_id, attachment_image_id 
FROM InvoiceHeader 
JOIN #InvoiceRecordsToUndo 
 	ON InvoiceHeader.invoice_id = #InvoiceRecordsToUndo.invoice_id
 	AND InvoiceHeader.revision_id = #InvoiceRecordsToUndo.revision_id

OPEN ImageID_Cursor
--	prime the pump
FETCH NEXT FROM ImageID_Cursor INTO @invoice_code, @invoice_image_id, @attachment_image_id

--	loop through all invoices that were requested to be undone deleting images and un-sent messages as we go
WHILE @@FETCH_STATUS = 0
BEGIN
	--  delete the invoice PDF image (if we have one to delete)
	IF @invoice_image_id IS NOT NULL
	BEGIN
		-- lookup which database this image is in
		SELECT @image_DB = image_database 
		  FROM plt_image..InvoiceImageXDatabase 
		 WHERE image_id = @invoice_image_id AND image_type = 'I'
		IF @image_DB IS NOT NULL 
		BEGIN
			-- Since we have a database we know that the record exists so delete it
			SET @execute_sql = 
				'DELETE FROM ' + @image_DB + '.dbo.InvoiceImage ' +
				' WHERE image_id = ' + CONVERT(varchar(15), @invoice_image_id) +
				' AND image_type = ''I'''
			EXEC (@execute_sql)
		END
	END

	--  delete the attachment PDF image (if we have one to delete)
	IF @attachment_image_id IS NOT NULL
	BEGIN
		-- lookup which database this image is in
		SELECT @image_DB = image_database 
		  FROM plt_image..InvoiceImageXDatabase 
		 WHERE image_id = @attachment_image_id AND image_type = 'A'
		IF @image_DB IS NOT NULL 
		BEGIN
			-- Since we have a database we know that the record exists so delete it
			SET @execute_sql = 
				'DELETE FROM ' + @image_DB + '.dbo.InvoiceImage ' +
				' WHERE image_id = ' + Convert(varchar(15), @attachment_image_id) +
				' AND image_type = ''A'''
			EXEC (@execute_sql)
		END
	END

	--  Void un-sent messages (fax, e-mail), if any
	IF @invoice_code IS NOT NULL
	BEGIN
	
		-- Initialize
		SET @message_status = ''
	
		-- Find un-sent message for this invoice
		DECLARE MessageID_Cursor CURSOR FOR
		SELECT message_id, ISNULL(status, 'N')
		FROM Message m 
		WHERE subject LIKE '%' + @invoice_code + '%'

		OPEN MessageID_Cursor
		--	prime the pump
		FETCH NEXT FROM MessageID_Cursor INTO @message_id, @message_status

		--	loop through all messages for the invoice, and void out any that haven't been sent
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF @message_id > 0 AND @message_status = 'S'
			BEGIN
				-- Found a message that was already sent; create audit record, but we cannot void the message.
				IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Creating BillingAudit Records ...'
				INSERT INTO #BillAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, line_id, price_id, 
							billing_summary_id, transaction_code, table_name, column_name, before_value, 
							after_value, date_modified, modified_by, audit_reference )
				SELECT 
					2,	-- stuff in 2 (non-null) for now and we will give it a unique key with an update next
					IDT.company_id,
					IDT.profit_ctr_id,
					IDT.trans_source, 
					IDT.receipt_id, 
					IDT.line_id, 
					IDT.price_id, 
					0, 	-- billing_summary_id can't be null, but we have nothing to put here so 0 will have to do
					'U', 
					'Message', 
					'Message Already Sent', 
					IH.invoice_code, 
					NULL, 
					@date_undone, 
					@as_userid, 
					'Invoice Processing - Undo Unposted Invoice could not void message ID ' + CONVERT(varchar(10), @message_id) + ' because it was already sent.'
				FROM InvoiceHeader IH
				JOIN InvoiceDetail IDT ON IDT.invoice_id = IH.invoice_id 
					AND IDT.revision_id = IH.revision_id
				JOIN #InvoiceRecordsToUndo ITU ON ITU.invoice_id = IH.invoice_id 
					AND ITU.revision_id = IH.revision_id
				WHERE IH.invoice_code = @invoice_code
			END

			IF @message_id > 0 AND @message_status <> 'S'
			BEGIN
				IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Voiding Message Record ...'
				UPDATE MessageAttachment SET status = 'V' WHERE message_id = @message_id
				UPDATE Message SET status = 'V', modified_by = @as_userid, date_modified = @date_undone, error_description = 'Voided message - User un-did unposted invoice ' + @invoice_code WHERE message_id = @message_id
				
				IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Creating BillingAudit Records ...'
				INSERT INTO #BillAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, line_id, price_id, 
							billing_summary_id, transaction_code, table_name, column_name, before_value, 
							after_value, date_modified, modified_by, audit_reference )
				SELECT 
					3,	-- stuff in 3 (non-null) for now and we will give it a unique key with an update next
					IDT.company_id,
					IDT.profit_ctr_id,
					IDT.trans_source, 
					IDT.receipt_id, 
					IDT.line_id, 
					IDT.price_id, 
					0, 	-- billing_summary_id can't be null, but we have nothing to put here so 0 will have to do
					'U', 
					'Message', 
					'Message Voided', 
					IH.invoice_code, 
					NULL, 
					@date_undone, 
					@as_userid, 
					'Invoice Processing - Undo Unposted Invoice voided message ID ' + CONVERT(varchar(10), @message_id) + ' before it was sent.'
				FROM InvoiceHeader IH
				JOIN InvoiceDetail IDT ON IDT.invoice_id = IH.invoice_id 
					AND IDT.revision_id = IH.revision_id
				JOIN #InvoiceRecordsToUndo ITU ON ITU.invoice_id = IH.invoice_id 
					AND ITU.revision_id = IH.revision_id
				WHERE IH.invoice_code = @invoice_code
			END
			
			-- get next set of image_ids for the next undo invoice, if any
			FETCH NEXT FROM MessageID_Cursor INTO @message_id, @message_status
		END
		
		CLOSE MessageID_Cursor
		DEALLOCATE MessageID_Cursor
	END

	-- get next set of image_ids for the next undo invoice, if any
	FETCH NEXT FROM ImageID_Cursor INTO @invoice_code, @invoice_image_id, @attachment_image_id
END

CLOSE ImageID_Cursor
DEALLOCATE ImageID_Cursor


IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Inserting BillingAudit Records ...'
-- Get the max key from BillingAudit
SELECT @audit_key = Max(audit_id) FROM BillingAudit

-- Stuff in a unique key for each record in the temporary table
UPDATE #BillAudit
 SET @audit_key = audit_id = @audit_key + 1
 
IF @ai_debug = 1 SELECT * FROM #BillAudit

-- At this point in time we have a temporary table with data that can be inserted into BillingAudit
INSERT INTO BillingAudit
SELECT * FROM #BillAudit


     

-- Now delete this invoice(s) from EQAI
IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting BillingSummary Records ...'
DELETE BillingSummary FROM BillingSummary INNER JOIN #InvoiceRecordsToUndo 
	ON BillingSummary.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
	   BillingSummary.revision_id = #InvoiceRecordsToUndo.revision_id

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceDetail Records ...'
DELETE InvoiceDetail FROM InvoiceDetail INNER JOIN #InvoiceRecordsToUndo 
	ON InvoiceDetail.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
	   InvoiceDetail.revision_id = #InvoiceRecordsToUndo.revision_id

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceAttachment Records ...'
DELETE InvoiceAttachment FROM InvoiceAttachment INNER JOIN #InvoiceRecordsToUndo 
	ON InvoiceAttachment.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
	   InvoiceAttachment.revision_id = #InvoiceRecordsToUndo.revision_id

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceComment Records ...'
DELETE InvoiceComment FROM InvoiceComment INNER JOIN #InvoiceRecordsToUndo 
	ON InvoiceComment.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
	   InvoiceComment.revision_id = #InvoiceRecordsToUndo.revision_id

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceHeader Records ...'
DELETE InvoiceHeader FROM InvoiceHeader INNER JOIN #InvoiceRecordsToUndo 
	ON InvoiceHeader.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
	   InvoiceHeader.revision_id = #InvoiceRecordsToUndo.revision_id

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Updating Billing Records ...'
--	User can only undo a nonrevised invoice (revision 1) so the following Update will work when undoing.
--	If the user is permitted to undo revised invoice (revision > 1) in the future then this logic will
--	need to be revisited to ensure that the billing record does not get a "New" status and that the
--	invoice information does not disappear.
UPDATE Billing
  SET invoice_id = NULL,
	invoice_code = NULL,
	invoice_date = NULL,
	status_code = 'N',  -- <N>ew ready to be invoiced again
	date_modified = @date_undone,
	modified_by = @as_userid
WHERE invoice_id IN (SELECT invoice_id FROM #InvoiceRecordsToUndo)


-------------------------------------------------------------------------------
-- Clean up JDE information for the invoice
-------------------------------------------------------------------------------
IF @sync_invoice_jde = 1
BEGIN
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceBillingDetail Records ...'
	DELETE InvoiceBillingDetail FROM InvoiceBillingDetail INNER JOIN #InvoiceRecordsToUndo 
		ON InvoiceBillingDetail.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
		   InvoiceBillingDetail.revision_id = #InvoiceRecordsToUndo.revision_id
		   
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting JDEInvoicePayItem Records ...'
	DELETE JDEInvoicePayItem FROM JDEInvoicePayItem INNER JOIN #InvoiceRecordsToUndo 
		ON JDEInvoicePayItem.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
		   JDEInvoicePayItem.revision_id = #InvoiceRecordsToUndo.revision_id
		   
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting JDEInvoiceGL Records ...'
	DELETE JDEInvoiceGL FROM JDEInvoiceGL INNER JOIN #InvoiceRecordsToUndo 
		ON JDEInvoiceGL.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
		   JDEInvoiceGL.revision_id = #InvoiceRecordsToUndo.revision_id
END

-------------------------------------------------------------------------------
-- Clean up AX information for the invoice
-------------------------------------------------------------------------------
IF @sync_invoice_ax = 1
BEGIN
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting InvoiceBillingDetail Records ...'
	DELETE InvoiceBillingDetail FROM InvoiceBillingDetail INNER JOIN #InvoiceRecordsToUndo 
		ON InvoiceBillingDetail.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
		   InvoiceBillingDetail.revision_id = #InvoiceRecordsToUndo.revision_id
		   
   	SELECT @axinvoiceheader_uid = axinvoiceheader_uid from AXInvoiceHeader INNER JOIN #InvoiceRecordsToUndo 
		ON AXInvoiceHeader.invoice_id = #InvoiceRecordsToUndo.invoice_id AND
		   AXInvoiceHeader.revision_id = #InvoiceRecordsToUndo.revision_id
		    	   		   
   	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting AXInvoiceLine Records ...'
	DELETE AXInvoiceLine
	FROM AXInvoiceLine
	INNER JOIN AXInvoiceHeader
		on AXInvoiceHeader.axinvoiceheader_uid = AXInvoiceLine.axinvoiceheader_uid
	INNER JOIN #InvoiceRecordsToUndo 
		ON #InvoiceRecordsToUndo.invoice_id =  AXInvoiceHeader.invoice_id
		AND #InvoiceRecordsToUndo.revision_id = AXInvoiceHeader.revision_id

   	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting AXInvoiceExport Records ...'
	DELETE AXInvoiceExport
	FROM AXInvoiceExport
	INNER JOIN AXInvoiceHeader
		on AXInvoiceHeader.axinvoiceheader_uid = AXInvoiceExport.axinvoiceheader_uid
	INNER JOIN #InvoiceRecordsToUndo 
		ON #InvoiceRecordsToUndo.invoice_id =  AXInvoiceHeader.invoice_id
		AND #InvoiceRecordsToUndo.revision_id = AXInvoiceHeader.revision_id

   	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Deleting AXInvoiceHeader Records ...'
	DELETE AXInvoiceHeader
	FROM AXInvoiceHeader
	INNER JOIN #InvoiceRecordsToUndo 
		ON AXInvoiceHeader.invoice_id = #InvoiceRecordsToUndo.invoice_id
		AND AXInvoiceHeader.revision_id = #InvoiceRecordsToUndo.revision_id
END


--  EQAI is updated now
--  This procedure is done

--	don't need the temp tables any longer
DROP TABLE #BillAudit

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_UndoUnpostedInvoices] TO [EQAI]
    AS [dbo];

