CREATE PROCEDURE sp_rpt_invoices_created (
	  @start_date_from	datetime
	, @end_date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

09/27/2017 AM	Created.  	

EXECUTE sp_rpt_invoices_created  '2017-09-01', '2017-09-30'
*************************************************************************************************/
SELECT 
 ih.invoice_date,
 ih.invoice_code,
 ih.revision_id,
 ih.status,
 ih.total_amt_due,
 ih.customer_id,
 c.cust_name,
 ih.date_added
FROM invoiceheader ih 
INNER JOIN Customer C on ih.customer_id = C.customer_id
WHERE ih.date_added >= @start_date_from 
AND ih.date_added <=  @end_date_to
order by ih.invoice_code, ih.revision_id desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoices_created] TO [EQAI]
    AS [dbo];

