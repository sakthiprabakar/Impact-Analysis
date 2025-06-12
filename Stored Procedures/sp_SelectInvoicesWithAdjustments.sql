--drop proc sp_SelectInvoicesWithAdjustments 
--go
CREATE PROCEDURE sp_SelectInvoicesWithAdjustments 
	@as_where_clause varchar(1024), 
	@ai_debug int = 0
AS
/***********************************************************************
This SP is called from w_invoice_processing to retrieve invoice records when the user
wishes to process invoices with pending adjustments.  A simple select won't return the
proper result set as there could be many revisions of an invoice with many adjustments.
SUMming and MAXing needs to be managed in order to get the proper result set.

This sp is loaded to Plt_AI.

08/02/2007 WAC	Created
10/18/2007 WAC	Enhanced for invoice adjustment processing.
01/02/2008 WAC	When updating the #comment table, billing records with the status of 'V' (void)
		are now ignored.
01/31/2018 MPM	Added currency_code to the final result set.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
10/17/2019 AM DevOps-12575 - Remove hold (H) invoices from #AdjustedInvoices along with preview invoices.
   Hold invoices already invoiced. Re-retrieving is causing an issue.

EXEC sp_SelectInvoicesWithAdjustments 'invoice_id=431305', 0
EXEC sp_SelectInvoicesWithAdjustments '', 0
***********************************************************************/
BEGIN

DECLARE @execute_sql	varchar(8000)

CREATE TABLE #AdjustedInvoices (
	invoice_id int NULL,
	revision_id int NULL,
	status char(1) NULL,
	invoice_code varchar(16) NULL,
	invoice_date datetime NULL,
	customer_id int NULL,
	total_amt_due money NULL,
	terms_code varchar(8)NULL,
	due_date datetime NULL,
	cust_name varchar(75) NULL,
	bill_to_cust_name varchar(75) NULL,
	bill_to_addr1 varchar(75) NULL,
	bill_to_addr2 varchar(75) NULL,
	bill_to_addr3 varchar(75) NULL,
	bill_to_addr4 varchar(75) NULL,
	bill_to_addr5 varchar(75) NULL,
	bill_to_city varchar(40) NULL,
	bill_to_state varchar(2) NULL,
	bill_to_zip_code varchar(15) NULL,
	bill_to_country varchar(40) NULL,
	adjustment_amt money NULL,
	ok_to_invoice varchar(1) NULL,
	popup_comment varchar(255) NULL,
	currency_code char(3) NULL )

CREATE TABLE #InvoiceAdjAmts (
	invoice_id int NULL,
	adjustment_amt money NULL )

CREATE TABLE #CommentData (
	invoice_id int NULL,
	revision_id int NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	trans_source varchar(1) NULL,
	receipt_id int NULL,
	record_count int NULL,
	billing_status varchar(1) NULL)

--	Select invoices that have pending adjustments
SET @execute_sql = 
'INSERT INTO #AdjustedInvoices (
	invoice_id,
	revision_id,
	status,
	invoice_code,
	invoice_date,
	customer_id,
	total_amt_due,
	terms_code,
	due_date,
	ok_to_invoice,
	currency_code )
  SELECT InvoiceHeader.invoice_id,   
         InvoiceHeader.revision_id,   
         InvoiceHeader.status,   
         InvoiceHeader.invoice_code,   
         InvoiceHeader.invoice_date,   
         InvoiceHeader.customer_id,   
         InvoiceHeader.total_amt_due,   
         InvoiceHeader.terms_code,   
         InvoiceHeader.due_date,
	 ''T'',
		InvoiceHeader.currency_code
FROM InvoiceHeader
WHERE 1=1
AND EXISTS (SELECT 1 FROM AdjustmentDetail 
		WHERE AdjustmentDetail.invoice_id = InvoiceHeader.invoice_id 
		AND   AdjustmentDetail.export_required = ''W'' )
AND InvoiceHeader.revision_id = (SELECT MAX( IH.revision_id )
				FROM InvoiceHeader IH WHERE IH.invoice_id = InvoiceHeader.invoice_id) '

IF @as_where_clause <> ''
BEGIN
--	call routine passed a where clause that needs to be appended
	IF UPPER(LEFT( LTRIM(@as_where_clause), 3 )) <> 'AND' SET @execute_sql = @execute_sql + ' AND '
	SET @execute_sql = @execute_sql + @as_where_clause
END

IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + @execute_sql
EXEC (@execute_sql)

--	If we put a preview invoice in the temp table then remove it because a preview invoice
--	indicates that "waiting" adjustments have already been selected for invoicing.
--   DevOps-12575 - Added H
 DELETE FROM #AdjustedInvoices WHERE status in ('P','H')


--	Now update the customer infomation fields in the temp table for the invoices that
--	were just selected that have pending adjustments
UPDATE #AdjustedInvoices
SET	cust_name = C.cust_name,
	bill_to_cust_name = C.bill_to_cust_name,
	bill_to_addr1 = C.bill_to_addr1,
	bill_to_addr2 = C.bill_to_addr2,
	bill_to_addr3 = C.bill_to_addr3,
	bill_to_addr4 = C.bill_to_addr4,
	bill_to_addr5 = C.bill_to_addr5,
	bill_to_city = C.bill_to_city,
	bill_to_state = C.bill_to_state,
	bill_to_zip_code = C.bill_to_zip_code,
	bill_to_country = C.bill_to_country
FROM #AdjustedInvoices AI, Customer C
WHERE AI.customer_id = C.customer_id

--	Populate the unprocessed (waiting) adjustment amount for the invoice
--	sum the amounts to a temporary table
INSERT INTO #InvoiceAdjAmts
SELECT AI.invoice_id,
	SUM(AD.adj_amt)
FROM #AdjustedInvoices AI, AdjustmentDetail AD
WHERE AI.invoice_id = AD.invoice_id 
AND AD.export_required = 'W'
GROUP BY AI.invoice_id
--	apply amounts from the temp table to the table we are populating
UPDATE #AdjustedInvoices
SET adjustment_amt = IAA.adjustment_amt
FROM #AdjustedInvoices AI, #InvoiceAdjAmts IAA
WHERE AI.invoice_id = IAA.invoice_id

--	Now we need to make sure that the invoices with adjustments that we are about to return are
--	indeed ready to invoice.  If a pending adjustment is for a transaction that has been
--	unsubmitted for further edits and the transaction has not been resubmitted yet then we need
--	to indicate this in the result set.  In addition, a transaction could have been resubmitted
--	but does not have the proper status for invoicing.
INSERT INTO #CommentData (
	invoice_id,
	revision_id,
	company_id,
	profit_ctr_id,
	trans_source,
	receipt_id,
	record_count )
SELECT 
ai.invoice_id, 
ai.revision_id, 
bc.company_id, 
bc.profit_ctr_id, 
bc.trans_source, 
bc.receipt_id,
0
FROM #AdjustedInvoices ai
JOIN BillingComment bc ON bc.invoice_id = ai.invoice_id
WHERE bc.receipt_status <> 'V'

UPDATE #CommentData
SET record_count = (SELECT Count(*) FROM Billing b WHERE b.company_id = #CommentData.company_id AND b.profit_ctr_id = #CommentData.profit_ctr_id AND b.trans_source = #CommentData.trans_source AND b.receipt_id = #CommentData.receipt_id AND b.status_code <> 'V')

--	For those comment records that have  record_count > 0 we need to populate the billing_status field
UPDATE #CommentData
SET billing_status = b.status_code
FROM #CommentData cd
JOIN Billing b ON b.company_id = cd.company_id 
	AND b.profit_ctr_id = cd.profit_ctr_id 
	AND b.trans_source = cd.trans_source 
	AND b.receipt_id = cd.receipt_id
	AND b.status_code <> 'V'
WHERE record_count > 0

--  #CommentData now has record_count and status_code loaded for each transaction found in BillingComment
--  for invoices with adjustments.  We need to make sure that if a transaction doesn't have the right 
--  status or there are no matching Billing records that the result set indicates such.  First error in
--  wins.

--  Every billing record that is being processed for this adjusted invoice has to have a stats of 'I'
UPDATE #AdjustedInvoices
SET ok_to_invoice = 'F',
popup_comment = CASE WHEN cd.trans_source = 'W' THEN 'Workorder ' ELSE 'Receipt ' END
		+ Convert( varchar(12), cd.receipt_id )
		+ ' has not been resubmitted for invoice processing.  Please submit and validate this transaction before you attempt to process the adjustments for this invoice.'
FROM #AdjustedInvoices ai 
JOIN #CommentData cd ON cd.invoice_id = ai.invoice_id AND cd.revision_id = ai.revision_id
WHERE cd.record_count = 0 AND ai.ok_to_invoice = 'T'

--  Every billing record that is being processed for this adjusted invoice has to have a stats of 'I'
UPDATE #AdjustedInvoices
SET ok_to_invoice = 'F',
popup_comment = CASE WHEN cd.trans_source = 'W' THEN 'Workorder ' ELSE 'Receipt ' END
		+ Convert( varchar(12), cd.receipt_id )
		+ ' does not have the correct status for invoicing.  Try validating the transaction before you attempt to process the adjustments for this invoice.'
FROM #AdjustedInvoices ai 
JOIN #CommentData cd ON cd.invoice_id = ai.invoice_id AND cd.revision_id = ai.revision_id
WHERE cd.billing_status <> 'I' AND ai.ok_to_invoice = 'T'

-- return the result set
SELECT * FROM #AdjustedInvoices
ORDER BY cust_name, invoice_date

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_SelectInvoicesWithAdjustments] TO [EQAI]
    AS [dbo];

