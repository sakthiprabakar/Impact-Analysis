CREATE PROCEDURE sp_invoice_print_summary 
	@invoice_id		int,
	@revision_id	int
AS
/**************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_invoice_print_summary.sql
PB Object(s):	d_invoice_print_summary

01/09/2007 RG	Created for new invoice printing 
04/16/2008 KAM	Updated to select and return the Retail Order Total
09/09/2008 JDB	Updated to select and return the Energy Surcharge Total
10/06/2010 JDB	Updated to select and return the Sales Tax Total
09/19/2011 JDB	Kept total sales tax amount here; created sp_invoice_print_summary_tax to 
				get the individual sales tax amounts.  (No real change to this SP.)
01/13/2015 AM   Combined both insurance and energy charges.
06/18/2015 RB   set transaction isolation level read uncommitted
06/14/2017 MPM	Updated total_disposal, total_project and amt_retail by adding back in 
				any discount that was applied.
06/04/2018 - AM - GEM:47960 - Invoice Print - Added currency code to printed document.
12/02/2022 AGC  DevOps 57362 added ERF and FRF
12/02/2022 AGC  DevOps 58558 added InvoiceHeader.status to return set to determine
				whether to print ERF/FRF disclaimer on the invoice

SELECT * FROM InvoiceHeader WHERE invoice_id = 777972

sp_invoice_print_summary 777972, 1
sp_invoice_print_summary 1248569, 1
***************************************************************************************/

set transaction isolation level read uncommitted

SELECT 	InvoiceHeader.invoice_code,
	0 AS posting_code,
	InvoiceHeader.customer_id, 
	CONVERT(datetime,InvoiceHeader.invoice_date) AS date_doc,
	CONVERT(money, InvoiceHeader.total_amt_gross) AS amt_gross, 
	CONVERT(money, InvoiceHeader.total_amt_discount) AS amt_discount, 
	CONVERT(money, InvoiceHeader.total_amt_due)	AS amt_due, 
	InvoiceHeader.days_due, 
	CONVERT(money, InvoiceHeader.total_amt_payment) AS amt_payment, 
	CONVERT(money, InvoiceHeader.total_amt_disposal) + ISNULL(CONVERT(money, (SELECT SUM(disc_amount) FROM InvoiceBillingDetail WHERE invoice_id = @invoice_id AND revision_id = @revision_id AND trans_source = 'R')),0) AS total_disposal,
	CONVERT(money, InvoiceHeader.total_amt_project) + ISNULL(CONVERT(money, (SELECT SUM(disc_amount) FROM InvoiceBillingDetail WHERE invoice_id = @invoice_id AND revision_id = @revision_id AND trans_source = 'W')),0) AS total_project, 
	0 AS amt_insurance,
	CONVERT(money, InvoiceHeader.total_amt_insurance + InvoiceHeader.total_amt_energy) AS amt_energy,
	CONVERT(money, InvoiceHeader.total_amt_disposal) AS amt_disposal,
	CONVERT(money, InvoiceHeader.total_amt_project) AS amt_project, 
	CONVERT(money, InvoiceHeader.total_amt_srcharge_h) AS amt_srcharge_h,
	CONVERT(money, InvoiceHeader.total_amt_srcharge_p) AS amt_srcharge_p,
	InvoiceHeader.due_date AS due_date,
	ISNULL(CONVERT(money,(SELECT SUM(extended_amt) FROM InvoiceDetail WHERE invoice_id = @invoice_id AND revision_id = @revision_id AND trans_source = 'O')),0) + ISNULL(CONVERT(money, (SELECT SUM(disc_amount) FROM InvoiceBillingDetail WHERE invoice_id = @invoice_id AND revision_id = @revision_id AND trans_source = 'O')),0) AS amt_retail,
	--New way, once InvoiceHeader has the total_amt_sales_tax field
	CONVERT(money, InvoiceHeader.total_amt_sales_tax) AS amt_sales_tax,
	InvoiceHeader.currency_code, 
	CONVERT(money, InvoiceHeader.total_amt_erf + InvoiceHeader.total_amt_frf) AS amt_erf_frf, 
	InvoiceHeader.status 
FROM InvoiceHeader
WHERE InvoiceHeader.invoice_id = @invoice_id	
AND InvoiceHeader.revision_id = @revision_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_summary] TO [EQAI]
    AS [dbo];

