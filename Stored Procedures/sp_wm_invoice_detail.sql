
CREATE PROCEDURE sp_wm_invoice_detail (
	@invoice_code varchar(16)
)
AS
/* *************************************
sp_wm_invoice_detail
  WM-formatted export of invoice detail data.
  Accepts input: 
      invoice_code to view

10/27/2010 - JPB - Created
01/21/2011 - JPB - Tweaked to use Billing for receipt/workorder SUMming.

exec sp_wm_invoice_detail '40282290'
exec sp_wm_invoice_detail '40488370'

select distinct billing_project_id from billing where invoice_code = '40282291'

select * from WalmartBillingAccount where billing_project_id = 3996

************************************* */

SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	ih.invoice_date AS Invoice_Date
	, ih.invoice_id
	, ISNULL(wbaS.wm_division_id, wbaNS.wm_division_id) AS Division
	, g.site_code AS Store_Number
	, ISNULL(wbaS.wm_account_id, wbaNS.wm_account_id) AS Account_Number
	, ih.invoice_code AS Invoice_Number
	, 257170 AS Vendor_Number
	, '' AS Imaging_ID
	, (
		SELECT SUM(waste_extended_amt) 
		FROM billing b 
		WHERE b.invoice_code = ih.invoice_code 
		AND b.status_code = 'I'	
		AND b.trans_source = 'R' 
		AND b.trans_type = 'D' 
		AND b.generator_id = id.generator_id
		) AS Material
	, (
		SELECT SUM(waste_extended_amt) 
		-- was total_extended_amt: should be same value for WO's either way.
		FROM billing b 
		WHERE b.invoice_code = ih.invoice_code 
		AND b.status_code = 'I'	
		AND (b.trans_source = 'W'
			OR
			(b.trans_source = 'R' and b.trans_type <> 'D')
		)
		AND b.generator_id = id.generator_id
		) AS Labor
	, 0 AS Shipping
	, (
		SELECT SUM(total_extended_amt) 
		FROM billing b WHERE b.invoice_code = ih.invoice_code 
		AND b.generator_id = id.generator_id 
		AND b.status_code = 'I' 
		AND b.trans_source IN ('R', 'W')
	    ) AS Invoice_SubTotal
	, (
		SELECT SUM(sr_extended_amt + insr_extended_amt + ensr_extended_amt) 
		FROM billing b 
		WHERE b.invoice_code = ih.invoice_code 
		AND b.generator_id = id.generator_id 
		AND b.status_code = 'I' 
		AND b.trans_source IN ('R', 'W')
		) AS Tax
	, (
		SELECT SUM(
			waste_extended_amt + 
			sr_extended_amt + 
			insr_extended_amt + 
			ensr_extended_amt) 
		FROM billing b 
		WHERE b.invoice_code = ih.invoice_code 
		AND b.generator_id = id.generator_id 
		AND b.status_code = 'I' 
		AND b.trans_source IN ('R', 'W')
		) AS Total_Invoice_Cost
	, ISNULL(wbaS.billing_project_comment, wbaNS.billing_project_comment) AS Comment
FROM InvoiceDetail id
INNER JOIN InvoiceHeader ih 
	ON id.invoice_id = ih.invoice_id 
	AND id.revision_id = ih.revision_id
LEFT OUTER JOIN Generator g 
	ON id.generator_id = g.generator_id
LEFT OUTER JOIN WalmartBillingAccount wbaS 
	ON id.billing_project_id = wbaS.billing_project_id 
	AND g.site_type = wbaS.site_type
LEFT OUTER JOIN WalmartBillingAccount wbaNS 
	ON id.billing_project_id = wbaNS.billing_project_id 
	AND g.site_type <> wbaNS.site_type
WHERE 1=1
AND ih.invoice_code = @invoice_code
AND ih.status = 'I'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_detail] TO [EQAI]
    AS [dbo];

