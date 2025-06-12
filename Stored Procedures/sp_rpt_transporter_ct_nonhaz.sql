CREATE PROCEDURE sp_rpt_transporter_ct_nonhaz 
	@date_from		datetime
,	@date_to		datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@EPA_ID			varchar(15)
AS
/***********************************************************************
Non-Hazardous Waste Transporter Report - Connecticut

Filename:	L:\Apps\SQL\EQAI\sp_rpt_transporter_ct_nonhaz.sql
PB Object(s):	r_transporter_ct_nonhaz (filtered to show only workorder_status = 'X')
		r_transporter_ct_nonhaz_worksheet

03/08/2005 JDB	Created
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
08/10/2006 RG   revised for changes in tsdfapproval and profile
11/14/2007 RG   revised for work order submitted flag 
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
07/16/2010 KAM  Updated teh select to not included voided workorderdetail rows
11/09/2010 SK	Modified to run on Plt_AI, can be run for the whole facility, particular facility or all companies
				moved to Plt_AI
02/04/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Result set changed to not return company/profit center name
				Changed to run by user selected EPA ID
				Changed to fetch StateLicenseCode from new table: TransporterStateLicense
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter_code
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.	
03/04/2011 SK	Added join from WorkOrderTransporter to Transporter based on transporter_code
	
sp_rpt_transporter_ct_nonhaz '01/1/2014', '03/15/2014', 1, 999999, '0', 'zzzz', 'MAD084814136'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @ct_hw_num	int

SET @ct_hw_num = 30

SELECT DISTINCT 
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' THEN 'X' ELSE woh.workorder_status END AS workorder_status,
	ta.customer_id,
	wom.manifest,
	ta.TSDF_approval_code,
	ta.waste_stream,
	wod.bill_unit_code,
	@ct_hw_num AS ct_hw_num,
	wot1.transporter_code,
	t.transporter_EPA_ID,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	transporter_city_state_zip = ISNULL(t.Transporter_city, '') + ', '  + ISNULL(t.Transporter_state, '') + '  ' + ISNULL(t.Transporter_zip_code, ''),
	woh.start_date,
	ta.generator_id,
	g.EPA_ID,
	g.generator_name,
	g.generator_address_1,
	g.generator_address_2,
	g.generator_address_3,
	g.generator_address_4,
	generator_city_state_zip = ISNULL(g.generator_city, '') + ', '  + ISNULL(g.generator_state, '') + '  ' + ISNULL(g.generator_zip_code, ''),
	DOT_shipping_name = ISNULL(ta.DOT_shipping_name, '') + CASE WHEN ta.hazmat = 'T' THEN ', ' + ISNULL(ta.hazmat_class, '') ELSE '' END
						+ CASE WHEN ta.hazmat = 'T' THEN ', ' + ISNULL(ta.UN_NA_flag, '') + ISNULL(right('0000' + CONVERT(varchar(4), ta.UN_NA_number),4), '') ELSE '' END
						+ CASE WHEN ta.hazmat = 'T' THEN ', ' + 'PG' + ISNULL(ta.package_group, '') ELSE '' END,
	ta.waste_desc,
	wc.display_name AS waste_code,
	IsNull(wodu.quantity, 0) AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	wod.TSDF_code,
	TSDF.TSDF_name,
	TSDF.TSDF_addr1,
	TSDF.TSDF_addr2,
	TSDF.TSDF_addr3,
	TSDF_city_state_zip = ISNULL(TSDF.TSDF_city, '') + ', '  + ISNULL(TSDF.TSDF_state, '') + '  ' + ISNULL(TSDF.TSDF_zip_code, '')
FROM workordermanifest wom
JOIN workorderdetail wod
	ON wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.workorder_ID = wom.workorder_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
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
JOIN workorderheader woh
	ON woh.company_id = wod.company_id
	AND woh.profit_ctr_ID = wod.profit_ctr_ID
	AND woh.workorder_ID = wod.workorder_ID
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
	AND woh.workorder_status IN ('N', 'C', 'A')
JOIN tsdfapproval ta
	ON ta.company_id = wod.company_id
	AND ta.profit_ctr_id = wod.profit_ctr_ID
	AND ta.TSDF_approval_id = wod.TSDF_approval_id
	AND ta.TSDF_approval_status = 'A'
JOIN generator g
	ON g.generator_id = ta.generator_id
JOIN TSDF
	ON TSDF.TSDF_code = wod.tsdf_code
	AND ISNULL(TSDF.eq_flag,'F') = 'F'
JOIN WasteCode wc
	ON wc.waste_code_uid = ta.waste_code_uid
	AND wc.waste_code_origin <> 'F'
	AND wc.waste_code <> 'NONE'
WHERE wom.manifest BETWEEN @manifest_from AND @manifest_to
	AND (TSDF.TSDF_state = 'CT' OR g.generator_state = 'CT')

UNION

SELECT DISTINCT 
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' THEN 'X' ELSE woh.workorder_status END AS workorder_status, 
	p.customer_id,
	wom.manifest,
	pa.approval_code,
	wod.waste_stream,
	wod.bill_unit_code,
	@ct_hw_num AS ct_hw_num,
	wot1.transporter_code,
	t.transporter_EPA_ID,
	t.Transporter_name,
	t.Transporter_addr1,
	t.Transporter_addr2,
	transporter_city_state_zip = ISNULL(t.Transporter_city, '') + ', '  + ISNULL(t.Transporter_state, '') + '  ' + ISNULL(t.Transporter_zip_code, ''),
	woh.start_date,
	g.generator_id,
	g.EPA_ID,
	g.generator_name,
	g.generator_address_1,
	g.generator_address_2,
	g.generator_address_3,
	g.generator_address_4,
	generator_city_state_zip = ISNULL(g.generator_city, '') + ', '  + ISNULL(g.generator_state, '') + '  ' + ISNULL(g.generator_zip_code, ''),
	DOT_shipping_name = ISNULL(p.DOT_shipping_name, '')	+ CASE WHEN p.hazmat = 'T' THEN ', ' + ISNULL(p.hazmat_class, '') ELSE '' END
						+ CASE WHEN p.hazmat = 'T' THEN ', ' + ISNULL(p.UN_NA_flag, '') + ISNULL(right('0000' + CONVERT(varchar(4), p.UN_NA_number),4), '') ELSE '' END
						+ CASE WHEN p.hazmat = 'T' THEN ', ' + 'PG' + ISNULL(p.package_group, '') ELSE '' END,
	p.approval_desc,
	wc.display_name AS waste_code,
	IsNull(wodu.quantity, 0) AS manifest_quantity,
	wodu.bill_unit_code AS manifest_unit,
	wod.TSDF_code,
	TSDF.TSDF_name,
	TSDF.TSDF_addr1,
	TSDF.TSDF_addr2,
	TSDF.TSDF_addr3,
	TSDF_city_state_zip = ISNULL(TSDF.TSDF_city, '') + ', '  + ISNULL(TSDF.TSDF_state, '') + '  ' + ISNULL(TSDF.TSDF_zip_code, '')
FROM workordermanifest wom
JOIN workorderdetail wod	
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
	ON woh.workorder_ID = wod.workorder_ID
	AND woh.profit_ctr_ID = wod.profit_ctr_ID
	AND woh.company_id = wod.company_id
	AND woh.workorder_status IN ('N', 'C', 'A')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN ProfileQuoteApproval pa 
	ON pa.company_id = wod.profile_company_id
	AND pa.profit_ctr_id = wod.profile_profit_ctr_id
	AND pa.profile_id = wod.profile_id
INNER JOIN Profile p 
	ON p.profile_id = pa.profile_id
	AND p.curr_status_code = 'A'
INNER JOIN Generator g 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag,'F') = 'T'
INNER JOIN WasteCode wc 
	ON wc.waste_code_uid = p.waste_code_uid
	AND wc.waste_code_origin <> 'F'
	AND wc.waste_code <> 'NONE'
WHERE (TSDF.TSDF_state = 'CT' OR g.generator_state = 'CT')
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
ORDER BY woh.start_date

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_ct_nonhaz] TO [EQAI]
    AS [dbo];

