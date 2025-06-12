DROP PROCEDURE IF EXISTS [dbo].[sp_billing_submit_calc_surcharges_billingdetail]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[sp_billing_submit_calc_surcharges_billingdetail] (
	@debug	int = 1
)
AS
/* ***********************************************************************************
sp_billing_submit_calc_surcharges_billingdetail
	- Encapsulates sp_billing_submit's handling of all BillingDetail records 
		for insurance surcharge, energy surcharge, and sales tax.

ASSUMES:
	- Whatever called it created a #Billing table so this proc knows what to work on.	
	- Whatever called it created a #BillingDetail table for this proc to modify/add rows.
	
History:	
03/16/2012 JDB	Created
03/19/2012 JDB	Fixed a bug in the product CASE statement in the call to fn_insr_amt_billingdetail_line
				for the calculation of insurance surcharge for receipts.  It was causing the insurance
				surcharge to get calculated on products that were regulated fees.
05/08/2012 JDB	Modified the logic in the Sales Tax GL account calculation so that it will take the
				department from the sales tax product (if it's not XXX).  If it is XXX, it will 
				continue to use the department of the transaction the sales tax applies to.
02/20/2013 SK	Modified to fetch JDE GL fields for products-  insr, ensr, salestax	
02/28/2013 JDB	Added the population of the new billingtype_uid field in BillingDetail.
04/18/2013 JDB	Modified to get correct JDE BU when calculating Insurance and Energy surcharge,
				particularly for replacing X's in the product's business unit.
12/04/2013 JDB	Modified the Energy surcharge calculation for JDE business unit.  It needed to be
				updated to get the disposal line's department because Energy surcharge always applies
				to the disposal line's department, not the department of any bundled products.
06/16/2014 JDB	Updated Insurance Surcharge insert statement so that it bypasses applying the surcharge
				to bundled products that are Regulated Fees.
12/30/2014  AM  Added billing_project_id parameter to fn_get_ensr_percent function. 
01/13/2015  AM  Added logic not to insert Insurance Surcharge after dbo.fn_GetEIRrate_min_effective_date ()
05/29/2016  AM  Added AX fields to #BillingDetail.
02/15/2017  AM  Added replace to Receipt 'Insurance' AX_Dimension_3 and AX_Dimension_4
06/05/2017 MPM	Modified to work with new disc_amount column in the BillingDetail table.
07/14/2017 JPB	Added explicit #BillingDetail* column lists for inserts
02/15/2018 MPM	Added population of #BillingDetail.currency_code.
04/17/2018 RWB	GEM:49865 Added replace on Energy and Insurance surcharges for Adv Detail and Project
11/30/2022 AGC  DevOps 58319 - Add ERF/FRF fees
12/20/2023 AGC  DevOps 75653 - fix FRF AX dimension 1 and 2
02/02/2024 AGC  DevOps 76720 - changed from Receipt.receipt_date/WorkOrder.start_date to submission date (current date)
                               for ERF/FRF
02/02/2024	AM	DevOps 76692 - changed profitcenter join
02/14/2024 AGC  DevOps 78307 - don't calculate EIR fee if EEC fee exists for @billing_date
02/28/2024 AGC  DevOps 78520 - don't calculate EEC fee if workorder is from SalesForce
07/22/2024 KS   Rally DE34399 - Updated arguement for fn_get_FRF_fee_rate() and fn_get_recovery_fee_flag()
								to be #billing.billing_date instead of @billing_date for FRF fees.
09/13/2024 AM   Rally#DE35428 - Apply EEC Fee When the Work Order 'Fix Price' Flag Is Checked.
11/12/2024 KS	Rally US128919 - Resource Class Name > Add "Exempt EEC".
								 If 'Exempt EEC' checkbox on a Resource Class Name record to 'T' then
								 the resource should be exempted from having an EEC fee applied.
12/16/2024	SG	Rally # DE36839 - EIR populating on SF integrated invoices- IC Direct Bill

SELECT * FROM Billing WHERE receipt_id = 50151 AND company_id = 25
SELECT * FROM BillingDetail WHERE billing_uid = 507300 ORDER BY line_id, ref_billingdetail_uid, billingdetail_uid
****************************************************************************************/  
BEGIN  
DECLARE @company_id			int,
		@profit_ctr_id		int,
		@trans_source		char(1),
		@receipt_id			int,
		@billing_date		datetime
	     
SELECT * INTO #BillingDetail_INSR FROM #BillingDetail WHERE 0=1
SELECT * INTO #BillingDetail_ENSR FROM #BillingDetail WHERE 0=1
--DevOps 58319 - Add ERF/FRF fees
SELECT * INTO #BillingDetail_ERF FROM #BillingDetail WHERE 0=1
SELECT * INTO #BillingDetail_FRF FROM #BillingDetail WHERE 0=1

IF @debug = 1 PRINT 'SELECT * FROM #Billing (sp_billing_submit_calc_surcharges_billingdetail)'
IF @debug = 1 SELECT * FROM #Billing
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail (sp_billing_submit_calc_surcharges_billingdetail)'
IF @debug = 1 SELECT * FROM #BillingDetail
-----------------------------------------------------------------------
--											For Receipts											--
------------------------------------------------------------------------------------------------------
-----------------------------------------------------
---- Insurance Surcharge
-----------------------------------------------------
SET @billing_date = GetDate ()

		INSERT INTO #BillingDetail_INSR
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_insr.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(c.insurance_surcharge_percent, 0) AS applied_percent,
			extended_amt = dbo.fn_insr_amt_billingdetail_line (  
				bd.billing_type,
				b.customer_id,
				ISNULL(b.billing_project_id, 0),
				bd.company_id,
				bd.profit_ctr_id,
				b.profile_id,
				CASE bd.billing_type 
					WHEN 'Product' THEN CASE 
						WHEN bd.ref_billingdetail_uid IS NULL THEN bd.product_id
						ELSE NULL END
					ELSE NULL END,
				--CASE bd.billing_type 
				--	WHEN 'Product' THEN CASE bd.ref_billingdetail_uid 
				--		WHEN NULL THEN bd.product_id
				--		ELSE NULL END
				--	ELSE NULL END,
				NULL,
				NULL,
				NULL,
				bd.extended_amt),
			gl_account_code = LEFT(p_insr.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			--ISNULL(p_insr.JDE_BU, 'XXXXXXX'),
			ISNULL(REPLACE(p_insr.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_insr.JDE_object, 'XXXXX'),
			p_insr.AX_MainAccount,
			p_insr.AX_Dimension_1,
			p_insr.AX_Dimension_2,
			REPLACE(p_insr.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_insr.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_insr.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_insr.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_insr.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'Insurance'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
			 AND b.billing_date <= ( dbo.fn_GetEIRrate_min_effective_date ())
		LEFT OUTER JOIN Company c ON c.company_id = bd.company_id
		LEFT OUTER JOIN Product p_insr ON p_insr.product_code = 'INSR' 
			AND p_insr.product_type = 'X' 
			AND p_insr.status = 'A' 
			AND p_insr.company_ID = bd.dist_company_id
			AND p_insr.profit_ctr_ID = bd.dist_profit_ctr_id
		LEFT OUTER JOIN Product p_product_being_billed ON p_product_being_billed.product_ID = bd.product_id
		WHERE 1=1
		AND bd.trans_source = 'R'
		-- JDB 6/16/2014 - This part was added so that we do not apply insurance surcharge to bundled Product lines that are Regulated Fees.
		AND ((bd.billing_type IN ('Disposal', 'Wash'))
			OR (bd.billing_type = 'Product' AND ISNULL(p_product_being_billed.regulated_fee, 'F') = 'F')
			)

		IF @debug = 1 PRINT 'SELECT * FROM ##BillingDetail_INSR (sp_billing_submit_calc_surcharges_billingdetail) Insurance Surcharge'
		IF @debug = 1 SELECT * FROM #BillingDetail_INSR
		-----------------------------------------------------
		---- Energy Surcharge
		-----------------------------------------------------
INSERT INTO #BillingDetail_ENSR
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_ensr.product_id, 
			bddisposal.company_id, 
			bddisposal.profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(dbo.fn_get_ensr_percent(b.billing_date, b.customer_id, b.billing_project_id), 0) AS applied_percent,
			extended_amt = dbo.fn_ensr_amt_billingdetail_line (  
				bd.billing_type,
				b.customer_id,
				ISNULL(b.billing_project_id, 0),
				bd.company_id,
				bd.profit_ctr_id,
				b.profile_id,
				b.billing_date,
				NULL,
				bd.extended_amt),
			-- Energy surcharge is applied to the Disposal and any bundled
			-- products, but the gl account goes to the company of the
			-- Disposal record.
			gl_account_code = LEFT(p_ensr.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bddisposal.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bddisposal.profit_ctr_id), 2)
				+ RIGHT(bddisposal.gl_account_code, 3),
			NULL AS sequence_id,
			--ISNULL(p_ensr.JDE_BU, 'XXXXXXX'),
			ISNULL(REPLACE(p_ensr.JDE_BU, 'XXX', RIGHT(bddisposal.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_ensr.JDE_object, 'XXXXX'),
			p_ensr.AX_MainAccount,
			p_ensr.AX_Dimension_1,
			p_ensr.AX_Dimension_2,
			REPLACE(p_ensr.AX_Dimension_3, 'XXX',bddisposal.AX_Dimension_3),
			REPLACE(p_ensr.AX_Dimension_4, 'XXXX',bddisposal.AX_Dimension_4),
			REPLACE(p_ensr.AX_Dimension_5_Part_1, 'XXXXXXXX', bddisposal.AX_Dimension_5_Part_1),
			REPLACE(p_ensr.AX_Dimension_5_Part_2, 'XXXX', bddisposal.AX_Dimension_5_Part_2),
			REPLACE(p_ensr.AX_Dimension_6,'XXX',bddisposal.AX_Dimension_6),
            NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'Energy'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
			AND ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) = 0 --DevOps 78307
		INNER JOIN #BillingDetail bddisposal ON bddisposal.billing_uid = bd.billing_uid
			AND bddisposal.billing_type = 'Disposal'
		LEFT OUTER JOIN Product p_ensr ON p_ensr.product_code = 'ENSR' 
			AND p_ensr.product_type = 'X' 
			AND p_ensr.status = 'A' 
			AND p_ensr.company_ID = bddisposal.company_id
			AND p_ensr.profit_ctr_ID = bddisposal.profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'R'
		AND ((bd.billing_type IN ('Disposal', 'Wash') AND bd.ref_billingdetail_uid IS NULL)		-- Apply energy surcharge to disposal or wash
			OR (bd.billing_type IN ('Product') AND bd.ref_billingdetail_uid IS NOT NULL))		-- Apply energy surcharge to bundled products only (not unbundled)
 
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_ENSR (sp_billing_submit_calc_surcharges_billingdetail) Energy Surcharge'
IF @debug = 1 SELECT * FROM #BillingDetail_ENSR

--DevOps 58319 - Add ERF/FRF fees
		-----------------------------------------------------
		---- Fuel Recovery Fee
		-----------------------------------------------------
		INSERT INTO #BillingDetail_FRF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_frf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
					THEN 0
				 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0)
				 END AS applied_percent,	
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
				CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
					THEN 0
				ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
				bd.extended_amt),
			gl_account_code = LEFT(p_frf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_frf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_frf.JDE_object, 'XXXXX'),
			p_frf.AX_MainAccount,
			REPLACE(p_frf.AX_Dimension_1, 'XXX', pc.AX_Dimension_1),
			REPLACE(p_frf.AX_Dimension_2, 'XXXXX', pc.AX_Dimension_2),
			REPLACE(p_frf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_frf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_frf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_frf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_frf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
            NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'FRF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		--INNER JOIN ProfitCenter pc ON pc.company_ID = bd.company_id AND pc.profit_ctr_ID = bd.profit_ctr_id
		INNER JOIN ProfitCenter pc ON  
			pc.company_ID = CASE WHEN bd.dist_company_id is null or bd.dist_company_id = 0 THEN bd.company_id ELSE bd.dist_company_id END
		    AND pc.profit_ctr_ID = CASE WHEN bd.dist_profit_ctr_ID is null THEN bd.profit_ctr_ID ELSE bd.dist_profit_ctr_ID END
		LEFT OUTER JOIN Product p_frf ON p_frf.product_code = 'FRF' 
			AND p_frf.product_type = 'X' 
			AND p_frf.status = 'A' 
			AND p_frf.company_ID = bd.company_id
			AND p_frf.profit_ctr_ID = bd.profit_ctr_id
		LEFT OUTER JOIN Product p_product_being_billed ON p_product_being_billed.product_ID = bd.product_id
		WHERE 1=1
		AND bd.billing_type IN ('Disposal', 'Product', 'Retail', 'Wash')
		AND bd.trans_source = 'R'
		AND ((bd.trans_type = 'D')
			OR (bd.trans_type = 'S' and  ISNULL(p_product_being_billed.regulated_fee, 'F') = 'F'))
 
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_FRF (sp_billing_submit_calc_surcharges_billingdetail) Fuel Recovery Surcharge'
IF @debug = 1 SELECT * FROM #BillingDetail_FRF

		-----------------------------------------------------
		---- Environmental Recovery Fee
		-----------------------------------------------------
		INSERT INTO #BillingDetail_ERF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_erf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0) AS applied_percent,
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('ERF', b.customer_id, b.billing_project_id, @billing_date),
				ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0),
				(bd.extended_amt + dbo.fn_erf_frf_amt_billingdetail_line(
					dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
					CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
							THEN 0
						 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
					bd.extended_amt))),
			gl_account_code = LEFT(p_erf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.dist_profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_erf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_erf.JDE_object, 'XXXXX'),
			p_erf.AX_MainAccount,
			p_erf.AX_Dimension_1,
			p_erf.AX_Dimension_2,
			REPLACE(p_erf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_erf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_erf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_erf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_erf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
            NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'ERF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		LEFT OUTER JOIN Product p_erf ON p_erf.product_code = 'ERF' 
			AND p_erf.product_type = 'X' 
			AND p_erf.status = 'A' 
			AND p_erf.company_ID = bd.company_id
			AND p_erf.profit_ctr_ID = bd.profit_ctr_id
		LEFT OUTER JOIN Product p_product_being_billed ON p_product_being_billed.product_ID = bd.product_id
		WHERE 1=1
		AND bd.billing_type IN ('Disposal', 'Product', 'Retail', 'Wash')
		AND bd.trans_source = 'R'
		AND ((bd.trans_type = 'D')
			OR (bd.trans_type = 'S' and  ISNULL(p_product_being_billed.regulated_fee, 'F') = 'F'))
 
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_FRF (sp_billing_submit_calc_surcharges_billingdetail) Fuel Recovery Surcharge'
IF @debug = 1 SELECT * FROM #BillingDetail_FRF

------------------------------------------------------------------------------------------------------
--											For Work Orders											--
------------------------------------------------------------------------------------------------------
-----------------------------------------------------
---- Insurance Surcharge
-----------------------------------------------------
	INSERT INTO #BillingDetail_INSR
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
	SELECT b.billing_uid,
		bd.billingdetail_uid AS ref_billingdetail_uid,
		bt.billingtype_uid,
		bt.billing_type,
		bd.company_id,
		bd.profit_ctr_id, 
		bd.receipt_id,
		bd.line_id,
		bd.price_id,
		bd.trans_source,
		NULL AS trans_type,
		p_insr.product_id, 
		bd.dist_company_id, 
		bd.dist_profit_ctr_id,
		NULL AS sales_tax_id,
		ISNULL(c.insurance_surcharge_percent, 0) AS applied_percent,
		extended_amt = dbo.fn_insr_amt_billingdetail_line (  
			bd.billing_type,
			b.customer_id,
			ISNULL(b.billing_project_id, 0),
			bd.company_id,
			bd.profit_ctr_id,
			b.profile_id,
			bd.product_id,
			b.workorder_resource_type,
			b.workorder_resource_item,
			b.bill_unit_code,
			bd.extended_amt),	
		gl_account_code = LEFT(p_insr.gl_account_code, 5) 
			+ RIGHT('00' + CONVERT(varchar(2), bd.dist_company_id), 2)
			+ RIGHT('00' + CONVERT(varchar(2), bd.dist_profit_ctr_id), 2)
			+ RIGHT(bd.gl_account_code, 3),
		NULL AS sequence_id,
		--ISNULL(p_insr.JDE_BU, 'XXXXXXX'),
		ISNULL(REPLACE(p_insr.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
		ISNULL(p_insr.JDE_object, 'XXXXX'),
		p_insr.AX_MainAccount,
		p_insr.AX_Dimension_1,
		p_insr.AX_Dimension_2,
		REPLACE(p_insr.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
		REPLACE(p_insr.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
		REPLACE(p_insr.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
		REPLACE(p_insr.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
		REPLACE(p_insr.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
		NULL,
			NULL,
			bd.currency_code
	FROM #BillingDetail bd
	INNER JOIN BillingType bt ON bt.billing_type = 'Insurance'
	INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
				AND b.billing_date <= (dbo.fn_GetEIRrate_min_effective_date ())
	LEFT OUTER JOIN Company c ON c.company_id = bd.company_id
	LEFT OUTER JOIN Product p_insr ON p_insr.product_code = 'INSR' 
		AND p_insr.product_type = 'X' 
		AND p_insr.status = 'A' 
		AND p_insr.company_ID = bd.dist_company_id
		AND p_insr.profit_ctr_ID = bd.dist_profit_ctr_id
	WHERE 1=1
	AND bd.trans_source = 'W'
	AND bd.billing_type IN ('WorkOrder')
 END
 
-----------------------------------------------------
---- Energy Surcharge
-----------------------------------------------------

		INSERT INTO #BillingDetail_ENSR
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_ensr.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(dbo.fn_get_ensr_percent(b.billing_date, b.customer_id, b.billing_project_id), 0) AS applied_percent,
			extended_amt = dbo.fn_ensr_amt_billingdetail_line (  
				bd.billing_type,
				b.customer_id,
				ISNULL(b.billing_project_id, 0),
				wod.profile_company_id,
				wod.profile_profit_ctr_id,
				b.profile_id,
				COALESCE(wom.date_delivered, b.billing_date),
				b.workorder_resource_type,
				bd.extended_amt),
			gl_account_code = LEFT(p_ensr.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			--ISNULL(p_ensr.JDE_BU, 'XXXXXXX'),
			ISNULL(REPLACE(p_ensr.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_ensr.JDE_object, 'XXXXX'),
			p_ensr.AX_MainAccount,
			p_ensr.AX_Dimension_1,
			p_ensr.AX_Dimension_2,
			REPLACE(p_ensr.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_ensr.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_ensr.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_ensr.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_ensr.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'Energy'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
			AND ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) = 0 --DevOps 78307
		INNER JOIN WorkOrderDetail wod ON wod.company_id = b.company_id
			AND wod.profit_ctr_id = b.profit_ctr_id
			AND wod.workorder_id = b.receipt_id
			AND wod.resource_type = b.workorder_resource_type
			AND wod.sequence_id = b.workorder_sequence_id
			AND wod.resource_type = 'D'					-- Energy surcharge only applies to disposal lines
		INNER JOIN WorkorderHeader woh ON woh.company_id = b.company_id
			AND woh.profit_ctr_id = b.profit_ctr_id
			AND woh.workorder_id = b.receipt_id
			AND woh.salesforce_invoice_CSID IS NULL
		INNER JOIN WorkOrderManifest wom ON wom.company_id = wod.company_id
			AND wom.profit_ctr_id = wod.profit_ctr_id
			AND wom.workorder_id = wod.workorder_id
			AND wom.manifest = wod.manifest
		LEFT OUTER JOIN Product p_ensr ON p_ensr.product_code = 'ENSR' 
			AND p_ensr.product_type = 'X' 
			AND p_ensr.status = 'A' 
			AND p_ensr.company_ID = bd.dist_company_id
			AND p_ensr.profit_ctr_ID = bd.dist_profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'W'
		AND bd.billing_type IN ('WorkOrder')

--DevOps 58319 - Add ERF/FRF fees
-----------------------------------------------------
---- Fuel Recovery Fee
-----------------------------------------------------

		INSERT INTO #BillingDetail_FRF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_frf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
					THEN 0
				 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0)
			END AS applied_percent,
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
				CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
						THEN 0
					ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
				bd.extended_amt),
			gl_account_code = LEFT(p_frf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_frf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_frf.JDE_object, 'XXXXX'),
			p_frf.AX_MainAccount,
			REPLACE(p_frf.AX_Dimension_1, 'XXX', pc.AX_Dimension_1),
			REPLACE(p_frf.AX_Dimension_2, 'XXXXX', pc.AX_Dimension_2),
			REPLACE(p_frf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_frf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_frf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_frf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_frf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'FRF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		--INNER JOIN ProfitCenter pc ON pc.company_ID = bd.company_id AND pc.profit_ctr_ID = bd.profit_ctr_id  
		INNER JOIN ProfitCenter pc ON  
			pc.company_ID = CASE WHEN bd.dist_company_id is null or bd.dist_company_id = 0 THEN bd.company_id ELSE bd.dist_company_id END
		    AND pc.profit_ctr_ID = CASE WHEN bd.dist_profit_ctr_ID is null THEN bd.profit_ctr_ID ELSE bd.dist_profit_ctr_ID END
		--DevOps 78520
		INNER JOIN WorkOrderHeader woh ON woh.company_id = b.company_id
			AND woh.profit_ctr_id = b.profit_ctr_id
			AND woh.workorder_id = b.receipt_id
			AND woh.salesforce_invoice_csid is null
		INNER JOIN WorkOrderDetail wod ON wod.company_id = b.company_id
			AND wod.profit_ctr_id = b.profit_ctr_id
			AND wod.workorder_id = b.receipt_id
			--Rally#DE35428
			AND ( ( wod.resource_type = b.workorder_resource_type ) AND ( wod.sequence_id = b.workorder_sequence_id )   
			      OR woh.fixed_price_flag = 'T' )
			AND wod.resource_type in ('D')
		--INNER JOIN WorkOrderManifest wom ON wom.company_id = wod.company_id
		--	AND wom.profit_ctr_id = wod.profit_ctr_id
		--	AND wom.workorder_id = wod.workorder_id
		--	AND wom.manifest = wod.manifest
		LEFT OUTER JOIN Product p_frf ON p_frf.product_code = 'FRF' 
			AND p_frf.product_type = 'X' 
			AND p_frf.status = 'A' 
			AND p_frf.company_ID = bd.dist_company_id
			AND p_frf.profit_ctr_ID = bd.dist_profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'W'
		AND bd.billing_type IN ('WorkOrder')

		INSERT INTO #BillingDetail_FRF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_frf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
					THEN 0
				 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0)
			END AS applied_percent,
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
				CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
						THEN 0
					 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
				bd.extended_amt),
			gl_account_code = LEFT(p_frf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_frf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_frf.JDE_object, 'XXXXX'),
			p_frf.AX_MainAccount,
			REPLACE(p_frf.AX_Dimension_1, 'XXX', pc.AX_Dimension_1),
			REPLACE(p_frf.AX_Dimension_2, 'XXXXX', pc.AX_Dimension_2),
			REPLACE(p_frf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_frf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_frf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_frf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_frf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'FRF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		--INNER JOIN ProfitCenter pc ON pc.company_ID = bd.company_id AND pc.profit_ctr_ID = bd.profit_ctr_id 
		INNER JOIN ProfitCenter pc ON  
			pc.company_ID = CASE WHEN bd.dist_company_id is null or bd.dist_company_id = 0 THEN bd.company_id ELSE bd.dist_company_id END
		    AND pc.profit_ctr_ID = CASE WHEN bd.dist_profit_ctr_ID is null THEN bd.profit_ctr_ID ELSE bd.dist_profit_ctr_ID END
		--DevOps 78520
		INNER JOIN WorkOrderHeader woh ON woh.company_id = b.company_id
			AND woh.profit_ctr_id = b.profit_ctr_id
			AND woh.workorder_id = b.receipt_id
			AND woh.salesforce_invoice_csid is null
		INNER JOIN WorkOrderDetail wod ON wod.company_id = b.company_id
			AND wod.profit_ctr_id = b.profit_ctr_id
			AND wod.workorder_id = b.receipt_id
			--Rally#DE35428
			AND ( ( wod.resource_type = b.workorder_resource_type ) AND ( wod.sequence_id = b.workorder_sequence_id )   
			      OR woh.fixed_price_flag = 'T' )
			AND wod.resource_type in ('E', 'L', 'S', 'O', 'G')
		JOIN ResourceClassDetail rcd
			ON wod.company_id = rcd.company_id
			AND wod.profit_ctr_id = rcd.profit_ctr_id
			AND wod.resource_class_code = rcd.resource_class_code
			AND wod.bill_unit_code = rcd.bill_unit_code
			and rcd.regulated_fee = 'F'
		--INNER JOIN WorkOrderManifest wom ON wom.company_id = wod.company_id
		--	AND wom.profit_ctr_id = wod.profit_ctr_id
		--	AND wom.workorder_id = wod.workorder_id
		--	AND wom.manifest = wod.manifest
		LEFT OUTER JOIN Product p_frf ON p_frf.product_code = 'FRF' 
			AND p_frf.product_type = 'X' 
			AND p_frf.status = 'A' 
			AND p_frf.company_ID = bd.dist_company_id
			AND p_frf.profit_ctr_ID = bd.dist_profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'W'
		AND bd.billing_type IN ('WorkOrder')

-----------------------------------------------------
---- Environmental Recovery Fee
-----------------------------------------------------

		INSERT INTO #BillingDetail_ERF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_erf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0) AS applied_percent,
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('ERF', b.customer_id, b.billing_project_id, @billing_date),
				ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0),
				(bd.extended_amt + dbo.fn_erf_frf_amt_billingdetail_line(
					dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
					CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
							THEN 0
						 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
					bd.extended_amt))),
			gl_account_code = LEFT(p_erf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_erf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_erf.JDE_object, 'XXXXX'),
			p_erf.AX_MainAccount,
			p_erf.AX_Dimension_1,
			p_erf.AX_Dimension_2,
			REPLACE(p_erf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_erf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_erf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_erf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_erf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'ERF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		INNER JOIN WorkOrderDetail wod ON wod.company_id = b.company_id
			AND wod.profit_ctr_id = b.profit_ctr_id
			AND wod.workorder_id = b.receipt_id
			AND wod.resource_type = b.workorder_resource_type
			AND wod.sequence_id = b.workorder_sequence_id
			AND wod.resource_type in ('D')
		--INNER JOIN WorkOrderManifest wom ON wom.company_id = wod.company_id
		--	AND wom.profit_ctr_id = wod.profit_ctr_id
		--	AND wom.workorder_id = wod.workorder_id
		--	AND wom.manifest = wod.manifest
		LEFT OUTER JOIN Product p_erf ON p_erf.product_code = 'ERF' 
			AND p_erf.product_type = 'X' 
			AND p_erf.status = 'A' 
			AND p_erf.company_ID = bd.dist_company_id
			AND p_erf.profit_ctr_ID = bd.dist_profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'W'
		AND bd.billing_type IN ('WorkOrder')

		INSERT INTO #BillingDetail_ERF
(
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
			bd.company_id,
			bd.profit_ctr_id, 
			bd.receipt_id,
			bd.line_id,
			bd.price_id,
			bd.trans_source,
			NULL AS trans_type,
			p_erf.product_id, 
			bd.dist_company_id, 
			bd.dist_profit_ctr_id,
			NULL AS sales_tax_id,
			ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0) AS applied_percent,
			extended_amt = dbo.fn_erf_frf_amt_billingdetail_line(
				dbo.fn_get_recovery_fee_flag('ERF', b.customer_id, b.billing_project_id, @billing_date),
				ISNULL(dbo.fn_get_erf_fee_rate(b.customer_id, b.billing_project_id, @billing_date), 0),
				(bd.extended_amt + dbo.fn_erf_frf_amt_billingdetail_line(
					dbo.fn_get_recovery_fee_flag('FRF', b.customer_id, b.billing_project_id, b.billing_date),
					CASE WHEN dbo.fn_get_resource_exempt_eec_fee_flag(b.workorder_resource_item, b.workorder_resource_type) = 'T'
							THEN 0
						 ELSE ISNULL(dbo.fn_get_frf_fee_rate(b.customer_id, b.billing_project_id, b.billing_date), 0) END,
					bd.extended_amt))),
			gl_account_code = LEFT(p_erf.gl_account_code, 5) 
				+ RIGHT('00' + CONVERT(varchar(2), bd.company_id), 2)
				+ RIGHT('00' + CONVERT(varchar(2), bd.profit_ctr_id), 2)
				+ RIGHT(bd.gl_account_code, 3),
			NULL AS sequence_id,
			ISNULL(REPLACE(p_erf.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
			ISNULL(p_erf.JDE_object, 'XXXXX'),
			p_erf.AX_MainAccount,
			p_erf.AX_Dimension_1,
			p_erf.AX_Dimension_2,
			REPLACE(p_erf.AX_Dimension_3, 'XXX',bd.AX_Dimension_3),
			REPLACE(p_erf.AX_Dimension_4, 'XXXX',bd.AX_Dimension_4),
			REPLACE(p_erf.AX_Dimension_5_Part_1, 'XXXXXXXX', bd.AX_Dimension_5_Part_1),
			REPLACE(p_erf.AX_Dimension_5_Part_2, 'XXXX', bd.AX_Dimension_5_Part_2),
			REPLACE(p_erf.AX_Dimension_6,'XXX',bd.AX_Dimension_6),
			NULL,
			NULL,
			bd.currency_code
		FROM #BillingDetail bd
		INNER JOIN BillingType bt ON bt.billing_type = 'ERF'
		INNER JOIN #Billing b ON b.billing_uid = bd.billing_uid
		INNER JOIN WorkOrderDetail wod ON wod.company_id = b.company_id
			AND wod.profit_ctr_id = b.profit_ctr_id
			AND wod.workorder_id = b.receipt_id
			AND wod.resource_type = b.workorder_resource_type
			AND wod.sequence_id = b.workorder_sequence_id
			AND wod.resource_type in ('E', 'L', 'S', 'O', 'G')
		JOIN ResourceClassDetail rcd
			ON wod.company_id = rcd.company_id
			AND wod.profit_ctr_id = rcd.profit_ctr_id
			AND wod.resource_class_code = rcd.resource_class_code
			AND wod.bill_unit_code = rcd.bill_unit_code
			and rcd.regulated_fee = 'F'
		--INNER JOIN WorkOrderManifest wom ON wom.company_id = wod.company_id
		--	AND wom.profit_ctr_id = wod.profit_ctr_id
		--	AND wom.workorder_id = wod.workorder_id
		--	AND wom.manifest = wod.manifest
		LEFT OUTER JOIN Product p_erf ON p_erf.product_code = 'ERF' 
			AND p_erf.product_type = 'X' 
			AND p_erf.status = 'A' 
			AND p_erf.company_ID = bd.dist_company_id
			AND p_erf.profit_ctr_ID = bd.dist_profit_ctr_id
		WHERE 1=1
		AND bd.trans_source = 'W'
		AND bd.billing_type IN ('WorkOrder')

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

			
-----------------------------------------------------
---- Insurance Surcharge
-----------------------------------------------------
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_INSR'
IF @debug = 1 SELECT * FROM #BillingDetail_INSR

INSERT INTO #BillingDetail (
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
	
)
SELECT billing_uid,
	ref_billingdetail_uid,
	billingtype_uid,
	billing_type,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	price_id,
	trans_source,
	trans_type,
	product_id, 
	dist_company_id,
	dist_profit_ctr_id,
	sales_tax_id,
	applied_percent,
	extended_amt,
	gl_account_code,
	sequence_id,
	jde_bu,
	jde_object,
	AX_MainAccount,
	AX_Dimension_1,
    AX_Dimension_2,
    AX_Dimension_3,
    AX_Dimension_4,
    AX_Dimension_5_Part_1,
    AX_Dimension_5_Part_2,
    AX_Dimension_6,
    NULL,
	NULL,
	currency_code
FROM #BillingDetail_INSR
WHERE 1=1 
AND extended_amt > 0.00

-----------------------------------------------------
---- Energy Surcharge
-----------------------------------------------------
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_ENSR'
IF @debug = 1 SELECT * FROM #BillingDetail_ENSR

INSERT INTO #BillingDetail (
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
SELECT billing_uid,
	ref_billingdetail_uid,
	billingtype_uid,
	billing_type,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	price_id,
	trans_source,
	trans_type,
	product_id, 
	dist_company_id,
	dist_profit_ctr_id,
	sales_tax_id,
	applied_percent,
	extended_amt,
	gl_account_code,
	sequence_id,
	jde_bu,
	jde_object,
    AX_MainAccount,
	AX_Dimension_1,
    AX_Dimension_2,
    AX_Dimension_3,
    AX_Dimension_4,
    AX_Dimension_5_Part_1,
    AX_Dimension_5_Part_2,
    AX_Dimension_6,
    NULL,
	NULL,
	currency_code
FROM #BillingDetail_ENSR
WHERE 1=1 
AND extended_amt > 0.00

--DevOps 58319 - Add ERF/FRF fees
-----------------------------------------------------
---- Fuel Recovery Fee
-----------------------------------------------------
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_FRF'
IF @debug = 1 SELECT * FROM #BillingDetail_FRF

INSERT INTO #BillingDetail (
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
SELECT billing_uid,
	ref_billingdetail_uid,
	billingtype_uid,
	billing_type,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	price_id,
	trans_source,
	trans_type,
	product_id, 
	dist_company_id,
	dist_profit_ctr_id,
	sales_tax_id,
	applied_percent,
	extended_amt,
	gl_account_code,
	sequence_id,
	jde_bu,
	jde_object,
    AX_MainAccount,
	AX_Dimension_1,
    AX_Dimension_2,
    AX_Dimension_3,
    AX_Dimension_4,
    AX_Dimension_5_Part_1,
    AX_Dimension_5_Part_2,
    AX_Dimension_6,
    NULL,
	NULL,
	currency_code
FROM #BillingDetail_FRF
WHERE 1=1 
AND extended_amt > 0.00

-----------------------------------------------------
---- Environmental Recovery Fee
-----------------------------------------------------
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail_ERF'
IF @debug = 1 SELECT * FROM #BillingDetail_ERF

INSERT INTO #BillingDetail (
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
SELECT billing_uid,
	ref_billingdetail_uid,
	billingtype_uid,
	billing_type,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	price_id,
	trans_source,
	trans_type,
	product_id, 
	dist_company_id,
	dist_profit_ctr_id,
	sales_tax_id,
	applied_percent,
	extended_amt,
	gl_account_code,
	sequence_id,
	jde_bu,
	jde_object,
    AX_MainAccount,
	AX_Dimension_1,
    AX_Dimension_2,
    AX_Dimension_3,
    AX_Dimension_4,
    AX_Dimension_5_Part_1,
    AX_Dimension_5_Part_2,
    AX_Dimension_6,
    NULL,
	NULL,
	currency_code
FROM #BillingDetail_ERF
WHERE 1=1 
AND extended_amt > 0.00

-----------------------------------------------------
---- Sales Tax
-----------------------------------------------------

INSERT INTO #BillingDetail (
	billing_uid			,
	ref_billingdetail_uid,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
	SELECT b.billing_uid,
		bd.billingdetail_uid AS ref_billingdetail_uid,
		bt.billingtype_uid,
		bt.billing_type,
		bd.company_id,
		bd.profit_ctr_id,
		bd.receipt_id,
		bd.line_id,
		bd.price_id,
		bd.trans_source,
		NULL AS trans_type,
		p.product_id, 
		bd.dist_company_id AS dist_company_id,
		bd.dist_profit_ctr_id AS dist_profit_ctr_id,
		stSubmitted.sales_tax_id, 
		ISNULL(stMain.sales_tax_percent, 0) AS applied_percent, 
		ROUND(ISNULL(stMain.sales_tax_percent / 100, 0) * ISNULL(bd.extended_amt, 0.00), 2) AS extended_amt,
		--LEFT(p.gl_account_code, 5) + RIGHT(bd.gl_account_code, 7) AS gl_account_code,
		LEFT(p.gl_account_code, 5)
			+ SUBSTRING(bd.gl_account_code, 6, 2)
			+ SUBSTRING(p.gl_account_code, 8, 2)
			+ REPLACE(RIGHT(p.gl_account_code, 3), 'XXX', RIGHT(bd.gl_account_code, 3) ) AS gl_account_code,
		NULL AS sequence_id,
		ISNULL(REPLACE(p.JDE_BU, 'XXX', RIGHT(bd.JDE_BU, 3)), 'XXXXXXX'),
		ISNULL(p.jde_object, 'XXXXX'),
		p.AX_MainAccount,
		p.AX_Dimension_1,
		p.AX_Dimension_2,
		p.AX_Dimension_3,
		p.AX_Dimension_4,
		p.AX_Dimension_5_Part_1,
		p.AX_Dimension_5_Part_2,
		p.AX_Dimension_6,
		NULL,
		NULL,
		bd.currency_code
	FROM #Billing b
	INNER JOIN BillingType bt ON bt.billing_type = 'SalesTax'
	INNER JOIN #BillingDetail bd ON bd.billing_uid = b.billing_uid
	JOIN #SalesTax stSubmitted ON 1=1
	JOIN SalesTax stMain ON stMain.sales_tax_id = stSubmitted.sales_tax_id
	JOIN Product p ON p.product_code = stMain.sales_tax_system_product_code
		AND p.product_type = 'X'
		AND p.status = 'A'
		AND p.company_ID = bd.dist_company_id
		AND p.profit_ctr_ID = bd.dist_profit_ctr_id
	WHERE 1=1
	AND bd.billing_type <> 'SalesTax'
	AND NOT EXISTS (SELECT 1 FROM SalesTaxExemption ste
		WHERE ste.sales_tax_id = stSubmitted.sales_tax_id
		AND ste.company_id = bd.company_id
		AND ste.profit_ctr_id = bd.profit_ctr_id
		AND ste.exemption_type = 'SR'
		AND ste.billing_type = bd.billing_type
		)
	AND NOT EXISTS (SELECT 1 FROM SalesTaxExemption ste
		WHERE ste.sales_tax_id = stSubmitted.sales_tax_id
		AND ste.company_id = bd.company_id
		AND ste.profit_ctr_id = bd.profit_ctr_id
		AND ste.exemption_type = 'P'
		AND ste.product_id = bd.product_id
		)
	AND NOT EXISTS (SELECT 1 FROM SalesTaxExemption ste
		WHERE ste.sales_tax_id = stSubmitted.sales_tax_id
		AND ste.company_id = bd.company_id
		AND ste.profit_ctr_id = bd.profit_ctr_id
		AND ste.exemption_type = 'R'
		AND ste.resource_class_code = b.workorder_resource_item
		)
	AND ((stSubmitted.sales_tax_id <> 63)
		OR (stSubmitted.sales_tax_id = 63 AND b.billing_date >= '7/1/2011')
		)	-- Only apply the CT sales tax to transactions after 7/1/11, when the law went into effect.
    
IF @debug = 1 PRINT 'SELECT * FROM #BillingDetail(sp_billing_submit_calc_surcharges_billingdetail) Sales Tax'
IF @debug = 1 SELECT * FROM #BillingDetail

GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_surcharges_billingdetail] TO [EQWEB]
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_surcharges_billingdetail] TO [COR_USER]
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_surcharges_billingdetail] TO [EQAI]
GO
