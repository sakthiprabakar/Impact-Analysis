CREATE PROCEDURE sp_ExportInvoiceRecords 
	@as_userid varchar(30), 
	@company_id int, 
	@finance_server varchar(20), 
	@finance_db varchar(20), 
	@ai_debug int = 0 
AS
/***********************************************************************
This SP is called from sp_ExportInvoices.  It is called to export invoices to the Epicor 
financial system.  Since the user can export multiple invoices that do not necessarily
fit into a neat range of values, 2 temp tables (#InvHdr01, #BillSum01) will be created 
and populated for this procedure to work from.

This sp is loaded to Plt_AI.

04/23/2007 WAC	Created
09/12/2007 WAC	Setting recurring_flag to 1 for trx_type 2032 (credit memo)
10/04/2007 WAC	Increased @finance_server and @finance_db from varchar(10) to varchar(20).
10/15/2007 WAC	'EQAI-DM' now stored in arinpchg.comment_code when trx_type = 2031 and revision_id > 1
12/18/2007 WAC	Made appropriate modifications to use the new applied_date field from the invoice
		header table for the epicor applied date.  This replaces logic that used to use the
		invoice/adjustment date as the applied date.
12/21/2007 WAC	It was discovered by looking at the old export window that credit memo transactions
		do not need ARINPAGE records.  This is also bore out in Epicor as none of these records
		are being deleted after the exported EQAI credit memo is posted.  So arinpage records 
		are now inserted for trx_type = 2031 transactions only.
05/20/2008 JDB	Added support for inserting credit card payments into arinptmp.
07/30/2009 JDB	Modified the value being inserted into arinpage.amt_due from
				#InvHdr01.total_amt_due to be (#InvHdr01.total_amt_gross - #InvHdr01.total_amt_discount).
				This was due to the fact that retail invoices already paid by credit card 
				would not post until the value of arinpage.amt_due was set to the invoice amount.  GEM:13011
01/19/2013 JDB	Modified to insert into new FinanceExport* tables to store a record of what was exported to Epicor.
06/06/2013 JDB	Updated the cash account that is used for payments to use department 100 instead of 200
				(don't know how this has been working this long, since we eliminated department 200 at the beginning of 2012!)
07/19/2013 JDB	Commented out the insert into arinptmp table because we are no longer exporting the cash received to Epicor.
				Since JDE cannot accept any payments that are applied to the invoice (at the time of invoicing),
				we are not going to export the payment information to Epicor either.

***********************************************************************/
BEGIN

DECLARE @juliantoday	int,
		@epicoruserid	int,
		@execute_sql	varchar(8000),
		@cash_acct_check	varchar(16),
		@cash_acct_charge	varchar(16),
		@date_exported	datetime


SET @cash_acct_check  = '01110'
SET @cash_acct_charge = '01125'
SELECT @date_exported = GETDATE()

--	Create a table that will be used for sub-totaling
CREATE TABLE #grouptotals (
	group_code varchar(20),
	group_total_amt float )

--	EQAI uses strings to identify users, Epicor wants an integer to identify users.  It is difficult to convert @as_userid
--	to an integer that Epicor likes since not all EQAI users that will be exporting invoices have a valid user in the Epicor
--	system.  At the time of this writing, and all prior invoices exported by the old software, use the user_id 57 which is the
--	SA user in Epicor.
--  1/19/13 JDB:  At least try to get the Epicor user ID before setting it to 57
SELECT @epicoruserid = user_id FROM NTSQLFINANCE.emaster.dbo.smusers WHERE user_name = @as_userid
IF @epicoruserid IS NULL
BEGIN
	SELECT @epicoruserid = 57
END

--	Get today's date in epicor julian format
SELECT @juliantoday = DATEDIFF(Day, '1/1/1980', GETDATE()) + 722815

-- When @company_id = 1 it is assumed that this stored procedure will be acting on the e01 epicor database and
-- will be exporting all records from the temporary tables.  Any other company_id values will cause this procedure 
--	to be selective of which company transactaons are posted to the appropriate epicor company database.


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Create a FinanceExportarinpchg invoice header record
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET @execute_sql = 
	'INSERT INTO FinanceExportarinpchg (
		company_id,
		exported_by,
		date_exported,
		trx_ctrl_num,
		doc_ctrl_num,
		doc_desc,
		apply_to_num,
		apply_trx_type,
		order_ctrl_num,
		batch_code,
		trx_type,
		date_entered,
		date_applied,
		date_doc,
		date_shipped,
		date_required,
		date_due,
		date_aging,
		customer_code,
		ship_to_code,
		salesperson_code,
		territory_code,
		comment_code,
		fob_code,
		freight_code,
		terms_code,
		fin_chg_code,
		price_code,
		dest_zone_code,
		posting_code,
		recurring_flag,
		recurring_code,
		tax_code,
		cust_po_num,
		total_weight,
		amt_gross,
		amt_freight,
		amt_tax,
		amt_tax_included,
		amt_discount,
		amt_net,
		amt_paid,
		amt_due,
		amt_cost,
		amt_profit,
		next_serial_id,
		printed_flag,
		posted_flag,
		hold_flag,
		hold_desc,
		user_id,
		customer_addr1,
		customer_addr2,
		customer_addr3,
		customer_addr4,
		customer_addr5,
		customer_addr6,
		ship_to_addr1,
		ship_to_addr2,
		ship_to_addr3,
		ship_to_addr4,
		ship_to_addr5,
		ship_to_addr6,
		attention_name,
		attention_phone,
		amt_rem_rev,
		amt_rem_tax,
		date_recurring,
		location_code,
		nat_cur_code,
		rate_type_home,
		rate_type_oper,
		rate_home,
		rate_oper,
		edit_list_flag,
		writeoff_code,
		vat_prc )
	SELECT 
		company_id, ''' +
		@as_userid + ''', ''' + 
		CONVERT(varchar(30), @date_exported, 120) + ''', 
		trx_ctrl_num,
		doc_ctrl_num,
		invoice_code,
		apply_to_num,
		apply_trx_type,
		'''',
		'''',
		trx_type, ' +
		CONVERT(varchar(20), @juliantoday) + ',
		julian_applied_date,
		julian_invoice_date,
		julian_invoice_date,
		julian_invoice_date,
		julian_due_date,
		julian_invoice_date,
		epicor_customer_code,
		'''',
		epicor_salesperson_code,
		epicor_territory_code,
		CASE WHEN trx_type = ''2032'' THEN ''EQAI-CM'' WHEN revision_id > 1 THEN ''EQAI-DM'' ELSE ''EQAI-IV'' END,
		'''',	--? fob
		'''',	--? freight code
		terms_code,
		'''',
		'''',
		'''',
		epicor_posting_code,
		CASE trx_type WHEN ''2032'' THEN 1 ELSE 0 END,
		'''',
		''NOTAX'',
		customer_po,
		0,		--? at present there is no weight field in InvoiceHeader to store here.  Is it applicable?  Does it matter in Epcior?
		total_amt_gross,
		0,
		0,
		0,
		total_amt_discount,
		total_amt_gross - total_amt_discount,
		total_amt_payment,
		total_amt_due,
		0,
		0,
		sequence_id,	--	+1 greater than Max(sequence_id) for detail lines of the invoice
		1,
		0,
		0,
		'''', ' +
		CONVERT(varchar(20), @epicoruserid) + ',
		cust_name,
		IsNULL(addr1, '''' ),
		IsNULL(addr2, '''' ),
		IsNULL(addr3, '''' ),
		IsNULL(addr4, '''' ),
		IsNULL(addr5, '''' ),
		'''',
		'''',
		'''',
		'''',
		'''',
		'''',
		IsNull(attention_name, '''' ),
		IsNull(attention_phone, ''''),
		0,
		0,
		0,
		'''',	--?location
		''USD'',
		''BUY'',
		''BUY'',
		1,
		1,
		0,
		''WRITEOFF'',
		0.0
 FROM #invhdr01 '


IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END

--	execute the invoice header insert
EXEC (@execute_sql)



--	create Epicor invoice header record
SET @execute_sql = 
	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.arinpchg (
		trx_ctrl_num,
		doc_ctrl_num,
		doc_desc,
		apply_to_num,
		apply_trx_type,
		order_ctrl_num,
		batch_code,
		trx_type,
		date_entered,
		date_applied,
		date_doc,
		date_shipped,
		date_required,
		date_due,
		date_aging,
		customer_code,
		ship_to_code,
		salesperson_code,
		territory_code,
		comment_code,
		fob_code,
		freight_code,
		terms_code,
		fin_chg_code,
		price_code,
		dest_zone_code,
		posting_code,
		recurring_flag,
		recurring_code,
		tax_code,
		cust_po_num,
		total_weight,
		amt_gross,
		amt_freight,
		amt_tax,
		amt_tax_included,
		amt_discount,
		amt_net,
		amt_paid,
		amt_due,
		amt_cost,
		amt_profit,
		next_serial_id,
		printed_flag,
		posted_flag,
		hold_flag,
		hold_desc,
		user_id,
		customer_addr1,
		customer_addr2,
		customer_addr3,
		customer_addr4,
		customer_addr5,
		customer_addr6,
		ship_to_addr1,
		ship_to_addr2,
		ship_to_addr3,
		ship_to_addr4,
		ship_to_addr5,
		ship_to_addr6,
		attention_name,
		attention_phone,
		amt_rem_rev,
		amt_rem_tax,
		date_recurring,
		location_code,
		nat_cur_code,
		rate_type_home,
		rate_type_oper,
		rate_home,
		rate_oper,
		edit_list_flag,
		writeoff_code,
		vat_prc )
	SELECT
		trx_ctrl_num,
		doc_ctrl_num,
		invoice_code,
		apply_to_num,
		apply_trx_type,
		'''',
		'''',
		trx_type, ' +
		CONVERT(varchar(20), @juliantoday) + ',
		julian_applied_date,
		julian_invoice_date,
		julian_invoice_date,
		julian_invoice_date,
		julian_due_date,
		julian_invoice_date,
		epicor_customer_code,
		'''',
		epicor_salesperson_code,
		epicor_territory_code,
		CASE WHEN trx_type = ''2032'' THEN ''EQAI-CM'' WHEN revision_id > 1 THEN ''EQAI-DM'' ELSE ''EQAI-IV'' END,
		'''',	--? fob
		'''',	--? freight code
		terms_code,
		'''',
		'''',
		'''',
		epicor_posting_code,
		CASE trx_type WHEN ''2032'' THEN 1 ELSE 0 END,
		'''',
		''NOTAX'',
		customer_po,
		0,		--? at present there is no weight field in InvoiceHeader to store here.  Is it applicable?  Does it matter in Epcior?
		total_amt_gross,
		0,
		0,
		0,
		total_amt_discount,
		total_amt_gross - total_amt_discount,
		total_amt_payment,
		total_amt_due,
		0,
		0,
		sequence_id,	--	+1 greater than Max(sequence_id) for detail lines of the invoice
		1,
		0,
		0,
		'''', ' +
		CONVERT(varchar(20), @epicoruserid) + ',
		cust_name,
		IsNULL(addr1, '''' ),
		IsNULL(addr2, '''' ),
		IsNULL(addr3, '''' ),
		IsNULL(addr4, '''' ),
		IsNULL(addr5, '''' ),
		'''',
		'''',
		'''',
		'''',
		'''',
		'''',
		IsNull(attention_name, '''' ),
		IsNull(attention_phone, ''''),
		0,
		0,
		0,
		'''',	--?location
		''USD'',
		''BUY'',
		''BUY'',
		1,
		1,
		0,
		''WRITEOFF'',
		0.0
 FROM #invhdr01 '

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the invoice header insert
EXEC (@execute_sql)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Insert a FinanceExportarinptax tax record even though there is no tax
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET @execute_sql = 
	'INSERT INTO FinanceExportarinptax (
		company_id,
		exported_by,
		date_exported,
		trx_ctrl_num,
		trx_type,
		sequence_id,
		tax_type_code,
		amt_taxable,
		amt_gross,
		amt_tax,
		amt_final_tax )
	SELECT
		company_id, ''' +
		@as_userid + ''', ''' + 
		CONVERT(varchar(30), @date_exported, 120) + ''', 
		trx_ctrl_num,
		trx_type,
		1,
		''NOTAX'',
		0,
		total_amt_gross,
		0,
		0
 FROM #invhdr01 '

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the tax record insert
EXEC (@execute_sql)


--	Insert an epicor tax record even though there is no tax
SET @execute_sql = 
	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.arinptax (
		trx_ctrl_num,
		trx_type,
		sequence_id,
		tax_type_code,
		amt_taxable,
		amt_gross,
		amt_tax,
		amt_final_tax )
	SELECT
		trx_ctrl_num,
		trx_type,
		1,
		''NOTAX'',
		0,
		total_amt_gross,
		0,
		0
 FROM #invhdr01 '

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the tax record insert
EXEC (@execute_sql)



-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Insert a FinanceExportarinpage aging record
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET @execute_sql = 
	'INSERT INTO FinanceExportarinpage (
		company_id,
		exported_by,
		date_exported,
		trx_ctrl_num,
		doc_ctrl_num,
		sequence_id,
		apply_to_num,
		apply_trx_type,
		trx_type,
		date_applied,
		date_due,
		date_aging,
		customer_code,
		salesperson_code,
		territory_code,
		price_code,
		amt_due )
	SELECT 
		company_id, ''' +
		@as_userid + ''', ''' + 
		CONVERT(varchar(30), @date_exported, 120) + ''', 
		trx_ctrl_num,
		'''',			--? WH.doc_ctrl_num, why not load this value for this record?
		1,			--? if 1 is OK for a sequence_id here would 1 be acceptable in other instances?
		'''',
		0,
		trx_type,
		julian_applied_date,
		julian_due_date,
		julian_invoice_date,
		epicor_customer_code,
		epicor_salesperson_code,
		epicor_territory_code,
		'''',
		(total_amt_gross - total_amt_discount)
    FROM #invhdr01 
    WHERE trx_type = 2031 '	-- insert only invoice and debit memo transactions.

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'AND company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the aging insert
EXEC (@execute_sql)



--	Insert an epicor aging record
SET @execute_sql = 
	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.arinpage (
		trx_ctrl_num,
		doc_ctrl_num,
		sequence_id,
		apply_to_num,
		apply_trx_type,
		trx_type,
		date_applied,
		date_due,
		date_aging,
		customer_code,
		salesperson_code,
		territory_code,
		price_code,
		amt_due )
	SELECT 
		trx_ctrl_num,
		'''',			--? WH.doc_ctrl_num, why not load this value for this record?
		1,			--? if 1 is OK for a sequence_id here would 1 be acceptable in other instances?
		'''',
		0,
		trx_type,
		julian_applied_date,
		julian_due_date,
		julian_invoice_date,
		epicor_customer_code,
		epicor_salesperson_code,
		epicor_territory_code,
		'''',
		(total_amt_gross - total_amt_discount)
    FROM #invhdr01 
    WHERE trx_type = 2031 '	-- insert only invoice and debit memo transactions.

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'AND company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the aging insert
EXEC (@execute_sql)


-- If we are posting at the company level then we will export a cash payment in the amount
-- of the invoice as a intercompany receivable so that the invoice doesn't appear on the 
-- company level aging report.  #invhdr01 will show a total_amt_payment = total_amt_due due
-- to processing performed in sp_ExportInvoices before this procedure was called.

-- If we are posting at the service level (company = 1) then we will only export a cash
-- payment if cash was received at time of receipt (total_amt_payment > 0).

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Insert a FinanceExportarinptmp aging record
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Commented out on 7/19/2013 because we are no longer exporting the cash received to Epicor.
-- Since JDE cannot accept any payments that are applied to the invoice (at the time of invoicing),
-- we are not going to export the payment information to Epicor either.  JDB
--SET @execute_sql = 
--	'INSERT INTO FinanceExportarinptmp (
--		company_id,
--		exported_by,
--		date_exported,
--		trx_ctrl_num,
--		doc_ctrl_num,
--		trx_desc,
--		date_doc,
--		customer_code,
--		payment_code,
--		amt_payment,
--		prompt1_inp,
--		prompt2_inp,
--		prompt3_inp,
--		prompt4_inp,
--		amt_disc_taken,
--		cash_acct_code ) '

--IF @company_id > 1 
--BEGIN
--	-- Since we are posting at the company level export a cash payment in the amount
--	-- of the invoice as a intercompany receivable.
--	SET @execute_sql = @execute_sql +
--	'SELECT
--		ih.company_id, ''' +
--		@as_userid + ''', ''' + 
--		CONVERT(varchar(30), @date_exported, 120) + ''', 
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Cash Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHECK'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_check + RIGHT('00' + CONVERT(varchar(2), @company_id), 2) + ''' + epicor_posting_code + ''100'' 
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND ih.revision_id = 1
--		AND ih.company_id = ' + CONVERT(varchar(3), @company_id) + ' 
--		AND b.tender_type IN (1, 2)
--	GROUP BY ih.company_id,
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code,
--		ih.epicor_posting_code
--	HAVING SUM(b.cash_received) > 0.00'


--	-- This adds in the portion for credit card payments
--	SET @execute_sql = @execute_sql +
--	'UNION ALL 
--	SELECT
--		ih.company_id, ''' +
--		@as_userid + ''', ''' + 
--		CONVERT(varchar(30), @date_exported, 120) + ''', 
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Credit Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHARGE'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_charge + RIGHT( '00' + CONVERT(varchar(2), @company_id), 2 ) + ''' + epicor_posting_code + ''100'' 
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND ih.revision_id = 1
--		AND ih.company_id = ' + CONVERT(varchar(3), @company_id) + ' 
--		AND b.tender_type = 3
--	GROUP BY ih.company_id,
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code,
--		ih.epicor_posting_code
--	HAVING SUM(b.cash_received) > 0.00 '

--END
--EXEC (@execute_sql)



--SET @execute_sql = 
--	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.arinptmp (
--		trx_ctrl_num,
--		doc_ctrl_num,
--		trx_desc,
--		date_doc,
--		customer_code,
--		payment_code,
--		amt_payment,
--		prompt1_inp,
--		prompt2_inp,
--		prompt3_inp,
--		prompt4_inp,
--		amt_disc_taken,
--		cash_acct_code ) '

--IF @company_id > 1 
--BEGIN
--	-- Since we are posting at the company level export a cash payment in the amount
--	-- of the invoice as a intercompany receivable.
--	SET @execute_sql = @execute_sql +
--	'SELECT
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Cash Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHECK'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_check + RIGHT('00' + CONVERT(varchar(2), @company_id), 2) + ''' + epicor_posting_code + ''100'' 
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND ih.revision_id = 1
--		AND ih.company_id = ' + CONVERT(varchar(3), @company_id) + ' 
--		AND b.tender_type IN (1, 2)
--	GROUP BY ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code,
--		ih.epicor_posting_code
--	HAVING SUM(b.cash_received) > 0.00'


--	-- This adds in the portion for credit card payments
--	SET @execute_sql = @execute_sql +
--	'UNION ALL 
--	SELECT
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Credit Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHARGE'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_charge + RIGHT( '00' + CONVERT(varchar(2), @company_id), 2 ) + ''' + epicor_posting_code + ''100'' 
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND ih.revision_id = 1
--		AND ih.company_id = ' + CONVERT(varchar(3), @company_id) + ' 
--		AND b.tender_type = 3
--	GROUP BY ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code,
--		ih.epicor_posting_code
--	HAVING SUM(b.cash_received) > 0.00 '



--	'SELECT
--	trx_ctrl_num,
--	doc_ctrl_num,
--	''Intercompany Receivable'', ' +
--	CONVERT(varchar(20), @juliantoday) + ',
--	epicor_customer_code,
--	''CHECK'', 
--	total_amt_payment,
--	'''',
--	'''',
--	'''',
--	'''',
--	0, 
--	''01110' + RIGHT( '00' + CONVERT(varchar(2), @company_id), 2 ) + ''' + epicor_posting_code + ''200'' 
--	FROM #invhdr01 
--	WHERE total_amt_payment > 0 
--	AND company_id = ' + CONVERT(varchar(3), @company_id )
--END

---------------------------------------------------------------------
-- This part is not called, because we don't post to company 01.
---------------------------------------------------------------------

--ELSE
--BEGIN
--	-- Since we are posting at the service level (company = 1) we will only export a cash record
--	-- for invoices that have had some cash applied.
--	--   Hard code cash account.  Company_id in the where clause is not needed because #invhdr01 at this time
--	--   only has service level transactions.
--	SET @execute_sql = @execute_sql +
--	'SELECT
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Cash Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHECK'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_check + ''' 
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND b.trans_source <> ''O''
--	GROUP BY ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code 
--	HAVING SUM(b.cash_received) > 0.00
--
--UNION ALL 
--
--	-- This adds in the portion for credit card payments
--	SELECT
--		ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		''Credit Payment'', ' +
--		CONVERT(varchar(20), @juliantoday) + ',
--		ih.epicor_customer_code,
--		''CHARGE'', 
--		SUM(b.cash_received),
--		'''',
--		'''',
--		'''',
--		'''',
--		0, 
--		''' + @cash_acct_charge + '''
--	FROM #invhdr01 ih
--	INNER JOIN Billing b ON ih.invoice_id = b.invoice_id
--	WHERE 1=1
--		AND b.trans_source = ''O''
--	GROUP BY ih.trx_ctrl_num,
--		ih.doc_ctrl_num,
--		ih.epicor_customer_code
--	HAVING SUM(b.cash_received) > 0.00 '
--
--END

--	execute the arinptmp insert
--EXEC (@execute_sql)


--	Update the Epicor accumulated CUSTOMER totals
--		Update an existing accumulation record if one already exists for this customer.
--		Create an accumulation record if one doesn''t already exist for this customer.
--		Update then Insert has to be processed in this order or totaling will be wrong.

--	summarize records by customer to be used for an update in a second
SET @execute_sql = 
	'INSERT #grouptotals (
	group_code,
	group_total_amt )
     SELECT 
	epicor_customer_code,
	SUM(total_amt_gross) - SUM(total_amt_discount)
    FROM #invhdr01 '
IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END

SET @execute_sql = @execute_sql + ' GROUP BY epicor_customer_code'
--	execute the group total insert
EXEC (@execute_sql)


-- Now update or insert as appropriate
SET @execute_sql = 
	'UPDATE ' + @finance_server + '.' + @finance_db + '.dbo.aractcus 
  SET amt_inv_unposted = amt_inv_unposted + GT.group_total_amt
 FROM #grouptotals GT, ' + @finance_server + '.' + @finance_db + '.dbo.aractcus CT
WHERE GT.group_code = CT.customer_code 
   AND EXISTS (SELECT 1 FROM ' + @finance_server + '.' + @finance_db + '.dbo.aractcus SCT WHERE SCT.customer_code = GT.group_code)'
--	execute the update
EXEC (@execute_sql)

-- insert a customer total record for any customer that doesn't already have a balance record
SET @execute_sql = 
	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.aractcus (
	customer_code,
	date_last_inv,
	date_last_cm,
	date_last_adj,
	date_last_wr_off,
	date_last_pyt,
	date_last_nsf,
	date_last_fin_chg,
	date_last_late_chg,
	date_last_comm,
	amt_last_inv,
	amt_last_cm,
	amt_last_adj,
	amt_last_wr_off,
	amt_last_pyt,
	amt_last_nsf,
	amt_last_fin_chg,
	amt_last_late_chg,
	amt_last_comm,
	amt_age_bracket1,
	amt_age_bracket2,
	amt_age_bracket3,
	amt_age_bracket4,
	amt_age_bracket5,
	amt_age_bracket6,
	amt_on_order,
	amt_inv_unposted,
	last_inv_doc,
	last_cm_doc,
	last_adj_doc,
	last_wr_off_doc,
	last_pyt_doc,
	last_nsf_doc,
	last_fin_chg_doc,
	last_late_chg_doc,
	high_amt_ar,
	high_amt_inv,
	high_date_ar,
	high_date_inv,
	num_inv,
	num_inv_paid,
	num_overdue_pyt,
	avg_days_pay,
	avg_days_overdue,
	last_trx_time,
	amt_balance,
	amt_on_acct,
	amt_age_b1_oper,
	amt_age_b2_oper,
	amt_age_b3_oper,
	amt_age_b4_oper,
	amt_age_b5_oper,
	amt_age_b6_oper,
	amt_on_order_oper,
	amt_inv_unp_oper,
	high_amt_ar_oper,
	high_amt_inv_oper,
	amt_balance_oper,
	amt_on_acct_oper,
	last_inv_cur,
	last_cm_cur,
	last_adj_cur,
	last_wr_off_cur,
	last_pyt_cur,
	last_nsf_cur,
	last_fin_chg_cur,
	last_late_chg_cur,
	last_age_upd_date )
     SELECT
	GT.group_code,		--	Epicor customer code
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	GT.group_total_amt,		--	accumulated net
	'''', '''', '''', '''', '''', '''', '''', '''', 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	''USD'', ''USD'', ''USD'', ''USD'', ''USD'', ''USD'', ''USD'', ''USD'', 
	0
 FROM #grouptotals GT
WHERE NOT EXISTS (SELECT 1 FROM ' + @finance_server + '.' + @finance_db + '.dbo.aractcus SCT WHERE SCT.customer_code = GT.group_code) '

--	execute the customer insert
EXEC (@execute_sql)


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Insert the FinanceExportarinpcdt detail records
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

--	Load the invoice detail lines, which will also include the insurance surcharge amount (if any).  The BillingSummary 
--	table will have all of the entries that we need for pupulating the arinpcdt table.
SET @execute_sql = 
	'INSERT INTO FinanceExportarinpcdt (
		company_id,
		exported_by,
		date_exported,
		trx_ctrl_num,
		doc_ctrl_num,
		sequence_id,
		trx_type,
		location_code,
		item_code,
		bulk_flag,
		date_entered,
		line_desc,
		qty_ordered,
		qty_shipped,
		unit_code,
		unit_price,
		unit_cost,
		weight,
		serial_id,
		tax_code,
		gl_rev_acct,
		disc_prc_flag,
		discount_amt,
		commission_flag,
		rma_num,
		return_code,
		qty_returned,
		qty_prev_returned,
		new_gl_rev_acct,
		iv_post_flag,
		oe_orig_flag,
		discount_prc,
		extended_price,
		calc_tax,
		reference_code,
		new_reference_code,
		cust_po )
	SELECT
		company_id, ''' +
		@as_userid + ''', ''' + 
		CONVERT(varchar(30), @date_exported, 120) + ''', 
		trx_ctrl_num,
		'''',		--? Why don''t we load the doc_ctrl_num??
		sequence_id,
		trx_type,	--	2031 or 2032
		'''',		-- Don''t have location code in BillingSummary ... "EQAI-SS", "EQAI-ST", "EQAI-LR", "EQAI-SR"
		'''',		-- Don''t have receipt stuff in summary and even if we did summed records won''t let us produce ... 
				--	String(ll_receipt_id) + "-" + String(ll_line_id) + "-" + String(ll_price_id)
		0, ' +
		CONVERT(varchar(20), @juliantoday) + ',
		'''',		-- no line description in BillingSummary table ... "Insurance Surcharge", "Bundled Transportation", approval description
		CASE trx_type WHEN ''2032'' THEN 0 ELSE 1 END,
		CASE trx_type WHEN ''2032'' THEN 0 ELSE 1 END,
		''EACH'',
		amount,
		0,		-- no unit cost
		0,		-- no weight
		sequence_id,
		''NOTAX'',
		gl_account_code,	--? is the GL account as stored during export going to be good for 01 level?
					--? GL account came from billing table probably for company level
		0,			-- Using fixed discount amount; value = 1 means using percentage amount
		0,			--?  don''t have a discount amount in BS, is this important?  Can amount be net of discount?
		0,
		'''',
		'''',
		CASE trx_type WHEN ''2032'' THEN 1 ELSE 0 END,	-- quantity returned
		0,
		'''',
		1,
		0,
		0,
		amount,
		0,
		reference_code,
		'''',
		''''
 FROM #BillSum01 '

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the aging insert
EXEC (@execute_sql)



--	Load the invoice detail lines, which will also include the insurance surcharge amount (if any).  The BillingSummary 
--	table will have all of the entries that we need for pupulating the arinpcdt table.
SET @execute_sql = 
	'INSERT INTO ' + @finance_server + '.' + @finance_db + '.dbo.arinpcdt (
		trx_ctrl_num,
		doc_ctrl_num,
		sequence_id,
		trx_type,
		location_code,
		item_code,
		bulk_flag,
		date_entered,
		line_desc,
		qty_ordered,
		qty_shipped,
		unit_code,
		unit_price,
		unit_cost,
		weight,
		serial_id,
		tax_code,
		gl_rev_acct,
		disc_prc_flag,
		discount_amt,
		commission_flag,
		rma_num,
		return_code,
		qty_returned,
		qty_prev_returned,
		new_gl_rev_acct,
		iv_post_flag,
		oe_orig_flag,
		discount_prc,
		extended_price,
		calc_tax,
		reference_code,
		new_reference_code,
		cust_po )
	SELECT
		trx_ctrl_num,
		'''',		--? Why don''t we load the doc_ctrl_num??
		sequence_id,
		trx_type,	--	2031 or 2032
		'''',		-- Don''t have location code in BillingSummary ... "EQAI-SS", "EQAI-ST", "EQAI-LR", "EQAI-SR"
		'''',		-- Don''t have receipt stuff in summary and even if we did summed records won''t let us produce ... 
				--	String(ll_receipt_id) + "-" + String(ll_line_id) + "-" + String(ll_price_id)
		0, ' +
		CONVERT(varchar(20), @juliantoday) + ',
		'''',		-- no line description in BillingSummary table ... "Insurance Surcharge", "Bundled Transportation", approval description
		CASE trx_type WHEN ''2032'' THEN 0 ELSE 1 END,
		CASE trx_type WHEN ''2032'' THEN 0 ELSE 1 END,
		''EACH'',
		amount,
		0,		-- no unit cost
		0,		-- no weight
		sequence_id,
		''NOTAX'',
		gl_account_code,	--? is the GL account as stored during export going to be good for 01 level?
					--? GL account came from billing table probably for company level
		0,			-- Using fixed discount amount; value = 1 means using percentage amount
		0,			--?  don''t have a discount amount in BS, is this important?  Can amount be net of discount?
		0,
		'''',
		'''',
		CASE trx_type WHEN ''2032'' THEN 1 ELSE 0 END,	-- quantity returned
		0,
		'''',
		1,
		0,
		0,
		amount,
		0,
		reference_code,
		'''',
		''''
 FROM #BillSum01 '

IF @company_id > 1 
BEGIN
	--	calling procedure wants to work on a company transaction, not corporate
	SET @execute_sql = @execute_sql + 'WHERE company_id = ' + CONVERT(varchar(3), @company_id )
END
--	execute the aging insert
EXEC (@execute_sql)


--	drop the temp table that was created at the start of the procedure
DROP TABLE #grouptotals
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ExportInvoiceRecords] TO [EQAI]
    AS [dbo];

