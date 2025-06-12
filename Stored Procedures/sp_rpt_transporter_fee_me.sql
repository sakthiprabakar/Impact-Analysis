CREATE PROCEDURE sp_rpt_transporter_fee_me 
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
Hazardous Waste Transporter Fee Report - Maine

PB Object(s):	r_transporter_fee_me
				r_transporter_fee_me_worksheet
				r_transporter_fee_me_sec_1-4
				r_transporter_fee_me_sec_5

12/15/2004 JDB	Created
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/27/2005 JDB	Changed to use #tmp table, so that we could update the
				bill unit conversion for each unit from the list Don Johnson sent.
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
06/16/2006 JDB	Replaced TSDFApprovalDetail with TSDFApprovalPrice
				for the Central Customer Service Project
08/10/2006 RG	Revised for changes in profile and tsdf
11/10/2006 MK	Removed join wod.TSDF_approval_bill_unit_code = ta.bill_unit_code
11/29/2006 MK	Added wod.manifest_line to selects to make sure disposal lines are 
				not removed due to identical information (distinct, union)
10/08/2007 RG   Revised for new Maine requirements (generator city,state)
11/12/2007 RG   Revised for workorder status.  Submitted workorders are now status of A
                and submitted_flag of T
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
04/27/2009 JDB	Fixed bad join between WorkOrderDetail and BillUnit (it now joins
				properly on wod.manifest_unit = b.manifest_unit).  In July 2008
				we changed the drop-down on work order disposal to use real manifest
				units for the manifest unit field, but didn't update this SP.
04/07/2010 RJG	Added join criterias to WorkOrderDetail: 
				1) wod.bill_unit_code = rc.bill_unit_code
				2) wod.profit_ctr_id = rc.profit_ctr_id
04/28/2010 JDB	Fixed join from 4/7/10 on ResourceClass. 
05/13/2010 JDB	Fixed join again from 4/7/10 on ResourceClass. 
				Also updated to use generators or facilities from Maine.  (Gemini 14353)
07/16/2010 KAM  Updaed the select to not include voided workorderdetail rows
11/16/2010 SK	Moved to Plt_AI , replaced where clause with joins, return company_id, company_name, profit_ctr_name
				runs only for a valid company- profit center
02/04/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Result set changed to not return company/profit center name
				Changed to run by user selected EPA ID
				Changed to fetch StateLicenseCode from new table: TransporterStateLicense
				Replaced use of ResourceClass Category with resourceclass code.
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter_code
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.
03/03/2011 SK	Added join from WorkOrderTransporter to Transporter based on transporter_code
08/21/2013 SM	Added wastecode table and displaying Display name
10/29/2013 JDB	Removed the waste_code field from the result set.  It was coming from the Profile or TSDFApproval tables,
				which is the wrong source for this data.
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).
10/24/2023  Prakash DevOps 72791 - Commented the ResourceClass Join

sp_rpt_transporter_fee_me '1/1/2017', '4/30/2017', 1, 999999, '0', 'zzzz', 'MAD084814136', 'S'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@me_license_num		varchar(7),
	@fee_lb				money,
	@conv_lbs			float,
	@conv_tons			float,
	@conv_yard			float,
	@conv_kg			float,
	@conv_gal			float

--SET @me_license_num = 'HWT-029'
SELECT @me_license_num = state_license_code FROM TransporterStateLicense
 WHERE State = 'ME' AND EPA_ID = @EPA_ID

SET @fee_lb = 0.03

SET @conv_lbs = 1
SET @conv_tons = 2000
SET @conv_yard = 1686
SET @conv_kg = 2.205
SET @conv_gal = 8.3453

SELECT DISTINCT 
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wot1.transporter_code,
	t.Transporter_EPA_ID,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	@me_license_num AS me_license_num,
	c.phone AS phone,
	wod.quantity_used,
	wod.bill_unit_code,
	wodu.quantity AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	ta.customer_id,
	wod.TSDF_code,
	ta.TSDF_approval_code,
	ta.waste_stream,
	g.EPA_ID,
	g.generator_name,
	--w.display_name as waste_code,
	'' AS waste_code,
	b.pound_conv,
	(wodu.quantity * b.pound_conv) AS total_pounds,
	@fee_lb AS fee_lb,
	wod.manifest_line,
    g.generator_city, 
    g.generator_state
INTO	#tmp
FROM	WorkorderDetail wod
INNER JOIN WorkorderManifest wom 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.company_id = wom.company_id
	AND wod.manifest = wom.manifest
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
INNER JOIN Transporter t 
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN WorkorderHeader woh 
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.company_id = woh.company_id
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN TSDFApproval ta 
	ON wod.TSDF_approval_id = ta.TSDF_approval_id
	AND wod.profit_ctr_id = ta.profit_ctr_id
	AND wod.company_id = ta.company_id
	AND ta.TSDF_approval_status = 'A'
--LEFT OUTER JOIN wastecode w
--	ON w.waste_code_uid = ta.waste_code_uid
INNER JOIN TSDFApprovalPrice tap 
	ON tap.TSDF_approval_id = ta.TSDF_approval_id
	AND tap.company_id = ta.company_id
	AND tap.profit_ctr_id = ta.profit_ctr_id
	AND tap.record_type = 'R'
	AND tap.resource_class_code = 'FEEMETRANS'
/* -- Commented for #72791
INNER JOIN ResourceClass rc 
	ON tap.company_id = rc.company_id
	AND tap.profit_ctr_id = rc.profit_ctr_id
	AND tap.resource_class_code = rc.resource_class_code
	AND tap.bill_unit_code = rc.bill_unit_code
	--AND rc.category = 'MEHWTFEE'
	AND rc.resource_class_code = 'FEEMETRANS'*/
INNER JOIN Billunit b 
	ON wodu.bill_unit_code = b.bill_unit_code
INNER JOIN Generator g 
	ON ta.generator_id = g.generator_id
INNER JOIN TSDF 
	ON wod.tsdf_code = TSDF.tsdf_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'F'
INNER JOIN Company c
	ON c.company_id = wod.company_id
WHERE wod.resource_type = 'D'
	AND wod.bill_rate >= -1	
	AND (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')

UNION

SELECT DISTINCT	
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wot1.transporter_code,
	t.Transporter_EPA_ID,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	@me_license_num AS me_license_num,
	c.phone AS phone,
	wod.quantity_used,
	wod.bill_unit_code,
	wodu.quantity AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	p.customer_id,
	wod.TSDF_code,
	pa.approval_code,
	wod.waste_stream,
	g.EPA_ID,
	g.generator_name,
	--wastecode.display_name as waste_code,
	'' AS waste_code,
	b.pound_conv,
	(wodu.quantity * b.pound_conv) AS total_pounds,
	@fee_lb AS fee_lb,
	wod.manifest_line,
	g.generator_city, 
	g.generator_state
FROM WorkOrderManifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.company_id = wom.company_id
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1	
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
INNER JOIN Transporter t 
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN WorkOrderHeader woh 
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.company_id = woh.company_id
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN ProfileQuoteDetail pqd 
	ON wod.profile_company_id = pqd.company_id
	AND wod.profile_profit_ctr_id = pqd.profit_ctr_id
	AND wod.profile_id = pqd.profile_id
	AND pqd.record_type = 'R'
	AND pqd.resource_class_code = 'FEEMETRANS'
INNER JOIN ProfileQuoteApproval pa 
	ON pqd.profile_id = pa.profile_id
	AND pqd.profit_ctr_id = pa.profit_ctr_id
	AND pqd.company_id = pa.company_id	
INNER JOIN Profile p 
	ON pa.profile_id = p.profile_id
	AND p.curr_status_code = 'A'
--LEFT OUTER JOIN wastecode 
--	ON wastecode.waste_code_uid = p.waste_code_uid
/* -- Commented for #72791
INNER JOIN ResourceClass rc 
	ON pqd.resource_class_company_id = rc.company_id
	AND pqd.resource_class_code = rc.resource_class_code
	AND pqd.bill_unit_code = rc.bill_unit_code
	--AND rc.category = 'MEHWTFEE'
	AND rc.resource_class_code = 'FEEMETRANS'*/
INNER JOIN Billunit b 
	ON wodu.bill_unit_code = b.bill_unit_code
INNER JOIN Generator g 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND IsNull(TSDF.eq_flag,'F') = 'T'
INNER JOIN Company c
	ON c.company_id = wom.company_id
WHERE (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
ORDER BY g.EPA_ID, wom.manifest, wod.tsdf_code

UPDATE #tmp SET pound_conv = @conv_lbs, total_pounds = manifest_quantity * @conv_lbs 
WHERE manifest_unit IN ('LB', 'LBS') AND pound_conv <> @conv_lbs

UPDATE #tmp SET pound_conv = @conv_tons, total_pounds = manifest_quantity * @conv_tons 
WHERE manifest_unit IN ('TON', 'TONS') AND pound_conv <> @conv_tons

UPDATE #tmp SET pound_conv = @conv_yard, total_pounds = manifest_quantity * @conv_yard 
WHERE manifest_unit IN ('CYB', 'YARD') AND pound_conv <> @conv_yard

UPDATE #tmp SET pound_conv = @conv_kg, total_pounds = manifest_quantity * @conv_kg 
WHERE manifest_unit = 'KG' AND pound_conv <> @conv_kg

UPDATE #tmp SET pound_conv = @conv_gal, total_pounds = manifest_quantity * @conv_gal 
WHERE manifest_unit = 'GAL' AND pound_conv <> @conv_gal

SELECT * FROM #tmp

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_me] TO [EQAI]
    AS [dbo];

