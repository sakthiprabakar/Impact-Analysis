CREATE PROCEDURE dbo.sp_LookupUnpostedInvoices 
	@invoice_from	varchar(16),
	@invoice_to	varchar(16),
	@customer_from	int,
	@customer_to	int,
	@invoice_date_from	datetime,
	@invoice_date_to	datetime,
	@db_type 	varchar(4),
--	@currency_code varchar(3),
	@ai_debug 	int = 0,
	@cust_name_from varchar(40),
	@cust_name_to varchar(40)
AS
/***********************************************************************
This SP is called from EQAI w_invoice_processing.  It is called to populate the treeview control
that will give indication to the user of invoices that were exported to Epicor, but not posted 
making it eligible to "undo".

This sp is loaded to Plt_AI.

04/23/2007 WAC	Created
08/10/2007 WAC	Modified to accommodate new invoice numbering scheme: 1xxxxxxxrrccpp
			Where:
				xxxxxxx = zero filled invoice number
				rr = zero filled invoice revision
				cc = zero filled company id
				pp = zero filled profit center id
09/11/2007 WAC	Modified to use EQAI tables instead of e01.arinpchg to lookup invoices for 
		the user specified criteria.  Once invoices have been identified a 
		doc_ctrl_num will be generated for each company on the invoice and lookups
		into the appropriate epicor databases will be performed to look for the 
		existance of unposted records.
10/03/2007 WAC	Changed EQAI table prefix to EQ.  Incorporated NTSQLFINANCE alias
10/08/2007 WAC	Incorporated references to NTSQLFINANCE instead of a lookup to EQ tables for finance server
05/21/2012 JDB	When populating the #InvoicesWithFacilities table, replaced join to InvoiceDetail with BillingSummary 
				because of distributed revenue transactions.  When you had a receipt in 03-00 that was actually 
				distributed to 03-02 for WDI Transportation, it broke this logic here, and would not allow the invoice to be undone.
01/10/2013 SK	Fixed the logic to look at BillingSummary.gl_account_code to get the correct co-pc when building the doc ctrl# on #InvoicesWithFacilities
				Also Added a couple debug stmts to see the posted bit on every facility at end.
02/14/2013 JDB	Replaced the BillingSummary company ID and profit center with the corresponding GL
				account segments.  This should have been done in January 2013 when we changed
				the JOIN to use BillingSummary.
10/09/2013 JDB	Modified to check JDE for unposted invoices, in addition to the check that
				it already does to check Epicor.
12/04/2013 JDB	Modified the @JDE_Go_Live_Date variable so that it is correct for the JDE go-live date of 12/10/2013.
07/28/2014 JDB	Modified to check for records in JDE where the batch type is set to IB for invoices.  It was picking up AP/voucher batches
				before adding this check, and the invoice would appear unable to be undone because the query found it with the same document #.
03/23/2017 RB	Commented out query for existence in GL staging table. It was very slow, production and Pay Item staging tables should suffice
01/31/2018 MPM	Added currency_code to the result set.
04/13/2018 AM   EQAI-49764 - Added code for AX.
07/23/2018 AM   EQAI-52395 - Added new @currency_code argument to sp.
08/07/2019 MPM	Samanage 12947 - Removed @currency_code input parameter.
03/30/2021 AGC  DevOps 19287 added cust_name_from and cust_name_to parameters

sp_LookupUnpostedInvoices '40438461', '40438461', 10673, 10673, null, null, 'PROD', 1
sp_LookupUnpostedInvoices null, null, 1, 999999, '9/30/13', '9/30/13', 'Test', 1
sp_LookupUnpostedInvoices NULL, NULL, 1, 999999, '9/30/13', '9/30/13', 'Test', 1
sp_LookupUnpostedInvoices '40485320', '40485320', 1, 999999, '9/30/13', '9/30/13', 'Test', 1
sp_LookupUnpostedInvoices NULL, NULL, 1, 999999, '1/30/13', '1/30/13', 'Test', 0
sp_LookupUnpostedInvoices NULL, NULL, 1, 999999, '8/8/13', '8/8/13', 'Test', 0
sp_LookupUnpostedInvoices '40474931', '40474931', 1, 999999, '8/8/13', '8/8/13', 'Test', 0
sp_LookupUnpostedInvoices null, null, 1, 999999, '01/01/2017', '02/14/2018', 'Dev', 0


SELECT * FROM InvoiceHeader WHERE invoice_code = '40382991'
SELECT * FROM BillingSummary WHERE invoice_id = 846975
SELECT * FROM InvoiceBillingDetail
SELECT * FROM JDEInvoicePayItem
SELECT * FROM JDEInvoiceGL
***********************************************************************/
DECLARE @finance_db 	varchar(20)
DECLARE @execute_sql	varchar(8000)

DECLARE @sync_invoice_epicor	tinyint,
		@sync_invoice_jde		tinyint,
		@JDE_Go_Live_Date		datetime,
		@sync_invoice_ax		tinyint
		
SET @JDE_Go_Live_Date = '12/10/2013'

-- Create a table that will be used to group finance databases for unposted invoices
CREATE TABLE #InvoiceCompanies (
	finance_db	varchar(10) null )

CREATE TABLE #UserSelectedInvoices (
	invoice_id	int null,
	revision_id	int null,
	invoice_code	varchar(16) null )

CREATE TABLE #InvoicesWithFacilities (
	invoice_id	int null,
	revision_id	int null,
	invoice_code	varchar(16) null,
	company_id 	int null,
	profit_ctr_id 	int null,
	doc_ctrl_num 	varchar(16) null,
	finance_db 	varchar(10) null,
	posted		tinyint null )	-- 1 = posted, 0 = unposted at company level

CREATE TABLE #UnpostedRecordCount (
	invoice_id	int null,
	revision_id	int null,
	invoice_code	varchar(16) null,
	doc_ctrl_num	varchar(16) null,
	inv_count	int null )

CREATE TABLE #EQAIInvoiceResultSet (
	invoice_id	int null,
	revision_id	int null,
	posted		tinyint null )	-- 1 = posted, 0 = unposted at company level

SET NOCOUNT ON

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



--	Extract records from InvoiceHeader that match the user criteria.  Calling Powerbuilder
--	script should have validated that the user specified some sort of criteria to prevent
--	a large result set.  Only <I>nvoiced or <Q>ueued invoices are eligible for undoing.  In
--	addition we will always be acting upon the Max revision of the invoice.
SET @execute_sql = 
'INSERT INTO #UserSelectedInvoices (
	invoice_id,
	revision_id,
	invoice_code )
SELECT invoice_id,
	revision_id,
	invoice_code
FROM InvoiceHeader
WHERE status IN (''I'', ''Q'') AND revision_id = (SELECT MAX(revision_id) FROM InvoiceDetail WHERE InvoiceDetail.invoice_id = InvoiceHeader.invoice_id)'

--	add in invoice_code criteria, if specified
IF @invoice_from IS NOT NULL AND @invoice_to IS NULL
	SET @execute_sql = @execute_sql + ' AND invoice_code = ''' + @invoice_from + ''''
ELSE IF @invoice_from IS NOT NULL AND @invoice_to IS NOT NULL
	SET @execute_sql = @execute_sql + ' AND invoice_code >= ''' + @invoice_from + '''' +
				' AND invoice_code <= ''' + @invoice_to + ''''

--	add in customer_id criteria, if specified
IF @customer_from IS NOT NULL AND @customer_to IS NULL
	SET @execute_sql = @execute_sql + ' AND customer_id = ''' + CONVERT(varchar(6), @customer_from) + ''''
ELSE IF @customer_from IS NOT NULL AND @customer_to IS NOT NULL
	SET @execute_sql = @execute_sql + ' AND customer_id >= ''' + CONVERT(varchar(6), @customer_from) + '''' +
			' AND customer_id <= ''' + CONVERT(varchar(6), @customer_to) + ''''

--	add in cust_name criteria, if specified
IF @cust_name_from IS NOT NULL AND @cust_name_to IS NULL
	SET @execute_sql = @execute_sql + ' AND cust_name like ''' + @cust_name_from + '%'''
ELSE IF @cust_name_from IS NOT NULL AND @cust_name_to IS NOT NULL
	SET @execute_sql = @execute_sql + ' AND cust_name >= ''' + @cust_name_from + '''' +
			' AND cust_name <= ''' + @cust_name_to + ''''

--	add in invoice date criteria, if specified
IF @invoice_date_from IS NOT NULL AND @invoice_date_to IS NULL
	SET @execute_sql = @execute_sql + ' AND invoice_date = ''' + CONVERT(varchar(10), @invoice_date_from, 110) + ''''
ELSE IF @invoice_date_from IS NOT NULL AND @invoice_date_to IS NOT NULL
	SET @execute_sql = @execute_sql + ' AND invoice_date >= ''' + CONVERT(varchar(10), @invoice_date_from, 110) + '''' +
			' AND invoice_date <= ''' + CONVERT(varchar(10), @invoice_date_to, 110 ) + ''''

--	add in currency_code criteria, if specified
--IF @currency_code IS NOT NULL
--	SET @execute_sql = @execute_sql + ' AND currency_code = ''' + CONVERT(varchar(3), @currency_code) + ''''
			
--	Now execute the SQL that was just formulated
IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
EXEC (@execute_sql)


-------------------------------------------------------------------------------
-- Check Epicor for the invoice
-------------------------------------------------------------------------------
IF @sync_invoice_epicor = 1
BEGIN

	--	Just because a record passes the user criteria doesn't mean that it is eligible for 
	--	undoing.  We now need to take the subset records from InvoiceHeader and determine how
	--	many facilities were a part of the selected invoices.
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Gathering facilities for selected invoices ...'
	--	doc_ctrl_num is formated in the epicor system as:  xxxxxxxxrrccpp
	--		where:
	--			xxxxxxxx is the invoice_code used in EQAI
	--			rr is the revision (zero filled)
	--			cc is the company_id (zero filled)
	--			pp is the profit_ctr_id (zero filled)
	INSERT INTO #InvoicesWithFacilities (
		invoice_id,
		revision_id,
		invoice_code,
		company_id,
		profit_ctr_id,
		doc_ctrl_num,
		posted )
	SELECT DISTINCT
		usi.invoice_id,
		usi.revision_id,
		usi.invoice_code,
		-- 2/5/13 JDB Replaced the BillingSummary company ID and profit center with the corresponding GL
		--				account segments.  This should have been done in January 2013 when we changed
		--				the JOIN to use BillingSummary.
		--idtl.company_id,
		--idtl.profit_ctr_id,
		CONVERT(int, SUBSTRING(bs.gl_account_code, 6, 2)) AS company_id,
		CONVERT(int, SUBSTRING(bs.gl_account_code, 8, 2)) AS profit_ctr_id,
		usi.invoice_code
			+ Right( '00' + Convert(varchar(2), usi.revision_id), 2 ) 
			+ SUBSTRING ( bs.gl_account_code , 6, 4 ),
			
			--+ Right( '00' + Convert(varchar(2), idtl.company_id), 2 ) 
			--+ Right( '00' + Convert(varchar(2), idtl.profit_ctr_id), 2 ), -- formulate doc_ctrl_num
		1	--	 assume posted

	------------------------------------------------------------------------------------------------------------------
	-- Commented this out and replaced with BillingSummary because of distributed revenue transactions.  5/18/12 JDB
	-- When you had a receipt in 03-00 that was actually distributed to 03-02 for WDI Transportation, 
	-- it broke this logic here, and would not allow the invoice to be undone.
	------------------------------------------------------------------------------------------------------------------
	--FROM #UserSelectedInvoices usi, InvoiceDetail idtl
	--WHERE usi.invoice_id = idtl.invoice_id AND usi.revision_id = idtl.revision_id

	FROM #UserSelectedInvoices usi
	JOIN BillingSummary bs ON usi.invoice_id = bs.invoice_id 
		AND usi.revision_id = bs.revision_id
	WHERE 1=1
	GROUP BY usi.invoice_id, usi.revision_id, usi.invoice_code, bs.company_id, bs.profit_ctr_id, bs.gl_account_code

	--	Now that we have a record for each facility of the invoice we need to look to the Epicor
	--	input tables and see if the invoice is still unposted for each facility of the invoice.
	--	Before we go to Epicor we need to know were we should be going to, so ... Populate the 
	--	temp table with the proper epicor database
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Populating finance_db ...'
	UPDATE #InvoicesWithFacilities
	   SET finance_db = db_name_epic 
	  FROM #InvoicesWithFacilities, eqconnect 
	 WHERE #InvoicesWithFacilities.company_id = eqconnect.company_id
	   AND eqconnect.db_type = @db_type

	IF @ai_debug = 1 PRINT 'SELECT * FROM #InvoicesWithFacilities'
	IF @ai_debug = 1 SELECT * FROM #InvoicesWithFacilities

	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Verifying that invoice(s) are unposted in company database(s) ...'
	-- get together all of the epicor databases that we will have to access
	INSERT INTO #InvoiceCompanies (
		finance_db )
	SELECT 
		finance_db
	FROM #InvoicesWithFacilities
	GROUP BY finance_db


	DECLARE Company_Cursor CURSOR FOR
	SELECT finance_db FROM #InvoiceCompanies
	OPEN Company_Cursor
	--	prime the pump
	FETCH NEXT FROM Company_Cursor INTO @finance_db

	--	loop through the appropriate finance databases get a count of unposted invoice records
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @execute_sql = 
		'INSERT INTO #UnpostedRecordCount (
			invoice_id,
			revision_id,
			invoice_code,
			doc_ctrl_num,
			inv_count )
		SELECT 
			iwf.invoice_id,
			iwf.revision_id,
			iwf.invoice_code,
			iwf.doc_ctrl_num,
			Count(*)
		FROM #InvoicesWithFacilities iwf, NTSQLFINANCE.' + @finance_db + '.dbo.arinpchg aic
		WHERE iwf.doc_ctrl_num = aic.doc_ctrl_num 
		  AND iwf.finance_db = ''' + @finance_db + ''' 
		  AND aic.comment_code = ''EQAI-IV''
		GROUP BY iwf.invoice_id, iwf.revision_id, iwf.invoice_code, iwf.doc_ctrl_num'
		IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' ' + @execute_sql
		IF @ai_debug = 1 PRINT 'SELECT * FROM #UnpostedRecordCount'
		IF @ai_debug = 1 SELECT * FROM #UnpostedRecordCount
		--	execute the SQL to look for the unposted invoice
		EXEC (@execute_sql)

		-- get next finance DB for the user selected invoice(s)
		FETCH NEXT FROM Company_Cursor INTO @finance_db
	END

	CLOSE Company_Cursor
	DEALLOCATE Company_Cursor

	--	Now that #UnpostedRecordCount is loaded we just need to join with #InvoicesWithFacilities to set
	--	the posted bit properly.  If we found a record where inv_count > 0 then invoice has NOT been posted.
	--	Don't need to worry about invoices that have been posted (inv_count = 0) as the 
	--	#InvoicesWithFacilities record was created with the posted bit set (1).
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Updating posted bit...'
	UPDATE #InvoicesWithFacilities
	SET posted = 0
	FROM #InvoicesWithFacilities iwf, #UnpostedRecordCount urc
	WHERE iwf.doc_ctrl_num = urc.doc_ctrl_num AND urc.inv_count > 0

	IF @ai_debug = 1 PRINT 'SELECT * FROM #InvoicesWithFacilities after updating posted bit'
	IF @ai_debug = 1 SELECT * FROM #InvoicesWithFacilities

	--	At this point in time #InvoicesWithFacilities has the posted bit set properly for each facility
	--	of the invoice, but we need to return a result with only a single record per invoice_id, revision_id
	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Grouping #InvoicesWithFacilities...'
	SELECT * INTO #InvoiceResultSet FROM #InvoicesWithFacilities WHERE 1 = 0
	INSERT INTO #EQAIInvoiceResultSet (
		invoice_id,
		revision_id,
		posted )
	SELECT 
		invoice_id,
		revision_id,
		MAX(posted)
	FROM #InvoicesWithFacilities
	GROUP BY invoice_id, revision_id
END		--IF @sync_invoice_epicor = 1


IF @sync_invoice_jde = 1
BEGIN
	-- Populate the #EQAIInvoiceResultSet temp table with invoices from #UserSelectedInvoices
	-- that exist in the JDE invoice tables.  The posted field will be determined by
	-- checking to see if the invoice exists in the JDE database.

	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' SELECT * FROM #UserSelectedInvoices'
	IF @ai_debug = 1 SELECT * FROM #UserSelectedInvoices
	
	INSERT INTO #EQAIInvoiceResultSet (
		invoice_id,
		revision_id,
		posted )
	-- This part of the union returns invoices that *ARE NOT* exported / posted in JDE
	SELECT 
		usi.invoice_id,
		usi.revision_id,
		0 AS posted
	FROM #UserSelectedInvoices usi
	JOIN InvoiceHeader ih (NOLOCK) ON ih.invoice_id = usi.invoice_id
		AND ih.revision_id = usi.revision_id
	WHERE 1=1
	AND ih.invoice_date >= @JDE_Go_Live_Date	-- We can't allow the user to undo any invoices that weren't even exported to JDE,
												-- so we need to keep this date check in there.
	-- Make sure the invoice is not in JDE's Production tables:
		-- JDE Customer Ledger / Pay Item table (F03B11)
		AND NOT EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEInvoicePayItem_F03B11
			WHERE document_number_RPDOC = CONVERT(int, usi.invoice_code)
			AND document_type_RPDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			AND batch_type_RPICUT = 'IB'
			)
		-- JDE General Ledger / GL table (F0911)
		AND NOT EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEInvoiceGL_F0911
			WHERE document_number_GLDOC = CONVERT(int, usi.invoice_code)
			AND document_type_GLDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI', 'AE')
			AND batch_type_GLICUT = 'IB'
			)
	-- Or in the Z tables:
		-- JDE Customer Ledger / Pay Item Z table (F03B11Z1)
		AND NOT EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEZInvoicePayItem_F03B11Z1
			WHERE document_number_VJDOC = CONVERT(int, usi.invoice_code)
			AND document_type_VJDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			)
/* rb
		-- JDE General Ledger / GL Z table (F0911)
		AND NOT EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEZInvoiceGL_F0911Z1
			WHERE document_number_VNDOC = CONVERT(int, usi.invoice_code)
			AND document_type_VNDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			)
*/
			
	UNION
	-- This part of the union returns invoices that *ARE* exported / posted in JDE
	SELECT 
		usi.invoice_id,
		usi.revision_id,
		1 AS posted
	FROM #UserSelectedInvoices usi
	JOIN InvoiceHeader ih (NOLOCK) ON ih.invoice_id = usi.invoice_id
		AND ih.revision_id = usi.revision_id
	WHERE 1=1
	AND ih.invoice_date >= @JDE_Go_Live_Date	-- We can't allow the user to undo any invoices that weren't even exported to JDE,
												-- so we need to keep this date check in there.
	-- Make sure the invoice is not in JDE's Production tables:
		-- JDE Customer Ledger / Pay Item table (F03B11)
		AND (
		EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEInvoicePayItem_F03B11
			WHERE document_number_RPDOC = CONVERT(int, usi.invoice_code)
			AND document_type_RPDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			AND batch_type_RPICUT = 'IB'
			)
		-- JDE General Ledger / GL table (F0911)
		OR EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEInvoiceGL_F0911
			WHERE document_number_GLDOC = CONVERT(int, usi.invoice_code)
			AND document_type_GLDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI', 'AE')
			AND batch_type_GLICUT = 'IB'
			)
	-- Or in the Z tables:
		-- JDE Customer Ledger / Pay Item Z table (F03B11Z1)
		OR EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEZInvoicePayItem_F03B11Z1
			WHERE document_number_VJDOC = CONVERT(int, usi.invoice_code)
			AND document_type_VJDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			)
/* rb
		-- JDE General Ledger / GL Z table (F0911)
		OR EXISTS (SELECT 1 
			FROM JDE.EQFinance.dbo.JDEZInvoiceGL_F0911Z1
			WHERE document_number_VNDOC = CONVERT(int, usi.invoice_code)
			AND document_type_VNDCT COLLATE SQL_Latin1_General_CP1_CI_AS IN ('RI')
			)
*/
		)

	IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' SELECT * FROM #EQAIInvoiceResultSet'
	IF @ai_debug = 1 SELECT * FROM #EQAIInvoiceResultSet
		
-- Z Tables	
--SELECT * FROM JDE.EQFinance.dbo.JDEZInvoicePayItem_F03B11Z1 WHERE document_number_VJDOC = 40445744
--SELECT * FROM JDE.EQFinance.dbo.JDEZInvoiceGL_F0911Z1 WHERE document_number_VNDOC = 40445744
-- Prod Tables
--SELECT * FROM JDE.EQFinance.dbo.JDEInvoicePayItem_F03B11 WHERE document_number_RPDOC = 40445744
--SELECT * FROM JDE.EQFinance.dbo.JDEInvoiceGL_F0911 WHERE document_number_GLDOC = 40445744 AND document_type_GLDCT IN ('RI', 'AE')
END
-- AX  - EQAI-49764
IF @sync_invoice_ax = 1
BEGIN
	INSERT INTO #EQAIInvoiceResultSet (
		invoice_id,
		revision_id,
		posted )
	SELECT 
		usi.invoice_id,
		usi.revision_id,
		0 AS posted
	FROM #UserSelectedInvoices usi
	JOIN AXInvoiceHeader aih  (NOLOCK) ON aih.invoice_id = usi.invoice_id
		AND aih.revision_id = usi.revision_id	   
	WHERE 1=1	
	AND NOT EXISTS (SELECT 1  
					FROM AXInvoiceExport aie
                    WHERE aie.axinvoiceheader_uid = aih.axinvoiceheader_uid
                     AND status in ('I','C'))
END

--	return the result set
IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Procedure Complete.'
SELECT DISTINCT ih.invoice_code,
	ih.invoice_id,
	ih.revision_id,
	MAX(irs.posted) AS posted,
	ih.customer_id,
	ih.cust_name,
	ih.addr1,
	ih.addr2,
	ih.addr3,
	ih.addr4,
	ih.addr5,
	ih.city,
	ih.state,
	ih.zip_code,
	ih.invoice_date,
	ih.total_amt_due,
	ih.due_date,
	ih.terms_code,
	ih.currency_code
FROM #EQAIInvoiceResultSet irs
JOIN InvoiceHeader ih (NOLOCK) ON irs.invoice_id = ih.invoice_id 
	AND irs.revision_id = ih.revision_id
GROUP BY ih.invoice_code,
	ih.invoice_id,
	ih.revision_id,
	ih.customer_id,
	ih.cust_name,
	ih.addr1,
	ih.addr2,
	ih.addr3,
	ih.addr4,
	ih.addr5,
	ih.city,
	ih.state,
	ih.zip_code,
	ih.invoice_date,
	ih.total_amt_due,
	ih.due_date,
	ih.terms_code,
	ih.currency_code
ORDER BY ih.cust_name, ih.invoice_code

--	don't need the temp tables any longer
DROP TABLE #InvoiceCompanies
DROP TABLE #UserSelectedInvoices
DROP TABLE #InvoicesWithFacilities
DROP TABLE #UnpostedRecordCount
DROP TABLE #EQAIInvoiceResultSet
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LookupUnpostedInvoices] TO [EQAI]
    AS [dbo];
GO

