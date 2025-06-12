USE PLT_AI
GO
CREATE OR ALTER PROCEDURE sp_rpt_eBilled_invoices
	@customer_id	int
,	@date_from		datetime
,	@date_to		datetime
AS
/***************************************************************************************
r_eBilled_invoices

07/18/2018 AM	Created - EQAI-49342  eBill report
09/05/2024 Subhrajyoti - Rally#US120412 - Update Request for EQAI Ebill Report

sp_rpt_eBilled_invoices 3260,'2018-01-01','2019-02-01'
sp_rpt_eBilled_invoices null,'2018-01-01','2018-02-01'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN
	IF @customer_id = 0
		SET @customer_id = -99999

	SELECT DISTINCT 
		ih.customer_id, 
		ih.cust_name, 
		ih.invoice_code, 
		ih.status, 
		ih.invoice_date, 
		ih.total_amt_due,
		ih.revision_id,
		cb.distribution_email_id
	FROM customerbilling cb (NOLOCK)
	JOIN invoiceheader ih (NOLOCK)
	ON cb.customer_id = ih.customer_id 
	JOIN invoicedetail id (NOLOCK)
	ON ih.invoice_id = id.invoice_id 
	AND id.billing_project_id = cb.billing_project_id 
	AND ih.revision_id = id.revision_id
	WHERE cb.ebilling_flag = 'T'
	AND ih.status = 'I'
	AND ih.invoice_date BETWEEN @date_from AND @date_to
	AND (ih.customer_id = @customer_id OR @customer_id = -99999) 
END
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_eBilled_invoices] TO [EQAI]
    AS [dbo];

