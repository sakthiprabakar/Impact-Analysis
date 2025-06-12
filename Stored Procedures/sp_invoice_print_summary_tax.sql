CREATE PROCEDURE sp_invoice_print_summary_tax 
	@invoice_id		int,
	@revision_id	int
AS
/**************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_invoice_print_summary_tax.sql
PB Object(s):	d_invoice_print_summary_tax

09/19/2011 JDB	Created to get the sales tax record(s) from InvoiceDetail for an invoice.
				(There can be multiples; not likely, but possible)
06/18/2015 RB   set transaction isolation level read uncommitted

sp_invoice_print_summary_tax 777972, 1
***************************************************************************************/

set transaction isolation level read uncommitted

SELECT InvoiceDetail.invoice_id, 
	InvoiceDetail.revision_id, 
	InvoiceHeader.invoice_code, 
	InvoiceDetail.line_desc_1, 
	SUM(InvoiceDetail.extended_amt) AS extended_amt
FROM InvoiceDetail
JOIN InvoiceHeader ON InvoiceHeader.invoice_id = InvoiceDetail.invoice_id
	AND InvoiceHeader.revision_id = InvoiceDetail.revision_id
WHERE InvoiceDetail.invoice_id = @invoice_id	
AND InvoiceDetail.revision_id = @revision_id
AND InvoiceDetail.sr_type_code = 'T'				-- 'T' is for tax
GROUP BY InvoiceDetail.invoice_id, InvoiceDetail.revision_id, InvoiceHeader.invoice_code, InvoiceDetail.line_desc_1
ORDER BY InvoiceDetail.invoice_id, InvoiceDetail.revision_id, InvoiceHeader.invoice_code, InvoiceDetail.line_desc_1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_summary_tax] TO [EQAI]
    AS [dbo];

