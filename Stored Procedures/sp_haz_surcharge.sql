
CREATE PROCEDURE sp_haz_surcharge
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS 
/***************************************************************************************
Filename:	F:\EQAI\SQL\EQAI\sp_haz_surcharge.sql
PB Object(s):	d_rpt_haz_surch_accounts
				d_rpt_haz_surch_dollars
		
01/28/1999 SCC	Modified for bill_unit_code size increase
01/27/1999 LT	Retrieve for disposal tickets only
04/12/2004 JDB	Added GRANT statement at bottom.
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table
11/11/2004 MK	Changed generator_code to generator_id
12/13/2004 JDB	Changed Ticket to Billing
03/09/2005 MK	Added Generator EPA_ID and join to Generator table
10/07/2005 LJT	Changed Billing Date to Invoice date
02/15/2006 rg   added profit center info to select list
09/29/2010 SK	Modified the report to take company ID as input argument.
		moved to Plt_AI
10/01/2010 SK	Modified the report to run for:
				1. All Companies- all profit centers
				2. selected company- all profit centers
				3. a facility : selected company-selected profit center		
01/12/2011 SK	Changed to use sr_extended_amt from BillingDetail instead of Billing
04/15/2011 RB	Changed where clause from billing_type = 'State' to billing_type = 'State-Haz'
09/18/2012 DZ	Changed where clause to use billing_uid
				Changed where clause to include 'MITAXHAZ' product
04/08/2014 JDB	Modified to exclude transactions that have already been invoiced on invoices
				before the @date_from.  Gemini 28271.
04/15/2014 SM	Modified to match with sp_haz_surcharge_gl procedure. 


sp_haz_surcharge   21, 0, '01/01/2013', '01/31/2013'
sp_haz_surcharge	14, 04, '2009-08-01', '2009-08-31'
sp_haz_surcharge	2, 21, '2010-06-01', '2010-06-15'
****************************************************************************************/
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT  
		Billing.receipt_id,
		Billing.line_id,
		Billing.price_id,
		Billing.billing_date,   
		Billing.customer_id,   
		w.display_name as waste_code,   
		Billing.bill_unit_code,   
		Billing.generator_id,   
		Billing.generator_name,   
		Billing.approval_code,   
		Billing.quantity,   
		Billing.gl_sr_account_code,   
		Billing.sr_type_code,   
		IsNull( Product.price, Billing.sr_price ) AS sr_price,   -- sagar changed
		IsNull(BillingDetail.extended_amt, 0.000) AS sr_extended_amt,
		Billing.manifest,   
		Customer.cust_name,
		BillUnit.bill_unit_desc,
		Generator.epa_id,
		Company.company_id,   
		Company.company_name,   
		PC.profit_ctr_id,
		PC.profit_ctr_name,
		PC.address_1 AS address_1,
		PC.address_2 AS address_2,
		PC.address_3 AS address_3,
		PC.EPA_ID AS profit_ctr_epa_ID,
		Product.product_id   -- sagar added
	FROM Billing (NOLOCK)
	JOIN Company (NOLOCK)
		ON Company.company_id = Billing.company_id
	JOIN ProfitCenter PC (NOLOCK)
		ON PC.company_ID = Billing.company_id
		AND PC.profit_ctr_ID = Billing.profit_ctr_id
		AND PC.status = 'A'
	JOIN Customer (NOLOCK)
		ON Customer.customer_id = Billing.customer_id
	JOIN BillUnit (NOLOCK)
		ON BillUnit.bill_unit_code = Billing.bill_unit_code
	LEFT OUTER JOIN WasteCode w (NOLOCK)
		ON w.waste_code_uid = Billing.waste_code_uid
	JOIN Generator (NOLOCK)
		ON Generator.generator_id = Billing.generator_id
	LEFT OUTER JOIN BillingDetail (NOLOCK)
		ON BillingDetail.billing_uid = Billing.billing_uid
		AND ((BillingDetail.billing_type = 'State-Haz')
			OR
			(BillingDetail.billing_type = 'Product'
			AND EXISTS ( SELECT 1 
						 FROM Product p (NOLOCK)
						WHERE p.product_code = 'MITAXHAZ'
						  AND p.product_id = BillingDetail.product_id
						  AND p.company_id = BillingDetail.company_id
						  AND p.profit_ctr_id = BillingDetail.profit_ctr_id
						)
			)
			)
	LEFT OUTER JOIN Product  -- sagar added
		ON BillingDetail.billing_type = 'Product'
		AND BillingDetail.product_id = Product.product_ID
	WHERE ( @company_id = 0 OR Billing.company_id = @company_id )
		AND (@company_id = 0 OR @profit_ctr_id = -1 OR Billing.profit_ctr_id = @profit_ctr_id )
		AND Billing.status_code = 'I'
		AND Billing.void_status = 'F'
		AND Billing.trans_source = 'R'			-- Report should only return records from Receipts - sagar
		AND Billing.trans_type = 'D'
		AND ( Billing.invoice_date BETWEEN @date_from AND @date_to ) 
		AND ( Billing.sr_type_code = 'H' OR Billing.sr_type_code = 'E')
		AND NOT EXISTS (SELECT 1
			FROM InvoiceDetail id (NOLOCK)
			JOIN InvoiceHeader ih (NOLOCK) ON ih.invoice_id = id.invoice_id
				AND ih.revision_id = id.revision_id
				AND ih.status IN ('I', 'O')
				AND ih.invoice_date < @date_from
			WHERE id.company_id = Billing.company_id
			AND id.profit_ctr_id = Billing.profit_ctr_id
			AND id.trans_source = Billing.trans_source
			AND id.receipt_id = Billing.receipt_id
			AND id.line_id = Billing.line_id
			AND id.price_id = Billing.price_id
			)
		AND EXISTS (SELECT 1                           -- sagar added this entire condition
			FROM ReceiptWasteCode rwc
			JOIN WasteCode wc ON wc.waste_code_uid = rwc.waste_code_uid
				AND ((wc.waste_code_origin = 'F')
					OR (wc.waste_code_origin = 'S' AND wc.state = 'MI'))
				AND wc.haz_flag = 'T'
			WHERE rwc.company_id = Billing.company_id
			AND rwc.profit_ctr_id = Billing.profit_ctr_id
			AND rwc.receipt_id = Billing.receipt_id
			AND rwc.line_id = Billing.line_id
			)
	ORDER BY 
		Billing.generator_id ASC,
		Billing.manifest ASC   
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_haz_surcharge] TO [EQAI]
    AS [dbo];
GO
