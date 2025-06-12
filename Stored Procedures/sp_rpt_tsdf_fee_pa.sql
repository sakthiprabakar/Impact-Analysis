CREATE PROCEDURE sp_rpt_tsdf_fee_pa 
	@company_id			int,
	@profit_ctr_id		int,
	@date_from			datetime, 
	@date_to			datetime,
	@customer_id_from	int,
	@customer_id_to		int,
	@manifest_from		varchar(15),
	@manifest_to		varchar(15)
AS
/***********************************************************************
Hazardous Waste TSDF Fee Report - Pennsylvania

Filename:		L:\Apps\SQL\EQAI\sp_rpt_tsdf_fee_pa.sql
PB Object(s):	r_tsdf_fee_pa_detail

07/19/2010 JDB	Created; copied from sp_rpt_transporter_fee_pa
02/16/2011 SK	Removed TransporterStateLicense Info, not used anywhere in sp
				Moved to Plt_AI
04/12/2011 RJG	Changed rounding of tons_storage and tons_treatment to be 
					if between 0 and .5, then .1 => to => between 0 and .1, then .1
08/19/2014 JDB	Added 3rd part of UNION to include receipts that have approvals with these 
				products as bundled charges:  PATAXHZTREAT or PATAXHZTRANS.

sp_rpt_tsdf_fee_pa 27, 0, '4/1/10', '6/30/10', 1, 999999, '0', 'zzz'
sp_rpt_tsdf_fee_pa 27, 0, '01/1/10', '02/01/2011', 1, 999999, '0', 'zzz'
sp_rpt_tsdf_fee_pa 27, 0, '10/17/13', '10/17/13', 13366, 13366, '0', 'zzzzzzzzz'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @fee_treat_dispose	float,
	@fee_recycle		float,
	@fee_exempt		float,
	@pound_conv_gal		float,
	@pound_conv_lb		float,
	@pound_conv_ton		float,
	@pound_conv_ton_metric	float,
	@pound_conv_liter	float,
	@pound_conv_cubic_yard	float,
	@pound_conv_cubic_meter	float,
	@pound_conv_kg		float,
	@pa_license_num		varchar(10),
	@transporter_code	varchar(15)

SET @fee_treat_dispose = 3.00
SET @fee_recycle = 1.50
SET @fee_exempt = 0.00

SET @pound_conv_gal = 8.0
SET @pound_conv_lb = 1.0
SET @pound_conv_ton = 2000
-- SET @pound_conv_ton_metric = 2204.6
SET @pound_conv_liter = 2.1
SET @pound_conv_cubic_yard = 2000
-- SET @pound_conv_cubic_meter = 2515.9
SET @pound_conv_kg = 2.2

-- Get the records that have products PATAXHZTREAT or PATAXHZTRANS on them, that directly reference the disposal lines.
SELECT 1 AS part_of_union,
	t.TSDF_code,
	t.tsdf_epa_id,
	t.TSDF_name,
	r1.company_id, 
	r1.profit_ctr_id, 
	r1.receipt_date,
	r1.receipt_id, 
	r1.line_id, 
	r1.manifest,
	r1.manifest_page_num,
	r1.manifest_line,
	r1.profile_id,
	r1.approval_code,
	r2.receipt_id as product_receipt_id,
	r2.line_id as product_line_id,
	r2.product_code,
	r2.bill_unit_code,
	r2.quantity,
	CASE r2.product_code
		WHEN 'PATAXHZTREAT' THEN 'TREAT/DISP'
		WHEN 'PATAXHZTRANS' THEN 'STORAGE'
		END AS treatment_method,
	CONVERT(money, 0.0) AS tons_treatment,
	CONVERT(money, 0.0) AS tons_storage,
	CONVERT(money, 0.0) AS tons_disposal,
	CONVERT(money, 0.0) AS tons_incineration,
	CONVERT(money, 0.0) AS tons_recycle,
	CONVERT(money, 0.0) AS tons_exempt
INTO #tmp
FROM Receipt r1 (NOLOCK)
INNER JOIN Customer c (NOLOCK)
	ON r1.customer_id = c.customer_id
INNER JOIN Receipt r2 (NOLOCK)
	ON r1.receipt_id = r2.ref_receipt_id
	AND r1.line_id = r2.ref_line_id
	AND r1.company_id = r2.company_id
	AND r1.profit_ctr_id = r2.profit_ctr_id
	AND EXISTS (
		SELECT 1 FROM Product pr (NOLOCK)
		WHERE r2.product_id = pr.product_id
		AND r2.company_id = pr.company_id
		AND r2.profit_ctr_id = pr.profit_ctr_id
		AND pr.regulated_fee = 'T'
		AND pr.product_code IN ('PATAXHZTREAT','PATAXHZTRANS')
		)
INNER JOIN Generator g (NOLOCK) ON r1.generator_id = g.generator_id
-- This join is not used
--INNER JOIN Profile p (NOLOCK) ON r1.profile_id = p.profile_id
INNER JOIN ProfitCenter pc (NOLOCK) ON r1.company_id = pc.company_id
	AND r1.profit_ctr_id = pc.profit_ctr_ID
INNER JOIN TSDF t (NOLOCK) ON pc.company_id = t.eq_company
	AND pc.profit_ctr_id = t.eq_profit_ctr
	AND ISNULL(t.eq_flag, 'F') = 'T'
	AND t.TSDF_status = 'A'
WHERE r1.company_id = @company_id 
AND r1.profit_ctr_id = @profit_ctr_id
AND r1.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND r1.receipt_date BETWEEN @date_from AND @date_to
AND r1.manifest BETWEEN @manifest_from AND @manifest_to
AND r1.trans_mode = 'I'				-- Inbound receipts
AND r1.trans_type = 'D'				-- Disposal records (not service/products)
AND r1.receipt_status = 'A'			-- Accepted status
AND r1.submitted_flag = 'T'			-- Submitted to Billing
AND r2.quantity > 0
	
UNION

-- Get the standalone product receipt lines for products PATAXHZTREAT or PATAXHZTRANS.
-- These do not reference any other receipt lines.
SELECT 2 AS part_of_union,
	t.TSDF_code,
	t.tsdf_epa_id,
	t.TSDF_name,
	r1.company_id, 
	r1.profit_ctr_id, 
	r1.receipt_date,
	r1.receipt_id, 
	r1.line_id, 
	r1.manifest,
	r1.manifest_page_num,
	r1.manifest_line,
	NULL, -- r1.profile_id,
	NULL, -- r1.approval_code,
	r1.receipt_id as product_receipt_id,
	r1.line_id as product_line_id,
	r1.product_code,
	r1.bill_unit_code,
	r1.quantity,
	CASE r1.product_code
		WHEN 'PATAXHZTREAT' THEN 'TREAT/DISP'
		WHEN 'PATAXHZTRANS' THEN 'STORAGE'
		END AS treatment_method,
	CONVERT(money, 0.0) AS tons_treatment,
	CONVERT(money, 0.0) AS tons_storage,
	CONVERT(money, 0.0) AS tons_disposal,
	CONVERT(money, 0.0) AS tons_incineration,
	CONVERT(money, 0.0) AS tons_recycle,
	CONVERT(money, 0.0) AS tons_exempt
FROM Receipt r1 (NOLOCK)
INNER JOIN Customer c (NOLOCK) ON r1.customer_id = c.customer_id
-- This join is not used
--INNER JOIN ReceiptPrice r1p (NOLOCK) ON r1.receipt_id = r1p.receipt_id
--	AND r1.line_id = r1p.line_id
--	AND r1.company_id = r1p.company_id
--	AND r1.profit_ctr_id = r1p.profit_ctr_id
INNER JOIN ProfitCenter pc (NOLOCK) ON r1.company_id = pc.company_id
	AND r1.profit_ctr_id = pc.profit_ctr_ID
INNER JOIN TSDF t (NOLOCK) ON pc.company_id = t.eq_company
	AND pc.profit_ctr_id = t.eq_profit_ctr
	AND ISNULL(t.eq_flag, 'F') = 'T'
	AND t.TSDF_status = 'A'
WHERE r1.company_id = @company_id 
AND r1.profit_ctr_id = @profit_ctr_id
AND r1.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND r1.receipt_date BETWEEN @date_from AND @date_to
AND r1.manifest BETWEEN @manifest_from AND @manifest_to
AND EXISTS (
	SELECT 1 FROM Product pr (NOLOCK)
	WHERE r1.product_id = pr.product_id
	AND r1.company_id = pr.company_id
	AND r1.profit_ctr_id = pr.profit_ctr_id
	AND pr.regulated_fee = 'T'
	AND pr.product_code IN ('PATAXHZTREAT','PATAXHZTRANS')
	)
AND r1.trans_mode = 'I'				-- Inbound receipts
AND r1.trans_type = 'S'				-- Service/products
AND r1.receipt_status = 'A'			-- Accepted status
AND r1.submitted_flag = 'T'			-- Submitted to Billing
AND ISNULL(r1.ref_receipt_id, -1) = -1
AND r1.quantity > 0
	
UNION

-- Get the disposal receipt lines with profiles that have product PATAXHZTREAT bundled into them.
SELECT 3 AS part_of_union,
	t.TSDF_code,
	t.tsdf_epa_id,
	t.TSDF_name,
	r1.company_id, 
	r1.profit_ctr_id, 
	r1.receipt_date,
	r1.receipt_id, 
	r1.line_id, 
	r1.manifest,
	r1.manifest_page_num,
	r1.manifest_line,
	r1.profile_id,
	r1.approval_code,
	r1.receipt_id AS product_receipt_id,
	r1.line_id AS product_line_id,
	pqd.product_code,
	r1.bill_unit_code,
	r1.quantity,
	CASE pqd.product_code
		WHEN 'PATAXHZTREAT' THEN 'TREAT/DISP'
		WHEN 'PATAXHZTRANS' THEN 'STORAGE'
		END AS treatment_method,
	CONVERT(money, 0.0) AS tons_treatment,
	CONVERT(money, 0.0) AS tons_storage,
	CONVERT(money, 0.0) AS tons_disposal,
	CONVERT(money, 0.0) AS tons_incineration,
	CONVERT(money, 0.0) AS tons_recycle,
	CONVERT(money, 0.0) AS tons_exempt
FROM Receipt r1 (NOLOCK)
INNER JOIN Customer c (NOLOCK) ON r1.customer_id = c.customer_id
INNER JOIN ProfitCenter pc (NOLOCK) ON r1.company_id = pc.company_id
	AND r1.profit_ctr_id = pc.profit_ctr_ID
INNER JOIN TSDF t (NOLOCK) ON pc.company_id = t.eq_company
	AND pc.profit_ctr_id = t.eq_profit_ctr
	AND ISNULL(t.eq_flag, 'F') = 'T'
	AND t.TSDF_status = 'A'
INNER JOIN Profile p (NOLOCK) ON r1.profile_id = p.profile_id
INNER JOIN ProfileQuoteDetail pqd (NOLOCK) ON pqd.company_id = r1.company_id
	AND pqd.profit_ctr_id = r1.profit_ctr_id
	AND pqd.profile_id = r1.profile_id
	AND pqd.status = 'A'
	AND pqd.record_type = 'S'
	AND pqd.bill_method = 'B'
	AND pqd.bill_quantity_flag = 'U'
	AND pqd.product_code IN ('PATAXHZTREAT','PATAXHZTRANS')
WHERE r1.company_id = @company_id 
AND r1.profit_ctr_id = @profit_ctr_id
AND r1.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND r1.receipt_date BETWEEN @date_from AND @date_to
AND r1.manifest BETWEEN @manifest_from AND @manifest_to
AND r1.trans_mode = 'I'				-- Inbound receipts
AND r1.trans_type = 'D'				-- Disposal records (not service/products)
AND r1.receipt_status = 'A'			-- Accepted status
AND r1.submitted_flag = 'T'			-- Submitted to Billing
AND r1.quantity > 0
ORDER BY r1.manifest, r1.manifest_page_num, r1.manifest_line

-- Round up to 0.1 if 0 < TONS < 0.1
UPDATE #tmp SET tons_treatment = 0.1
WHERE treatment_method = 'TREAT/DISP'
AND bill_unit_code = 'TONS'
AND quantity > 0
AND quantity < 0.1

UPDATE #tmp SET tons_storage = 0.1
WHERE treatment_method = 'STORAGE'
AND bill_unit_code = 'TONS'
AND quantity > 0
AND quantity < 0.1


-- Round values to nearest 1/10 TONS
UPDATE #tmp SET tons_treatment = ISNULL(
	CASE bill_unit_code
	WHEN 'LBS' THEN ROUND((quantity * @pound_conv_lb) / 2000, 1)
	WHEN 'KG' THEN ROUND((quantity * @pound_conv_kg) / 2000, 1)
	WHEN 'GAL' THEN ROUND((quantity * @pound_conv_gal) / 2000, 1)
	WHEN 'TONS' THEN ROUND((quantity * @pound_conv_ton) / 2000, 1)
	WHEN 'YARD' THEN ROUND((quantity * @pound_conv_cubic_yard) / 2000, 1)
	WHEN 'CYB' THEN ROUND((quantity * @pound_conv_cubic_yard) / 2000, 1)
	END, 0.0)
WHERE treatment_method = 'TREAT/DISP'
AND tons_treatment = 0.0


UPDATE #tmp SET tons_storage = ISNULL(
	CASE bill_unit_code
	WHEN 'LBS' THEN ROUND((quantity * @pound_conv_lb) / 2000, 1)
	WHEN 'KG' THEN ROUND((quantity * @pound_conv_kg) / 2000, 1)
	WHEN 'GAL' THEN ROUND((quantity * @pound_conv_gal) / 2000, 1)
	WHEN 'TONS' THEN ROUND((quantity * @pound_conv_ton) / 2000, 1)
	WHEN 'YARD' THEN ROUND((quantity * @pound_conv_cubic_yard) / 2000, 1)
	WHEN 'CYB' THEN ROUND((quantity * @pound_conv_cubic_yard) / 2000, 1)
	END, 0.0)
WHERE treatment_method = 'STORAGE'
AND tons_storage = 0.0

SELECT TSDF_code
	, #tmp.tsdf_epa_id
	, #tmp.TSDF_name
	, #tmp.company_id
	, #tmp.profit_ctr_id
	, #tmp.receipt_date
	, #tmp.receipt_id
	, #tmp.line_id
	, #tmp.manifest
	, #tmp.manifest_page_num
	, #tmp.manifest_line
	, #tmp.profile_id
	, #tmp.approval_code
	, #tmp.product_receipt_id
	, #tmp.product_line_id
	, #tmp.product_code
	, #tmp.bill_unit_code
	, #tmp.quantity
	, #tmp.treatment_method
	, #tmp.tons_treatment
	, #tmp.tons_storage
	, #tmp.tons_disposal
	, #tmp.tons_incineration
	, #tmp.tons_recycle
	, #tmp.tons_exempt
FROM #tmp
ORDER BY #tmp.manifest, #tmp.manifest_page_num, #tmp.manifest_line

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_tsdf_fee_pa] TO [EQAI]
    AS [dbo];

