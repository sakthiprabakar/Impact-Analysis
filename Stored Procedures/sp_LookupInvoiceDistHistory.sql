--Rally # US129919
USE [PLT_AI]
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_LookupInvoiceDistHistory]
AS
/***********************************************************************
This SP is called from EQAI w_invoice_print_view.  The user has the ability to select multiple 
invoices for printing, which don't have to be in a neat range of invoice_codes.  
As such a temporary table #InvoiceDistHistory will be populated with the required columns for 
all user selected invoices.  This procedure will then use this temp table to return a result 
set that can be used by w_invoice_print_status screen.

This sp is loaded to Plt_AI.

02/05/2025 Sailaja Created

To test:
DROP Table #InvoiceDistHistory
CREATE TABLE #InvoiceDistHistory ( invoice_id int, invoice_code varchar(16), revision_id int, 
customer_id int, cust_name varchar(40),customer_type varchar(20),contact_name varchar(40),
contact_company varchar(40),contact_email varchar(60), dist_method_desc varchar(30) )

INSERT INTO #InvoiceDistHistory
VALUES ( )

EXEC sp_LookupInvoiceDistHistory
***********************************************************************/
BEGIN

SET NOCOUNT ON

SELECT	IDH.invoice_id,
IDH.invoice_code,
IDH.revision_id,
IDH.customer_id,
IDH.cust_name,
IDH.customer_type,
IDH.contact_name,
IDH.contact_company,
IDH.contact_email,
IDH.dist_method_desc,
IDH.comments
FROM #InvoiceDistHistory IDH
ORDER BY IDH.dist_method_desc, IDH.invoice_code, IDH.revision_id, IDH.customer_id desc


END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LookupInvoiceDistHistory] TO [EQAI];
GO
