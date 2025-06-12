/* -- Commented 6/21/2019 -JPB: deprecated function

CREATE PROCEDURE sp_rpt_extract_walmart_finance_by_invoice (
	@invoice_id				int,
	@report_log_id          int = null
	--@output_mode			varchar(20)		-- one of: 'validation', 'wm-extract', 'eq-extract'
)
AS

/* ***********************************************************
Procedure    : sp_rpt_extract_walmart_finance_by_invoice
Database     : PLT_AI
Created      : Jan 25 2008 - Jonathan Broome
Description  : Creates a Wal-Mart Financial Extract

   10/21/2011 - JPB
	 Copied from sp_rpt_extract_walmart_finance
	
sp_rpt_extract_walmart_finance_by_invoice 799437
select * from billing where invoice_id = 962187 and receipt_id = 949853
select * from billingdetail where billing_uid = 5795398 and receipt_id = 949853


*********************************************************** */
SET NOCOUNT ON

-- Define other variables used internally:
DECLARE
	@list 					varchar(7500),
	@vendor_number			varchar(20) = '257170/368172'


Create Table #Customer (
	customer_id	int
)
-- INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '10673, 13031, 12650')
-- Finance Extract run 8/9/2011:
INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '10673')

	
-- Create #Extract for inserts later:
CREATE TABLE #Extract (
	-- Walmart Fields:
	site_code 					varchar(16) NULL,	-- Facility Number
	site_type_abbr 				varchar(10) NULL,	-- Facility Type
	division					varchar(10) NULL,	-- Division -- Begin using in 2012
	market						varchar(10) NULL,	-- Market -- Begin using in 2012
	region						varchar(10) NULL,	-- Region -- Begin using in 2012
	generator_city 				varchar(40) NULL,	-- City
	generator_state 			varchar(2) NULL,	-- State
	service_date 				datetime NULL,		-- Shipment Date
	epa_id 						varchar(12) NULL,	-- Haz Waste Generator EPA ID
	manifest 					varchar(15) NULL,	-- Manifest Number
	manifest_line 				int NULL,			-- Manifest Line
	pounds 						float NULL,			-- Weight
	bill_unit_desc 				varchar(40) NULL,	-- Container Type
	quantity 					float NULL,			-- Container Quantity
	billing_quantity 			float NULL,			-- Billing Quantity
	cost_item					varchar(40) NULL,	-- Cost Item Description
	item_desc 					varchar(150) NULL,	-- Item Description
	waste_desc 					varchar(50) NULL,	-- Waste Profile Description
	approval_or_resource 		varchar(60) NULL,	-- Waste Profile Number
	dot_description				varchar(255) NULL,	-- DOT Description
	disposal_method				varchar(100) NULL,	-- WM-list Disposal Method
	service_type 				varchar(150) NULL,	-- Service Type
	service_description			varchar(50) NULL,	-- Service Description (e.g. HW OS Lg Qty Const)
	vendor_number				varchar(20) NULL,	-- Vendor Number
	invoice_number 				varchar(150) NULL,	-- Invoice Number
	po_number 					varchar(150) NULL,	-- PO Number
	receipt_id 					int NULL,			-- Workorder Number
	unit_price 					money NULL,			-- Unit Price
	tax							float NULL,			-- Tax
	extended_cost				money NULL,			-- Extended Tax

	-- EQ Fields:
	company_id 					smallint NULL,
	profit_ctr_id	 			smallint NULL,
	line_sequence_id			int NULL,
	generator_id 				int NULL,
	site_type	 				varchar(40) NULL,
	manifest_page 				int NULL,
	item_type 					varchar(9) NULL,
	tsdf_approval_id 			int NULL,
	profile_id 					int NULL,
	source_table 				varchar(20) NULL,
	receipt_date				datetime NULL,
	receipt_workorder_id		int NULL,
	workorder_start_date		datetime NULL,
	customer_id					int NULL
)

/* *************************************************************

Build Phase...
	Insert records to #Extract from
	1. TSDF (3rd party) disposal
	2. Receipt (EQ) disposal
	3. No-Waste Pickup Workorders

	Each step also has a #NotSubmitted copy - to trap for records
	that would have been included, if only they were submitted for
	billing already.  This info is for validation purposes.

	Before Receipts can be inseted into #Extract, a separate
	pre-condition query has to be run to build #ReceiptTransporter
	with info needed by the Receipt insert.

************************************************************** */

-- Work Orders using TSDFApprovals (where customer = @customer_id)
INSERT #Extract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	null as division,
	null as market,
	null as region,
	g.generator_city,
	g.generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
	g.epa_id AS epa_id,
	d.manifest,
	CASE WHEN isnull(d.manifest_line, '') <> '' THEN
		CASE WHEN IsNumeric(d.manifest_line) <> 1 THEN
			dbo.fn_convert_manifest_line(d.manifest_line, d.manifest_page_num)
		ELSE
			d.manifest_line
		END
	ELSE
		NULL
	END AS manifest_line,
    -- ISNULL(d.pounds, 0) AS pounds,
	ISNULL(
		(
			SELECT 
				quantity
				FROM WorkOrderDetailUnit a
				WHERE a.workorder_id = d.workorder_id
				AND a.company_id = d.company_id
				AND a.profit_ctr_id = d.profit_ctr_id
				AND a.sequence_id = d.sequence_id
				AND a.bill_unit_code = 'LBS'
				and d.resource_type = 'D'
		) 
	, 0) as pounds, -- workorder detail pounds
	null, -- b.bill_unit_desc,
    -- ISNULL(d.quantity, 0) AS quantity,
	/*    
    ISNULL( 
        CASE
                WHEN u.quantity IS NULL
                THEN IsNull(d.quantity,0)
                ELSE u.quantity
        END
    , 0) AS quantity,
    */
  	ISNULL(d.container_count, 0) AS quantity, -- It's CONTAINER quantity.
  	/* Kept above instead of matching to Disposal extract because in2 places this extract
  	is very specific about it being CONTAINER quantity to use */
	ISNULL(Billing.quantity, 0) AS billing_quantity,

	cost_item = CASE WHEN ((billing.trans_source = 'W' and billing.workorder_resource_type = 'D') 
							or (billing.trans_source = 'R' and billing.trans_type = 'D') 
							or (billing.trans_source = 'R' and billing.trans_type = 'S' and billing.waste_code = 'LMIN')
							or (billing.trans_source = 'R' and billing.trans_type = 'S' and exists(select 1 from billingdetail bd where bd.billing_uid = billing.billing_uid 
																									and bd.product_id in (select product_id from product where product_code = 'LMIN'))))
			THEN 'Disposal' ELSE
				CASE WHEN (billing.trans_source = 'W' and (billing.workorder_resource_type = 'S' or billing.workorder_resource_item = 'MISC'))
				THEN 'Supply' ELSE
					CASE WHEN (billing.workorder_resource_item = 'LABTEST')
					THEN 'Analysis' ELSE
						CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' and billing.workorder_resource_item = 'FEEGASSR')
						THEN 'Surcharge' ELSE
							CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'STOPFEE')
							THEN 'Stop Fee' ELSE
								CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'DEMURRAGE')
								THEN 'Demurrage' ELSE
									CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP'))
									-- just for this run SK 09/14 changed to include the one work order categorized incorrectly as Equipment, tractor
									--CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP', 'TRACTOR'))
										THEN 'Freight' ELSE
											CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'TRAN')
												THEN 'Transportation' ELSE
													'Cost Item Undefined'
											END
									END
								END
							END
						END
					END
				END
			END,
	
	CONVERT(varchar(60), COALESCE(d.tsdf_approval_code, d.resource_class_code)) + ' ' + isnull(t.waste_desc, '') AS item_desc,
	t.waste_desc AS waste_desc,
    CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
        d.resource_class_code
    ELSE
        d.tsdf_approval_code
    END AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	
	disposal_method = replace(
		  CASE 
			  WHEN t.disposal_service_id = (select disposal_service_id from DisposalService (nolock) where disposal_service_desc = 'Other') THEN 
				  t.disposal_service_other_desc
			  ELSE
				  ds.disposal_service_desc
		  END 
		, 'Incineration/Witness', 'Incineration'),
	
	CASE WHEN (w.company_id = 14 and w.profit_ctr_id = 5 and w.billing_project_id = 99) THEN 'ER' ELSE 'Routine' END as service_type,
	service_description = CASE billing.billing_project_id
			-- WM...
			WHEN 3996 THEN 'HW ROUTINE'
			WHEN 4001 THEN 'HW ROUTINE'
			WHEN 4033 THEN 'HW OS LG QTY CONTST'
			WHEN 4043 THEN 'HW OS LG QTY PHOTO'
			WHEN 4031 THEN 'HW OS CHEM SPILL'
			WHEN 4011 THEN 'HW OS ABANDONED'
			WHEN 4007 THEN 'HW OS STATION FULL'
			WHEN 4019 THEN 'HW OS STATION FULL'
			WHEN 4025 THEN 'HW OS STATION FULL'
			WHEN 4047 THEN 'HW OS ANALYSIS'
			WHEN 4017 THEN 'HW OS REACTION'
			WHEN 4003 THEN 'HW OS SUPPLY ONLY'
			WHEN 4005 THEN 'HW OS SUPPLY ONLY'
			WHEN 3998 THEN 'RX ROUTINE'
			WHEN 4009 THEN 'RX OS STATION FULL'
			-- SAMS...
			WHEN 3997 THEN 'HW ROUTINE'
			WHEN 4002 THEN 'HW ROUTINE'
			WHEN 4034 THEN 'HW OS LG QTY CONTST'
			WHEN 4044 THEN 'HW OS LG QTY PHOTO'
			WHEN 4032 THEN 'HW OS CHEM SPILL'
			WHEN 4012 THEN 'HW OS ABANDONED'
			WHEN 4008 THEN 'HW OS STATION FULL'
			WHEN 4021 THEN 'HW OS STATION FULL'
			WHEN 4026 THEN 'HW OS STATION FULL'
			WHEN 4048 THEN 'HW OS ANALYSIS'
			WHEN 4018 THEN 'HW OS REACTION'
			WHEN 4004 THEN 'HW OS SUPPLY ONLY'
			WHEN 4006 THEN 'HW OS SUPPLY ONLY'
			WHEN 3999 THEN 'RX ROUTINE'
			WHEN 4010 THEN 'RX OS STATION FULL'
			ELSE NULL
		END,
	@vendor_number as vendor_number,
	Billing.invoice_code AS invoice_number,
	Billing.purchase_order AS po_number,
	d.workorder_id as receipt_id,
	ISNULL(Billing.price, 0) AS unit_price,
	(
		select sum(isnull(bd.extended_amt, 0))
		from billingdetail bd
		where 	bd.receipt_id = Billing.receipt_id
			and bd.line_id = Billing.line_id
			and bd.price_id = Billing.price_id
			and bd.trans_source = Billing.trans_source
			AND bd.company_id = Billing.company_id
			and bd.profit_ctr_id = Billing.profit_ctr_id
			and bd.billing_type = 'Salestax'
	) AS tax,
	(
		select sum(isnull(bd.extended_amt, 0))
		from billingdetail bd
		where 	bd.receipt_id = Billing.receipt_id
			and bd.line_id = Billing.line_id
			and bd.price_id = Billing.price_id
			and bd.trans_source = Billing.trans_source
			AND bd.company_id = Billing.company_id
			and bd.profit_ctr_id = Billing.profit_ctr_id
			and bd.billing_type <> 'Salestax'
	) AS extended_cost,

	-- EQ Fields:
	w.company_id,
	w.profit_ctr_id,
	d.sequence_id as line_sequence_id,
	g.generator_id,
	g.site_type,
	d.manifest_page_num,
	d.resource_type AS item_type,
	t.tsdf_approval_id,
	NULL AS profile_id,
	'Workorder' AS source_table,
	NULL AS receipt_date,
	NULL AS receipt_workorder_id,
	w.start_date AS workorder_start_date,
	w.customer_id AS customer_id
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
INNER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
-- INNER JOIN BillUnit b  (nolock) ON d.bill_unit_code = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
INNER JOIN Billing Billing  (nolock) ON
	d.workorder_id = Billing.receipt_id
	AND d.company_id = Billing.company_id
	AND d.profit_ctr_id = Billing.profit_ctr_id
	AND d.resource_type = Billing.workorder_resource_type
	AND d.sequence_id = Billing.workorder_sequence_id
	AND Billing.trans_source = 'W'
	AND billing.invoice_id = @invoice_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
LEFT OUTER JOIN ResourceClassDetail rcd (nolock)
	ON Billing.workorder_resource_item = rcd.resource_class_code
	AND Billing.company_id = rcd.company_id
	AND Billing.profit_ctr_id = rcd.profit_ctr_id
	AND Billing.bill_unit_code = rcd.bill_unit_code
WHERE 1=1
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND w.submitted_flag = 'T'
AND Billing.status_code = 'I'
-- AND (isnull(w.billing_project_id, 0) <> 145 OR (isnull(w.billing_project_id, 0) = 145 and w.customer_id <> 10673))
-- AND isnull(w.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
-- AND isnull(w.billing_project_id, 0) in (select billing_project_id from #BillingProject)




--	PRINT 'Receipt/Transporter Fix'
/*
This query has 3 union'd components:
first component: workorder inner join to billinglinklookup and receipt
second component: receipt inner join to WMReceiptWorkorderTransporter and workorder
third component: receipt not linked to either BLL or WMRWT
*/
select distinct
	r.receipt_id,
	r.line_id,
	rp.price_id,
	r.company_id,
	r.profit_ctr_id,
	wo.workorder_id as receipt_workorder_id,
	wo.company_id as workorder_company_id,
	wo.profit_ctr_id as workorder_profit_ctr_id,
	-- wo.start_date as service_date,
	-- 2009-05-27: Above changed to following:
	isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
	r.receipt_date,
	'F' as calc_recent_wo_flag
INTO #WMReceiptTransporter
from workorderheader wo (nolock) 
inner join billinglinklookup bll  (nolock) on
	wo.company_id = bll.source_company_id
	and wo.profit_ctr_id = bll.source_profit_ctr_id
	and wo.workorder_id = bll.source_id
inner join receipt r  (nolock) on bll.company_id = r.company_id
	and bll.profit_ctr_id = r.profit_ctr_id
	and bll.receipt_id = r.receipt_id
INNER JOIN ReceiptPrice rp  (nolock) ON
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
	AND billing.invoice_id = @invoice_id
-- 2009-05-27: Added following join to allow selection by receipttransporter.sign_date in "service_date" field
left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
	and rt1.profit_ctr_id = r.profit_ctr_id
	and rt1.company_id = r.company_id
	and rt1.transporter_sequence_id = 1
WHERE 1=1
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
	-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
	-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
--	AND isnull(wo.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
--	AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
--	AND isnull(wo.billing_project_id, 0) in (select billing_project_id from #BillingProject)
--	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)
union
select distinct
	r.receipt_id,
	r.line_id,
	rp.price_id,
	r.company_id,
	r.profit_ctr_id,
	null as receipt_workorder_id,
	null as workorder_company_id,
	null as workorder_profit_ctr_id,
	-- null as service_date,
	-- 2009-05-27: Above changed to following:
	rt1.transporter_sign_date as service_date,
	r.receipt_date,
	'F' as calc_recent_wo_flag
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
	AND billing.invoice_id = @invoice_id
-- 2009-05-27: Added following join to allow selection by receipttransporter.sign_date in "service_date" field
left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
	and rt1.profit_ctr_id = r.profit_ctr_id
	and rt1.company_id = r.company_id
	and rt1.transporter_sequence_id = 1
WHERE 1=1
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
	-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
	-- AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
--	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)	
	and not exists (
		select receipt_id from billinglinklookup bll (nolock) 
		where bll.company_id = r.company_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.receipt_id = r.receipt_id
		union all
		select receipt_id from WMReceiptWorkorderTransporter rwt (nolock) 
		where rwt.receipt_company_id = r.company_id
		and rwt.receipt_profit_ctr_id = r.profit_ctr_id
		and rwt.receipt_id = r.receipt_id
		and rwt.workorder_id is not null
	)


-- Receipts
INSERT #Extract
SELECT DISTINCT
		-- Walmart Fields:
		g.site_code,
		gst.generator_site_type_abbr AS site_type_abbr,
		null as division,
		null as market,
		null as region,
		g.generator_city,
		g.generator_state,
		wrt.service_date,
		-- coalesce(r.Load_Generator_EPA_ID, g.epa_id, '') AS epa_id,
		g.epa_id,
		r.manifest,
		CASE WHEN ISNULL(r.manifest_line, '') <> '' THEN
			CASE WHEN IsNumeric(r.manifest_line) <> 1 THEN
				dbo.fn_convert_manifest_line(r.manifest_line, r.manifest_page_num)
			ELSE
				r.manifest_line
			END
		ELSE
			NULL
		END AS manifest_line,
		r.line_weight as pounds, -- pull in NULL for now, we'll update it from Receipt.Net_weight later - 12/20/2010
		b.bill_unit_desc,
		-- ISNULL(rp.bill_quantity, 0) AS quantity,
		ISNULL(r.container_count, 0) AS quantity, -- It's CONTAINER quantity
		ISNULL(Billing.quantity, 0) AS billing_quantity,
		
		cost_item = CASE WHEN ((billing.trans_source = 'W' and billing.workorder_resource_type = 'D') 
								or (billing.trans_source = 'R' and billing.trans_type = 'D') 
								or (billing.trans_source = 'R' and billing.trans_type = 'S' and billing.waste_code = 'LMIN')
								or (billing.trans_source = 'R' and billing.trans_type = 'S' and exists(select 1 from billingdetail bd where bd.billing_uid = billing.billing_uid 
																									and bd.product_id in (select product_id from product where product_code = 'LMIN'))))
				THEN 'Disposal' ELSE
					CASE WHEN (billing.trans_source = 'W' and (billing.workorder_resource_type = 'S' or billing.workorder_resource_item = 'MISC'))
					THEN 'Supply' ELSE
						CASE WHEN (billing.workorder_resource_item = 'LABTEST')
						THEN 'Analysis' ELSE
							CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' and billing.workorder_resource_item = 'FEEGASSR')
							THEN 'Surcharge' ELSE
								CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'STOPFEE')
								THEN 'Stop Fee' ELSE
									CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'DEMURRAGE')
									THEN 'Demurrage' ELSE
										CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP'))
										-- just for this run SK 09/14 changed to include the one work order categorized incorrectly as Equipment, tractor
										--CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_item IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP', 'TRACTOR'))
										THEN 'Freight' ELSE
											CASE WHEN (billing.trans_source = 'W' AND billing.workorder_resource_type = 'O' AND billing.workorder_resource_item = 'TRAN')
												THEN 'Transportation' ELSE
													'Cost Item Undefined'
											END
										END
									END
								END
							END
						END
					END
				END,
		
		ISNULL(Billing.service_desc_1,'') + ' ' + ISNULL(NULLIF(Billing.service_desc_2, Billing.service_desc_1), '') AS item_desc,
		p.Approval_desc AS waste_desc,
		COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
		NULL as dot_description,
		disposal_method = replace(
		  dbo.fn_wm_disposal_method(
			ds.disposal_service_desc,
			pqa.disposal_service_other_desc,
			pqa.ob_tsdf_approval_id,
			pqa.ob_eq_profile_id,
			pqa.ob_eq_company_id,
			pqa.ob_eq_profit_ctr_id)
		   , 'Incineration/Witness', 'Incineration'),

		CASE WHEN (r.company_id = 14 and r.profit_ctr_id = 5 and r.billing_project_id = 99) THEN 'ER' ELSE 'Routine' END as service_type,
		
		service_description = CASE billing.billing_project_id
			-- WM...
			WHEN 3996 THEN 'HW ROUTINE'
			WHEN 4001 THEN 'HW ROUTINE'
			WHEN 4033 THEN 'HW OS LG QTY CONTST'
			WHEN 4043 THEN 'HW OS LG QTY PHOTO'
			WHEN 4031 THEN 'HW OS CHEM SPILL'
			WHEN 4011 THEN 'HW OS ABANDONED'
			WHEN 4007 THEN 'HW OS STATION FULL'
			WHEN 4019 THEN 'HW OS STATION FULL'
			WHEN 4025 THEN 'HW OS STATION FULL'
			WHEN 4047 THEN 'HW OS ANALYSIS'
			WHEN 4017 THEN 'HW OS REACTION'
			WHEN 4003 THEN 'HW OS SUPPLY ONLY'
			WHEN 4005 THEN 'HW OS SUPPLY ONLY'
			WHEN 3998 THEN 'RX ROUTINE'
			WHEN 4009 THEN 'RX OS STATION FULL'
			-- SAMS...
			WHEN 3997 THEN 'HW ROUTINE'
			WHEN 4002 THEN 'HW ROUTINE'
			WHEN 4034 THEN 'HW OS LG QTY CONTST'
			WHEN 4044 THEN 'HW OS LG QTY PHOTO'
			WHEN 4032 THEN 'HW OS CHEM SPILL'
			WHEN 4012 THEN 'HW OS ABANDONED'
			WHEN 4008 THEN 'HW OS STATION FULL'
			WHEN 4021 THEN 'HW OS STATION FULL'
			WHEN 4026 THEN 'HW OS STATION FULL'
			WHEN 4048 THEN 'HW OS ANALYSIS'
			WHEN 4018 THEN 'HW OS REACTION'
			WHEN 4004 THEN 'HW OS SUPPLY ONLY'
			WHEN 4006 THEN 'HW OS SUPPLY ONLY'
			WHEN 3999 THEN 'RX ROUTINE'
			WHEN 4010 THEN 'RX OS STATION FULL'
			ELSE NULL
		END,
		
		@vendor_number as vendor_number,
		Billing.invoice_code AS invoice_number,
		Billing.purchase_order AS po_number,
		wrt.receipt_id,
		ISNULL(Billing.price, 0) AS unit_price,
		(
			select sum(isnull(bd.extended_amt, 0))
			from billingdetail bd
			where 	bd.receipt_id = Billing.receipt_id
				and bd.line_id = Billing.line_id
				and bd.price_id = Billing.price_id
				and bd.trans_source = Billing.trans_source
				AND bd.company_id = Billing.company_id
				and bd.profit_ctr_id = Billing.profit_ctr_id
				and bd.billing_type = 'Salestax'
		) AS tax,
		(
			select sum(isnull(bd.extended_amt, 0))
			from billingdetail bd
			where 	bd.receipt_id = Billing.receipt_id
				and bd.line_id = Billing.line_id
				and bd.price_id = Billing.price_id
				and bd.trans_source = Billing.trans_source
				AND bd.company_id = Billing.company_id
				and bd.profit_ctr_id = Billing.profit_ctr_id
				and bd.billing_type <> 'SalesTax'
		) AS extended_cost,

		-- EQ Fields:
		wrt.company_id,
		wrt.profit_ctr_id,
		r.line_id,
		r.generator_id,
		g.site_type,
		r.manifest_page_num AS manifest_page,
		r.trans_type AS item_type,
		NULL AS tsdf_approval_id,
		r.profile_id,
		'Receipt' AS source_table,
		r.receipt_date,
		wrt.receipt_workorder_id,
		wrt.service_date AS workorder_start_date,
		r.customer_id

	FROM Receipt r (nolock) 
	INNER JOIN ReceiptPrice rp  (nolock) ON
		/* r.link_Receipt_ReceiptPrice = rp.link_Receipt_ReceiptPrice */
		R.receipt_id = rp.receipt_id
		and r.company_id = rp.company_id
		and r.profit_ctr_id = rp.profit_ctr_id
		and r.line_id = rp.line_id
	INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
	INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
	INNER JOIN #WMReceiptTransporter wrt ON
		r.company_id = wrt.company_id
		and r.profit_ctr_id = wrt.profit_ctr_id
		and r.receipt_id = wrt.receipt_id
		and r.line_id = wrt.line_id
		and rp.price_id = wrt.price_id
	INNER JOIN Billing Billing  (nolock) ON
		r.receipt_id = Billing.receipt_id
		AND r.company_id = Billing.company_id
		AND r.profit_ctr_id = Billing.profit_ctr_id
		AND r.line_id = Billing.line_id
		and rp.price_id = Billing.price_id
		AND Billing.trans_source = 'R'
		AND billing.invoice_id = @invoice_id
	LEFT OUTER JOIN Profile p  (nolock) on r.profile_id = p.profile_id
	LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
	LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
	LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
		on r.profile_id = pqa.profile_id 
		and r.company_id = pqa.company_id 
		and r.profit_ctr_id = pqa.profit_ctr_id 
	LEFT OUTER JOIN DisposalService ds  (nolock)
		on pqa.disposal_service_id = ds.disposal_service_id
	WHERE 1=1
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
--	AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
--	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)

-- Update fields left null in #Extract
UPDATE #Extract set
	dot_description =
		CASE WHEN #Extract.tsdf_approval_id IS NOT NULL THEN
			(SELECT DOT_shipping_name FROM tsdfapproval  (nolock) WHERE tsdf_approval_id = #Extract.tsdf_approval_id)
		ELSE
			CASE WHEN #Extract.profile_id IS NOT NULL THEN
				left(dbo.fn_manifest_dot_description('P', #Extract.profile_id), 255)
			ELSE
				''
			END
		END

-- WM format the disposal_method info...

update #Extract set
	disposal_method = 
      CASE ltrim(rtrim(ISNULL(disposal_method, '')))
          WHEN 'Canada Landfill'      THEN 'Landfill D'
          WHEN 'Cement Kiln'          THEN 'Fuel Blending/Energy Recovery'
          WHEN 'Fuel Blender'         THEN 'Fuel Blending/Energy Recovery'
          WHEN 'Incineration'         THEN 'Incineration'
          WHEN 'Oil Marketer'         THEN 'Recycling'
          WHEN 'POTW'                 THEN 'Treatment/POTW'
          WHEN 'Recycling Facility'   THEN 'Recycling'
          WHEN 'Subtitle C Landfill'  THEN 'Landfill C'
          WHEN 'Subtitle D Landfill'  THEN 'Landfill D'
          WHEN 'Retort'               THEN 'Recycle/Metals (Retort)'
          WHEN 'Scrap'                THEN 'Recycle/Metals (Scrap)'
          WHEN 'Smelt'                THEN 'Recycle/Metals (Smelting)'
          WHEN 'Universal Handler'    THEN 'Recycling'
          WHEN 'Other'                THEN 'PROBLEM: Other' + 
               CASE WHEN profile_id is not null then ' - Profile ID: ' + convert(varchar(20), profile_id) else
                    CASE WHEN tsdf_approval_id is not null then ' - TSDF Approval ID: ' + convert(varchar(20), tsdf_approval_id) else
                         'No Profile/TSDFA ID for ' + left(source_table, 1) + ': ' + convert(varchar(20), receipt_id)
                    end
               end
          WHEN 'Deepwell'             THEN 'PROBLEM: Deepwell' + 
              CASE WHEN profile_id is not null then ' - Profile ID: ' + convert(varchar(20), profile_id) else
                   CASE WHEN tsdf_approval_id is not null then ' - TSDF Approval ID: ' + convert(varchar(20), tsdf_approval_id) else
                        'No Profile/TSDFA ID for ' + left(source_table, 1) + ': ' + convert(varchar(20), receipt_id)
                   end
              end
          WHEN 'TSDF'                 THEN 
              isnull(
                  (
                      SELECT -- disposal_method
                          CASE ltrim(rtrim(ISNULL(disposal_method, '')))
                              WHEN 'Canada Landfill'      THEN 'Landfill D'
                              WHEN 'Cement Kiln'          THEN 'Fuel Blending/Energy Recovery'
                              WHEN 'Fuel Blender'         THEN 'Fuel Blending/Energy Recovery'
                              WHEN 'Incineration'         THEN 'Incineration'
                              WHEN 'Oil Marketer'         THEN 'Recycling'
                              WHEN 'POTW'                 THEN 'Treatment/POTW'
                              WHEN 'Recycling Facility'   THEN 'Recycling'
                              WHEN 'Subtitle C Landfill'  THEN 'Landfill C'
                              WHEN 'Subtitle D Landfill'  THEN 'Landfill D'
                              WHEN 'Retort'               THEN 'Recycle/Metals (Retort)'
                              WHEN 'Scrap'                THEN 'Recycle/Metals (Scrap)'
                              WHEN 'Smelt'                THEN 'Recycle/Metals (Smelting)'
                              WHEN 'Universal Handler'    THEN 'Recycling'
                              WHEN 'Other'                THEN 'PROBLEM: Other' + 
                                   CASE WHEN profile_id is not null then ' - Profile ID: ' + convert(varchar(20), profile_id) else
                                        CASE WHEN tsdf_approval_id is not null then ' - TSDF Approval ID: ' + convert(varchar(20), tsdf_approval_id) else
                                             'No Profile/TSDFA ID for ' + left(source_table,1) + ': ' + convert(varchar(20), receipt_id)
                                        end
                                   end
                              WHEN 'Deepwell'             THEN 'PROBLEM: Deepwell' + 
                                  CASE WHEN profile_id is not null then ' - Profile ID: ' + convert(varchar(20), profile_id) else
                                       CASE WHEN tsdf_approval_id is not null then ' - TSDF Approval ID: ' + convert(varchar(20), tsdf_approval_id) else
                                            'No Profile/TSDFA ID for ' + left(source_table, 1) + ': ' + convert(varchar(20), receipt_id)
                                       end
                                  END
                              ELSE ISNULL(disposal_method, '') 
                          END
                      FROM disposalservice dss 
                      INNER JOIN TSDFApproval tss
                          ON tss.disposal_service_id = dss.disposal_service_id
                      INNER JOIN ProfileQuoteApproval pqass on tss.tsdf_approval_id = pqass.OB_TSDF_approval_id
                      where pqass.profile_id = #Extract.profile_id
                          AND pqass.company_id = #Extract.company_id
                          AND pqass.profit_ctr_id = #Extract.profit_ctr_id
                  ), 'PROBLEM: TSDF Disposal Service not identified in profile_id: ' + convert(varchar(10), #Extract.company_id) + '-' + convert(varchar(10), #Extract.profit_ctr_id) + ':' + convert(varchar(20), #Extract.profile_id)
              )
          ELSE CASE WHEN waste_desc = 'No waste picked up' THEN '' ELSE ISNULL(disposal_method, '') END
      END

update #Extract set waste_desc = approval_or_resource where isnull(waste_desc, '') = ''

update #Extract set division = case site_type_abbr
		WHEN 'WM' THEN 1
		WHEN 'SUP' THEN 1
		WHEN 'WNM' THEN 1
		WHEN 'XPS' THEN 1
		WHEN 'WTC' then 1
		WHEN 'SAMS' THEN 18
		ELSE 0
	END

-- #Extract is finished now.

SELECT
	-- Walmart Fields:
	ISNULL(site_code 				, '') as 'Facility Number',
	ISNULL(site_type_abbr 			, '') as 'Facility Type',
	ISNULL(division					, '') as 'Division', -- Begin using in 2012
	ISNULL(market					, '') as 'Market', -- Begin using in 2012
	ISNULL(region					, '') as 'Region', -- Begin using in 2012
	ISNULL(generator_city 			, '') as 'City',
	ISNULL(generator_state 			, '') as 'State',
	ISNULL(CONVERT(varchar(20), service_date, 101), '') AS 'Shipment Date',
	ISNULL(epa_id 					, '') as 'Haz Waste Generator EPA ID',
	ISNULL(manifest 				, '') as 'Manifest Number',
	ISNULL(NULLIF(manifest_line, 0), '') AS 'Manifest Line',
	ISNULL(pounds 					, '') as 'Weight',
	ISNULL(bill_unit_desc 			, '') as 'Container Type',
	ISNULL(quantity 				, '') as 'Container Quantity',
	ISNULL(billing_quantity 		, '') as 'Billing Quantity',
	
	ISNULL(cost_item 				, '') as 'Cost Item Description',
	
--	ISNULL(item_desc 				, '') as 'Item Description',
	
	ISNULL(waste_desc 				, '') as 'Waste Profile Description',
	ISNULL(approval_or_resource 	, '') as 'Waste Profile Number',
	ISNULL(dot_description			, '') as 'DOT Description',
	ISNULL(disposal_method			, '') as 'Disposal Method',
	ISNULL(service_type 			, '') as 'Service Type',
	ISNULL(service_description		, '') as 'Service Description',
	'30'								  as 'Service Frequency',
	ISNULL(vendor_number			, '') as 'Vendor Number',
	ISNULL(invoice_number 			, '') as 'Invoice Number',
--	ISNULL(po_number 				, '') as 'PO Number',
	ISNULL(receipt_id 				, '') as 'Workorder Number',
	ISNULL(unit_price 				, 0) as 'Unit Price',
	ISNULL(tax						, 0) as 'Tax',
	ISNULL(extended_cost			, 0) as 'Extended Amount'
FROM #Extract
ORDER BY
	generator_state,
	generator_city,
	site_code,
	service_date,
	receipt_id
--COMPUTE SUM(ISNULL(tax						, 0)), SUM (ISNULL(extended_cost			, 0))
--END

   	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_finance_by_invoice] TO [EQAI]
    AS [dbo];

*/
