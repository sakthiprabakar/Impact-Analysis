drop PROCEDURE if exists sp_rpt_transporter_fee_me_oil
go

CREATE PROCEDURE sp_rpt_transporter_fee_me_oil 
	@date_from		datetime
,	@date_to		datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@EPA_ID			varchar(15)
AS
/***********************************************************************
Waste Oil Fee Report - Maine

Filename:	L:\Apps\SQL\EQAI\sp_rpt_transporter_fee_me_oil.sql
PB Object(s):	r_transporter_fee_me_oil

12/15/2004 JDB	Created
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
08/10/2006 RG   revised for changes in tsdfapproval and profie
11/12/2007 RG   revised for workorder status.  submited workorders are now status of A
                and submitted-flag of T
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
05/11/2009 JDB	Added ERG_suffix
04/07/2010 RJG	Added join criterias to WorkOrderDetail: 
				1) wod.bill_unit_code = rc.bill_unit_code
				2) wod.profit_ctr_id = rc.profit_ctr_id
04/28/2010 JDB	Fixed join from 4/7/10 on ResourceClass. 
07/16/2010 KAM  Updated the SQl to not include voided workorderdetail Rows
07/16/2010 KAM	Updated to get the transporter from the transporterstatelicense table
02/08/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Added company_id to the resultset, Formatted Queries to use ANSI joins
				Changed to run by user selected EPA ID & not transporter code
				--TO DO : Remove resource class category and used resource class code in Joins
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter_code
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.
03/03/2011 SK	Added join from WorkOrderTransporter to Transporter based on transporter_code
08/21/2013 SM	Added wastecode table and displaying Display name
05/06/2022 AGC  DevOps 41879 changed the gallons calculation and the BillUnit join
04/13/2023 UG   DevOps 42099 Added the columns from the Generator table ( generator_site_address[which is actually a concatenation of generator_address_1 to 5] , generator_city, generator_state and generator_zip_code ) by replacing the gen_mail_addr1 to 5

	
sp_rpt_transporter_fee_me_oil '1/1/2010', '3/31/2010', 1, 999999, '0', 'zzz', 'MAD084814136'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--Select @transporter_code = IsNull(transporter_code,'XXX') from TransporterStateLicense where State = 'ME'

SELECT DISTINCT 
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wod.manifest_page_num,
	wod.manifest_line_id,
	wot1.transporter_code,
	transporter_receive_date = ISNULL(wot1.transporter_sign_date, woh.start_date),
	g.EPA_ID AS generator_EPA_ID,
	g.generator_name,
	generator_address_1 = ISNULL(g.generator_address_1, ''),
	generator_address_2 = ISNULL(g.generator_address_2, ''),
	generator_address_3 = ISNULL(g.generator_address_3, ''),
	generator_address_4 = ISNULL(g.generator_address_4, ''),
	generator_address_5 = ISNULL(g.generator_address_5, ''),
	g.generator_city,
	g.generator_state,
	g.generator_zip_code,
	t.TSDF_EPA_ID,
	t.TSDF_name,
	t.TSDF_addr1,
	t.TSDF_addr2,
	t.TSDF_addr3,
	t.TSDF_city,
	t.TSDF_state,
	t.TSDF_zip_code,
	ta.customer_id,
	wod.TSDF_code,
	ta.TSDF_approval_code,
	ta.waste_stream,
	wastecode.display_name as waste_code,
	DOT_shipping_name = ISNULL(ta.DOT_shipping_name, ''),
	hazmat = ISNULL(ta.hazmat, ''),
	hazmat_class = ISNULL(ta.hazmat_class, ''),
	UN_NA_formatted = dbo.fn_un_na_number(ta.UN_NA_flag, ta.UN_NA_number),
	package_group = ISNULL(ta.package_group, ''),
	reportable_quantity_flag = ISNULL(ta.reportable_quantity_flag, ''),
	RQ_reason = ISNULL(ta.RQ_reason, ''),
	ERG_number = ISNULL(ta.ERG_number, 0),
	ERG_suffix = ISNULL(ta.ERG_suffix, ''),
	waste_desc = ISNULL(ta.waste_desc, ''),
	wodu.quantity as quantity_used, --wod.quantity_used,
	wodu.bill_unit_code, --wod.bill_unit_code,
	wodu.quantity AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	b.gal_conv,
	--ISNULL(wod.quantity_used * b.gal_conv, 0) AS gallons
	ISNULL(wodu.quantity * b.gal_conv, 0) AS gallons
FROM WorkorderHeader woh
JOIN WorkorderDetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
JOIN WorkorderManifest wom
	ON wom.company_id = wod.company_id
	AND wom.profit_ctr_ID = wod.profit_ctr_ID
	AND wom.workorder_ID = wod.workorder_ID
	AND wom.manifest = wod.manifest
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
JOIN Transporter tr
	ON tr.eq_flag = 'T'
	AND tr.Transporter_EPA_ID = @EPA_ID
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = tr.transporter_code
	AND wot1.transporter_sequence_id = 1
JOIN TSDF t
	ON t.TSDF_code = wod.TSDF_code
	AND ISNULL(t.eq_flag,'F') = 'F'
JOIN TSDFApproval ta
	ON ta.company_id = wod.company_id
	AND ta.profit_ctr_id = wod.profit_ctr_id
	AND ta.TSDF_approval_id = wod.TSDF_approval_id
	AND ta.TSDF_approval_status = 'A'
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = ta.waste_code_uid
JOIN TSDFApprovalPrice tap
	ON tap.company_id = ta.company_id
	AND tap.profit_ctr_id = ta.profit_ctr_id
	AND tap.TSDF_approval_id = ta.TSDF_approval_id
	AND tap.record_type = 'R'
JOIN ResourceClass rc
	ON rc.company_id = wod.company_id
	AND rc.profit_ctr_id = wod.profit_ctr_ID
	AND rc.bill_unit_code = wod.bill_unit_code
	AND rc.resource_class_code = tap.resource_class_code
	AND rc.bill_unit_code = tap.bill_unit_code
	AND rc.category = 'MEOILFEE'
	--AND rc.resource_class_code = ''
JOIN Billunit b
	--ON b.bill_unit_code = tap.bill_unit_code
	ON b.bill_unit_code = wodu.bill_unit_code
JOIN Generator g
	ON g.generator_id = ta.generator_id
WHERE woh.workorder_status = 'A'
	AND woh.submitted_flag = 'T'
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
	-- AND wom.transporter_code_1 = @transporter_code

UNION
	
SELECT DISTINCT 
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wod.manifest_page_num,
	wod.manifest_line_id,
	wot1.transporter_code,
	transporter_receive_date = ISNULL(wot1.transporter_sign_date, woh.start_date),
	g.EPA_ID AS generator_EPA_ID,
	g.generator_name,
	generator_address_1 = ISNULL(g.generator_address_1, ''),
	generator_address_2 = ISNULL(g.generator_address_2, ''),
	generator_address_3 = ISNULL(g.generator_address_3, ''),
	generator_address_4 = ISNULL(g.generator_address_4, ''),
	generator_address_5 = ISNULL(g.generator_address_5, ''),
	g.generator_city,
	g.generator_state,
	g.generator_zip_code,
	t.TSDF_EPA_ID,
	t.TSDF_name,
	t.TSDF_addr1,
	t.TSDF_addr2,
	t.TSDF_addr3,
	t.TSDF_city,
	t.TSDF_state,
	t.TSDF_zip_code,
	p.customer_id,
	wod.TSDF_code,
	pa.approval_code,
	wod.waste_stream,
	wastecode.display_name as waste_code,
	DOT_shipping_name = ISNULL(p.DOT_shipping_name, ''),
	hazmat = ISNULL(p.hazmat, ''),
	hazmat_class = ISNULL(p.hazmat_class, ''),
	UN_NA_formatted = dbo.fn_un_na_number(p.UN_NA_flag, p.UN_NA_number),
	package_group = ISNULL(p.package_group, ''),
	reportable_quantity_flag = ISNULL(p.reportable_quantity_flag, ''),
	RQ_reason = ISNULL(p.RQ_reason, ''),
	ERG_number = ISNULL(p.ERG_number, 0),
	ERG_suffix = ISNULL(p.ERG_suffix, ''),
	waste_desc = ISNULL(p.approval_desc, ''),
	wodu.quantity as quantity_used, --wod.quantity_used,
	wodu.bill_unit_code, --wod.bill_unit_code,
	wodu.quantity AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	b.gal_conv,
	--ISNULL(wod.quantity_used * b.gal_conv, 0) AS gallons
	ISNULL(wodu.quantity * b.gal_conv, 0) AS gallons
FROM WorkOrderManifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.manifest = wom.manifest
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
INNER JOIN Transporter tr
	ON tr.transporter_EPA_ID = @EPA_ID
	AND tr.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = tr.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN WorkOrderHeader woh 
	ON woh.workorder_ID = wod.workorder_ID
	AND woh.company_id = wod.company_id
	AND woh.profit_ctr_ID = wod.profit_ctr_ID
	AND woh.workorder_status = 'A'
	AND woh.submitted_flag = 'T'
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN ProfileQuoteDetail pqd 
	ON pqd.company_id = wod.profile_company_id 
	AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
	AND pqd.profile_id = wod.profile_id
	AND pqd.record_type = 'R'
INNER JOIN ProfileQuoteApproval pa 
	ON pa.profile_id = pqd.profile_id
	AND pa.profit_ctr_id = pqd.profit_ctr_id
	AND pa.company_id = pqd.company_id
INNER JOIN Profile p 
	ON p.profile_id = pa.profile_id
	AND p.curr_status_code = 'A'
LEFT OUTER JOIN wastecode
	ON wastecode.waste_code_uid = p.waste_code_uid
INNER JOIN ResourceClass rc 
	ON rc.resource_class_code = pqd.resource_class_code
	AND rc.bill_unit_code = pqd.bill_unit_code
	AND rc.category = 'MEOILFEE'
	--AND rc.resource_class_code = ''
INNER JOIN BillUnit b 
	--ON b.bill_unit_code = pqd.bill_unit_code
	ON b.bill_unit_code = wodu.bill_unit_code
INNER JOIN Generator g 
	ON g.generator_id = woh.generator_id
INNER JOIN TSDF t 
	ON t.TSDF_code = wod.TSDF_code
	AND ISNULL(t.eq_flag,'F') = 'T'
WHERE 1=1
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
	--AND wom.transporter_code_1 = @transporter_code
ORDER BY g.EPA_ID, wod.tsdf_code, wom.manifest, wod.manifest_line_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_me_oil] TO [EQAI];

GO
