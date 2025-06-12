CREATE PROCEDURE sp_invoice_print_summary_sales_tax 
	@invoice_id		int,
	@revision_id	int
AS
/**************************************************************************************
Filename:		L:\Apps\SQL\EQAI\Plt_AI\Procedures\sp_invoice_print_summary_sales_tax.sql
PB Object(s):	d_invoice_print_summary

09/01/2010 JDB	Copied from sp_invoice_print_summary, and created specifically
				for printing invoices with NY sales tax

sp_invoice_print_summary_sales_tax 690383, 1
***************************************************************************************/
SELECT 	InvoiceHeader.invoice_code,
	0 AS posting_code,
	InvoiceHeader.customer_id, 
	CONVERT(datetime,InvoiceHeader.invoice_date) AS date_doc,
	CONVERT(money, InvoiceHeader.total_amt_gross) AS amt_gross, 
	CONVERT(money, InvoiceHeader.total_amt_discount) AS amt_discount, 
	CONVERT(money, InvoiceHeader.total_amt_due) AS amt_due, 
	InvoiceHeader.days_due, 
	CONVERT(money, InvoiceHeader.total_amt_payment) AS amt_payment, 
	CONVERT(money, InvoiceHeader.total_amt_disposal) AS total_disposal,
	CONVERT(money, InvoiceHeader.total_amt_project) AS total_project, 
	CONVERT(money, InvoiceHeader.total_amt_insurance) AS amt_insurance,
	CONVERT(money, InvoiceHeader.total_amt_energy) AS amt_energy,
	CONVERT(money, InvoiceHeader.total_amt_disposal) AS amt_disposal,
	CONVERT(money, InvoiceHeader.total_amt_project) AS amt_project, 
	CONVERT(money, InvoiceHeader.total_amt_srcharge_h) AS amt_srcharge_h,
	CONVERT(money, InvoiceHeader.total_amt_srcharge_p) AS amt_srcharge_p,
	InvoiceHeader.due_date AS due_date,
	CONVERT(money,(SELECT SUM(extended_amt) 
		FROM InvoiceDetail 
		WHERE invoice_id = @invoice_id 
		AND revision_id = @revision_id 
		AND trans_source = 'O'
		)) AS amt_retail,
	(SELECT SUM(BillingDetail.extended_amt) 
		FROM BillingDetail
		INNER JOIN InvoiceDetail ON BillingDetail.company_id = InvoiceDetail.company_id
			AND BillingDetail.profit_ctr_id = InvoiceDetail.profit_ctr_id
			AND BillingDetail.receipt_id = InvoiceDetail.receipt_id
			AND BillingDetail.line_id = InvoiceDetail.line_id
			AND BillingDetail.price_id = InvoiceDetail.price_id
		WHERE billing_type = 'SalesTax'
		AND InvoiceDetail.invoice_id = @invoice_id 
		AND InvoiceDetail.revision_id = @revision_id 
		) AS amt_sales_tax
INTO #tmp
FROM InvoiceHeader
WHERE InvoiceHeader.invoice_id = @invoice_id	
AND InvoiceHeader.revision_id = @revision_id

UPDATE #tmp SET amt_gross = amt_gross + amt_sales_tax,
	amt_due = amt_due + amt_sales_tax

SELECT * FROM #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_summary_sales_tax] TO [EQAI]
    AS [dbo];

