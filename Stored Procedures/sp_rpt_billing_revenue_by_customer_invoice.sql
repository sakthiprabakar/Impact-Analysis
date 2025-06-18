
CREATE OR ALTER   PROCEDURE [dbo].[sp_rpt_billing_revenue_by_customer_invoice]  
 @company_id  int  
, @profit_ctr_id int  
, @date_from  datetime  
, @date_to  datetime  
AS   
/****************************************************************************  
Customer Invoice Report  - Report created with the base report of Billing Revenue by Invoice Date - Detail
(r_billing_revenue_by_customer_invoice)  

PB Object(s): r_billing_revenue_by_customer_invoice
    w_report_child_1  
  
03/21/2025 RK US146351 - Stored Procedure Created for 'Invoice by Customer - Detail' Report.
SP created by the base object of 'sp_rpt_billing_revenue_by_invoice'.
*************************************************************************************************************/  
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  
BEGIN
	--1 Select receipts not linked to Work orders  
	SELECT DISTINCT  
	 Receipt.receipt_id  
	, Receipt.receipt_status  
	, Receipt.receipt_date  
	, Receipt.company_id  
	, Receipt.profit_ctr_id  
	, Receipt.customer_id  
	, Customer.cust_name  
	, MAX(Generator.EPA_ID) AS EPA_ID  
	, MAX(Generator.generator_name) AS generator_name  
	, SUM(ISNULL(ReceiptPrice.waste_extended_amt,0)) AS waste_extended_amt  
	, SUM(ISNULL(ReceiptPrice.sr_extended_amt,0)) AS sr_extended_amt  
	, SUM(ISNULL(ReceiptPrice.total_extended_amt,0)) AS total_extended_amt  
	, NULL AS source_id  
	, NULL AS source_company_id  
	, NULL AS source_profit_ctr_id  
	, 'Waste Receipt' AS account_desc  
	, CASE WHEN Receipt.receipt_status IN ('N', 'L', 'U') THEN 'U' ELSE 'B' END AS billed  
	, Billing.invoice_code  
	, Billing.invoice_date  
	, 'RR' AS record_type  
	, Company.company_name  
	, ProfitCenter.profit_ctr_name
	, IBD.AX_MainAccount 
	, IBD.AX_Dimension_1 
	, IBD.AX_Dimension_2 
	, IBD.AX_Dimension_3 
	, IBD.AX_Dimension_4
	, ID.line_desc_1
	, Receipt.approval_code
	, Billing.manifest
	, Billing.purchase_order
	, Billing.profile_id
	FROM Receipt  
	JOIN ReceiptPrice  
	 ON ReceiptPrice.receipt_id = Receipt.receipt_id  
	 AND ReceiptPrice.line_id = Receipt.line_id  
	 AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id  
	 AND ReceiptPrice.company_id = Receipt.company_id  
	JOIN Billing  
	 ON Billing.receipt_id = Receipt.receipt_id  
	 AND Billing.line_id = Receipt.line_id  
	 AND Billing.price_id = ReceiptPrice.price_id  
	 AND Billing.profit_ctr_id = Receipt.profit_ctr_id  
	 AND Billing.company_id = Receipt.company_id  
	 AND Billing.invoice_date BETWEEN @date_from AND @date_to  
	JOIN Company  
	 ON Company.company_id = Receipt.company_id  
	JOIN ProfitCenter  
	 ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id  
	 AND ProfitCenter.company_ID = Receipt.company_id  
	LEFT OUTER JOIN Generator  
	 ON Generator.generator_id = Receipt.generator_id  
	LEFT OUTER JOIN Customer  
	 ON Customer.customer_ID = Receipt.customer_id  
	LEFT OUTER JOIN InvoiceBillingDetail IBD
	 ON IBD.receipt_id = Receipt.receipt_id
	 AND IBD.company_id = Receipt.company_id
	 AND IBD.profit_ctr_id = Receipt.profit_ctr_id
	 AND IBD.line_id = Receipt.line_id
	LEFT OUTER JOIN InvoiceDetail ID --Rajesh
	 ON ID.company_id = Billing.company_id
	 AND ID.profit_ctr_id = Billing.profit_ctr_id
	 AND ID.invoice_id = Billing.invoice_id
	 AND ID.line_id = Billing.line_id

	WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )  
	  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )  
	  AND Receipt.trans_mode = 'I'  
	  AND Receipt.receipt_status IN ('N', 'L', 'U', 'A')  
	  AND NOT EXISTS (SELECT receipt_id FROM BillingLinkLookup   
		 WHERE Receipt.company_id = BillingLinkLookup.company_id  
		 AND Receipt.profit_ctr_id = BillingLinkLookup.profit_ctr_id  
		 AND Receipt.receipt_id = BillingLinkLookup.receipt_id   
		 AND BillingLinkLookup.source_type = 'W')  
	GROUP BY   
	 Billing.invoice_code,  
	 Billing.invoice_date,  
	 Receipt.receipt_id,  
	 Receipt.receipt_status,  
	 Receipt.receipt_date,  
	 Receipt.company_id,  
	 Receipt.profit_ctr_id,  
	 Receipt.customer_id,  
	 Customer.cust_name,  
	 Company.company_name,  
	 ProfitCenter.profit_ctr_name,
	 IBD.AX_MainAccount,
	 IBD.AX_Dimension_1,
	 IBD.AX_Dimension_2,
	 IBD.AX_Dimension_3,
	 IBD.AX_Dimension_4,
	 ID.line_desc_1,
	 Receipt.approval_code,
	 Billing.manifest,
	 Billing.purchase_order,
	 Billing.profile_id
   
	--2 Select Receipts linked to WorkOrders in the same company, but different or same profit centers  
	UNION  
	SELECT DISTINCT  
	 Receipt.receipt_id  
	, Receipt.receipt_status  
	, Receipt.receipt_date  
	, Receipt.company_id  
	, Receipt.profit_ctr_id  
	, Receipt.customer_id  
	, Customer.cust_name  
	, MAX(Generator.EPA_ID) AS EPA_ID  
	, MAX(Generator.generator_name) AS generator_name  
	, SUM(ISNULL(ReceiptPrice.waste_extended_amt,0)) AS waste_extended_amt  
	, SUM(ISNULL(ReceiptPrice.sr_extended_amt,0)) AS sr_extended_amt  
	, SUM(ISNULL(ReceiptPrice.total_extended_amt,0)) AS total_extended_amt  
	, BillingLinkLookup.source_id  
	, BillingLinkLookup.source_company_id  
	, BillingLinkLookup.source_profit_ctr_id  
	, WorkorderTypeHeader.account_desc  
	, CASE WHEN Receipt.receipt_status IN ('N', 'L', 'U') THEN 'U' ELSE 'B' END AS billed  
	, Billing.invoice_code  
	, Billing.invoice_date  
	, 'RW1' AS record_type  
	, Company.company_name  
	, ProfitCenter.profit_ctr_name  
	, IBD.AX_MainAccount 
	, IBD.AX_Dimension_1 
	, IBD.AX_Dimension_2 
	, IBD.AX_Dimension_3 
	, IBD.AX_Dimension_4
	, ID.line_desc_1
	, Receipt.approval_code
	, Billing.manifest
	, Billing.purchase_order
	, Billing.profile_id

	FROM Receipt  
	JOIN ReceiptPrice  
	 ON ReceiptPrice.receipt_id = Receipt.receipt_id  
	 AND ReceiptPrice.line_id = Receipt.line_id  
	 AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id  
	 AND ReceiptPrice.company_id = Receipt.company_id  
	JOIN Billing  
	 ON Billing.receipt_id = Receipt.receipt_id  
	 AND Billing.line_id = Receipt.line_id  
	 AND Billing.price_id = ReceiptPrice.price_id  
	 AND Billing.profit_ctr_id = Receipt.profit_ctr_id  
	 AND Billing.company_id = Receipt.company_id  
	 AND Billing.invoice_date BETWEEN @date_from AND @date_to  
	JOIN WorkorderHeader  
	 ON WorkorderHeader.company_id = Receipt.company_id  
	JOIN WorkorderTypeHeader  
	 ON WorkorderTypeHeader.workorder_type_id = WorkorderHeader.workorder_type_id  
	JOIN BillingLinkLookup  
	 ON BillingLinkLookup.company_id = Receipt.company_id  
	 AND BillingLinkLookup.profit_ctr_id = Receipt.profit_ctr_id  
	 AND BillingLinkLookup.receipt_id = Receipt.receipt_id  
	 AND BillingLinkLookup.source_company_id = Receipt.company_id  
	 AND BillingLinkLookup.source_profit_ctr_id = WorkorderHeader.profit_ctr_id  
	 AND BillingLinkLookup.source_type = 'W'  
	 AND BillingLinkLookup.source_id = WorkorderHeader.workorder_id  
	JOIN Company  
	 ON Company.company_id = Receipt.company_id  
	JOIN ProfitCenter  
	 ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id  
	 AND ProfitCenter.company_ID = Receipt.company_id  
	LEFT OUTER JOIN Generator  
	 ON Generator.generator_id = Receipt.generator_id  
	LEFT OUTER JOIN Customer  
	 ON Customer.customer_ID = Receipt.customer_id   
	LEFT OUTER JOIN InvoiceBillingDetail IBD
	 ON IBD.receipt_id = Receipt.receipt_id
	 AND IBD.company_id = Receipt.company_id
	 AND IBD.profit_ctr_id = Receipt.profit_ctr_id
	 AND IBD.line_id = Receipt.line_id
	LEFT OUTER JOIN InvoiceDetail ID --Rajesh
	 ON ID.company_id = Billing.company_id
	 AND ID.profit_ctr_id = Billing.profit_ctr_id
	 AND ID.invoice_id = Billing.invoice_id
	 AND ID.line_id = Billing.line_id
	WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )  
	  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )  
	  AND Receipt.trans_mode = 'I'  
	  AND Receipt.receipt_status IN ('N', 'L', 'U', 'A')  
	GROUP BY   
	 Billing.invoice_code,  
	 Billing.invoice_date,  
	 Receipt.receipt_id,  
	 Receipt.receipt_status,  
	 Receipt.receipt_date,  
	 Receipt.company_id,  
	 Receipt.profit_ctr_id,  
	 Receipt.customer_id,  
	 BillingLinkLookup.source_company_id,  
	 BillingLinkLookup.source_profit_ctr_id,  
	 WorkorderTypeHeader.account_desc,  
	 BillingLinkLookup.source_id,  
	 Customer.cust_name,  
	 Company.company_name,  
	 ProfitCenter.profit_ctr_name,
	 IBD.AX_MainAccount, 
	 IBD.AX_Dimension_1, 
	 IBD.AX_Dimension_2, 
	 IBD.AX_Dimension_3, 
	 IBD.AX_Dimension_4,
	 ID.line_desc_1,
	 Receipt.approval_code,
	 Billing.manifest,
	 Billing.purchase_order,
	 Billing.profile_id
  
	--3 select receipts linked to workorders in different companies  
	UNION  
	SELECT DISTINCT  
	 Receipt.receipt_id  
	, Receipt.receipt_status  
	, Receipt.receipt_date  
	, Receipt.company_id  
	, Receipt.profit_ctr_id  
	, Receipt.customer_id  
	, Customer.cust_name  
	, MAX(Generator.EPA_ID) AS EPA_ID  
	, MAX(Generator.generator_name) AS generator_name  
	, SUM(ISNULL(ReceiptPrice.waste_extended_amt,0)) AS waste_extended_amt  
	, SUM(ISNULL(ReceiptPrice.sr_extended_amt,0)) AS sr_extended_amt  
	, SUM(ISNULL(ReceiptPrice.total_extended_amt,0)) AS total_extended_amt  
	, BillingLinkLookup.source_id  
	, BillingLinkLookup.source_company_id  
	, BillingLinkLookup.source_profit_ctr_id  
	, '' AS account_desc  
	, CASE WHEN Receipt.receipt_status IN ('N', 'L', 'U') THEN 'U' ELSE 'B' END AS billed  
	, Billing.invoice_code  
	, Billing.invoice_date  
	, 'RW2' AS record_type  
	, Company.company_name  
	, ProfitCenter.profit_ctr_name  
	, IBD.AX_MainAccount
	, IBD.AX_Dimension_1
	, IBD.AX_Dimension_2
	, IBD.AX_Dimension_3
	, IBD.AX_Dimension_4
	, ID.line_desc_1
	, Receipt.approval_code
	, Billing.manifest
	, Billing.purchase_order
	, Billing.profile_id
	FROM Receipt  
	JOIN ReceiptPrice  
	 ON ReceiptPrice.receipt_id = Receipt.receipt_id  
	 AND ReceiptPrice.line_id = Receipt.line_id  
	 AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id  
	 AND ReceiptPrice.company_id = Receipt.company_id  
	JOIN Billing  
	 ON Billing.receipt_id = Receipt.receipt_id  
	 AND Billing.line_id = Receipt.line_id  
	 AND Billing.price_id = ReceiptPrice.price_id  
	 AND Billing.profit_ctr_id = Receipt.profit_ctr_id  
	 AND Billing.company_id = Receipt.company_id  
	 AND Billing.invoice_date BETWEEN @date_from AND @date_to  
	JOIN BillingLinkLookup  
	 ON BillingLinkLookup.company_id = Receipt.company_id  
	 AND BillingLinkLookup.profit_ctr_id = Receipt.profit_ctr_id  
	 AND BillingLinkLookup.receipt_id = Receipt.receipt_id  
	 AND BillingLinkLookup.source_company_id <> Receipt.company_id  
	 AND BillingLinkLookup.source_type = 'W'  
	 AND BillingLinkLookup.source_id IS NOT NULL  
	 AND BillingLinkLookup.source_company_id IS NOT NULL  
	 AND BillingLinkLookup.source_profit_ctr_id IS NOT NULL  
	JOIN Company  
	 ON Company.company_id = Receipt.company_id  
	JOIN ProfitCenter  
	 ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id  
	 AND ProfitCenter.company_ID = Receipt.company_id  
	LEFT OUTER JOIN Generator  
	 ON Generator.generator_id = Receipt.generator_id  
	LEFT OUTER JOIN Customer  
	 ON Customer.customer_ID = Receipt.customer_id  
	LEFT OUTER JOIN InvoiceBillingDetail IBD
	 ON IBD.receipt_id = Receipt.receipt_id
	 AND IBD.company_id = Receipt.company_id
	 AND IBD.profit_ctr_id = Receipt.profit_ctr_id
	 AND IBD.line_id = Receipt.line_id
	LEFT JOIN InvoiceDetail ID --Rajesh
	 ON ID.company_id = Billing.company_id
	 AND ID.profit_ctr_id = Billing.profit_ctr_id
	 AND ID.invoice_id = Billing.invoice_id
	 AND ID.line_id = Billing.line_id
	WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )  
	  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )  
	  AND Receipt.trans_mode = 'I'  
	  AND Receipt.receipt_status IN ('N', 'L', 'U', 'A')  
	GROUP BY   
	 Billing.invoice_code,  
	 Billing.invoice_date,  
	 Receipt.receipt_id,  
	 Receipt.receipt_status,  
	 Receipt.receipt_date,  
	 Receipt.company_id,  
	 Receipt.profit_ctr_id,  
	 Receipt.customer_id,  
	 BillingLinkLookup.source_company_id,  
	 BillingLinkLookup.source_profit_ctr_id,  
	 BillingLinkLookup.source_id,  
	 Customer.cust_name,  
	 Company.company_name,  
	 ProfitCenter.profit_ctr_name,
	 IBD.AX_MainAccount, 
	 IBD.AX_Dimension_1, 
	 IBD.AX_Dimension_2, 
	 IBD.AX_Dimension_3, 
	 IBD.AX_Dimension_4,
	 ID.line_desc_1,
	 Receipt.approval_code,
	 Billing.manifest,
	 Billing.purchase_order,
	 Billing.profile_id
  
	--4  
	UNION  
	SELECT DISTINCT  
	 Receipt.receipt_id  
	, Receipt.receipt_status  
	, Receipt.receipt_date  
	, Receipt.company_id  
	, Receipt.profit_ctr_id  
	, Receipt.customer_id  
	, Customer.cust_name  
	, MAX(Generator.EPA_ID) AS EPA_ID  
	, MAX(Generator.generator_name) AS generator_name  
	, SUM(ISNULL(ReceiptPrice.waste_extended_amt,0)) AS waste_extended_amt  
	, SUM(ISNULL(ReceiptPrice.sr_extended_amt,0)) AS sr_extended_amt  
	, SUM(ISNULL(ReceiptPrice.total_extended_amt,0)) AS total_extended_amt  
	, BillingLinkLookup.source_id  
	, BillingLinkLookup.source_company_id  
	, BillingLinkLookup.source_profit_ctr_id  
	, '' AS account_desc  
	, CASE WHEN Receipt.receipt_status IN ('N', 'L', 'U') THEN 'U' ELSE 'B' END AS billed  
	, Billing.invoice_code  
	, Billing.invoice_date  
	, 'RW3' AS record_type  
	, Company.company_name  
	, ProfitCenter.profit_ctr_name  
	, IBD.AX_MainAccount 
	, IBD.AX_Dimension_1 
	, IBD.AX_Dimension_2 
	, IBD.AX_Dimension_3 
	, IBD.AX_Dimension_4
	, ID.line_desc_1
	, Receipt.approval_code
	, Billing.manifest
	, Billing.purchase_order
	, Billing.profile_id
	FROM Receipt  
	JOIN ReceiptPrice  
	 ON ReceiptPrice.receipt_id = Receipt.receipt_id  
	 AND ReceiptPrice.line_id = Receipt.line_id  
	 AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id  
	 AND ReceiptPrice.company_id = Receipt.company_id  
	JOIN Billing  
	 ON Billing.receipt_id = Receipt.receipt_id  
	 AND Billing.line_id = Receipt.line_id  
	 AND Billing.price_id = ReceiptPrice.price_id  
	 AND Billing.profit_ctr_id = Receipt.profit_ctr_id  
	 AND Billing.company_id = Receipt.company_id  
	 AND Billing.invoice_date BETWEEN @date_from AND @date_to  
	JOIN BillingLinkLookup  
	 ON BillingLinkLookup.company_id = Receipt.company_id  
	 AND BillingLinkLookup.profit_ctr_id = Receipt.profit_ctr_id  
	 AND BillingLinkLookup.receipt_id = Receipt.receipt_id  
	 AND BillingLinkLookup.source_company_id = Receipt.company_id  
	 AND BillingLinkLookup.source_type = 'W'  
	 AND BillingLinkLookup.source_id IS NOT NULL  
	 AND BillingLinkLookup.source_company_id IS NOT NULL  
	 AND BillingLinkLookup.source_profit_ctr_id IS NOT NULL  
	JOIN Company  
	 ON Company.company_id = Receipt.company_id  
	JOIN ProfitCenter  
	 ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id  
	 AND ProfitCenter.company_ID = Receipt.company_id  
	LEFT OUTER JOIN Generator  
	 ON Generator.generator_id = Receipt.generator_id  
	LEFT OUTER JOIN Customer  
	 ON Customer.customer_ID = Receipt.customer_id 
	LEFT OUTER JOIN InvoiceBillingDetail IBD
	 ON IBD.receipt_id = Receipt.receipt_id
	 AND IBD.company_id = Receipt.company_id
	 AND IBD.profit_ctr_id = Receipt.profit_ctr_id
	 AND IBD.line_id = Receipt.line_id
	LEFT OUTER JOIN InvoiceDetail ID --Rajesh
	 ON ID.company_id = Billing.company_id
	 AND ID.profit_ctr_id = Billing.profit_ctr_id
	 AND ID.invoice_id = Billing.invoice_id
	 AND ID.line_id = Billing.line_id
	WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )  
	  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )  
	  AND Receipt.trans_mode = 'I'  
	  AND Receipt.receipt_status IN ('N', 'L', 'U', 'A')  
	  AND NOT EXISTS (SELECT workorder_id FROM WorkOrderHeader   
		 WHERE BillingLinkLookup.source_company_id = WorkorderHeader.company_id  
		 AND BillingLinkLookup.source_profit_ctr_id = WorkOrderHeader.profit_ctr_id  
		 AND BillingLinkLookup.source_id = WorkOrderHeader.workorder_id)  
	GROUP BY   
	 Billing.invoice_code,  
	 Billing.invoice_date,  
	 Receipt.receipt_id,  
	 Receipt.receipt_status,  
	 Receipt.receipt_date,  
	 Receipt.company_id,  
	 Receipt.profit_ctr_id,  
	 Receipt.customer_id,  
	 BillingLinkLookup.source_company_id,  
	 BillingLinkLookup.source_profit_ctr_id,  
	 BillingLinkLookup.source_id,  
	 Customer.cust_name,  
	 Company.company_name,  
	 ProfitCenter.profit_ctr_name,
	 IBD.AX_MainAccount, 
	 IBD.AX_Dimension_1, 
	 IBD.AX_Dimension_2, 
	 IBD.AX_Dimension_3, 
	 IBD.AX_Dimension_4,
	 ID.line_desc_1,
	 Receipt.approval_code,
	 Billing.manifest,
	 Billing.purchase_order,
	 Billing.profile_id
  

	--5 select billed workorders  
	UNION  
	SELECT DISTINCT  
	 Billing.receipt_id  
	, WorkorderHeader.workorder_status  
	, Billing.billing_date  
	, Billing.company_id  
	, Billing.profit_ctr_id  
	, Billing.customer_id  
	, Customer.cust_name  
	, MAX(Generator.EPA_ID) AS EPA_ID  
	, MAX(Generator.generator_name) AS generator_name  
	, waste_extended_amt = ISNULL((SELECT SUM(ISNULL(bd.extended_amt, 0)) FROM BillingDetail bd  
		   WHERE bd.company_id = Billing.company_id   
			AND bd.profit_ctr_id = Billing.profit_ctr_id  
			AND bd.receipt_id = Billing.receipt_id  
			AND ((bd.trans_type = 'D' AND bd.billing_type = 'Disposal') OR   
			  (bd.trans_source = 'W' AND bd.billing_type = 'WorkOrder')OR  
			  ((bd.trans_type = 'S' OR bd.trans_type = 'T') AND bd.billing_type = 'Product') OR  
			  (bd.trans_source = 'O' AND bd.billing_type = 'Retail') OR  
			  (bd.trans_type = 'W' AND bd.billing_type = 'Wash'))), 0.000)  
	, sr_extended_amt = ISNULL((SELECT SUM(ISNULL(bd.extended_amt, 0)) FROM BillingDetail bd  
		   WHERE bd.company_id = Billing.company_id   
			AND bd.profit_ctr_id = Billing.profit_ctr_id  
			AND bd.receipt_id = Billing.receipt_id  
			AND bd.billing_type = 'State'), 0.000)  
	, total_extended_amt = ISNULL((SELECT SUM(ISNULL(bd.extended_amt, 0)) FROM BillingDetail bd  
		   WHERE bd.company_id = Billing.company_id   
			AND bd.profit_ctr_id = Billing.profit_ctr_id  
			AND bd.receipt_id = Billing.receipt_id), 0.000)  
	, WorkorderHeader.workorder_id  
	, Billing.company_id  
	, WorkorderHeader.profit_ctr_id  
	, WorkorderTypeHeader.account_desc  
	, CASE WHEN WorkorderHeader.workorder_status IN ('N', 'C', 'A') THEN 'U' ELSE 'B' END AS billed  
	, Billing.invoice_code  
	, Billing.invoice_date  
	, 'WO' AS record_type  
	, Company.company_name  
	, ProfitCenter.profit_ctr_name  
	, IBD.AX_MainAccount
	, IBD.AX_Dimension_1
	, IBD.AX_Dimension_2
	, IBD.AX_Dimension_3
	, IBD.AX_Dimension_4
	, ID.line_desc_1
	, Billing.approval_code
	, Billing.manifest
	, Billing.purchase_order
	, Billing.profile_id
	FROM Billing  
	JOIN WorkorderHeader  
	 ON WorkorderHeader.workorder_ID = Billing.receipt_id  
	 AND WorkorderHeader.company_id = Billing.company_id  
	 AND WorkorderHeader.profit_ctr_ID = Billing.profit_ctr_id  
	 AND WorkorderHeader.workorder_status IN ('N', 'C', 'A', 'X')  
	JOIN WorkorderTypeHeader  
	 ON WorkorderTypeHeader.workorder_type_id = WorkorderHeader.workorder_type_id  
	JOIN Company  
	 ON Company.company_id = Billing.company_id  
	JOIN ProfitCenter  
	 ON ProfitCenter.profit_ctr_ID = Billing.profit_ctr_id  
	 AND ProfitCenter.company_ID = Billing.company_id  
	LEFT OUTER JOIN Generator  
	 ON Generator.generator_id = WorkorderHeader.generator_id  
	LEFT OUTER JOIN Customer  
	 ON Customer.customer_id = WorkorderHeader.customer_id
	LEFT OUTER JOIN InvoiceBillingDetail IBD
	 ON IBD.receipt_id = Billing.receipt_id
	 AND IBD.company_id = Billing.company_id
	 AND IBD.profit_ctr_id = Billing.profit_ctr_id
	 AND IBD.line_id = Billing.line_id
	LEFT OUTER JOIN InvoiceDetail ID --Rajesh
	 ON ID.company_id = Billing.company_id
	 AND ID.profit_ctr_id = Billing.profit_ctr_id
	 AND ID.invoice_id = Billing.invoice_id
	 AND ID.line_id = Billing.line_id
	WHERE ( @company_id = 0 OR Billing.company_id = @company_id )  
	  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Billing.profit_ctr_id = @profit_ctr_id )  
	  AND Billing.invoice_date BETWEEN @date_from AND @date_to  
	GROUP BY   
	 Billing.invoice_code,  
	 Billing.invoice_date,  
	 Billing.receipt_id,  
	 WorkorderHeader.workorder_status,  
	 Billing.billing_date,  
	 Billing.company_id,  
	 Billing.profit_ctr_id,  
	 Billing.customer_id,  
	 WorkorderHeader.profit_ctr_id,  
	 WorkorderTypeHeader.account_desc,  
	 WorkorderHeader.workorder_id,  
	 Customer.cust_name,  
	 Company.company_name,  
	 ProfitCenter.profit_ctr_name,
	 IBD.AX_MainAccount, 
	 IBD.AX_Dimension_1, 
	 IBD.AX_Dimension_2, 
	 IBD.AX_Dimension_3, 
	 IBD.AX_Dimension_4,
	 ID.line_desc_1,
	 Billing.approval_code,
	 Billing.manifest,
	 Billing.purchase_order,
	 Billing.profile_id
	ORDER BY record_type, Receipt.receipt_status, Receipt.customer_id, Receipt.receipt_id
END
GO

-- Grant execution permissions to users
GRANT EXECUTE ON [dbo].[sp_rpt_billing_revenue_by_customer_invoice] TO EQAI
GO