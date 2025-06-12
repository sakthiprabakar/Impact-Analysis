CREATE PROCEDURE sp_rite_aid_invoice_v2_detail (
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

01/21/2013 JPB	Copied this to sp_rite_aid_invoice_v2_detail from sp_rite_aid_invoice
				Determined during the build for their new invoice that you just could. not. use.
				the existing sp because it returned the summary rows in the same recordset as the
				detail rows and you couldn't summarize just the detail parts because they were all
				lumped together. argh.
				
				So here we are.  The plan will be to run Detail for the detail spreadsheet. The
				summary invoice will call detail (to a table) and then summarize that as needed.

02/14/2013 JPB	Added ability to find preview invoices
02/18/2013 JPB	Removed DISTINCT from the first #tmp select, it was hiding tax amounts by accident.

06/06/2013 JPB  Change to Order By on final outputs to force States to come out together.

06/02/2014	JPB	Converted smallint fields to int

10/06/2014 JDB	Modified to handle bundled products by excluding them from the insert into the #tmp
				table, but still including their extended_amt in the total for the line.
01/31/2018 JPB	Added 2nd-pass update of service date values in case the work order that's supposed
				to provide the value is not in billing/valid for this update.
07/08/2024 KS	Rally116985 - Modified service_desc_1 datatype to VARCHAR(100) for #tmp table.

SELECT * FROM invoiceheader ih 
INNER JOIN invoicedetail id on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id
where ih.customer_id = 14231 
and ih.status = 'I'
and isnull(line_desc_2, '') like '%lbs%'
-- and id.billing_date > '12/1/2012'
order by invoice_date desc

-- There's not one.  Let's make one.  After all, this is dev.

--	1. find a suitable victim. Want one that'll have a lbs overage.
SELECT * FROM ResourceClassBundle where stop_fee_description like 'CT Rx Waste Removal Up to %'
-- Got one.  40426423 / 892197

SELECT * FROM billing where invoice_id = 892197 -- 2012-11-15, 2012-11-05
update billing set billing_date = billing_date + 30 where invoice_id = 892197 -- Poof.

-- Unfortunately, it's already in billing and I don't feel like mangling all the records. So some won't be congruent.

and id.line_desc_1 in (Select disposal_Description from resourceclassbundle)
order by ih.invoice_date desc

SELECT * FROM customer where cust_name like 'rite%aid%'

SELECT * FROM invoiceheader where invoice_code = '40426423'
SELECT * FROM invoicedetail where invoice_id = 892196 

EXECUTE sp_rite_aid_invoice_v2_detail 14231, null, null, '1/27/13', '1/29/13'
EXECUTE sp_rite_aid_invoice 14231, '40426423', '40426423', '1/1/12', '12/31/13'
EXECUTE sp_rite_aid_invoice 14231, '40426422', '40426424', '1/1/12', '12/31/13'

--EXECUTE sp_rite_aid_invoice_v2_detail 14232, '40402256', '40402256', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_detail 14232, '40402257', '40402257', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_detail 14232, '40402258', '40402258', '9/10/12', '9/11/12'
--EXECUTE sp_rite_aid_invoice_v2_detail 14232, '40402260', '40402260', '9/10/12', '9/11/12'

select 141.75 + 172.51 + 19.34
select 130.97 + 144.89 + 19.34
select 17.59 + 9.00 + 21.25 + 53.35 + 149.40 + 15.92 -- = 266.51

--SELECT * FROM WorkOrderDetail WHERE resource_class_code IN ('STOPFEECT','STOPFEECTP','STOPFEEMA','STOPFEEMAP','STOPFEEVT','STOPFEEVTP','STOPFEEMI','STOPFEEMIP','STOPFEEOH','STOPFEEOHP','STOPFEENJ','STOPFEENJP')

EXECUTE sp_rite_aid_invoice_v2_detail 14231, 'Preview_1327408', 'Preview_1327408', '8/28/2014', '8/30/2019'

SELECT  * FROM  billing 
WHERE receipt_id = 1992988 
and company_id = 21
and profit_ctr_id = 0

*************************************************************************************************/

declare @force_dev_mode		int = 0

CREATE TABLE #tmp (
	invoice_id					int				NOT NULL
	, invoice_code				varchar(16)		NOT NULL
	, invoice_date				datetime		NOT NULL
	, invoice_sequence			int		NOT NULL
	, status_code				char(1)			NULL
	, customer_id				int				NULL
	, generator_id				int				NULL
	, generator_site_code		varchar(16)		NULL
	, generator_city			varchar(40)		NULL
	, generator_state			varchar(2)		NULL
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
	, resource_description		varchar(100)	NULL
	, resource_unit_price		money			NULL
	, rx_overage				money			NULL
	, front_end_overage			money			NULL
	, rx_pounds					float			NULL
	, front_end_pounds			float			NULL
	, rx_pounds_included		float			NULL
	, front_end_pounds_included	float			NULL
	, rx_pounds_over_limit		float			NULL
	, front_end_pounds_over_limit	float		NULL
	, rx_overage_charge			money			NULL
	, front_end_overage_charge	money			NULL
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
	, special_stop_fee			int		NULL
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
	, unit_price			money
	, pounds_included		int
	, pharmacy_flag			char(1)
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
AND (b.status_code = 'I' OR (b.status_code = 'N' and invoice_preview_flag = 'T'))
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

/* During dev, I want to force a transaction date > 12/1/2012. */
if @force_dev_mode > 0
	update #rcb set transaction_date = transaction_date + 30 where transaction_date < '12/1/2012'

		
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
		, unit_price = rcb.unit_price
		, pounds_included = rcb.pounds_included
		, pharmacy_flag = rcb.pharmacy_flag
	FROM #RCB inner join ResourceClassBundle rcb
		ON #RCB.resource_class_code = rcb.resource_class_code
		AND #RCB.effective_date = rcb.effective_date

-- SELECT * FROM #rcb
	
INSERT INTO #tmp
SELECT -- do NOT do distinct here.
	b.invoice_id
	, b.invoice_code
	, b.invoice_date
	, CASE bd.billing_type
		WHEN 'WorkOrder' THEN 
			CASE WHEN rcb.resource_class_code IS NULL THEN 20
			ELSE CASE WHEN rcb.resource_class_code LIKE 'STPFE%' THEN 5 ELSE 10 END
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
	, g.generator_id
	, g.site_code AS generator_site_code
	, g.generator_city
	, g.generator_state

	,	
--	, CASE bd.billing_type
--		WHEN 'Insurance' THEN NULL
--		WHEN 'Energy' THEN NULL
--		WHEN 'SalesTax' THEN NULL
--		WHEN 'State-Haz' THEN NULL
--		WHEN 'State-Perp' THEN NULL
--		ELSE 
		bd.trans_source
--		END AS trans_source
		
	, bd.billing_type

	,	
--	, CASE bd.billing_type
--		WHEN 'Insurance' THEN NULL
--		WHEN 'Energy' THEN NULL
--		WHEN 'SalesTax' THEN NULL
--		WHEN 'State-Haz' THEN NULL
--		WHEN 'State-Perp' THEN NULL
--		ELSE 
		bd.company_id
--		END AS company_id

	,		
--	, CASE bd.billing_type
--		WHEN 'Insurance' THEN NULL
--		WHEN 'Energy' THEN NULL
--		WHEN 'SalesTax' THEN NULL
--		WHEN 'State-Haz' THEN NULL
--		WHEN 'State-Perp' THEN NULL
--		ELSE 
		bd.profit_ctr_id
--		END AS profit_ctr_id

	, 
--	CASE bd.billing_type
--		WHEN 'Insurance' THEN NULL
--		WHEN 'Energy' THEN NULL
--		WHEN 'SalesTax' THEN NULL
--		WHEN 'State-Haz' THEN NULL
--		WHEN 'State-Perp' THEN NULL
--		ELSE 
		bd.receipt_id
--		END AS receipt_id
		
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
		
	, CASE 
		WHEN rcb.resource_class_code IS NULL THEN ''
		ELSE rcb.resource_class_code
		END AS resource_class_code
		
	, rcb.stop_fee_description as resource_description
	, coalesce(rcb.stop_fee_price, 
		CASE bd.billing_type 
			WHEN 'Insurance' THEN bd.extended_amt
			WHEN 'Energy' THEN bd.extended_amt
			WHEN 'SalesTax' THEN bd.extended_amt
			-- 10-6-2014 JDB - Change this to get the extended amount for the MI Surcharges:
			--WHEN 'State-Haz' THEN b.sr_price
			--WHEN 'State-Perp' THEN b.sr_price
			WHEN 'State-Haz' THEN bd.extended_amt
			WHEN 'State-Perp' THEN bd.extended_amt
			ELSE b.price
			END
		) as resource_unit_price

	, 0 as rx_overage			-- update later
	, 0 as front_end_overage	-- update later
	, 0 as rx_pounds			-- update later
	, 0 as front_end_pounds		-- update later
	, CASE WHEN isnull(rcb.pharmacy_flag, 'F') = 'T' then rcb.pounds_included else 0 end as rx_pounds_included
	, CASE WHEN isnull(rcb.pharmacy_flag, 'F') = 'F' then rcb.pounds_included else 0 end as front_end_pounds_included
	, 0 as rx_pounds_over_limit
	, 0 as front_end_pounds_over_limit

	, CASE WHEN isnull(rcb.pharmacy_flag, 'F') = 'T' then rcb.unit_price else 0 end as rx_overage_charge
	, CASE WHEN isnull(rcb.pharmacy_flag, 'F') = 'F' then rcb.unit_price else 0 end as front_end_overage_charge
		
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
		-- 10-6-2014 JDB - Change this to get the extended amount for the MI Surcharges:
		--WHEN 'State-Haz' THEN b.sr_price
		--WHEN 'State-Perp' THEN b.sr_price
		WHEN 'State-Haz' THEN bd.extended_amt
		WHEN 'State-Perp' THEN bd.extended_amt
		ELSE b.price
		END AS price
	
	-- 10-6-2014 JDB - Change this to get the total amount for the line:
	--, bd.extended_amt AS actual_extended_amt
	, actual_extended_amt = CASE WHEN bd.billing_type IN ('Disposal', 'Wash') THEN (SELECT SUM(bd2.extended_amt) FROM BillingDetail bd2 WHERE bd.billing_uid = bd2.billing_uid AND bd2.billing_type NOT IN ('State-Haz', 'State-Perp', 'SalesTax'))
		WHEN bd.billing_type IN ('Product') AND ref_billingdetail_uid IS NULL THEN (SELECT SUM(bd2.extended_amt) FROM BillingDetail bd2 WHERE bd.billing_uid = bd2.billing_uid AND bd2.billing_type NOT IN ('State-Haz', 'State-Perp', 'SalesTax'))
		ELSE bd.extended_amt
		END
	
	, rcb.stop_fee_price AS stop_fee_from_quote
	-- 10-6-2014 JDB - Change this to get the total amount for the line:
	--, rcb.stop_fee_price - bd.extended_amt AS diff
	, rcb.stop_fee_price - (CASE WHEN bd.billing_type IN ('Disposal', 'Wash') THEN (SELECT SUM(bd2.extended_amt) FROM BillingDetail bd2 WHERE bd.billing_uid = bd2.billing_uid AND bd2.billing_type NOT IN ('State-Haz', 'State-Perp', 'SalesTax'))
							WHEN bd.billing_type IN ('Product') AND ref_billingdetail_uid IS NULL THEN (SELECT SUM(bd2.extended_amt) FROM BillingDetail bd2 WHERE bd.billing_uid = bd2.billing_uid AND bd2.billing_type NOT IN ('State-Haz', 'State-Perp', 'SalesTax'))
							ELSE bd.extended_amt
							END
							) AS diff
			
	, CASE WHEN rcb.resource_class_code IS NULL THEN 0
		ELSE 10*ROW_NUMBER() OVER(PARTITION BY b.invoice_id, bd.company_id, bd.profit_ctr_id
			ORDER BY b.invoice_id, bd.company_id, bd.profit_ctr_id ASC)
		END AS special_stop_fee
FROM BillingDetail bd
JOIN Billing b ON b.billing_uid = bd.billing_uid
LEFT OUTER JOIN Product p ON p.product_id = bd.product_id
	AND p.company_id = bd.dist_company_id
	AND p.profit_ctr_id = bd.dist_profit_ctr_id
LEFT OUTER JOIN #RCB rcb ON rcb.resource_class_code = b.workorder_resource_item
	AND rcb.trans_source = b.trans_source
	AND rcb.receipt_id = b.receipt_id
	AND rcb.line_id = b.line_id
	AND rcb.company_id = b.company_id
	AND rcb.profit_ctr_id = b.profit_ctr_id
	AND bd.billing_type NOT IN ('Insurance', 'Energy', 'SalesTax', 'State-Haz', 'State-Perp')
LEFT OUTER JOIN generator g on b.generator_id = g.generator_id
	AND bd.billing_type NOT IN ('Insurance', 'Energy', 'SalesTax', 'State-Haz', 'State-Perp')
WHERE 1=1
AND (b.status_code = 'I' OR (b.status_code = 'N' and invoice_preview_flag = 'T'))
-- 10-6-2014 JDB - Exclude bundled products:
AND NOT (bd.billing_type = 'Product' AND ref_billingdetail_uid IS NOT NULL)
AND b.customer_id = @customer_id
AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR b.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)


-----------------------------------------------------------------------------------------------------
-- Update information on the disposal records that are included in the Stop Fee
-----------------------------------------------------------------------------------------------------
UPDATE disp_included SET special_stop_fee = -wo_with_stop_fee.special_stop_fee
	, resource_class_code = wo_with_stop_fee.resource_class_code
	, service_desc_1 = rcb.disposal_description
	, company_id = bll.source_company_id
	, profit_ctr_id = bll.source_profit_ctr_id
	, receipt_id = bll.source_id
	, line_id = NULL
	, invoice_sequence = 10
	, generator_id = wo_with_stop_fee.generator_id
	, generator_site_code = wo_with_stop_fee.generator_site_code
	, generator_city = wo_with_stop_fee.generator_city
	, generator_state = wo_with_stop_fee.generator_state
	, billing_date = wo_with_stop_fee.billing_date
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
AND disp_included.billing_type NOT IN ('Insurance', 'Energy', 'SalesTax', 'State-Haz', 'State-Perp')

-- Attribute all the receipt info to the workorder that'll display in output
UPDATE disp_included SET company_id = wo_with_stop_fee.company_id
	, profit_ctr_id = wo_with_stop_fee.profit_ctr_id
	, trans_source = 'W'
	, receipt_id = wo_with_stop_fee.receipt_id
	, line_id = NULL
	, generator_id = wo_with_stop_fee.generator_id
	, generator_site_code = wo_with_stop_fee.generator_site_code
	, generator_city = wo_with_stop_fee.generator_city
	, generator_state = wo_with_stop_fee.generator_state
	, billing_date = wo_with_stop_fee.billing_date
FROM #tmp disp_included
JOIN BillingLinkLookup bll ON bll.company_id = disp_included.company_id
	AND bll.profit_ctr_id = disp_included.profit_ctr_id
	AND bll.receipt_id = disp_included.receipt_id
JOIN #tmp wo_with_stop_fee ON wo_with_stop_fee.company_id = bll.source_company_id
	AND wo_with_stop_fee.profit_ctr_id = bll.source_profit_ctr_id
	AND wo_with_stop_fee.receipt_id = bll.source_id
	AND wo_with_stop_fee.trans_source = 'W'
	AND wo_with_stop_fee.special_stop_fee > 0
WHERE disp_included.trans_source = 'R'

UPDATE disp_included SET generator_id = wg.generator_id
	, generator_site_code = wg.generator_site_code
	, generator_city = wg.generator_city
	, generator_state = wg.generator_state
	, billing_date = wg.billing_date
FROM #tmp disp_included
JOIN #tmp wg ON wg.company_id = disp_included.company_id
	AND wg.profit_ctr_id = disp_included.profit_ctr_id
	AND wg.receipt_id = disp_included.receipt_id
	AND wg.trans_source = disp_included.trans_source
	AND wg.generator_id is not null
WHERE disp_included.trans_source = 'W'
	and disp_included.generator_id is null

-- last chance: update billing_date to service date if it's still the original billing_date
UPDATE #tmp set billing_date = rt.transporter_sign_date
from #tmp t
join billing b
	on t.receipt_id = b.receipt_id
	and t.line_id = b.line_id
	and t.company_id = b.company_id
	and t.profit_ctr_id = b.profit_ctr_id
join receipttransporter rt
	on t.receipt_id = rt.receipt_id
	and t.company_id = rt.company_id
	and t.profit_ctr_id = rt.profit_ctr_id
	and rt.transporter_sequence_id = 1
WHERE t.trans_source = 'R'
	and t.billing_date = b.billing_date

-- select * from #tmp order by receipt_id, line_id, price_id, invoice_sequence, profile_id, product_id

-- Update pounds & overage fields:

update #tmp set front_end_pounds = (
--	select sum(case when round(cast(quantity as decimal), 0) = 0 then 1 else round(cast(quantity as decimal), 0) end) from #tmp c
	select sum(quantity) from #tmp c
	where 
	c.invoice_id = o.invoice_id
	and c.receipt_id = o.receipt_id
	and c.company_id = o.company_id
	and c.profit_ctr_id = o.profit_ctr_id
	and c.resource_class_code = o.resource_class_code
	and c.billing_type = 'disposal'
) 
from #tmp o
inner join #rcb rcb
	on rcb.trans_source = o.trans_source
	AND rcb.receipt_id = o.receipt_id
	AND rcb.line_id = o.line_id
	AND rcb.company_id = o.company_id
	AND rcb.profit_ctr_id = o.profit_ctr_id
	and rcb.resource_class_code = o.resource_class_code
where o.trans_source = 'W' and o.billing_type = 'WorkOrder' and o.resource_unit_price is not null
and isnull(rcb.pharmacy_flag, 'F') = 'F'

update #tmp set rx_pounds = (
	-- select sum(case when round(cast(quantity as decimal), 0) = 0 then 1 else round(cast(quantity as decimal), 0) end) from #tmp c
	select sum(quantity) from #tmp c
	where 
	c.invoice_id = o.invoice_id
	and c.receipt_id = o.receipt_id
	and c.company_id = o.company_id
	and c.profit_ctr_id = o.profit_ctr_id
	and c.resource_class_code = o.resource_class_code
	and c.billing_type = 'disposal'
)
from #tmp o
inner join #rcb rcb
	on rcb.trans_source = o.trans_source
	AND rcb.receipt_id = o.receipt_id
	AND rcb.line_id = o.line_id
	AND rcb.company_id = o.company_id
	AND rcb.profit_ctr_id = o.profit_ctr_id
	and rcb.resource_class_code = o.resource_class_code
where o.trans_source = 'W' and o.billing_type = 'WorkOrder' and o.resource_unit_price is not null
and isnull(rcb.pharmacy_flag, 'F') = 'T'

update #tmp set 
	rx_pounds_over_limit = case when rx_pounds > rx_pounds_included then rx_pounds - rx_pounds_included else 0 end,
	front_end_pounds_over_limit = case when front_end_pounds > front_end_pounds_included then front_end_pounds - front_end_pounds_included else 0 end

update #tmp set rx_overage = rx_overage_charge * rx_pounds_over_limit, front_end_overage = front_end_overage_charge * front_end_pounds_over_limit



-- SELECT * FROM #tmp

-----------------------------------------------------------------------------------------------------
-- Insert into #tmpsum
-----------------------------------------------------------------------------------------------------
SELECT invoice_id		
	, invoice_code
	, invoice_date
	, invoice_sequence
	, customer_id
	, generator_id
	, generator_site_code
	, generator_city
	, generator_state
	, billing_date
	, company_id
	, profit_ctr_id
	, trans_source
	, receipt_id
	, line_id
	, SUM(quantity) as quantity
	, resource_class_code
	, case when isnull(resource_class_code, '') <> '' then resource_description else NULL end as resource_description
	, SUM(resource_unit_price) as resource_unit_price
	, rx_overage
	, front_end_overage
	, rx_pounds
	, front_end_pounds
	, service_desc_1
	, special_stop_fee
	, SUM(actual_extended_amt) AS actual_extended_amt
	, stop_fee_from_quote
	, SUM(resource_unit_price + rx_overage + front_end_overage) AS special_invoice_amt
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
	, generator_site_code
	, generator_city
	, generator_state
	, billing_date
	, company_id
	, profit_ctr_id
	, trans_source
	, receipt_id
	, line_id
	, resource_class_code
	, case when isnull(resource_class_code, '') <> '' then resource_description else NULL end
	-- , resource_unit_price
	, rx_overage
	, front_end_overage
	, rx_pounds
	, front_end_pounds
	, service_desc_1
	, special_stop_fee
	, stop_fee_from_quote
	, diff

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for the Stop Fee itself
-----------------------------------------------------------------------------------------------------
/*
UPDATE #tmpsum SET special_invoice_amt = actual_extended_amt + diff
WHERE ISNULL(resource_class_code, '') > ''
AND special_stop_fee > 0
AND diff IS NOT NULL
*/

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

update #tmpsum set quantity = 1 where invoice_sequence > 100

-----------------------------------------------------------------------------------------------------
-- Update the special invoice amount for the Invoice Total line
-- This is so that we can compare the actual amount billed to the special invoice's total.
-----------------------------------------------------------------------------------------------------
/*
UPDATE #tmpsum SET special_invoice_amt = x.sum_special_invoice_amt
FROM #tmpsum
JOIN (SELECT invoice_id, SUM(special_invoice_amt) AS sum_special_invoice_amt 
	FROM #tmpsum
	GROUP BY invoice_id) x ON x.invoice_id = #tmpsum.invoice_id
WHERE special_invoice_amt IS NULL
AND service_desc_1 = 'Invoice Total'
*/

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

/*
-- Validate that the actual amount of the invoice (from InvoiceHeader) matches the sum total of the "special" invoice
UPDATE #tmpsum SET validation_message = CASE WHEN validation_message IS NULL 
	THEN 'Invoice ' + invoice_code + ':  Actual invoice amount ($' + CONVERT(varchar(10), actual_extended_amt) + ') does not match special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ').'
	ELSE validation_message + '  Invoice ' + invoice_code + ':  Actual invoice amount ($' + CONVERT(varchar(10), actual_extended_amt) + ') does not match special customer invoice amount ($' + CONVERT(varchar(10), special_invoice_amt) + ').'
	END
WHERE service_desc_1 = 'Invoice Total'
AND actual_extended_amt <> special_invoice_amt
*/

/* During dev, I want to force service_desc_1 = resource_description when not null */
if @force_dev_mode > 0
	update #tmpsum set service_desc_1 = resource_description where resource_description is not null

-- SELECT * FROM #tmpsum ORDER BY invoice_id, invoice_sequence, resource_class_code, special_stop_fee DESC

SELECT
	t.invoice_id	
	, ih.revision_id	
	, t.invoice_code
	, t.invoice_date
	, ih.due_date
	, compmain.remit_to
	, compmain.phone_customer_service
	, t.customer_id
	, c.cust_name
	, ih.addr1
	, ih.addr2
	, ih.addr3
	, ih.addr4
	, ih.addr5
	, ih.attention_name
	, ih.customer_po
	, ih.customer_release
	, t.invoice_sequence
	, t.generator_id
	, g.EPA_ID
	, g.generator_name
	, t.generator_site_code
	, t.generator_city
	, t.generator_state
	, t.billing_date
	, t.company_id
	, t.profit_ctr_id
	, comptransaction.company_name
	, t.trans_source
	, t.receipt_id
	, t.line_id
	, t.quantity
	, t.resource_class_code
	, t.resource_description
	, t.resource_unit_price
	, isnull(t.rx_overage, 0) as rx_overage
	, isnull(t.front_end_overage, 0) as front_end_overage
	, isnull(t.rx_pounds, 0) as rx_pounds
	, isnull(t.front_end_pounds, 0) as front_end_pounds
	, t.service_desc_1
	, t.special_stop_fee
	, t.actual_extended_amt
	, t.stop_fee_from_quote
	, t.special_invoice_amt
	, t.diff
	, t.validation_message
INTO #tmpOutput	
FROM #tmpsum t
JOIN Customer c ON c.customer_id = t.customer_id
LEFT OUTER JOIN Company comptransaction ON comptransaction.company_id = t.company_id
JOIN Company compmain ON compmain.company_id = 1
LEFT OUTER JOIN InvoiceHeader ih ON ih.invoice_id = t.invoice_id
	AND ih.revision_id = (SELECT MAX(revision_id) FROM InvoiceHeader WHERE invoice_id = t.invoice_id)
	AND ih.status = 'I'
LEFT OUTER JOIN Generator g ON g.generator_id = t.generator_id
WHERE t.special_invoice_amt > 0.00
and t.special_stop_fee >= 0.00 -- Excluding these because they were in the ORIGINAL Rite Aid format but should be excluded here (the overage price is worked into the stop fee line)
-- AND (service_desc_1 = 'Invoice Total' OR service_desc_1 LIKE '%Sales Tax')
ORDER BY t.invoice_id, t.invoice_sequence, t.resource_class_code, t.special_stop_fee DESC


SELECT *
FROM #tmpOutput
WHERE special_invoice_amt > 0
ORDER BY generator_state, invoice_id, generator_city, invoice_sequence
--compute sum(special_invoice_amt)

DROP TABLE #tmp
DROP TABLE #tmpsum

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rite_aid_invoice_v2_detail] TO [EQAI]
    AS [dbo];

