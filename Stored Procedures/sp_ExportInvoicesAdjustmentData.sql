CREATE PROCEDURE sp_ExportInvoicesAdjustmentData 
	@invoice_id			int
	, @revision_id		int
	, @ai_debug			int = 0
AS
/*******************************************************************************************
This SP is called from sp_ExportInvoices for adjustments.  
It is called in order to compare the difference between the revision that is 
sent in and the prior revision for that invoice.  It populates the temp table
that should already be created before this SP is called.

This sp is loaded to Plt_AI.

03/05/2013 JDB	Created.
01/13/2016 RWB	To determine Reserve Account for prior years, join to ProfitCenterAging instead
		of ProfitCenter (it has a history of JDE CoPc links...ProfitCenter only has current)
02/22/2019 RWB	MSS 2016 migration...COMPUTE is now depricated, and was being used in a debug statement

-- Testing:
DROP TABLE #InvoiceBillingDetail_AdjustmentData
SELECT orig_billing_uid, orig_billingdetail_uid, orig_ref_billingdetail_uid, invoice_id, revision_id, billingtype_uid, billing_type, company_id, profit_ctr_id, receipt_id, line_id, price_id, trans_source, trans_type, product_id, dist_company_id, dist_profit_ctr_id, sales_tax_id, applied_percent, extended_amt, JDE_BU, JDE_object, CONVERT(datetime, NULL) AS min_invoice_date, CONVERT(datetime, NULL) AS applied_date, convert (varchar (max), null ) as AX_account
INTO #InvoiceBillingDetail_AdjustmentData
FROM InvoiceBillingDetail
WHERE 0=1

EXEC sp_ExportInvoicesAdjustmentData 921674, 2, 1
EXEC sp_ExportInvoicesAdjustmentData  1122437, 2, 1
EXEC sp_ExportInvoicesAdjustmentData 1195405 , 2,1
EXEC sp_ExportInvoicesAdjustmentData 1220904, 2 ,1
********************************************************************************************/
DECLARE	@prev_revision_id	int,
	  @sync_invoice_jde				tinyint,
	  @sync_invoice_ax				tinyint

SET @prev_revision_id = @revision_id - 1

---------------------------------------------------------------
-- Do we export invoices/adjustments to JDE?
---------------------------------------------------------------
SELECT @sync_invoice_jde = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'JDE'

---------------------------------------------------------------
-- Do we export invoices/adjustments to AX?
---------------------------------------------------------------
SELECT @sync_invoice_ax = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'AX'

--IF @sync_invoice_ax = 1  
 BEGIN
	-- Insert into #InvoiceBillingDetail_AdjustmentData for prior revision
	INSERT INTO #InvoiceBillingDetail_AdjustmentData
	SELECT ibd.orig_billing_uid
		, ibd.orig_billingdetail_uid
		, ibd.orig_ref_billingdetail_uid
		, ibd.invoice_id
		, @revision_id AS revision_id		-- This is necessary so that joins that use this table later will work.
		, ibd.billingtype_uid
		, ibd.billing_type
		, ibd.company_id
		, ibd.profit_ctr_id
		, ibd.receipt_id
		, ibd.line_id
		, ibd.price_id
		, ibd.trans_source
		, ibd.trans_type
		, ibd.product_id
		, ibd.dist_company_id
		, ibd.dist_profit_ctr_id
		, ibd.sales_tax_id
		, ibd.applied_percent
		, -(ibd.extended_amt)					-- The negative sign will serve to "credit" back everything from the prior revision
		, ibd.JDE_BU AS JDE_BU
		, ibd.JDE_object AS JDE_object
		, CONVERT(datetime, NULL) AS min_invoice_date
		, CONVERT(datetime, NULL) AS applied_date
		, CASE len(rtrim(AX_Dimension_5_Part_2))
			WHEN  0 THEN
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' +
			   ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' +
			   ibd.AX_Dimension_5_Part_1
			   --'-' + nullif(rtrim(AX_Dimension_5_Part_1),'')
			ELSE
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' +
			   ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 +  '-' +
			   ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2   END AS AX_ACCOUNT		
	FROM InvoiceBillingDetail ibd
	WHERE ibd.invoice_id = @invoice_id
	AND ibd.revision_id = @prev_revision_id 
	ORDER BY ibd.trans_source, ibd.receipt_id, ibd.line_id, ibd.price_id, ibd.billingtype_uid

	-- Insert into #InvoiceBillingDetail_AdjustmentData for this revision
	INSERT INTO #InvoiceBillingDetail_AdjustmentData
	SELECT ibd.orig_billing_uid
		, ibd.orig_billingdetail_uid
		, ibd.orig_ref_billingdetail_uid
		, ibd.invoice_id
		, ibd.revision_id
		, ibd.billingtype_uid
		, ibd.billing_type
		, ibd.company_id
		, ibd.profit_ctr_id
		, ibd.receipt_id
		, ibd.line_id
		, ibd.price_id
		, ibd.trans_source
		, ibd.trans_type
		, ibd.product_id
		, ibd.dist_company_id
		, ibd.dist_profit_ctr_id
		, ibd.sales_tax_id
		, ibd.applied_percent
		, ibd.extended_amt
	    , ibd.JDE_BU AS JDE_BU
		, ibd.JDE_object AS JDE_object
		, CONVERT(datetime, NULL) AS min_invoice_date
		, CONVERT(datetime, NULL) AS applied_date
		, CASE len(rtrim(AX_Dimension_5_Part_2))
			WHEN  0 THEN
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' +
			   ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' +
			   ibd.AX_Dimension_5_Part_1
			   --'-' + nullif(rtrim(AX_Dimension_5_Part_1),'')
			ELSE
			   ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' +
			   ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' +
			   ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 +  '-' +
			   AX_Dimension_5_Part_1 + '.' + AX_Dimension_5_Part_2   END AS AX_ACCOUNT
	FROM InvoiceBillingDetail ibd
	WHERE ibd.invoice_id = @invoice_id
	AND ibd.revision_id = @revision_id 
	ORDER BY ibd.trans_source, ibd.receipt_id, ibd.line_id, ibd.price_id, ibd.billingtype_uid
 END
 
--IF @sync_invoice_jde = 1   
 --BEGIN	 
	-- -- Insert into #InvoiceBillingDetail_AdjustmentData for prior revision
	--INSERT INTO #InvoiceBillingDetail_AdjustmentData
	--SELECT ibd.orig_billing_uid
	--	, ibd.orig_billingdetail_uid
	--	, ibd.orig_ref_billingdetail_uid
	--	, ibd.invoice_id
	--	, @revision_id AS revision_id		-- This is necessary so that joins that use this table later will work.
	--	, ibd.billingtype_uid
	--	, ibd.billing_type
	--	, ibd.company_id
	--	, ibd.profit_ctr_id
	--	, ibd.receipt_id
	--	, ibd.line_id
	--	, ibd.price_id
	--	, ibd.trans_source
	--	, ibd.trans_type
	--	, ibd.product_id
	--	, ibd.dist_company_id
	--	, ibd.dist_profit_ctr_id
	--	, ibd.sales_tax_id
	--	, ibd.applied_percent
	--	, -(ibd.extended_amt)					-- The negative sign will serve to "credit" back everything from the prior revision
	--	, ibd.JDE_BU
	--	, ibd.JDE_object
	--	, CONVERT(datetime, NULL) AS min_invoice_date
	--	, CONVERT(datetime, NULL) AS applied_date
	--	, '' AS AX_ACCOUNT	
	--FROM InvoiceBillingDetail ibd
	--WHERE ibd.invoice_id = @invoice_id
	--AND ibd.revision_id = @prev_revision_id 
	--ORDER BY ibd.trans_source, ibd.receipt_id, ibd.line_id, ibd.price_id, ibd.billingtype_uid

	---- Insert into #InvoiceBillingDetail_AdjustmentData for this revision
	--INSERT INTO #InvoiceBillingDetail_AdjustmentData
	--SELECT ibd.orig_billing_uid
	--	, ibd.orig_billingdetail_uid
	--	, ibd.orig_ref_billingdetail_uid
	--	, ibd.invoice_id
	--	, ibd.revision_id
	--	, ibd.billingtype_uid
	--	, ibd.billing_type
	--	, ibd.company_id
	--	, ibd.profit_ctr_id
	--	, ibd.receipt_id
	--	, ibd.line_id
	--	, ibd.price_id
	--	, ibd.trans_source
	--	, ibd.trans_type
	--	, ibd.product_id
	--	, ibd.dist_company_id
	--	, ibd.dist_profit_ctr_id
	--	, ibd.sales_tax_id
	--	, ibd.applied_percent
	--	, ibd.extended_amt
	--	, ibd.JDE_BU
	--	, ibd.JDE_object
	--	, CONVERT(datetime, NULL) AS min_invoice_date
	--	, CONVERT(datetime, NULL) AS applied_date
	--	, ''  AS AX_ACCOUNT	
	--FROM InvoiceBillingDetail ibd
	--WHERE ibd.invoice_id = @invoice_id
	--AND ibd.revision_id = @revision_id 
	--ORDER BY ibd.trans_source, ibd.receipt_id, ibd.line_id, ibd.price_id, ibd.billingtype_uid
--END

-- Set the applied date of the adjustment, and the earliest date a receipt/work order may have been invoiced.
UPDATE #InvoiceBillingDetail_AdjustmentData 
	SET applied_date = (SELECT MAX(ih.applied_date)
						FROM InvoiceHeader ih
						WHERE ih.invoice_id = #InvoiceBillingDetail_AdjustmentData.invoice_id
						AND ih.revision_id = #InvoiceBillingDetail_AdjustmentData.revision_id
						)
	, min_invoice_date = (SELECT MIN(ihmin.invoice_date) 
						FROM InvoiceHeader ihmin
						JOIN InvoiceDetail idmin ON idmin.invoice_id = ihmin.invoice_id
							AND idmin.revision_id = ihmin.revision_id
						WHERE idmin.company_id = #InvoiceBillingDetail_AdjustmentData.company_id
						AND idmin.profit_ctr_id = #InvoiceBillingDetail_AdjustmentData.profit_ctr_id
						AND idmin.trans_source = #InvoiceBillingDetail_AdjustmentData.trans_source
						AND idmin.receipt_id = #InvoiceBillingDetail_AdjustmentData.receipt_id
						)

-- Update the JDE Business Unit and Object fields from the reserve account system product for records that were invoice
-- in a prior year.
IF @sync_invoice_jde = 1 
 BEGIN
	UPDATE #InvoiceBillingDetail_AdjustmentData 
		SET JDE_BU = ISNULL((SELECT ISNULL(p.JDE_BU, 'XXXXXXX')
						FROM Product p
						JOIN ProfitCenterAging pc ON pc.company_id = p.company_ID
							AND pc.profit_ctr_ID = p.profit_ctr_ID
						WHERE pc.JDE_copc = LEFT(#InvoiceBillingDetail_AdjustmentData.JDE_BU, 4)
						AND p.product_type = 'X'
						AND p.product_code = 'RESERVEACCOUNT'
						), 'XXXXXXX')									
		, JDE_object = ISNULL((SELECT ISNULL(p.JDE_object, 'XXXXX')
						FROM Product p
						JOIN ProfitCenterAging pc ON pc.company_id = p.company_ID
							AND pc.profit_ctr_ID = p.profit_ctr_ID
						WHERE pc.JDE_copc = LEFT(#InvoiceBillingDetail_AdjustmentData.JDE_BU, 4)
						AND p.product_type = 'X'
						AND p.product_code = 'RESERVEACCOUNT'
						), 'XXXXX')
	WHERE min_invoice_date IS NOT NULL
	AND applied_date IS NOT NULL
	AND DATEPART(year, min_invoice_date) < DATEPART(year, applied_date)
END
-- Make sure the copc and dept fields match now that we've (possibly) updated some records to have the Reserve account.
--UPDATE #InvoiceBillingDetail_AdjustmentData 
--	SET JDE_BU_copc = LEFT(JDE_BU, 4)
--	, JDE_BU_dept = RIGHT(JDE_BU, 3)


IF @ai_debug = 1 
BEGIN
	SELECT * FROM #InvoiceBillingDetail_AdjustmentData 
	
	SELECT invoice_id, revision_id, company_id, profit_ctr_id, trans_source, receipt_id, JDE_BU, JDE_object, SUM(extended_amt),AX_account
	FROM #InvoiceBillingDetail_AdjustmentData 
	GROUP BY invoice_id, revision_id, company_id, profit_ctr_id, trans_source, receipt_id, JDE_BU, JDE_object, AX_account
--	COMPUTE SUM(SUM(extended_amt))
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ExportInvoicesAdjustmentData] TO [EQAI]
    AS [dbo];
GO

