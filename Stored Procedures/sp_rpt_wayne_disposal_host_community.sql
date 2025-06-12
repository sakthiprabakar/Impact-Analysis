CREATE PROCEDURE sp_rpt_wayne_disposal_host_community 
	@company_id				int
	, @profit_ctr_id		int
	, @receipt_date_from	datetime
	, @receipt_date_to		datetime
AS
/*******************************************************************************************
This SP is called from the Wayne Disposal Community Agreement Reports. 
PB Object(s):	r_wayne_disposal_host_community_detail
				r_wayne_disposal_host_community_summary
				r_wayne_disposal_internal_audit_detail

This sp is loaded to Plt_AI.

07/26/2012 JDB	Created.
04/01/2013 RN	Added code for Internal Audit Report. 
01/20/2014 AM	Rajeswari added actual_quantity, actual_unit, actual_price, actual_amount columns to sp on 04/01/2013, But they never made it to production.
01/20/2014 AM	Added logic to exclude record when company is 3 Or Dispposal service is sub C Or actual_amount charge  > 0 
01/21/2014 JDB	Changed join to the Ref Receipt table (to get the WHCA products) to join to the minimum price_id for the receipt line.
				This is so that we can accurately display non-bulk receipt lines that are split into multiple units (i.e. 6 DM55 and 2 DM30 on the same line)
				The datawindow for the Internal Audit Report also needed to be updated accordingly so that it doesn't show and add up the duplicates.
01/22/2014 JDB	Added a calculated field called "sequence_id" to the #tmp table, to store a 1,2,3,.... sequence to the records for each receipt-line-price ID.
				We needed a way to identify the receipt lines that were split into multiple units, like DM30 and DM55.  In these cases, there exists a 
				WHCA product for each bill unit, but they all reference the same receipt line (but there's no way to indicate which *unit* they reference on that line).  
				This field will allow us to update the temp table -- see below -- to blank out the amount we owe the township for these	duplicated records.
01/23/2014 JDB	Included bundled WHCA charges into the report.  This required splitting the main select into a union of two selects.  The first gets the unbundled
				WHCA charges (unless there are no unbundled, but does have bundled), and the second gets the bundled WHCA charges.
01/24/2014 JDB	Included work order charges in the report.  This will be the third section of the UNION.
01/24/2014 JDB	Added the Customer.EQ_flag field in order to identify which customers are EQ inter-company, and which are real, paying customers.  We will
				show the difference on the Internal Audit Report.
01/27/2014 JDB	Added a new variable to store the date that the agreement went into effect.  Using this, we can zero out the amount EQ owes the township
				before that date.
				
sp_rpt_wayne_disposal_host_community 3, 0,'1/1/13', '3/31/13'
******************************************************************************************/
BEGIN

DECLARE	@agreement_effective_date	datetime

SET @agreement_effective_date = '9/27/2013'

CREATE TABLE #whca (
	bill_unit_code	varchar(4)
	, whca_fee		float
	)

INSERT INTO #whca VALUES ('GAL'		,0.01)
INSERT INTO #whca VALUES ('CUFT'	,0.06)
INSERT INTO #whca VALUES ('CYB'		,1.65)
INSERT INTO #whca VALUES ('D100'	,0.82)
INSERT INTO #whca VALUES ('D110'	,0.90)
INSERT INTO #whca VALUES ('DM01'	,0.01)
INSERT INTO #whca VALUES ('DM02'	,0.02)
INSERT INTO #whca VALUES ('DM05'	,0.04)
INSERT INTO #whca VALUES ('DM10'	,0.08)
INSERT INTO #whca VALUES ('DM12'	,0.10)
INSERT INTO #whca VALUES ('DM15'	,0.12)
INSERT INTO #whca VALUES ('DM16'	,0.13)
INSERT INTO #whca VALUES ('DM20'	,0.16)
INSERT INTO #whca VALUES ('DM25'	,0.20)
INSERT INTO #whca VALUES ('DM2X'	,0.02)
INSERT INTO #whca VALUES ('DM30'	,0.25)
INSERT INTO #whca VALUES ('DM35'	,0.29)
INSERT INTO #whca VALUES ('DM40'	,0.33)
INSERT INTO #whca VALUES ('DM45'	,0.37)
INSERT INTO #whca VALUES ('DM50'	,0.41)
INSERT INTO #whca VALUES ('DM55'	,0.45)
INSERT INTO #whca VALUES ('DM85'	,0.69)
INSERT INTO #whca VALUES ('DM95'	,0.78)
INSERT INTO #whca VALUES ('LBS'		,0.0008)
INSERT INTO #whca VALUES ('PALL'	,1.65)
INSERT INTO #whca VALUES ('T110'	,0.90)
INSERT INTO #whca VALUES ('T220'	,1.80)
INSERT INTO #whca VALUES ('T250'	,2.04)
INSERT INTO #whca VALUES ('T275'	,2.25)
INSERT INTO #whca VALUES ('T300'	,2.45)
INSERT INTO #whca VALUES ('T330'	,2.70)
INSERT INTO #whca VALUES ('T350'	,2.86)
INSERT INTO #whca VALUES ('T400'	,3.27)
INSERT INTO #whca VALUES ('T550'	,4.49)
INSERT INTO #whca VALUES ('TONS'	,1.65)
INSERT INTO #whca VALUES ('YARD'	,1.65)

-- Unbundled WHCA Charges
SELECT r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, rp.price_id
	-- 1/22/2014 JDB - Added this sequence_id to the select, because we needed a way to identify the receipt lines that were split into multiple units, like DM30 and DM55.
	--					In these cases, there exists a WHCA product for each bill unit, but they all reference the same receipt line (but there's no way to indicate which *unit*
	--					they reference on that line).  This field will allow us to update the temp table -- see below -- to blank out the amount we owe the township for these
	--					duplicated records.
	, sequence_id = ROW_NUMBER() OVER(PARTITION BY r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, rp.price_id ORDER BY r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, rp.price_id)
	, r.receipt_date
	, r.manifest
	, r.manifest_page_num
	, r.manifest_line
	, r.receipt_status
	, r.fingerpr_status
	, r.waste_accepted_flag
	, r.submitted_flag
	, r.customer_id
	, r.generator_id
	, r.profile_id
	, r.approval_code
	, r.waste_code
	, r.treatment_id
	, r.bulk_flag
	, rp.bill_quantity
	, rp.bill_unit_code
	, r.line_weight
	, r.manifest_quantity
	, r.manifest_unit
	, reporting_quarter = CONVERT(varchar(10), NULL)
	, reporting_quantity = CONVERT(float, NULL)
	, reporting_bill_unit = CONVERT(varchar(4), NULL)
	, whca_fee = CONVERT(money, NULL)
	, Rpref.bill_quantity AS actual_quantity
	, Rpref.bill_unit_code AS actual_unit
	, Rpref.price AS actual_price
	, Rpref.total_extended_amt AS actual_amount
	, T.disposal_service_code
	, 'unbundled' AS charge_type
INTO #tmp	
FROM Receipt r (NOLOCK)
JOIN ReceiptPrice rp (NOLOCK) ON rp.company_id = r.company_id
	AND rp.profit_ctr_id = r.profit_ctr_id
	AND rp.receipt_id = r.receipt_id
	AND rp.line_id = r.line_id
LEFT OUTER JOIN Receipt Rref (NOLOCK) ON Rref.ref_line_id = r.line_id
	AND Rref.ref_receipt_id = r.receipt_id
	AND Rref.product_code = 'WHCA'
	AND Rref.fingerpr_status NOT IN ('V', 'R')
	AND rp.price_id = (SELECT MIN(rp2.price_id) FROM ReceiptPrice rp2 WHERE rp2.company_id = r.company_id AND rp2.profit_ctr_id = r.profit_ctr_id AND rp2.receipt_id = r.receipt_id AND rp2.line_id = r.line_id)
LEFT OUTER JOIN ReceiptPrice Rpref (NOLOCK) ON  Rpref.company_id = Rref.company_id
	AND Rpref.profit_ctr_id = Rref.profit_ctr_id
	AND Rpref.receipt_id = Rref.receipt_id
	AND Rpref.line_id = Rref.line_id
LEFT OUTER JOIN Treatment t (NOLOCK) ON t.treatment_id = r.treatment_id 
    AND t.company_id = r.company_id
    AND t.profit_ctr_id = r.profit_ctr_id
WHERE 1=1
AND ( @company_id = 0 OR r.company_id = @company_id )
AND ( @company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id )
AND r.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to		-- Date range
AND r.receipt_date >= '1/7/2013'										-- We implemented the WHCA fee on 1/7/13, so we do not owe on receipts before that
AND r.trans_mode = 'I'
AND r.trans_type = 'D'													-- Include only disposal lines
AND r.fingerpr_status NOT IN ('V', 'R')									-- Do not include Void or Rejected lines
AND ((r.receipt_status IN ('A')	)										-- Include only Accepted 
	OR (r.receipt_status = 'U' AND r.waste_accepted_flag = 'T') )		--		OR Waste Accepted lines

-- Customers whose billing projects are set up to be "WHCA Exempt" are excluded here
-- These customers are basically WDI itself, not normal customers that get exemptions.
AND NOT EXISTS (SELECT 1 FROM dbo.CustomerBilling cb (NOLOCK)
	WHERE cb.customer_id = r.customer_id
	AND cb.billing_project_id = r.billing_project_id
	AND ISNULL(cb.whca_exempt,'F') = 'T')
	
-- What follows is a way to exclude the records that have no corresponding unbundled WHCA product
--		(all those Rpref... IS NULL lines)
-- but DO have bundled WHCA products.
--		(the EXISTS section)
-- This, combined with the UNION below to get the bundled WHCA charges, will present the data correctly.
AND NOT (Rpref.bill_quantity IS NULL 
	AND Rpref.bill_unit_code IS NULL 
	AND Rpref.price IS NULL 
	AND Rpref.total_extended_amt IS NULL
	AND EXISTS (SELECT 1 FROM Billing b (NOLOCK) 
		INNER JOIN BillingDetail bd (NOLOCK) ON bd.billing_uid = b.billing_uid
			AND bd.trans_type = 'S'
		INNER JOIN Product whcap (NOLOCK) ON whcap.product_ID = bd.product_id
			AND whcap.product_code = 'WHCA'
		WHERE b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
		AND b.receipt_id = r.receipt_id
		AND b.line_id = r.line_id
		AND b.price_id = rp.price_id
		AND b.trans_source = 'R'
		)
	)

UNION

-- Bundled WCHA Charges
SELECT r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, rp.price_id
	-- 1/22/2014 JDB - Added this sequence_id to the select, because we needed a way to identify the receipt lines that were split into multiple units, like DM30 and DM55.
	--					In these cases, there exists a WHCA product for each bill unit, but they all reference the same receipt line (but there's no way to indicate which *unit*
	--					they reference on that line).  This field will allow us to update the temp table -- see below -- to blank out the amount we owe the township for these
	--					duplicated records.
	, sequence_id = ROW_NUMBER() OVER(PARTITION BY r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, rp.price_id ORDER BY r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, rp.price_id)
	, r.receipt_date
	, r.manifest
	, r.manifest_page_num
	, r.manifest_line
	, r.receipt_status
	, r.fingerpr_status
	, r.waste_accepted_flag
	, r.submitted_flag
	, r.customer_id
	, r.generator_id
	, r.profile_id
	, r.approval_code
	, r.waste_code
	, r.treatment_id
	, r.bulk_flag
	, rp.bill_quantity
	, rp.bill_unit_code
	, r.line_weight
	, r.manifest_quantity
	, r.manifest_unit
	, reporting_quarter = CONVERT(varchar(10), NULL)
	, reporting_quantity = CONVERT(float, NULL)
	, reporting_bill_unit = CONVERT(varchar(4), NULL)
	, whca_fee = CONVERT(money, NULL)
	, NULL AS actual_quantity
	, whcap.bill_unit_code AS actual_unit
	, NULL AS actual_price
	, bd.extended_amt AS actual_amount
	, T.disposal_service_code
	, 'bundled' AS charge_type
FROM Receipt r (NOLOCK)
JOIN ReceiptPrice rp (NOLOCK) ON rp.company_id = r.company_id
	AND rp.profit_ctr_id = r.profit_ctr_id
	AND rp.receipt_id = r.receipt_id
	AND rp.line_id = r.line_id
INNER JOIN Billing b (NOLOCK) ON b.company_id = r.company_id
	AND b.profit_ctr_id = r.profit_ctr_id
	AND b.receipt_id = r.receipt_id
	AND b.line_id = r.line_id
	AND b.price_id = rp.price_id
	AND b.trans_source = 'R'
INNER JOIN BillingDetail bd (NOLOCK) ON bd.billing_uid = b.billing_uid
	AND bd.trans_type = 'S'
INNER JOIN Product whcap (NOLOCK) ON whcap.product_ID = bd.product_id
	AND whcap.product_code = 'WHCA'
LEFT OUTER JOIN Treatment t (NOLOCK) ON t.treatment_id = r.treatment_id 
    AND t.company_id = r.company_id
    AND t.profit_ctr_id = r.profit_ctr_id
WHERE 1=1
AND ( @company_id = 0 OR r.company_id = @company_id )
AND ( @company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id )
AND r.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to		-- Date range
AND r.receipt_date >= '1/7/2013'										-- We implemented the WHCA fee on 1/7/13, so we do not owe on receipts before that
AND r.trans_mode = 'I'
AND r.trans_type = 'D'													-- Include only disposal lines
AND r.fingerpr_status NOT IN ('V', 'R')									-- Do not include Void or Rejected lines
AND ((r.receipt_status IN ('A')	)										-- Include only Accepted 
	OR (r.receipt_status = 'U' AND r.waste_accepted_flag = 'T') )		--		OR Waste Accepted lines

-- Customers whose billing projects are set up to be "WHCA Exempt" are excluded here
-- These customers are basically WDI itself, not normal customers that get exemptions.
AND NOT EXISTS (SELECT 1 FROM dbo.CustomerBilling cb (NOLOCK)
	WHERE cb.customer_id = r.customer_id
	AND cb.billing_project_id = r.billing_project_id
	AND ISNULL(cb.whca_exempt,'F') = 'T')

UNION

-- Work Order Charges
SELECT woh.company_id
	, woh.profit_ctr_id
	, woh.workorder_ID
	, wod.sequence_id AS line_id
	, 1 AS price_id
	-- 1/22/2014 JDB - Added this sequence_id to the select, because we needed a way to identify the receipt lines that were split into multiple units, like DM30 and DM55.
	--					In these cases, there exists a WHCA product for each bill unit, but they all reference the same receipt line (but there's no way to indicate which *unit*
	--					they reference on that line).  This field will allow us to update the temp table -- see below -- to blank out the amount we owe the township for these
	--					duplicated records.
	, sequence_id = ROW_NUMBER() OVER(PARTITION BY woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.sequence_id ORDER BY woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.sequence_id)
	, woh.end_date
	, NULL AS manifest
	, NULL AS manifest_page_num
	, NULL AS manifest_line
	, woh.workorder_status
	, NULL AS fingerpr_status
	, NULL AS waste_accepted_flag
	, woh.submitted_flag
	, woh.customer_id
	, woh.generator_id
	, NULL AS profile_id
	, NULL AS approval_code
	, NULL AS waste_code
	, NULL AS treatment_id
	, NULL AS bulk_flag
	, wod.quantity_used
	, wod.bill_unit_code
	, NULL AS line_weight
	, NULL AS manifest_quantity
	, NULL AS manifest_unit
	, reporting_quarter = CONVERT(varchar(10), NULL)
	, reporting_quantity = CONVERT(float, NULL)
	, reporting_bill_unit = CONVERT(varchar(4), NULL)
	, whca_fee = CONVERT(money, NULL)
	, wod.quantity_used AS actual_quantity
	, wod.bill_unit_code AS actual_unit
	, wod.price AS actual_price
	, wod.extended_price AS actual_amount
	, NULL AS disposal_service_code
	, 'workorder' AS charge_type
FROM WorkOrderHeader woh (NOLOCK)
JOIN WorkOrderDetail wod (NOLOCK) ON wod.company_id = woh.company_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type = 'O'
	AND wod.resource_class_code = 'FEEWHCA'
	AND wod.bill_rate > 0
	AND wod.extended_price > 0
WHERE 1=1
AND ( @company_id = 0 OR woh.company_id = @company_id )
AND ( @company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id )
AND woh.end_date BETWEEN @receipt_date_from AND @receipt_date_to		-- Date range
AND woh.end_date >= '1/7/2013'											-- We implemented the WHCA fee on 1/7/13, so we do not owe on receipts before that
AND woh.workorder_status = 'A' AND woh.submitted_flag = 'T'				-- Include only Accepted and Submitted records
	
-- Customers whose billing projects are set up to be "WHCA Exempt" are excluded here
-- These customers are basically WDI itself, not normal customers that get exemptions.
AND NOT EXISTS (SELECT 1 FROM dbo.CustomerBilling cb (NOLOCK)	
	WHERE cb.customer_id = woh.customer_id
	AND cb.billing_project_id = woh.billing_project_id
	AND ISNULL(cb.whca_exempt,'F') = 'T')

-- Set the quarter of the receipt lines
UPDATE #tmp SET reporting_quarter = 'Q1 ' + CONVERT(varchar(4), DATEPART(year, receipt_date)) WHERE DATEPART(month, receipt_date) IN (1,2,3)
UPDATE #tmp SET reporting_quarter = 'Q2 ' + CONVERT(varchar(4), DATEPART(year, receipt_date)) WHERE DATEPART(month, receipt_date) IN (4,5,6)
UPDATE #tmp SET reporting_quarter = 'Q3 ' + CONVERT(varchar(4), DATEPART(year, receipt_date)) WHERE DATEPART(month, receipt_date) IN (7,8,9)
UPDATE #tmp SET reporting_quarter = 'Q4 ' + CONVERT(varchar(4), DATEPART(year, receipt_date)) WHERE DATEPART(month, receipt_date) IN (10,11,12)

-- Set the reporting bill unit to YARD for the 000686 approval (it's always billed in YARD).
-- Otherwise, if it's billed in YARD on other approvals, convert it to TONS
UPDATE #tmp 
SET reporting_bill_unit = CASE WHEN approval_code = '000686' THEN bill_unit_code
	ELSE
		CASE bill_unit_code WHEN 'YARD' THEN 'TONS'
			ELSE bill_unit_code
		END
	END
WHERE charge_type <> 'workorder'

UPDATE #tmp SET whca_fee = #whca.whca_fee
FROM #tmp
LEFT OUTER JOIN #whca ON #whca.bill_unit_code = #tmp.reporting_bill_unit

-- Set the reporting quantity equal to bill quantity for the 000686 approval
UPDATE #tmp
SET reporting_quantity = bill_quantity
WHERE approval_code = '000686'
AND reporting_quantity IS NULL

-- According to the Project Request, YARD should be converted to TONS as follows:
--
-- If the Line Weight is entered on the receipt, divide this number by 2000 to equal TONS
-- If the Line Weight is blank, but the manifested weight is in pounds, then devide the number by 2000 to equal TONS
-- If the Line Weight is blank and the Bill Quantity is entered in YARD, then use the quantity entered in the following format 1 YARD = 1 TON
--
-- Set the reporting quantity to the line weight / 2000 if it's billed in YARD (but not approval 000686)
UPDATE #tmp
SET reporting_quantity = line_weight / 2000.00
WHERE bill_unit_code = 'YARD'
AND reporting_quantity IS NULL 
AND charge_type <> 'workorder'

-- Set the reporting quantity to the manifest weight / 2000 if it's billed in YARD and manifested in pounds
UPDATE #tmp
SET reporting_quantity = manifest_quantity / 2000.00
WHERE bill_unit_code = 'YARD'
AND manifest_unit = 'P'
AND reporting_quantity IS NULL 
AND charge_type <> 'workorder'

-- Set the reporting quantity to the bill quantity if it's billed in YARD and hasn't already been updated
UPDATE #tmp
SET reporting_quantity = bill_quantity
WHERE bill_unit_code = 'YARD'
AND reporting_quantity IS NULL
AND charge_type <> 'workorder'

-- Set the reporting quantity to the bill quantity if it hasn't already been updated
UPDATE #tmp
SET reporting_quantity = bill_quantity
WHERE reporting_quantity IS NULL
AND charge_type <> 'workorder'

-- 1/21/2014 AM - If company is not 3 then we dont pay the Township so make the values to 0.
UPDATE #tmp
SET #tmp.whca_fee = 0
WHERE #tmp.company_id <> 3

-- 1/22/2014 JDB - If the sequence_id > 1, we need to blank out the reporting information, because EQ only owes once for each receipt-line-price ID
UPDATE #tmp
SET #tmp.reporting_quantity = 0
	, #tmp.reporting_bill_unit = NULL
	, #tmp.whca_fee = 0
WHERE #tmp.sequence_id > 1

-- 1/27/2014 JDB - If the transaction occurred before the agreement went into effect, EQ does not owe
UPDATE #tmp
SET #tmp.whca_fee = 0
WHERE #tmp.receipt_date < @agreement_effective_date
	
-- Detail Report
SELECT #tmp.company_id
	, #tmp.profit_ctr_id
	, #tmp.receipt_id
	, #tmp.line_id
	, #tmp.price_id
	, #tmp.sequence_id
	, #tmp.receipt_date
	, #tmp.manifest
	, #tmp.receipt_status
	, #tmp.waste_accepted_flag
	, #tmp.submitted_flag
	, #tmp.customer_id
	, c.cust_name
	, #tmp.generator_id
	, ISNULL(g.EPA_ID, '') AS generator_EPA_ID
	, ISNULL(g.generator_name, '') AS generator_name
	, #tmp.profile_id
	, #tmp.approval_code
	, #tmp.waste_code
	, #tmp.bulk_flag
	, #tmp.bill_quantity
	, #tmp.bill_unit_code
	, #tmp.line_weight
	, #tmp.manifest_quantity
	, #tmp.manifest_unit
	, #tmp.reporting_quarter
	, #tmp.reporting_quantity
	, #tmp.reporting_bill_unit
	, #tmp.whca_fee
	, ISNULL(co.company_name, '')
	, ISNULL(co.address_1, '') AS company_address_1
	, ISNULL(co.address_2, '') AS company_address_2
	, ISNULL(co.EPA_ID, 'N/A') AS company_EPA_ID
	, ISNULL(pc.profit_ctr_name, '') AS profit_ctr_name
	, ISNULL(pc.address_1, '') AS profit_ctr_address_1
	, ISNULL(pc.address_2, '') AS profit_ctr_address_2
	, ISNULL(pc.EPA_ID, 'N/A') AS profit_ctr_epa_ID
	, #tmp.actual_quantity
	, #tmp.actual_unit
	, #tmp.actual_price
	, #tmp.actual_amount
	, #tmp.disposal_service_code
	, #tmp.charge_type
	, ISNULL(c.eq_flag, 'F') AS eq_flag
	FROM #tmp
	JOIN Company co (NOLOCK) ON co.company_id = #tmp.company_id
	JOIN ProfitCenter pc (NOLOCK) ON pc.company_id = #tmp.company_id
		AND pc.profit_ctr_id = #tmp.profit_ctr_id
	JOIN Customer c (NOLOCK) ON c.customer_id = #tmp.customer_id
	LEFT OUTER JOIN Generator g (NOLOCK) ON g.generator_id = #tmp.generator_id
WHERE 1=1
AND ( #tmp.company_id = 3 
	OR #tmp.Disposal_service_code =  'Sub C' 
	OR #tmp.actual_amount > 0 
	)

DROP TABLE #tmp
DROP TABLE #whca
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_wayne_disposal_host_community] TO [EQAI]
    AS [dbo];

