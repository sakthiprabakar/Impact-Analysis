CREATE PROCEDURE sp_rpt_transporter_fee_pa 
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
Hazardous Waste Transporter Fee Report - Pennsylvania

PB Object(s):	r_transporter_fee_pa_summ, 
				r_transporter_fee_pa_detail,
				r_transporter_fee_pa_worksheet

07/21/2003 JDB	Created
11/11/2004 MK	Changed generator_code to generator_id
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
11/12/2007 RG   revised for workorder status.  submitted workorders are now 
				status of A and submitted-flag of T.
08/22/2008 JDB	In July 08 we modified the work order manifest unit drop-down to use manifest unit
				instead of bill unit, but we didn't convert the data.  Today this SP was modified
				to return the bill unit instead of the manifest unit, because the DWs are expecting it.
02/02/2009 JDB	Changed the Profile-Generator join on generator_id to a 
				WorkOrderHeader-Generator join because of the VARIOUS generator.
01/17/2010 JDB	Added (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA') to both WHERE clauses.  Because
				of the VARIOUS generators we're using, too many manifests were being reported.
				Also updated the first query in the UNION to use the new ANSI join syntax.
04/07/2010 RJG	Added join criterias to WorkOrderDetail: 
				1) wod.bill_unit_code = rc.bill_unit_code
				2) wod.profit_ctr_id = rc.profit_ctr_id
04/28/2010 JDB	Fixed join from 4/7/10 on ResourceClass. 
05/13/2010 JDB	Fixed join again from 4/7/10 on ResourceClass. 
07/13/2010 JDB	Updated to exclude Voided records.
				Added manifest_page_num to the list of fields selected and returned.
07/16/2010 KAM  Updated to get the transporter_code from the new TransporterStateLicense table.
07/19/2010 JDB	Added SELECTs in the Union for EQ Pennsylvania.
11/16/2010 SK	Moved to Plt_AI , replaced where clause with joins, return company_id
01/17/2011 JDB	Added ability to run this on 25-EQ Ohio as well by adding the work table to Plt_25_AI,
				and adding 25 to the IN clause.
02/07/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Result set changed to not return company/profit center name but only company-profit ctr id
				Changed to run by user selected EPA ID
				Changed to fetch StateLicenseCode from new table: TransporterStateLicense
				Replaced ResourceClass Category with resourceclass code
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter_code
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.
03/02/2011 SK	Removed JDB change from 01/17/2011
03/04/2011 SK	Added customer_name to the resultset
10/24/2012 DZ   GEM20964 In the second SELECT, changed the where clause for resource_class to ProfileQuoteApproval for better performance
08/21/2013 SM	Added wastecode table and displaying Display name
11/07/2013 JDB	Changed the waste_code field to use the results of the fn_workorder_waste_code_list function.  It was coming from the 
					Profile or TSDFApproval tables,	which is the wrong source for this data.
				Also removed the pound conversion factors from the result set, and instead changed it to return the tons directly from
					the stored procedure.  This required the creation of #tmp_pound_conv to store the conversion factors, and use in the join.
				Also changed the result set to round any tons that are between 0 and 0.1 up to 0.1, per Kenny Wenstrom.
				Also changed the actual quantity and unit to come from the WorkOrderDetailUnit table where billing_flag = 'T', instead
					of from WorkOrderDetail, which is obsolete for disposal lines.
				Also change the manifest unit to return the one-character unit (P, T, G, etc.) instead of the bill unit.
				Also changed several other fields in the result set so that they come from the work order instead of the profile or TSDF Approval.
				Also added work order end date to the result set (this is for use by the PA electronic report, not this one)
11/12/2013 JDB	Changed sort order of this SP to match the datawindow.  Also, this will help with the new PA electronic report,
					which needs this SP to sort by manifest then manifest line.
03/28/2014 JDB	Modified 3rd part of UNION (for EQ PA) that was referencing the WorkOrderDetail.quantity field for Other resources,
					and changed it to use WorkOrderDetail.quantity_used instead.  I am sure this was a copy/paste error from the changes in November.
08/18/2014 JDB	Added the entire select into a #tmp table, in order to be able to remove duplicates that appear in two of the parts of the UNION.
					For some transactions, they would be returned in both 1 and 3 or 2 and 3 of the UNION, which would look like duplicates.  Since
					part 3 of the UNION is the most accurate, if those exist we now delete the corresponding record from the #tmp table in parts 1 or 2.
				Modified 3rd part of UNION (for EQ PA) to use the receipt's manifest unit and quantity for the tons calculation, instead of the work order's.
					This is a significant change, but it is needed to address the issue where there are multiple lines on the disposal tab of the 
					work order (and therefore multiple lines on the corresponding receipt), but only one fee added to the Other tab of the work order.
					Before this change, this report would return the multiple lines of disposal, and they all had the same quantity from the work order fee.
				Also modified 3rd part of UNION (for EQ PA) to select only hazardous receipt lines (as in, contain at least one federal hazardous waste code)
				Also modified 3rd part of UNION (for EQ PA) to return the correct waste codes (it was sending in the work order information into the
					fn_receipt_waste_codes function instead of the receipt information).
10/08/2014 JDB	Modified 3rd part of UNION (for EQ PA) so that the join to TSDF used the receipt company's company and profit center (since we know this is
					for disposal to EQ facilities).  After the changes in August 2014 above, the query was joining the TSDF table to the WorkOrderDetail table
					but the WorkOrderDetail record was the Other charge, not the disposal.  Therefore many records were excluded from the report when they
					should have been included.
				Also added NOLOCK hints to the 1st and 2nd parts of the UNION.
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).

sp_rpt_transporter_fee_pa '7/1/2014', '7/1/2014', 1, 999999, '010335000JJK', '010335000JJK', 'PAD010154045'	-- 4 disposal lines with only 1 other line for FEEPATRT
sp_rpt_transporter_fee_pa '1/8/2014', '1/8/2014', 1, 999999, '010333467JJK', '010333467JJK', 'PAD010154045'	-- 1 line, but showing as 2 because both parts of union are picking it up
sp_rpt_transporter_fee_pa '1/20/2014', '1/20/2014', 1, 999999, '010334042JJK', '010334042JJK', 'PAD010154045'	-- 3 lines, 2 of which were non-hazardous
sp_rpt_transporter_fee_pa '1/20/2014', '1/31/2014', 1, 999999, '010334042JJK', '010334042JJK', 'PAD010154045'
sp_rpt_transporter_fee_pa '9/1/2013', '9/5/2013', 1, 999999, '0', 'zzz', 'MAD084814136'



EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/10/2014', 1, 999999, '0', 'zzzzzzzzzzzz', 'PAD010154045'

EXEC sp_rpt_transporter_fee_pa '1/8/2014', '1/8/2014', 1, 999999, '010333467JJK', '010333467JJK', 'PAD010154045'	-- 1 line, but showing as 2 because both parts of union are picking it up
EXEC sp_rpt_transporter_fee_pa '1/3/2014', '1/3/2014', 1, 999999, '010333425JJK', '010333425JJK', 'PAD010154045'	-- 4 disposal lines with only 1 other line for FEEPATRT
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010334119JJK', '010334119JJK', 'PAD010154045'	-- 1 line, but showing as 2 because both parts of union are picking it up
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010334128JJK', '010334128JJK', 'PAD010154045'	-- 1 line, but showing as 2 because both parts of union are picking it up
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '011040105JJK', '011040105JJK', 'PAD010154045'	-- User entered one manifest, but two fees, instead of both manifests

EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010333434JJK', '010333434JJK', 'PAD010154045'	-- 5 disposal lines with only 1 other line for FEEPATRT
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010333457JJK', '010333457JJK', 'PAD010154045'	-- 5 disposal lines with only 1 other line for FEEPATRT
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010333458JJK', '010333458JJK', 'PAD010154045'	-- 5 disposal lines with only 1 other line for FEEPATRT
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010333470JJK', '010333470JJK', 'PAD010154045'	-- 5 disposal lines with only 1 other line for FEEPATRT
EXEC sp_rpt_transporter_fee_pa '1/1/2014', '1/31/2014', 1, 999999, '010333470JJK', '010333470JJK', 'PAD010154045','C'	-- 5 disposal lines with only 1 other line for FEEPATRT
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@fee_treat_dispose		float,
	@fee_recycle			float,
	@fee_exempt				float,
	@pound_conv_gal			float,
	@pound_conv_lb			float,
	@pound_conv_ton			float,
	@pound_conv_ton_metric	float,
	@pound_conv_liter		float,
	@pound_conv_cubic_yard	float,
	@pound_conv_cubic_meter	float,
	@pound_conv_kg			float,
	@pa_license_num			varchar(10)

SET @fee_treat_dispose = 3.00
SET @fee_recycle = 1.50
SET @fee_exempt = 0.00

--SET @pound_conv_gal = 8.0
--SET @pound_conv_lb = 1.0
--SET @pound_conv_ton = 2000
---- SET @pound_conv_ton_metric = 2204.6
--SET @pound_conv_liter = 2.1
--SET @pound_conv_cubic_yard = 2000
---- SET @pound_conv_cubic_meter = 2515.9
--SET @pound_conv_kg = 2.2

CREATE TABLE #tmp_pound_conv (
	manifest_unit		char(1)
	, pound_conv		money
	)
INSERT #tmp_pound_conv VALUES ('P', 1.0)
INSERT #tmp_pound_conv VALUES ('L', 2.1)
INSERT #tmp_pound_conv VALUES ('K', 2.2)
INSERT #tmp_pound_conv VALUES ('G', 8.0)
INSERT #tmp_pound_conv VALUES ('T', 2000.0)
INSERT #tmp_pound_conv VALUES ('Y', 2000.0)


--SET @pa_license_num = 'AH0224'
SELECT @pa_license_num = state_license_code FROM TransporterStateLicense
 WHERE State = 'PA' AND EPA_ID = @EPA_ID

SELECT DISTINCT 
	1 AS part_of_union,
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wod.manifest_page_num,
	wod.manifest_line,
	wot1.transporter_code,
	t.Transporter_EPA_ID,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_addr3,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	t.Transporter_country,
	t.Transporter_contact,
	t.Transporter_contact_phone,
	--wod.quantity_used,							-- Should use value from WorkOrderDetailUnit
	--wod.bill_unit_code,							-- Should use value from WorkOrderDetailUnit
	wodub.quantity AS quantity_used,
	wodub.bill_unit_code AS bill_unit_code,
	wodum.quantity AS manifest_quantity,
	--wodum.bill_unit_code AS manifest_unit,
	bu.manifest_unit,
	ta.customer_id,
	wod.TSDF_code,
	--ta.TSDF_approval_code,						-- Should use value from Work Order
	wod.TSDF_approval_code,
	--ta.waste_stream,								-- Should use value from Work Order
	wod.waste_stream,
	--ta.generator_id,								-- Should use value from Work Order
	woh.generator_id,
	g.EPA_ID,
	--w.display_name as waste_code,
	dbo.fn_workorder_waste_code_list(wom.workorder_id, wom.company_id, wom.profit_ctr_id, wod.sequence_id) AS waste_code,
	ta.treatment_method,
	c.cust_name,
	ISNULL(CASE ta.treatment_method 
		WHEN 'TREAT/DISP' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_treat_dispose,
	ISNULL(CASE ta.treatment_method 
		WHEN 'RECYCLE' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_recycle,
	ISNULL(CASE ta.treatment_method 
		WHEN 'EXEMPT' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_exempt,
	ISNULL(CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
		ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
		END, 0.0) AS tons_total,
	woh.end_date
INTO #tmp
FROM WorkOrderManifest wom (NOLOCK)
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodum (NOLOCK)				--Manifest Unit
	ON wodum.company_id = wod.company_id
	AND wodum.profit_ctr_ID = wod.profit_ctr_ID
	AND wodum.workorder_id = wod.workorder_ID
	AND wodum.sequence_id = wod.sequence_ID
	AND wodum.manifest_flag = 'T'
INNER JOIN WorkOrderDetailUnit wodub (NOLOCK)				--Billing Units
	ON wodub.company_id = wod.company_id
	AND wodub.profit_ctr_ID = wod.profit_ctr_ID
	AND wodub.workorder_id = wod.workorder_ID
	AND wodub.sequence_id = wod.sequence_ID
	AND wodub.billing_flag = 'T'
INNER JOIN BillUnit bu (NOLOCK)
	ON bu.bill_unit_code = wodum.bill_unit_code
INNER JOIN #tmp_pound_conv (NOLOCK)
	ON #tmp_pound_conv.manifest_unit = bu.manifest_unit
INNER JOIN Transporter t (NOLOCK) 
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1 (NOLOCK)
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN WorkOrderHeader woh (NOLOCK)
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.end_date BETWEEN @date_from AND @date_to
INNER JOIN TSDFApproval ta (NOLOCK)
	ON wod.TSDF_approval_id = ta.TSDF_approval_id
	AND wod.company_id = ta.company_id
	AND wod.profit_ctr_id = ta.profit_ctr_id
	AND ta.treatment_method IN ('TREAT/DISP', 'RECYCLE', 'EXEMPT')
	AND ta.TSDF_approval_status = 'A'
--LEFT OUTER JOIN wastecode w
--	ON w.waste_code_uid = ta.waste_code_uid
INNER JOIN TSDFApprovalPrice tap (NOLOCK)
	ON ta.TSDF_approval_id = tap.TSDF_approval_id
	AND ta.company_id = tap.company_id
	AND ta.profit_ctr_id = tap.profit_ctr_id
	AND tap.record_type = 'R'
INNER JOIN ResourceClass rc (NOLOCK)
	ON tap.company_id = rc.company_id
	AND tap.profit_ctr_id = rc.profit_ctr_id
	AND tap.resource_class_code = rc.resource_class_code
	AND tap.bill_unit_code = rc.bill_unit_code
	AND rc.resource_class_code IN ('FEEPAREC', 'FEEPATRT')
INNER JOIN Generator g (NOLOCK)
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF (NOLOCK) 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'F'
INNER JOIN Customer c (NOLOCK)
	ON c.customer_ID = ta.customer_id
WHERE (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
	--AND rc.category = 'PAHWTFEE'
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
	
UNION

SELECT DISTINCT 
	2 AS part_of_union,
	wom.workorder_id,
	wom.company_id,
	wom.profit_ctr_id,
	wom.manifest,
	wod.manifest_page_num,
	wod.manifest_line,
	wot1.transporter_code,
	t.Transporter_EPA_ID,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_addr3,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	t.Transporter_country,
	t.Transporter_contact,
	t.Transporter_contact_phone,
	--wod.quantity_used,							-- Should use value from WorkOrderDetailUnit
	--wod.bill_unit_code,							-- Should use value from WorkOrderDetailUnit
	wodub.quantity AS quantity_used,
	wodub.bill_unit_code AS bill_unit_code,
	wodum.quantity AS manifest_quantity,
	--wodum.bill_unit_code AS manifest_unit,
	bu.manifest_unit,
	p.customer_id,
	wod.TSDF_code,
	pa.approval_code,
	wod.waste_stream,
	g.generator_id,
	g.EPA_ID,
	--w.display_name as waste_code,
	dbo.fn_workorder_waste_code_list(wom.workorder_id, wom.company_id, wom.profit_ctr_id, wod.sequence_id) AS waste_code,
	p.treatment_method,
	c.cust_name,
	ISNULL(CASE p.treatment_method 
		WHEN 'TREAT/DISP' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_treat_dispose,
	ISNULL(CASE p.treatment_method 
		WHEN 'RECYCLE' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_recycle,
	ISNULL(CASE p.treatment_method 
		WHEN 'EXEMPT' THEN 
			CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_exempt,
	ISNULL(CASE WHEN ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
		ELSE ROUND(((ISNULL(wodum.quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
		END, 0.0) AS tons_total,
	woh.end_date
FROM WorkOrderManifest wom (NOLOCK)
INNER JOIN WorkOrderDetail wod (NOLOCK) 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodum (NOLOCK)				-- Manifest Unit
	ON wodum.company_id = wod.company_id
	AND wodum.profit_ctr_ID = wod.profit_ctr_ID
	AND wodum.workorder_id = wod.workorder_ID
	AND wodum.sequence_id = wod.sequence_ID
	AND wodum.manifest_flag = 'T'
INNER JOIN WorkOrderDetailUnit wodub (NOLOCK)				--Billing Units
	ON wodub.company_id = wod.company_id
	AND wodub.profit_ctr_ID = wod.profit_ctr_ID
	AND wodub.workorder_id = wod.workorder_ID
	AND wodub.sequence_id = wod.sequence_ID
	AND wodub.billing_flag = 'T'
INNER JOIN BillUnit bu (NOLOCK)
	ON bu.bill_unit_code = wodum.bill_unit_code
INNER JOIN #tmp_pound_conv (NOLOCK)
	ON #tmp_pound_conv.manifest_unit = bu.manifest_unit
INNER JOIN Transporter t (NOLOCK) 
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
INNER JOIN WorkOrderTransporter wot1 (NOLOCK)
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
INNER JOIN WorkOrderHeader woh (NOLOCK) 
	ON wod.workorder_ID = woh.workorder_ID
	AND woh.company_id = wod.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.end_date BETWEEN @date_from AND @date_to
INNER JOIN ProfileQuoteDetail pqd (NOLOCK) 
	ON wod.profile_company_id = pqd.company_id
	AND wod.profile_profit_ctr_id = pqd.profit_ctr_id
	AND wod.profile_id = pqd.profile_id
	AND pqd.record_type = 'R'
INNER JOIN ProfileQuoteApproval pa (NOLOCK) 
	ON pqd.profile_id = pa.profile_id
	AND pqd.profit_ctr_id = pa.profit_ctr_id
	AND pqd.company_id = pa.company_id
	AND pqd.resource_class_code IN ('FEEPAREC', 'FEEPATRT')  --DZ
INNER JOIN Profile p (NOLOCK) 
	ON pa.profile_id = p.profile_id
	AND p.curr_status_code = 'A'
	AND p.treatment_method IN ('TREAT/DISP', 'RECYCLE', 'EXEMPT')
--LEFT OUTER JOIN wastecode w
--	ON w.waste_code_uid = p.waste_code_uid
INNER JOIN ResourceClass rc (NOLOCK) 
	ON pqd.resource_class_company_id = rc.company_id
	AND pqd.resource_class_code = rc.resource_class_code
	AND pqd.bill_unit_code = rc.bill_unit_code
	--AND rc.resource_class_code IN ('FEEPAREC', 'FEEPATRT')
INNER JOIN BillUnit b (NOLOCK) 
	ON pqd.bill_unit_code = b.bill_unit_code
INNER JOIN Generator g (NOLOCK) 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF (NOLOCK) 
	ON TSDF.TSDF_code = wod.TSDF_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'T'
INNER JOIN Customer c (NOLOCK)
	ON c.customer_ID = p.customer_id
WHERE (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
	--AND rc.category = 'PAHWTFEE'
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to

UNION	--Added specifically for EQ Pennsylvania for June 2010
		--This part of the union joins to the work table to get quantities from the linked
		--receipt instead of the work order (it was a lump sum on the work order, so can't 
		--be broken out.

SELECT DISTINCT 
	3 AS part_of_union,
	woh.workorder_id,
	woh.company_id,
	woh.profit_ctr_id,
	wom.manifest,
	r.manifest_page_num,
	r.manifest_line,
	wot1.transporter_code,
	t.Transporter_EPA_ID,
	t.Transporter_addr1,
	t.Transporter_addr2,
	t.Transporter_addr3,
	t.Transporter_city,
	t.Transporter_state,
	t.Transporter_zip_code,
	t.Transporter_country,
	t.Transporter_contact,
	t.Transporter_contact_phone,
	
	--wod.quantity_used,
	r.quantity AS quantity_used,
	
	--wod.bill_unit_code,
	r.bill_unit_code AS bill_unit_code,
	
	--r.manifest_quantity,
	--wod.quantity_used AS manifest_quantity,
	r.manifest_quantity AS manifest_quantity,
	
	--CASE LEN(r.manifest_unit)
	--	WHEN 1 THEN (SELECT bill_unit_code FROM BillUnit WHERE manifest_unit = r.manifest_unit)
	--	ELSE r.manifest_unit
	--END AS manifest_unit,
	--wod.bill_unit_code AS manifest_unit,
	--bu.manifest_unit,
	r.manifest_unit AS manifest_unit,
	
	woh.customer_id,
	TSDF.TSDF_code,
	r.approval_code AS TSDF_approval_code,
	NULL AS waste_stream,
	g.generator_id,
	g.EPA_ID,
	--dbo.fn_receipt_waste_code_list(wom.workorder_id, wom.company_id, wom.profit_ctr_id, wod.sequence_id) AS waste_code,
	dbo.fn_receipt_waste_code_list(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS waste_code,
	CASE wod.resource_class_code 
		WHEN 'FEEPATRT' THEN 'TREAT/DISP'
		WHEN 'FEEPAREC' THEN 'RECYCLE'
		END AS treatment_method,
	c.cust_name,
	
	--ISNULL(CASE (CASE wod.resource_class_code WHEN 'FEEPATRT' THEN 'TREAT/DISP' WHEN 'FEEPAREC' THEN 'RECYCLE' END)
	--	WHEN 'TREAT/DISP' THEN 
	--		CASE WHEN ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
	--			ELSE ROUND(((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
	--			END
	--	END, 0.0) AS tons_treat_dispose,
	ISNULL(CASE (CASE wod.resource_class_code WHEN 'FEEPATRT' THEN 'TREAT/DISP' WHEN 'FEEPAREC' THEN 'RECYCLE' END)
		WHEN 'TREAT/DISP' THEN 
			CASE WHEN ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_treat_dispose,
		
	--ISNULL(CASE (CASE wod.resource_class_code WHEN 'FEEPATRT' THEN 'TREAT/DISP' WHEN 'FEEPAREC' THEN 'RECYCLE' END)
	--	WHEN 'RECYCLE' THEN 
	--		CASE WHEN ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
	--			ELSE ROUND(((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
	--			END
	--	END, 0.0) AS tons_recycle,
	ISNULL(CASE (CASE wod.resource_class_code WHEN 'FEEPATRT' THEN 'TREAT/DISP' WHEN 'FEEPAREC' THEN 'RECYCLE' END)
		WHEN 'RECYCLE' THEN 
			CASE WHEN ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
				ELSE ROUND(((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
				END
		END, 0.0) AS tons_recycle,
		
	0.0 AS tons_exempt,
	
	--ISNULL(CASE WHEN ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
	--	ELSE ROUND(((ISNULL(wod.quantity_used, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
	--	END, 0.0) AS tons_total,
	ISNULL(CASE WHEN ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) > 0 AND ((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000) < 0.1 THEN 0.1
		ELSE ROUND(((ISNULL(r.manifest_quantity, 0.0) * ISNULL(#tmp_pound_conv.pound_conv, 0.0)) / 2000), 1)
		END, 0.0) AS tons_total,
		
	woh.end_date
FROM WorkorderHeader woh (NOLOCK)
INNER JOIN WorkorderDetail wod (NOLOCK)
	ON woh.company_id = wod.company_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.workorder_id  = wod.workorder_id
	AND wod.bill_rate >= -1
INNER JOIN Generator g (NOLOCK)
	ON woh.generator_id = g.generator_id
INNER JOIN Customer c (NOLOCK)
	ON c.customer_ID = woh.customer_ID
INNER JOIN BillingLinkLookup bl (NOLOCK)
	ON bl.source_company_id = woh.company_id
	AND bl.source_profit_ctr_id = woh.profit_ctr_id
	AND bl.source_id = woh.workorder_id
INNER JOIN Receipt r (NOLOCK)
	ON bl.company_id = r.company_id
	AND bl.profit_ctr_id = r.profit_ctr_id
	AND bl.receipt_id = r.receipt_id
	AND r.manifest_flag = 'M'
INNER JOIN TSDF (NOLOCK) 
	ON TSDF.eq_company = r.company_id
	AND TSDF.eq_profit_ctr = r.profit_ctr_id
	AND ISNULL(TSDF.eq_flag, 'F') = 'T'
--INNER JOIN BillUnit bu (NOLOCK)
	--ON bu.bill_unit_code = wod.bill_unit_code
INNER JOIN #tmp_pound_conv
	ON #tmp_pound_conv.manifest_unit = r.manifest_unit
INNER JOIN Transporter t (NOLOCK)
	ON t.transporter_EPA_ID = @EPA_ID
	AND t.eq_flag = 'T'
LEFT OUTER JOIN WorkorderManifest wom (NOLOCK)
	ON woh.company_id = wom.company_id
	AND woh.profit_ctr_id = wom.profit_ctr_id
	AND woh.workorder_id  = wom.workorder_id
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
INNER JOIN WorkOrderTransporter wot1 (NOLOCK)
	ON wot1.company_id = wom.company_id
	AND wot1.profit_ctr_id = wom.profit_ctr_ID
	AND wot1.workorder_id = wom.workorder_ID
	AND wot1.manifest = wom.manifest
	AND wot1.transporter_code = t.transporter_code
	AND wot1.transporter_sequence_id = 1
WHERE woh.end_date BETWEEN @date_from AND @date_to
AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
AND wod.resource_class_code IN ('FEEPATRT', 'FEEPAREC')
AND r.trans_type = 'D'
AND r.receipt_status = 'A'
AND r.trans_mode = 'I'
AND (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
AND EXISTS (SELECT 1 FROM ReceiptwasteCode rwc (NOLOCK)
        JOIN Wastecode wc (NOLOCK) ON rwc.waste_code_uid = wc.waste_code_uid
		WHERE rwc.company_id = r.company_id
        AND rwc.profit_ctr_id = r.profit_ctr_id
        AND rwc.receipt_id = r.receipt_id
        AND rwc.line_id = r.line_id
        AND wc.waste_code_origin = 'F'
        AND wc.haz_flag = 'T'
        )
ORDER BY wom.manifest, wod.manifest_line


---------------------------------------
-- Delete duplicates from #tmp
---------------------------------------
-- Remove any work order manifest lines that were from the first two parts of the union above,
-- if they exist in the third part.
DELETE tmp1or2
FROM #tmp tmp1or2
JOIN #tmp tmp3 ON tmp3.company_id = tmp1or2.company_id
	AND tmp3.profit_ctr_ID = tmp1or2.profit_ctr_ID
	AND tmp3.workorder_ID = tmp1or2.workorder_ID
	AND tmp3.manifest = tmp1or2.manifest
	AND tmp3.manifest_page_num = tmp1or2.manifest_page_num
	AND tmp1or2.manifest_line = tmp1or2.manifest_line
	AND tmp3.part_of_union = 3
WHERE tmp1or2.part_of_union IN (1,2)


---------------------------------------
-- Final SELECT
---------------------------------------
SELECT  
	#tmp.workorder_id
	, #tmp.company_id
	, #tmp.profit_ctr_id
	, #tmp.manifest
	, #tmp.manifest_page_num
	, #tmp.manifest_line
	, #tmp.transporter_code
	, #tmp.Transporter_EPA_ID
	, #tmp.Transporter_addr1
	, #tmp.Transporter_addr2
	, #tmp.Transporter_addr3
	, #tmp.Transporter_city
	, #tmp.Transporter_state
	, #tmp.Transporter_zip_code
	, #tmp.Transporter_country
	, #tmp.Transporter_contact
	, #tmp.Transporter_contact_phone
	, @pa_license_num AS pa_license_num
	, #tmp.quantity_used
	, #tmp.bill_unit_code
	, #tmp.manifest_quantity
	, #tmp.manifest_unit
	, #tmp.customer_id
	, #tmp.TSDF_code
	, #tmp.TSDF_approval_code
	, #tmp.waste_stream
	, #tmp.generator_id
	, #tmp.EPA_ID
	, #tmp.waste_code
	, #tmp.treatment_method
	, @fee_treat_dispose AS fee_treat_dispose
	, @fee_recycle AS fee_recycle
	, @fee_exempt AS fee_exempt
	, #tmp.cust_name
	, #tmp.tons_treat_dispose
	, #tmp.tons_recycle
	, #tmp.tons_exempt
	, #tmp.tons_total
	, #tmp.end_date
FROM #tmp (NOLOCK)
ORDER BY #tmp.manifest, #tmp.manifest_line

DROP TABLE #tmp_pound_conv
DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_pa] TO [EQAI]
    AS [dbo];

