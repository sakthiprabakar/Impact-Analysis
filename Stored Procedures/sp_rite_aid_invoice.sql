CREATE PROCEDURE sp_rite_aid_invoice (
	  @customer_id			int
	, @invoice_code_from	varchar(16)
	, @invoice_code_to		varchar(16)
	, @invoice_date_from	datetime
	, @invoice_date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

09/07/2012 JDB	Created.  This SP returns data specifically designed for Rite Aid, with Stop Fees
				that include a certain amount of disposal in their pricing.
01/21/2013 JPB	Added #RCB table & population to handle effective-date logic for ResourceClassBundle
07/04/2024 KS	Rally116985 - Modified service_desc_1 datatype to VARCHAR(100) for #tmp table.

SELECT * FROM invoiceheader where customer_id = 14231 order by invoice_date desc
SELECT * FROM customer where cust_name like 'rite%aid%'

EXECUTE sp_rite_aid_invoice 14231, '40411704', '40411704', '1/1/12', '12/31/13'
--EXECUTE sp_rite_aid_invoice 14232, '40402256', '40402256', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice 14232, '40402257', '40402257', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice 14232, '40402258', '40402258', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice 14232, '40402260', '40402260', '9/10/12', '9/11/12'

SELECT * FROM ResourceClassBundle

--SELECT * FROM WorkOrderDetail WHERE resource_class_code IN ('STOPFEECT','STOPFEECTP','STOPFEEMA','STOPFEEMAP','STOPFEEVT','STOPFEEVTP','STOPFEEMI','STOPFEEMIP','STOPFEEOH','STOPFEEOHP','STOPFEENJ','STOPFEENJP')
*************************************************************************************************/

CREATE TABLE #tmp (
	invoice_id					int				NOT NULL
	, invoice_code				varchar(16)		NOT NULL
	, invoice_date				datetime		NOT NULL
	, invoice_sequence			smallint		NOT NULL
	, status_code				char(1)			NULL
	, customer_id				int				NULL
	, generator_id				int				NULL
	, trans_source				char(1)			NULL
	, billing_type				varchar(10)		NULL
	, company_id				int				NULL
	, profit_ctr_id				int				NULL
	, receipt_id				int				NULL
	, line_id					int				NULL
	, price_id					int				NULL
	, billing_date				datetime		NULL
	, resource_type				varchar(15)		NULL
	, resource_class_code		varchar(15)		NULL
	, profile_id				int				NULL
	, approval_code				varchar(15)		NULL
	, service_desc_1			varchar(100)	NULL
	, product_id				int				NULL
	, sales_tax_id				int				NULL
	, quantity					float			NULL
	, bill_unit_code			varchar(4)		NULL
	, price						money			NULL
	, actual_extended_amt		money			NOT NULL
	, stop_fee_from_quote		money			NULL
	, diff						money			NULL
	, special_stop_fee			smallint		NULL
	)

-- Build a temp local instance of ResourceClassBundle.
-- This should tie to transaction key info and handle the date logic
-- so the #RCB table contains the relevant ResourceClassBundle fields
-- per transaction:
CREATE TABLE #RCB ( rcb_id	int not null identity(1,1)
	, trans_source			varchar(1)
	, receipt_id			int
	, line_id				int
	, company_id			int
	, profit_ctr_id			int
	, resource_class_code	varchar(10)
	, transaction_date		datetime
	, effective_date		datetime
	, stop_fee_price		money
	, stop_fee_description	varchar(100)
	, disposal_description	varchar(50)
)

-- Get transaction key info into #RCB
INSERT #RCB (trans_source, receipt_id, line_id, company_id, profit_ctr_id, resource_class_code)
SELECT DISTINCT
	b.trans_source
	, b.receipt_id
	, b.line_id
	, b.company_id
	, b.profit_ctr_id
	, CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE b.workorder_resource_item
		END
FROM BillingDetail bd
JOIN Billing b ON b.billing_uid = bd.billing_uid
WHERE 1=1
AND b.status_code = 'I'
AND b.customer_id = @customer_id
AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR b.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)
AND CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE isnull(b.workorder_resource_item, '')
		END <> ''

-- update RCB to set the correct transation_date per row:
	-- Workorders:
	UPDATE #RCB	SET transaction_date = wh.start_date
	FROM #RCB INNER JOIN WorkorderHeader wh 
		ON #RCB.receipt_id = wh.workorder_id
		AND #RCB.company_id = wh.company_id
		AND #RCB.profit_ctr_id = wh.profit_ctr_id
	WHERE #RCB.transaction_date IS NULL
		AND #RCB.trans_source = 'W'

	-- Receipts linked to Workorders:
	UPDATE #RCB	SET transaction_date = wh.start_date
	FROM #RCB INNER JOIN Receipt r
		ON #RCB.receipt_id = r.receipt_id
		AND #RCB.company_id = r.company_id
		AND #RCB.profit_ctr_id = r.profit_ctr_id
	INNER JOIN BillingLinkLookup bll
		ON r.receipt_id = bll.receipt_id
		and r.company_id = bll.company_id
		and r.profit_ctr_id = bll.profit_ctr_id
	INNER JOIN WorkorderHeader wh
		ON bll.source_id = wh.workorder_id
		AND bll.source_company_id = wh.company_id
		and bll.source_profit_ctr_id = wh.profit_ctr_id
	WHERE #RCB.transaction_date IS NULL
		AND #RCB.trans_source = 'R'

	-- Receipts not linked to Workorders, where there's a ReceiptTransporter Sign Date:
	UPDATE #RCB	SET transaction_date = rt.transporter_sign_date
	FROM #RCB INNER JOIN Receipt r
		ON #RCB.receipt_id = r.receipt_id
		AND #RCB.company_id = r.company_id
		AND #RCB.profit_ctr_id = r.profit_ctr_id
	INNER JOIN ReceiptTransporter rt
		ON r.receipt_id = rt.receipt_id
		AND r.company_id = rt.company_id
		AND r.profit_ctr_id = rt.profit_ctr_id
		AND rt.transporter_sequence_id = 1
		AND rt.transporter_sign_date IS NOT NULL
	WHERE #RCB.transaction_date IS NULL
		AND #RCB.trans_source = 'R'
		AND NOT EXISTS (
			SELECT 1 FROM
			BillingLinkLookup bll
			WHERE r.receipt_id = bll.receipt_id
			and r.company_id = bll.company_id
			and r.profit_ctr_id = bll.profit_ctr_id
		)

	-- Receipts not linked to Workorders, where there's no ReceiptTransporter Sign Date:
	UPDATE #RCB	SET transaction_date = r.receipt_date
	FROM #RCB INNER JOIN Receipt r
		ON #RCB.receipt_id = r.receipt_id
		AND #RCB.company_id = r.company_id
		AND #RCB.profit_ctr_id = r.profit_ctr_id
	WHERE #RCB.transaction_date IS NULL
		AND #RCB.trans_source = 'R'
		AND NOT EXISTS (
			SELECT 1 FROM
			ReceiptTransporter rt
			WHERE r.receipt_id = rt.receipt_id
			AND r.company_id = rt.company_id
			AND r.profit_ctr_id = rt.profit_ctr_id
			AND rt.transporter_sequence_id = 1
			AND rt.transporter_sign_date IS NOT NULL
		)
		AND NOT EXISTS (
			SELECT 1 FROM
			BillingLinkLookup bll
			WHERE r.receipt_id = bll.receipt_id
			and r.company_id = bll.company_id
			and r.profit_ctr_id = bll.profit_ctr_id
		)
		
	-- Populate #RCB effective_date based on the keys gathered:
	UPDATE #RCB SET effective_date = (
		select max(rcb.effective_date)
		FROM #RCB r2 INNER JOIN ResourceClassBundle rcb 
			ON r2.resource_class_code = rcb.resource_class_code
			AND rcb.effective_date < r2.transaction_date
		WHERE r2.rcb_id = #RCB.rcb_id
	)
	
	-- Populate #RCB Fields based on effective_date
	UPDATE #RCB SET
		stop_fee_price = rcb.stop_fee_price
		, stop_fee_description = rcb.stop_fee_description
		, disposal_description = rcb.disposal_description
	FROM #RCB inner join ResourceClassBundle rcb
		ON #RCB.resource_class_code = rcb.resource_class_code
		AND #RCB.effective_date = rcb.effective_date

	
INSERT INTO #tmp
SELECT b.invoice_id
	, b.invoice_code
	, b.invoice_date
	, CASE bd.billing_type
		WHEN 'WorkOrder' THEN 
			CASE WHEN rcb.resource_class_code IS NULL THEN 20
			ELSE 10
			END
		WHEN 'Disposal' THEN 30
		WHEN 'Product' THEN 30
		WHEN 'Wash' THEN 30
		WHEN 'State-Haz' THEN 150
		WHEN 'State-Perp' THEN 160
		WHEN 'Retail' THEN 170
		WHEN 'Insurance' THEN 180
		WHEN 'Energy' THEN 190
		WHEN 'SalesTax' THEN 200
		ELSE 300
		END AS invoice_sequence
	, b.status_code
	, b.customer_id
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE b.generator_id
		END AS generator_id
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.trans_source
		END AS trans_source
		
	, bd.billing_type
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.company_id
		END AS company_id
		
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.profit_ctr_id
		END AS profit_ctr_id
		
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.receipt_id
		END AS receipt_id
		
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.line_id
		END AS line_id
		
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE bd.price_id
		END AS price_id
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN NULL
		WHEN 'Energy' THEN NULL
		WHEN 'SalesTax' THEN NULL
		WHEN 'State-Haz' THEN NULL
		WHEN 'State-Perp' THEN NULL
		ELSE b.billing_date
		END AS billing_date
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE b.workorder_resource_type
		END AS resource_type
		
	, CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE CASE 
			WHEN rcb.resource_class_code IS NULL THEN ''
			ELSE rcb.resource_class_code
			END
		END AS resource_class_code
	, b.profile_id
	, b.approval_code
	
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 'Insurance Surcharge'
		WHEN 'Energy' THEN 'Energy Surcharge'
		WHEN 'SalesTax' THEN p.description
		WHEN 'State-Haz' THEN 'Michigan Hazardous Surcharge'
		WHEN 'State-Perp' THEN 'Michigan Perpetual Care Surcharge'
		ELSE b.service_desc_1
		END AS service_desc_1
	, bd.product_id
	, bd.sales_tax_id
	
	, CASE bd.billing_type 
		WHEN 'Insurance' THEN 1
		WHEN 'Energy' THEN 1
		WHEN 'SalesTax' THEN 1
		WHEN 'State-Haz' THEN 1
		WHEN 'State-Perp' THEN 1
		ELSE b.quantity
		END AS quantity
		
	, CASE bd.billing_type 
		WHEN 'Insurance' THEN 'EACH'
		WHEN 'Energy' THEN 'EACH'
		WHEN 'SalesTax' THEN 'EACH'
		WHEN 'State-Haz' THEN 'EACH'
		WHEN 'State-Perp' THEN 'EACH'
		ELSE b.bill_unit_code
		END AS bill_unit_code
		
	, CASE bd.billing_type 
		WHEN 'Insurance' THEN bd.extended_amt
		WHEN 'Energy' THEN bd.extended_amt
		WHEN 'SalesTax' THEN bd.extended_amt
		WHEN 'State-Haz' THEN b.sr_price
		WHEN 'State-Perp' THEN b.sr_price
		ELSE b.price
		END AS price
	, bd.extended_amt AS actual_extended_amt
	, rcb.stop_fee_price AS stop_fee_from_quote
	, rcb.stop_fee_price - bd.extended_amt AS diff
	, CASE WHEN rcb.resource_class_code IS NULL THEN 0
		ELSE 10*ROW_NUMBER() OVER(PARTITION BY b.invoice_id, bd.company_id, bd.profit_ctr_id
			ORDER BY b.invoice_id, bd.company_id, bd.profit_ctr_id ASC)
		END AS special_stop_fee
FROM BillingDetail bd
JOIN Billing b ON b.billing_uid = bd.billing_uid
LEFT OUTER JOIN Product p ON p.product_id = bd.product_id
	AND p.company_id = bd.dist_company_id
	AND p.profit_ctr_id = bd.dist_profit_ctr_id
LEFT OUTER JOIN #RCB rcb ON 
rcb.trans_source = b.trans_source
AND rcb.receipt_id = b.receipt_id
AND rcb.line_id = b.line_id
AND rcb.company_id = b.company_id
AND rcb.profit_ctr_id = b.profit_ctr_id
AND rcb.resource_class_code = CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE b.workorder_resource_item
		END
WHERE 1=1
AND b.status_code = 'I'
AND b.customer_id = @customer_id
AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR b.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)



INSERT INTO #tmp (invoice_id
	, invoice_code
	, invoice_date
	, invoice_sequence
	, status_code
	, customer_id
	, resource_class_code
	, service_desc_1
	, actual_extended_amt
)
SELECT DISTINCT a.invoice_id
	, a.invoice_code
	, a.invoice_date
	, 500 AS invoice_sequence
	, a.status_code
	, a.customer_id
	, '' AS resource_class_code
	, 'Invoice Total' AS service_desc_1
	, ih.total_amt_due
FROM #tmp a
JOIN InvoiceHeader ih ON ih.invoice_id = a.invoice_id
	AND ih.revision_id = (SELECT MAX(revision_id) FROM InvoiceHeader WHERE invoice_id = a.invoice_id)
	AND ih.status = 'I'

	
	

-----------------------------------------------------------------------------------------------------
-- Update information on the disposal records that are included in the Stop Fee
-----------------------------------------------------------------------------------------------------
UPDATE disp_included SET special_stop_fee = -wo_with_stop_fee.special_stop_fee
	, resource_class_code = wo_with_stop_fee.resource_class_code
	, service_desc_1 = rcb.disposal_description
	, company_id = NULL
	, profit_ctr_id = NULL
	, trans_source = NULL
	, receipt_id = NULL
	, line_id = NULL
	, invoice_sequence = 10
FROM #tmp disp_included
JOIN BillingLinkLookup bll ON bll.company_id = disp_included.company_id
	AND bll.profit_ctr_id = disp_included.profit_ctr_id
	AND bll.receipt_id = disp_included.receipt_id
JOIN #tmp wo_with_stop_fee ON wo_with_stop_fee.company_id = bll.source_company_id
	AND wo_with_stop_fee.profit_ctr_id = bll.source_profit_ctr_id
	AND wo_with_stop_fee.receipt_id = bll.source_id
	AND wo_with_stop_fee.trans_source = 'W'
	AND wo_with_stop_fee.special_stop_fee > 0
JOIN ProfileQuoteDetail pqd ON pqd.company_id = disp_included.company_id
	AND pqd.profit_ctr_id = disp_included.profit_ctr_id
	AND pqd.profile_id = disp_included.profile_id
	AND pqd.resource_class_code = wo_with_stop_fee.resource_class_code
	AND pqd.bill_method = 'B'
	AND pqd.record_type = 'R'
JOIN #RCB rcb ON rcb.resource_class_code = wo_with_stop_fee.resource_class_code
WHERE disp_included.trans_source = 'R'
--AND disp_included.billing_type = 'Disposal'		-- Don't include just disposal, because sometimes the disposal is split into products (distributed revenue)
AND disp_included.billing_type NOT IN ('Insurance', 'Energy', 'SalesTax', 'State-Haz', 'State-Perp')


-----------------------------------------------------------------------------------------------------
-- Insert into #tmpsum
-----------------------------------------------------------------------------------------------------
SELECT invoice_id		
	, invoice_code
	, invoice_date
	, invoice_sequence
	, customer_id
	, generator_id
	, billing_date
	, company_id
	, profit_ctr_id
	, trans_source
	, receipt_id
	, line_id
	, resource_class_code
	, service_desc_1
	, special_stop_fee
	, SUM(actual_extended_amt) AS actual_extended_amt
	, stop_fee_from_quote
	, CONVERT(money, NULL) AS special_invoice_amt
	, diff
	, CONVERT(varchar(255), NULL) AS validation_message
INTO #tmpsum
FROM #tmp
GROUP BY invoice_id
	, invoice_code
	, invoice_date
	, invoice_sequence
	, customer_id
	, generator_id
	, billing_date
	, company_id
	, profit_ctr_id
	, trans_source
	, receipt_id
	, line_id
	, resource_class_code
	, service_desc_1
	, special_stop_fee
	, stop_fee_from_quote
	, diff

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for the Stop Fee itself
-----------------------------------------------------------------------------------------------------
UPDATE #tmpsum SET special_invoice_amt = actual_extended_amt + diff
WHERE ISNULL(resource_class_code, '') > ''
AND special_stop_fee > 0
AND diff IS NOT NULL

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for the Disposal that is included in the Stop Fee
-----------------------------------------------------------------------------------------------------
UPDATE disposal SET diff = -workorder.diff, special_invoice_amt = disposal.actual_extended_amt - workorder.diff
FROM #tmpsum disposal
JOIN #tmpsum workorder ON workorder.invoice_id = disposal.invoice_id
	AND workorder.generator_id = disposal.generator_id
	AND workorder.resource_class_code = disposal.resource_class_code
	AND workorder.special_stop_fee > 0
	AND workorder.diff IS NOT NULL
WHERE ISNULL(disposal.resource_class_code, '') > ''
AND disposal.special_stop_fee < 0

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for all the other lines that haven't already been calculated
-----------------------------------------------------------------------------------------------------
UPDATE #tmpsum SET special_invoice_amt = actual_extended_amt
WHERE special_invoice_amt IS NULL
AND service_desc_1 <> 'Invoice Total'

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for the Invoice Total line
-- This is so that we can compare the actual amount billed to the special invoice's total.
-----------------------------------------------------------------------------------------------------
UPDATE #tmpsum SET special_invoice_amt = x.sum_special_invoice_amt
FROM #tmpsum
JOIN (SELECT invoice_id, SUM(special_invoice_amt) AS sum_special_invoice_amt 
	FROM #tmpsum
	GROUP BY invoice_id) x ON x.invoice_id = #tmpsum.invoice_id
WHERE special_invoice_amt IS NULL
AND service_desc_1 = 'Invoice Total'


-----------------------------------------------------------------------------------------------------
-- Add some validation here
-----------------------------------------------------------------------------------------------------
-- Validate that the actual amount of the Stop Fee doesn't exceed the quoted price from ResourceClassBundle
UPDATE #tmpsum SET validation_message = CASE WHEN validation_message IS NULL 
	THEN 'Invoice ' + invoice_code + ':  Stop Fee "' + resource_class_code + '" ($' + CONVERT(varchar(10), actual_extended_amt) + ') was charged more than the customer quoted amount of $' + CONVERT(varchar(10), stop_fee_from_quote) + '.'
	ELSE validation_message + '  Invoice ' + invoice_code + ':  Stop Fee "' + resource_class_code + '" ($' + CONVERT(varchar(10), actual_extended_amt) + ') was charged more than the customer quoted amount of $' + CONVERT(varchar(10), stop_fee_from_quote) + '.'
	END
WHERE ISNULL(resource_class_code, '') > ''
AND special_stop_fee > 0
AND actual_extended_amt > stop_fee_from_quote


-- Validate that the special invoice amount doesn't end up being negative 
-- This could happen if they do the math wrong when calculating what the amount of the Stop Fee should be
UPDATE #tmpsum SET validation_message = CASE WHEN validation_message IS NULL 
	THEN 'Invoice ' + invoice_code + ':  Special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ') is less than $0.00.'
	ELSE validation_message + '  Invoice ' + invoice_code + ':  Special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ') is less than $0.00.'
	END
WHERE special_invoice_amt < 0


-- Validate that the actual amount of the invoice (from InvoiceHeader) matches the sum total of the "special" invoice
UPDATE #tmpsum SET validation_message = CASE WHEN validation_message IS NULL 
	THEN 'Invoice ' + invoice_code + ':  Actual invoice amount ($' + CONVERT(varchar(10), actual_extended_amt) + ') does not match special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ').'
	ELSE validation_message + '  Invoice ' + invoice_code + ':  Actual invoice amount ($' + CONVERT(varchar(10), actual_extended_amt) + ') does not match special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ').'
	END
WHERE service_desc_1 = 'Invoice Total'
AND actual_extended_amt <> special_invoice_amt


--SELECT * FROM #tmpsum
--ORDER BY invoice_id, invoice_sequence, resource_class_code, special_stop_fee DESC

SELECT
	#tmpsum.invoice_id	
	, ih.revision_id	
	, #tmpsum.invoice_code
	, #tmpsum.invoice_date
	, ih.due_date
	, compmain.remit_to
	, compmain.phone_customer_service
	, #tmpsum.customer_id
	, c.cust_name
	, ih.addr1
	, ih.addr2
	, ih.addr3
	, ih.addr4
	, ih.addr5
	, ih.attention_name
	, ih.customer_po
	, ih.customer_release
	, #tmpsum.invoice_sequence
	, #tmpsum.generator_id
	, g.EPA_ID
	, g.generator_name
	, #tmpsum.billing_date
	, #tmpsum.company_id
	, #tmpsum.profit_ctr_id
	, comptransaction.company_name
	, #tmpsum.trans_source
	, #tmpsum.receipt_id
	, #tmpsum.line_id
	, #tmpsum.resource_class_code
	, #tmpsum.service_desc_1
	, #tmpsum.special_stop_fee
	, #tmpsum.actual_extended_amt
	, #tmpsum.stop_fee_from_quote
	, #tmpsum.special_invoice_amt
	, #tmpsum.diff
	, #tmpsum.validation_message
FROM #tmpsum
JOIN Customer c ON c.customer_id = #tmpsum.customer_id
LEFT OUTER JOIN Company comptransaction ON comptransaction.company_id = #tmpsum.company_id
JOIN Company compmain ON compmain.company_id = 1
JOIN InvoiceHeader ih ON ih.invoice_id = #tmpsum.invoice_id
	AND ih.revision_id = (SELECT MAX(revision_id) FROM InvoiceHeader WHERE invoice_id = #tmpsum.invoice_id)
	AND ih.status = 'I'
LEFT OUTER JOIN Generator g ON g.generator_id = #tmpsum.generator_id
WHERE #tmpsum.special_invoice_amt > 0.00
ORDER BY #tmpsum.invoice_id, #tmpsum.invoice_sequence, #tmpsum.resource_class_code, #tmpsum.special_stop_fee DESC



--SELECT *, 0 AS special_stop_fee, 0 AS processed
--INTO #tmp_Billing
--FROM Billing b
--WHERE 1=1
--AND b.status_code = 'I'
--AND b.customer_id = @customer_id
--AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR b.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
--AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)

--SELECT * FROM #tmp_Billing

--SELECT bd.*, 0 AS processed
--INTO #tmp_BillingDetail
--FROM BillingDetail bd
--JOIN #tmp_Billing b ON b.billing_uid = bd.billing_uid

--DROP TABLE #tmp_Billing
--DROP TABLE #tmp_BillingDetail
DROP TABLE #tmp
DROP TABLE #tmpsum

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice] TO [EQAI]
    AS [dbo];

