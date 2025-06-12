CREATE PROCEDURE sp_rpt_transporter_fee_ri 
	@date_from		datetime
,	@date_to		datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@EPA_ID			varchar(15)
,	@work_order_status	char(1)
AS
/***********************************************************************
Hazardous Waste Generation Fee Report - Rhode Island

Load to:		Plt_AI
PB Object(s):	r_transporter_fee_ri_summ, 
				r_transporter_fee_ri_worksheet

03/10/2005 JDB	Created (copied from MA HW Transporter Fee Report)
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
05/05/2005 MK	Added generator_name to select
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
		pull one report for the whole facility
08/10/2006 rg   revised for tsdfapproval and profile
03/23/2007 rg   updated fee values per regulations eqai 4723.
11/12/2007 rg   revised for workorder status.  submited workorders are now status of A
                and submitted-flag of T.
08/22/2008 JDB	In July 08 we modified the work order manifest unit drop-down to use manifest unit
				instead of bill unit, but we didn't convert the data.  Today this SP was modified
				to return the bill unit instead of the manifest unit, because the DWs are expecting it.
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
04/08/2010 RJG	Added join criterias to WorkOrderDetail: 
				1) wod.bill_unit_code = rc.bill_unit_code
				2) wod.profit_ctr_id = rc.profit_ctr_id
04/28/2010 JDB	Fixed join from 4/8/10 on ResourceClass. 
05/13/2010 JDB	Fixed join again from 4/8/10 on ResourceClass. 
07/16/2010 KAM  Updated the SQL to not include voided workorderdetail Rows
10/27/2010 SK	Moved to Plt_AI , replaced where clause with joins, return company_id, company_name, profit_ctr_name
02/04/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Result set changed to not return company/profit center name
				Changed to run by user selected EPA ID
				Changed to fetch StateLicenseCode from new table: TransporterStateLicense
				Replaced use of ResourceClass Category with resourceclass code.
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter_code
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.
03/04/2011 SK	Added join from WorkOrderTransporter to Transporter based on transporter_code
08/03/2011 JDB	Changed join to TSDFApprovalPrice & ProfileQuoteDetail to be LEFT OUTER so that the fee doesn't HAVE to 
				exist in that table for the record to be included in the report.  Also changed the way that the exempt records
				are selected and returned.
08/21/2013 SM	Added wastecode table and displaying Display name
11/01/2013 JDB	Commented out the waste_code field from the result set.  It was coming from the Profile or TSDFApproval tables,
				which is the wrong source for this data.
				Added WorkOrderDetail.sequence_id to the result set, because we need it to get the waste codes for the line.
				Also changed the report to exclude BOLs, per Kenny Wenstrom in Gemini 20974.
				Changed the calculation of subject_to_fee to be a sub-select.
				Updated manifest quantity calculation to set it to 1 if it's between 0 and 1, otherwise use normal rounding.
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).

sp_rpt_transporter_fee_ri '10/1/2008', '10/31/2008', 1, 999999, '0', 'zzzz', 'MAD084814136', 'S'

***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE
	@fee_gal				float,
	@fee_lb					float,
	@fee_ton				float,
	@fee_ton_metric			float,
	@fee_liter				float,
	@fee_cubic_yard			float,
	@fee_cubic_meter		float,
	@fee_kg					float,
	@pound_conv_gal			float,
	@pound_conv_lb			float,
	@pound_conv_ton			float,
	@pound_conv_ton_metric	float,
	@gal_conv_liter			float,
	@gal_conv_cubic_yard	float,
	@gal_conv_cubic_meter	float,
	@pound_conv_kg			float,
	@ri_license_num			varchar(10)

SET @fee_gal = 0.19
SET @fee_lb = 0.023
SET @fee_ton = 0.023
SET @fee_ton_metric = 0.023
SET @fee_liter = 0.19
SET @fee_cubic_yard = 0.19
SET @fee_cubic_meter = 0.19
SET @fee_kg = 0.023

SET @pound_conv_gal = 8.3453
SET @pound_conv_lb = 1.0
SET @pound_conv_ton = 2000
SET @pound_conv_ton_metric = 2204.6
SET @gal_conv_liter = 0.264
SET @gal_conv_cubic_yard = 202
SET @gal_conv_cubic_meter = 264
SET @pound_conv_kg = 2.205

--SET @ri_license_num = 'RI-312'
SELECT @ri_license_num = state_license_code FROM TransporterStateLicense 
	WHERE State = 'RI' AND EPA_ID = @EPA_ID


SELECT @pound_conv_gal = ISNULL(pound_conv, 8.3453) FROM BillUnit WHERE bill_unit_code = 'GAL'
SELECT @pound_conv_lb = ISNULL(pound_conv, 1.0) FROM BillUnit WHERE bill_unit_code = 'LBS'
SELECT @pound_conv_ton = ISNULL(pound_conv, 2000) FROM BillUnit WHERE bill_unit_code = 'TONS'
SELECT @pound_conv_ton_metric = ISNULL(pound_conv, 2204.6) FROM BillUnit WHERE bill_unit_code = 'MTON'	-- Currently NULL
SELECT @gal_conv_cubic_yard = ISNULL(gal_conv, 202) FROM BillUnit WHERE bill_unit_code = 'CYB'
SELECT @gal_conv_liter = ISNULL(gal_conv, 0.264) FROM BillUnit WHERE bill_unit_code = 'LITR'		-- Currently NULL
SELECT @pound_conv_kg = ISNULL(pound_conv, 2.205) FROM BillUnit WHERE bill_unit_code = 'KG'
-- SELECT @pound_conv_cubic_meter = gal_conv FROM BillUnit WHERE bill_unit_code = ''		-- Currently no bill unit for cubic meter

-- non eq tsdf
SELECT DISTINCT 
	wom.workorder_id
,	wom.company_id
,	wom.profit_ctr_id
,	wom.manifest
,	t.transporter_code
,	t.Transporter_EPA_ID
,	@ri_license_num AS ri_license_num
--,	wod.quantity_used
--,	wod.bill_unit_code
--,	wodu.quantity AS manifest_quantity
--,	wodu.bill_unit_code AS manifest_unit
,	wodub.quantity
,	wodub.bill_unit_code
--,	wodum.quantity AS manifest_quantity
,	manifest_quantity = CASE WHEN ISNULL(wodum.quantity, 0) > 0 AND ISNULL(wodum.quantity, 0) < 1 THEN 1 ELSE ROUND(ISNULL(wodum.quantity, 0), 0) END
,	wodum.bill_unit_code AS manifest_unit
--,	CASE LEN(wod.manifest_unit) WHEN 1 THEN (SELECT bill_unit_code FROM BillUnit WHERE manifest_unit = wod.manifest_unit)
--								ELSE wod.manifest_unit
--	END AS manifest_unit
--,	ta.customer_id									-- Should use the customer from the work order
,	woh.customer_id
,	wod.TSDF_code
--,	ta.TSDF_approval_code							-- Should use the approval from the work order
,	wod.TSDF_approval_code
--,	ta.waste_stream									-- Should use the waste stream from the work order
,	wod.waste_stream
,	g.generator_id
,	g.EPA_ID
--,	w.display_name as waste_code
,	'' AS waste_code
,	b.pound_conv
--,	1 AS subject_to_fee
--,	CASE tap.fee_exempt_flag WHEN 'T' THEN 0 ELSE 1 END AS subject_to_fee
,	subject_to_fee = ISNULL((SELECT CASE tap.fee_exempt_flag WHEN 'T' THEN 0 ELSE 1 END
		FROM TSDFApprovalPrice tap
		WHERE tap.TSDF_approval_id = wod.TSDF_approval_id
		AND tap.profit_ctr_id = wod.profit_ctr_id
		AND tap.company_id = wod.company_id 
		AND tap.record_type = 'R'
		AND tap.resource_class_code IN ('FEERIHW', 'FEERI')
		), 1)
,	@fee_gal AS fee_gal
,	@fee_lb AS fee_lb
,	@fee_ton AS fee_ton
,	@fee_ton_metric AS fee_ton_metric
,	@fee_liter AS fee_liter
,	@fee_cubic_yard AS fee_cubic_yard
,	@fee_cubic_meter AS fee_cubic_meter
,	@fee_kg AS fee_kg
,	@pound_conv_gal AS pound_conv_gal
,	@pound_conv_lb AS pound_conv_lb
,	@pound_conv_ton AS pound_conv_ton
,	@pound_conv_ton_metric AS pound_conv_ton_metric
,	@gal_conv_liter AS gal_conv_liter
,	@gal_conv_cubic_yard AS pound_conv_cubic_yard
,	@gal_conv_cubic_meter AS pound_conv_cubic_meter
,	@pound_conv_kg AS pound_conv_kg
,	g.generator_name
,	'TA' as approval_type
,	wod.company_id AS approval_company
--,	ta.tsdf_approval_id								-- Should use the profile from the work order
,	wod.TSDF_approval_id
,	wod.manifest_line
,	wod.sequence_ID
INTO #tmp
FROM workordermanifest wom
JOIN workorderdetail wod
	ON wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.workorder_ID = wom.workorder_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1	
JOIN WorkOrderDetailUnit wodum
	ON wodum.company_id = wod.company_id
	AND wodum.profit_ctr_ID = wod.profit_ctr_ID
	AND wodum.workorder_id = wod.workorder_ID
	AND wodum.sequence_id = wod.sequence_ID
	AND wodum.manifest_flag = 'T'
JOIN WorkOrderDetailUnit wodub
	ON wodub.company_id = wod.company_id
	AND wodub.profit_ctr_ID = wod.profit_ctr_ID
	AND wodub.workorder_id = wod.workorder_ID
	AND wodub.sequence_id = wod.sequence_ID
	AND wodub.billing_flag = 'T'
JOIN workorderheader woh
	ON woh.company_id = wom.company_id
	AND woh.profit_ctr_ID = wom.profit_ctr_ID
	AND woh.workorder_ID = wom.workorder_ID
	AND woh.start_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
--JOIN tsdfapproval ta
--	ON ta.company_id = wod.company_id
--	AND ta.profit_ctr_id = wod.profit_ctr_ID
--	AND ta.TSDF_approval_id = wod.TSDF_approval_id
--	AND ta.TSDF_approval_status = 'A'
--LEFT OUTER JOIN wastecode w
--	ON w.waste_code_uid = ta.waste_code_uid
--LEFT OUTER JOIN tsdfapprovalprice tap
--	ON tap.company_id = wod.company_id
--	AND tap.profit_ctr_id = wod.profit_ctr_ID
--	AND tap.TSDF_approval_id = wod.TSDF_approval_id
--	AND tap.record_type = 'R'
--LEFT OUTER JOIN resourceclass rc
--	ON rc.company_id = tap.company_id
--	AND rc.profit_ctr_id = tap.profit_ctr_ID
--	AND rc.resource_class_code = tap.resource_class_code
--	AND rc.bill_unit_code = tap.bill_unit_code
--	--AND rc.category = 'RIHWGFEE'
--	AND rc.resource_class_code IN ('FEERIHW', 'FEERI')
JOIN billunit b
	ON b.bill_unit_code = wodum.bill_unit_code
JOIN transporter t
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
JOIN generator g
	ON g.generator_id = woh.generator_id
	AND g.generator_state = 'RI'
JOIN TSDF
	ON TSDF.TSDF_code = wod.tsdf_code
	AND ISNULL(TSDF.eq_flag,'F') = 'F'
WHERE wom.manifest BETWEEN @manifest_from AND @manifest_to	
AND wom.manifest_flag = 'T'
		
--UNION

--SELECT DISTINCT 
--	wom.workorder_id
--,	wom.company_id
--,	wom.profit_ctr_id
--,	wom.manifest
--,	wot1.transporter_code
--,	t.Transporter_EPA_ID
--,	@ri_license_num AS ma_license_num
--,	wod.quantity_used
--,	wod.bill_unit_code
--,	wodu.quantity AS manifest_quantity
--,	wodu.bill_unit_code AS manifest_unit
----,	CASE LEN(wod.manifest_unit) WHEN 1 THEN (SELECT bill_unit_code FROM BillUnit WHERE manifest_unit = wod.manifest_unit)
----								ELSE wod.manifest_unit
----	END AS manifest_unit
--,	ta.customer_id
--,	wod.TSDF_code
--,	ta.TSDF_approval_code
--,	ta.waste_stream
--,	g.generator_id
--,	g.EPA_ID
--,	ta.waste_code
--,	b.pound_conv
--,	0 AS subject_to_fee
--,	@fee_gal AS fee_gal
--,	@fee_lb AS fee_lb
--,	@fee_ton AS fee_ton
--,	@fee_ton_metric AS fee_ton_metric
--,	@fee_liter AS fee_liter
--,	@fee_cubic_yard AS fee_cubic_yard
--,	@fee_cubic_meter AS fee_cubic_meter
--,	@fee_kg AS fee_kg
--,	@pound_conv_gal AS pound_conv_gal
--,	@pound_conv_lb AS pound_conv_lb
--,	@pound_conv_ton AS pound_conv_ton
--,	@pound_conv_ton_metric AS pound_conv_ton_metric
--,	@gal_conv_liter AS gal_conv_liter
--,	@gal_conv_cubic_yard AS pound_conv_cubic_yard
--,	@gal_conv_cubic_meter AS pound_conv_cubic_meter
--,	@pound_conv_kg AS pound_conv_kg
--,	g.generator_name
--,	'TA' as approval_type
--,	ta.company_id as approval_company
--,	ta.tsdf_approval_id
--FROM workordermanifest wom
--JOIN workorderdetail wod
--	ON wod.company_id = wom.company_id
--	AND wod.profit_ctr_ID = wom.profit_ctr_ID
--	AND wod.workorder_ID = wom.workorder_ID
--	AND wod.manifest = wom.manifest
--	AND wod.resource_type = 'D'
--	AND wod.bill_rate >= -1	
--INNER JOIN WorkOrderDetailUnit wodu
--	ON wodu.company_id = wod.company_id
--	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
--	AND wodu.workorder_id = wod.workorder_ID
--	AND wodu.sequence_id = wod.sequence_ID
--	AND wodu.manifest_flag = 'T'
--JOIN transporter t
--	ON t.transporter_EPA_ID = @EPA_ID
--	AND t.eq_flag = 'T'
--INNER JOIN WorkOrderTransporter wot1
--	ON wot1.company_id = wom.company_id
--	AND wot1.profit_ctr_id = wom.profit_ctr_ID
--	AND wot1.workorder_id = wom.workorder_ID
--	AND wot1.manifest = wom.manifest
--	AND wot1.transporter_code = t.transporter_code
--	AND wot1.transporter_sequence_id = 1
--JOIN workorderheader woh
--	ON woh.company_id = wom.company_id
--	AND woh.profit_ctr_ID = wom.profit_ctr_ID
--	AND woh.workorder_ID = wom.workorder_ID
--	AND woh.start_date BETWEEN @date_from AND @date_to
--	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
--	AND woh.workorder_status = 'A'
--	AND woh.submitted_flag = 'T'
--JOIN tsdfapproval ta
--	ON ta.company_id = wod.company_id
--	AND ta.profit_ctr_id = wod.profit_ctr_ID
--	AND ta.TSDF_approval_id = wod.TSDF_approval_id
--	AND ta.TSDF_approval_status = 'A'
--JOIN tsdfapprovalprice tap
--	ON tap.company_id = wod.company_id
--	AND tap.profit_ctr_id = wod.profit_ctr_ID
--	AND tap.TSDF_approval_id = wod.TSDF_approval_id
--	AND tap.record_type = 'R'
--JOIN resourceclass rc
--	ON rc.company_id = tap.company_id
--	AND rc.profit_ctr_id = tap.profit_ctr_ID
--	AND rc.resource_class_code = tap.resource_class_code
--	AND rc.bill_unit_code = tap.bill_unit_code
--	AND rc.resource_class_code IN ('FEERIHW', 'FEERI')
--JOIN billunit b
--	ON b.bill_unit_code = tap.bill_unit_code
--JOIN generator g
--	ON g.generator_id = ta.generator_id
--	AND g.generator_state = 'RI'
--JOIN TSDF
--	ON TSDF.TSDF_code = wod.tsdf_code
--	AND ISNULL(TSDF.eq_flag,'F') = 'F'
--WHERE wom.manifest BETWEEN @manifest_from AND @manifest_to
	
-- eq tsdf use profiles
-- eq tsdf
union
SELECT DISTINCT 
	wom.workorder_id
,	wom.company_id
,	wom.profit_ctr_id
,	wom.manifest
,	t.transporter_code
,	t.Transporter_EPA_ID
,	@ri_license_num AS ri_license_num
--,	wod.quantity_used
--,	wod.bill_unit_code
--,	wodu.quantity AS manifest_quantity
--,	wodu.bill_unit_code AS manifest_unit
,	wodub.quantity
,	wodub.bill_unit_code
--,	wodum.quantity AS manifest_quantity
,	manifest_quantity = CASE WHEN ISNULL(wodum.quantity, 0) > 0 AND ISNULL(wodum.quantity, 0) < 1 THEN 1 ELSE ROUND(ISNULL(wodum.quantity, 0), 0) END
,	wodum.bill_unit_code AS manifest_unit
--,	CASE LEN(wod.manifest_unit) WHEN 1 THEN (SELECT bill_unit_code FROM BillUnit WHERE manifest_unit = wod.manifest_unit)
--								ELSE wod.manifest_unit
--	END AS manifest_unit
--,	p.customer_id									-- Should use the customer from the work order
,	woh.customer_id
,	TSDF_code = (SELECT MIN(tsdf_code) 
		FROM TSDF 
		WHERE eq_company = wod.profile_company_id 
		AND eq_profit_ctr = wod.profile_profit_ctr_id 
		AND eq_flag = 'T'
		)
--,	pa.approval_code								-- Should use the approval from the work order
,	wod.TSDF_approval_code
,	wod.waste_stream
,	g.generator_id
,	g.EPA_ID
--,	w.display_name as waste_code
,	'' AS waste_code
,	b.pound_conv
--,	1 AS subject_to_fee
--,	CASE pqd.fee_exempt_flag WHEN 'T' THEN 0 ELSE 1 END AS subject_to_fee
,	subject_to_fee = ISNULL((SELECT CASE pqd.fee_exempt_flag WHEN 'T' THEN 0 ELSE 1 END
		FROM ProfileQuoteDetail pqd
		WHERE pqd.profile_id = wod.profile_id
		AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
		AND pqd.company_id = wod.profile_company_id 
		AND pqd.record_type = 'R'
		AND pqd.resource_class_code IN ('FEERIHW', 'FEERI')
		), 1)
,	@fee_gal AS fee_gal
,	@fee_lb AS fee_lb
,	@fee_ton AS fee_ton
,	@fee_ton_metric AS fee_ton_metric
,	@fee_liter AS fee_liter
,	@fee_cubic_yard AS fee_cubic_yard
,	@fee_cubic_meter AS fee_cubic_meter
,	@fee_kg AS fee_kg
,	@pound_conv_gal AS pound_conv_gal
,	@pound_conv_lb AS pound_conv_lb
,	@pound_conv_ton AS pound_conv_ton
,	@pound_conv_ton_metric AS pound_conv_ton_metric
,	@gal_conv_liter AS gal_conv_liter
,	@gal_conv_cubic_yard AS pound_conv_cubic_yard
,	@gal_conv_cubic_meter AS pound_conv_cubic_meter
,	@pound_conv_kg AS pound_conv_kg
,	g.generator_name
,	'P' as approval_type
--,	pa.company_id AS approval_company				-- Should use the profile company ID from the work order
,	wod.profile_company_id AS approval_company
--,	pa.profile_id									-- Should use the profile from the work order
,	wod.profile_id
,	wod.manifest_line
,	wod.sequence_ID
FROM workordermanifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1	
INNER JOIN WorkOrderDetailUnit wodum
	ON wodum.company_id = wod.company_id
	AND wodum.profit_ctr_ID = wod.profit_ctr_ID
	AND wodum.workorder_id = wod.workorder_ID
	AND wodum.sequence_id = wod.sequence_ID
	AND wodum.manifest_flag = 'T'
INNER JOIN WorkOrderDetailUnit wodub
	ON wodub.company_id = wod.company_id
	AND wodub.profit_ctr_ID = wod.profit_ctr_ID
	AND wodub.workorder_id = wod.workorder_ID
	AND wodub.sequence_id = wod.sequence_ID
	AND wodub.billing_flag = 'T'
INNER JOIN WorkOrderHeader woh 
	ON woh.company_id = wom.company_id
	AND woh.profit_ctr_ID = wom.profit_ctr_ID
	AND woh.workorder_ID = wom.workorder_ID
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
--INNER JOIN ProfileQuoteApproval pa 
--	ON wod.profile_id = pa.profile_id
--	AND wod.profile_profit_ctr_id = pa.profit_ctr_id
--	AND wod.profile_company_id = pa.company_id
--INNER JOIN Profile p 
--	ON p.profile_id = pa.profile_id
--	AND p.curr_status_code = 'A'
--LEFT OUTER JOIN wastecode w
--	ON w.waste_code_uid = p.waste_code_uid
--LEFT OUTER JOIN ProfileQuoteDetail pqd 
--	ON pqd.company_id = wod.profile_company_id
--	AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
--	AND pqd.profile_id = wod.profile_id
--	AND pqd.record_type = 'R'
--LEFT OUTER JOIN ResourceClass rc 
--	ON rc.resource_class_code = pqd.resource_class_code
--	AND rc.bill_unit_code = pqd.bill_unit_code
--	AND rc.company_id = wom.company_id
--	AND rc.profit_ctr_id = wom.profit_ctr_ID
--	--AND rc.company_id = pqd.resource_class_company_id
--	AND rc.resource_class_code IN ('FEERIHW', 'FEERI')
--INNER JOIN BillUnit b 
--	ON b.bill_unit_code = pqd.bill_unit_code
INNER JOIN BillUnit b
	ON b.bill_unit_code = wodum.bill_unit_code
JOIN transporter t
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN Generator g 
	ON g.generator_id = woh.generator_id
	AND g.generator_state = 'RI'
INNER JOIN TSDF 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag,'F') = 'T'
WHERE wom.manifest BETWEEN @manifest_from AND @manifest_to
AND wom.manifest_flag = 'T'
		
--UNION

--SELECT DISTINCT 
--	wom.workorder_id
--,	wom.company_id
--,	wom.profit_ctr_id
--,	wom.manifest
--,	wot1.transporter_code
--,	t.Transporter_EPA_ID
--,	@ri_license_num AS ma_license_num
--,	wod.quantity_used
--,	wod.bill_unit_code
--,	wodu.quantity AS manifest_quantity
--,	wodu.bill_unit_code AS manifest_unit
----,	CASE LEN(wod.manifest_unit) WHEN 1 THEN (SELECT bill_unit_code FROM BillUnit WHERE manifest_unit = wod.manifest_unit)
----								ELSE wod.manifest_unit
----	END AS manifest_unit
--,	p.customer_id
--,	TSDF_code = (select min(tsdf_code) from TSDF where eq_company = wod.profile_company_id and eq_profit_ctr = wod.profile_profit_ctr_id and eq_flag = 'T')
--,	pa.approval_code
--,	wod.waste_stream
--,	g.generator_id
--,	g.EPA_ID
--,	p.waste_code
--,	b.pound_conv
--,	0 AS subject_to_fee
--,	@fee_gal AS fee_gal
--,	@fee_lb AS fee_lb
--,	@fee_ton AS fee_ton
--,	@fee_ton_metric AS fee_ton_metric
--,	@fee_liter AS fee_liter
--,	@fee_cubic_yard AS fee_cubic_yard
--,	@fee_cubic_meter AS fee_cubic_meter
--,	@fee_kg AS fee_kg
--,	@pound_conv_gal AS pound_conv_gal
--,	@pound_conv_lb AS pound_conv_lb
--,	@pound_conv_ton AS pound_conv_ton
--,	@pound_conv_ton_metric AS pound_conv_ton_metric
--,	@gal_conv_liter AS gal_conv_liter
--,	@gal_conv_cubic_yard AS pound_conv_cubic_yard
--,	@gal_conv_cubic_meter AS pound_conv_cubic_meter
--,	@pound_conv_kg AS pound_conv_kg
--,	g.generator_name
--,	'P' as approval_type
--,	pa.company_id as approval_company
--,	pa.profile_id
--FROM workordermanifest wom
--INNER JOIN WorkOrderDetail wod 
--	ON wod.workorder_ID = wom.workorder_ID
--	AND wod.company_id = wom.company_id
--	AND wod.profit_ctr_ID = wom.profit_ctr_ID
--	AND wod.manifest = wom.manifest
--	AND wod.resource_type = 'D'
--	AND wod.bill_rate >= -1	
--INNER JOIN WorkOrderDetailUnit wodu
--	ON wodu.company_id = wod.company_id
--	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
--	AND wodu.workorder_id = wod.workorder_ID
--	AND wodu.sequence_id = wod.sequence_ID
--	AND wodu.manifest_flag = 'T'
--JOIN transporter t
--	ON t.transporter_EPA_ID = @EPA_ID
--	AND t.eq_flag = 'T'
--INNER JOIN WorkOrderTransporter wot1
--	ON wot1.company_id = wom.company_id
--	AND wot1.profit_ctr_id = wom.profit_ctr_ID
--	AND wot1.workorder_id = wom.workorder_ID
--	AND wot1.manifest = wom.manifest
--	AND wot1.transporter_code = t.transporter_code
--	AND wot1.transporter_sequence_id = 1
--INNER JOIN WorkOrderHeader woh 
--	ON woh.company_id = wom.company_id
--	AND woh.profit_ctr_ID = wom.profit_ctr_ID
--	AND woh.workorder_ID = wom.workorder_ID
--	AND woh.workorder_status = 'A'
--	AND woh.submitted_flag = 'T'
--	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
--	AND woh.start_date BETWEEN @date_from AND @date_to
--INNER JOIN ProfileQuoteDetail pqd 
--	ON pqd.company_id = wod.profile_company_id
--	AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
--	AND pqd.profile_id = wod.profile_id
--	AND pqd.record_type = 'R'
--INNER JOIN ProfileQuoteApproval pa 
--	ON pqd.profile_id = pa.profile_id
--	AND pqd.profit_ctr_id = pa.profit_ctr_id
--	AND pqd.company_id = pa.company_id
--INNER JOIN Profile p 
--	ON p.profile_id =pa.profile_id
--	AND p.curr_status_code = 'A'
--INNER JOIN ResourceClass rc 
--	ON rc.resource_class_code = pqd.resource_class_code
--	AND rc.bill_unit_code = pqd.bill_unit_code
--	--AND rc.company_id = wom.company_id
--	--AND rc.profit_ctr_id = wom.profit_ctr_ID
--	AND rc.company_id = pqd.resource_class_company_id
--	AND rc.resource_class_code IN ('FEERIHW', 'FEERI')
--INNER JOIN BillUnit b 
--	ON b.bill_unit_code = pqd.bill_unit_code
--INNER JOIN Generator g 
--	ON g.generator_id = woh.generator_id
--	AND g.generator_state = 'RI'
--INNER JOIN TSDF 
--	ON TSDF.TSDF_code = wod.TSDF_code
--	AND ISNULL(TSDF.eq_flag,'F') = 'T'
--WHERE wom.manifest BETWEEN @manifest_from AND @manifest_to
ORDER BY subject_to_fee, g.generator_id, wom.manifest, wod.tsdf_code


-- Do this insert only because the datawindow is expecting records where subject_to_fee is zero for ALL records
INSERT INTO #tmp
SELECT workorder_id
,	company_id
,	profit_ctr_id
,	manifest
,	transporter_code
,	transporter_EPA_ID
,	ri_license_num
,	quantity
,	bill_unit_code
,	manifest_quantity
,	manifest_unit
,	customer_id
,	TSDF_code
,	TSDF_approval_code
,	waste_stream
,	generator_id
,	EPA_ID
--,	waste_code
,	'' AS waste_code
,	pound_conv
,	0
,	fee_gal
,	fee_lb
,	fee_ton
,	fee_ton_metric
,	fee_liter
,	fee_cubic_yard
,	fee_cubic_meter
,	fee_kg
,	pound_conv_gal
,	pound_conv_lb
,	pound_conv_ton
,	pound_conv_ton_metric
,	gal_conv_liter
,	pound_conv_cubic_yard
,	pound_conv_cubic_meter
,	pound_conv_kg
,	generator_name
,	approval_type
,	approval_company
,	tsdf_approval_id
,	manifest_line
,	sequence_ID
FROM #tmp
WHERE subject_to_fee = 1

SELECT workorder_id
,	company_id
,	profit_ctr_id
,	manifest
,	transporter_code
,	transporter_EPA_ID
,	ri_license_num
,	quantity
,	bill_unit_code
,	manifest_quantity
,	manifest_unit
,	customer_id
,	TSDF_code
,	TSDF_approval_code
,	waste_stream
,	generator_id
,	EPA_ID
--,	waste_code
,	'' AS waste_code
,	pound_conv
,	subject_to_fee
,	fee_gal
,	fee_lb
,	fee_ton
,	fee_ton_metric
,	fee_liter
,	fee_cubic_yard
,	fee_cubic_meter
,	fee_kg
,	pound_conv_gal
,	pound_conv_lb
,	pound_conv_ton
,	pound_conv_ton_metric
,	gal_conv_liter
,	pound_conv_cubic_yard
,	pound_conv_cubic_meter
,	pound_conv_kg
,	generator_name
,	approval_type
,	approval_company
,	tsdf_approval_id
,	manifest_line
,	sequence_ID
FROM #tmp

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_ri] TO [EQAI]
    AS [dbo];

