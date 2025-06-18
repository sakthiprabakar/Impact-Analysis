CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_billing_adjustments_processed_report]
	 @company_id INTEGER
	, @profit_ctr_id INTEGER
	, @date_modified_from DATETIME
	, @date_modified_to DATETIME
	, @invoice_date_from DATETIME
	, @invoice_date_to DATETIME
	, @customer_id_from INTEGER
	, @customer_id_to INTEGER 
	, @invoice_id_from VARCHAR(12)
	, @invoice_id_to VARCHAR(12)
     
AS  
/***********************************************************************************
sp_rpt_billing_adjustments_processed_report
Loads to : PLT_AI  
Modifications:  
03/02/2025 KS Rally US126547 - Created  
  
EXEC sp_rpt_billing_adjustments_processed_report 74, 87, '25 feb 2025', '26 feb 2025', '21 aug 2024', '21 aug 2024', 3770, 3770, '1094258', '1094258'
***********************************************************************************/  
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT DISTINCT b.company_id
		, b.profit_ctr_id
		, b.trans_source
		, b.receipt_id
		, b.line_id
		, b.price_id
		, b.invoice_id
		, b.invoice_code
		, b.invoice_date
		, b.billing_date
		, b.service_desc_1
		, ba.column_name
		, ba.before_value
		, ba.after_value
		, CASE WHEN TRIM(ba.column_name) IN(TRIM('extended_amt'),
											TRIM('bundled_tran_extended_amt'),
											TRIM('Disposal extended_amt'),
											TRIM('Energy extended_amt'),
											TRIM('ensr_extended_amt'),
											TRIM('extended_amt'),
											TRIM('FRF extended_amt'),
											TRIM('frf_extended_amt'),
											TRIM('insr_extended_amt'),
											TRIM('Insurance extended_amt'),
											TRIM('orig_extended_amt'),
											TRIM('Product extended_amt'),
											TRIM('Retail extended_amt'),
											TRIM('sales_tax_amt'),
											TRIM('SalesTax extended_amt'),
											TRIM('sr_extended_amt'),
											TRIM('State-Haz extended_amt'),
											TRIM('State-Perp extended_amt'),
											TRIM('total_extended_amt'),
											TRIM('waste_extended_amt'),
											TRIM('WorkOrder extended_amt')
										)
				THEN ISNULL(TRY_PARSE(REPLACE(ba.after_value, ',', '') AS DECIMAL(18, 2)) - TRY_PARSE(REPLACE(ba.before_value, ',', '') AS DECIMAL(18, 2)), 0.00)
				ELSE 0.00
		  END AS change_amt
		, TRIM(ba.trans_source) + ' ' + CONVERT(VARCHAR(20), ba.company_id) + '-' + CONVERT(VARCHAR(20), ba.profit_ctr_id) + ' ' + CONVERT(VARCHAR(20), ba.receipt_id) + 
			CASE WHEN ba.line_id IS NULL 
			THEN '' 
			ELSE '-' + CONVERT(VARCHAR(20), ba.line_id) + (CASE WHEN ba.price_id IS NULL 
																THEN '' 
																ELSE '-' + CONVERT(VARCHAR(20), ba.price_id) 
														   END) END AS ids_billrecs_row
		, b.customer_id
		, c.cust_name AS customer_name
		, ah.adjustment_id
		, bar.reason_desc
		, b.currency_code
		, u.user_name
		, ba.date_modified
	FROM dbo.Billing b
	JOIN dbo.BillingAudit ba
	ON ba.company_id = b.company_id
	AND ba.profit_ctr_id = b.profit_ctr_id
	AND ba.line_id = b.line_id
	AND ba.price_id = b.price_id
	AND ba.receipt_id = b.receipt_id
	AND ba.trans_source = b.trans_source
	JOIN dbo.Customer c
	ON c.customer_ID = b.customer_id
	JOIN dbo.AdjustmentHeader ah
	ON ah.adjustment_id = ba.billing_summary_id
	JOIN dbo.BillingAdjustmentReason bar
	ON bar.reason_id = ah.adj_reason_code
	JOIN dbo.Users u
	ON u.user_code = ba.modified_by
	WHERE (@company_id = 0 OR b.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR b.profit_ctr_id = @profit_ctr_id)
	AND ba.date_modified BETWEEN @date_modified_from AND @date_modified_to
	AND b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to
	AND b.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND b.invoice_code BETWEEN @invoice_id_from AND @invoice_id_to
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_billing_adjustments_processed_report] TO [EQAI]
GO