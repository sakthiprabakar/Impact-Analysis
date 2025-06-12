CREATE PROCEDURE sp_rpt_transporter_fee_ma_emor 
	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@EPA_ID				varchar(15)
,	@work_order_status	char(1)
AS
/***********************************************************************
Hazardous Waste Transporter Fee 
Electronic Monthly Operating Report (EMOR) - Massachusetts

Filename:		L:\Apps\SQL\EQAI\sp_rpt_transporter_fee_ma_emor.sql
PB Object(s):	r_transporter_fee_ma_emor
		
07/29/2003 JDB	Created
11/11/2004 MK	Changed generator_code to generator_id
02/15/2005 JDB	Changed StateManDocNo from 17 to 20 characters per Don Johnson.
03/07/2005 JDB	Added the MA exempt fee from TSDF approval
04/07/2005 JDB	Added bill_unit_code for TSDFApproval
04/12/2006 MK	Removed profit_ctr_id = @profit_ctr_id from where clause to 
				pull one report for the whole facility
06/19/2006 JDB	Modified so that the LEFT 32 of gen_addr_[1,2] and LEFT 20
				of gen_city are inserted into #tmp
08/10/2006 RG	Modified for changes in profile and TSDF approvals
11/09/2006 MK	Replaced old joins to TSDFApproval with tsdf_approval_id
11/12/2007 RG	Revised for workorder status.  Submitted Work Orders are now status of A
                and submitted_flag of T
07/29/2008 JDB	Modified to meet new MA DEP requirements (Gemini 8252)
08/07/2008 JDB	Added column headers for new MA DEP export requirements
01/30/2009 JDB	Wrapped the SELECT for the cursor inside an ISNULL to prevent an error
				from occurring (See Gemini 10132).
09/11/2009 JDB	Added ISNULL around the manifest unit field because it was breaking the export.
11/09/2009 JDB	Fixed arithmetic overflow error for type varchar, value = 4036600.436000
				by changing the wod.manifest_quantity field to 14 characters from 7.
01/06/2010 JDB	Updated to get treatment_id from ProfileQuoteApproval instead of Profile table.
07/16/2010 KAM  updated the select to not include voided workorderdetail rows
07/16/2010 KAM  Updated the report to use a transporter_code that is selected from the TransporterStateLicense table
02/08/2011 SK	Changed to run for all companies(removed companyid/pc as input args)
				Added company_id to result set
				Changed to run by user selected EPA ID and not transporter code
				Use Treatment not TreatmentALL
				Moved on Plt_AI
02/18/2011 SK	Used the new table WorkOrderTransporter to fetch fields transporter1, transporter2 & transporter receive date
02/18/2011 SK	Manifest_quantity & manifest_unit are moved to WorkOrderDetailUnit from WorkOrderDetail. Changed to join to same.
02/18/2011 SK	transporter_fee_exempt_code_ma moved to TSDFApprovalPrice or ProfileQuoteDetail as transporter_fee_exempt_code.
03/01/2011 SK	Fixed a bad join on ProfileQuoteDetail for company/profit_ctr
03/02/2011 SK	Fixed join for TransporterCode on Wot1 and added transporters 3 to 5
03/09/2011 SK	Added ProfileQuoteDetail.record_type = 'R' to avoid duplicate lines from ProfileQuoteDetail
08/02/2011 JDB	Changed join to TSDFApprovalPrice & ProfileQuoteDetail to be LEFT OUTER so that the fee doesn't HAVE to 
				exist in that table for the record to be included in the EMOR.
03/29/2012 JDB	Added "AND pqd.resource_class_code = 'FEEMAHW'" to the join to ProfileQuoteDetail so that this report would
				return the Fee column from the correct resource class (there are multiple PQD records on some of our profiles - one for MA, 
				another for RI, ME, etc.)
08/21/2013 SM	Added wastecode table and displaying Display name
11/01/2013 JDB	Modified to use the waste codes from the WorkOrderWasteCode table instead of ProfileWasteCode and TSDFApprovalWasteCode
				Also changed the WasteNo1 through WasteNo6 fields back to varchar(4) because this is a fixed-width report.
				Changed the fee exempt code to a sub-select because it was incorrect.
				Updated manifest quantity calculation to set it to 1 if it's between 0 and 1, otherwise use normal rounding.
				Added code to replace carriage returns in the DOT Shipping Name with a blank space.
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).

sp_rpt_transporter_fee_ma_emor '7/7/2013', '7/9/2013', 10877, 10877, '0', 'zzz', 'MAD084814136','S'

sp_rpt_transporter_fee_ma_emor '7/1/2013', '7/31/2013', 1, 999999, '0', 'zzz', 'MAD084814136'
576 5:46, 561 3:28, 
sp_rpt_transporter_fee_ma_emor '9/1/2013', '9/30/2013', 1, 999999, '0', 'zzz', 'MAD084814136'
sp_rpt_transporter_fee_ma_emor '3/1/2017', '5/30/2017', 1, 999999, '0', 'zzz', 'MAD084814136', 'C'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@line				int,
	@ls_description		varchar(1500),
	@intcounter 		int
	
SET NOCOUNT ON

CREATE TABLE #tmp (
	workorder_id	int			NOT NULL,
	company_id		int			NOT NULL,
	profit_ctr_id	int			NOT NULL,
	workorder_status varchar(1)	NOT NULL,
	line_id			int			NULL,
	RecordType		varchar(11)	NULL,
	ReportingYear	varchar(14)	NULL,
	ReportingMonth	varchar(15)	NULL,
 	DefaultEPAID	varchar(25)	NULL,
	StateManDocNo	varchar(26)	NULL,
	GenEPAID		varchar(16)	NULL,
	GenName			varchar(50)	NULL,
	GenAddr1		varchar(32)	NULL,
	GenAddr2		varchar(32)	NULL,
	GenCity			varchar(20)	NULL,
	GenStateProv	varchar(29)	NULL,
	GenPostalCode	varchar(26)	NULL,
	GenCountry		varchar(22)	NULL,
	GenMailAddr1	varchar(32)	NULL,
	GenMailAddr2	varchar(32)	NULL,
	GenMailCity		varchar(20)	NULL,
	GenMailStateProv varchar(29) NULL,
	GenMailPostalCode varchar(26) NULL,
	GenMailCountry	varchar(22)	NULL,
	Tran1EPAID		varchar(20)	NULL,
	Tran1CompName	varchar(32)	NULL,
	Tran1RecptDate	varchar(30)	NULL,
	Tran2EPAID		varchar(20)	NULL,
	Tran2CompName	varchar(32)	NULL,
	Tran2RecptDate	varchar(30)	NULL,
	Tran3EPAID		varchar(20)	NULL,
	Tran3CompName	varchar(32)	NULL,
	Tran3RecptDate	varchar(30)	NULL,
	Tran4EPAID		varchar(20)	NULL,
	Tran4CompName	varchar(32)	NULL,
	Tran4RecptDate	varchar(30)	NULL,
	Tran5EPAID		varchar(20)	NULL,
	Tran5CompName	varchar(32)	NULL,
	Tran5RecptDate	varchar(30)	NULL,
	FacEPAID		varchar(15)	NULL,
	FacName			varchar(32)	NULL,
	FacRecptDate	varchar(21)	NULL,
	DiscrepInd		varchar(240) NULL,
	DiscrepQty		varchar(31) NULL,
	DiscrepType		varchar(27) NULL,
	DiscrepResidue	varchar(30) NULL,
	DiscrepPartial	varchar(40) NULL,
	DiscrepFull		varchar(37) NULL,
	DiscrepOther	varchar(28) NULL,
	ManifestRef		varchar(28) NULL,
	AltFacEPAID		varchar(25) NULL,
	AltFacName		varchar(32) NULL,
	AltFacRecpDate	varchar(31) NULL,
	GenCertDate		varchar(28)	NULL,
	LineNum			varchar(7)	NULL,
	DOTDescr		varchar(50)	NULL,
	ContCnt			varchar(15)	NULL,
	ContType		varchar(14)	NULL,
	TotQty			varchar(14)	NULL,
	UnitWtVol		varchar(11)	NULL,
	WasteNo1		varchar(10)	NULL,
	WasteNo2		varchar(10)	NULL,
	WasteNo3		varchar(10)	NULL,
	WasteNo4		varchar(10)	NULL,
	WasteNo5		varchar(10)	NULL,
	WasteNo6		varchar(10)	NULL,
	MgmtCode		varchar(22)	NULL,
	Fee				varchar(3)	NULL	)


INSERT INTO #tmp VALUES (-1, -1, -1, 'X', -1,
'RECORD_TYPE',
'REPORTING_YEAR',
'REPORTING_MONTH',
'SOURCE_TRANSPORTER_EPA_ID',
'STATE_MANIFEST_DOCUMENT_NO',
'GENERATOR_EPA_ID',
'GENERATOR_NAME',
'GENERATOR_SITE_ADDRESS_LINE_1',
'GENERATOR_SITE_ADDRESS_LINE_2',
'GENERATOR_SITE_CITY',
'GENERATOR_SITE_STATE_PROVINCE',
'GENERATOR_SITE_POSTAL_CODE',
'GENERATOR_SITE_COUNTRY',
'GENERATOR_MAIL_ADDRESS_LINE_1',
'GENERATOR_MAIL_ADDRESS_LINE_2',
'GENERATOR_MAIL_CITY',
'GENERATOR_MAIL_STATE_PROVINCE',
'GENERATOR_MAIL_POSTAL_CODE',
'GENERATOR_MAIL_COUNTRY',
'TRANSPORTER_1_EPA_ID',
'TRANSPORTER_1_COMPANY_NAME',
'TRANSPORTER_1_MATERIALS_RECEIP',
'TRANSPORTER_2_EPA_ID',
'TRANSPORTER_2_COMPANY_NAME',
'TRANSPORTER_2_MATERIALS_RECEIP',
'TRANSPORTER_3_EPA_ID',
'TRANSPORTER_3_COMPANY_NAME',
'TRANSPORTER_3_MATERIALS_RECEIP',
'TRANSPORTER_4_EPA_ID',
'TRANSPORTER_4_COMPANY_NAME',
'TRANSPORTER_4_MATERIALS_RECEIP',
'TRANSPORTER_5_EPA_ID',
'TRANSPORTER_5_COMPANY_NAME',
'TRANSPORTER_5_MATERIALS_RECEIP',
'FACILITY_EPA_ID',
'FACILITY_NAME',
'FACILITY_RECEIPT_DATE',
'DISCREPANCY_INDICATION',
'DISCREPANCY_INDICATION_QUANTITY',
'DISCREPANCY_INDICATION_TYPE',
'DISCREPANCY_INDICATION_RESIDUE',
'DISCREPANCY_INDICATION_PARTIAL_REJECTION',
'DISCREPANCY_INDICATION_FULL_REJECTION',
'DISCREPANCY_INDICATION_OTHER',
'MANIFEST_REFERENCE_NUMBER',
'ALTERNATE_FACILITY_EPA_ID',
'ALTERNATE_FACILITY_NAME',
'ALTERNATE_FACILITY_RECEIPT_DATE',
'GENERATOR_CERTIFICATION_DATE',
'LINE_NO',
'DOT_DESCRIPTION',
'CONTAINER_COUNT',
'CONTAINER_TYPE',
'TOTAL_QUANTITY',
'UNIT_WT_VOL',
'WASTE_NO_1',
'WASTE_NO_2',
'WASTE_NO_3',
'WASTE_NO_4',
'WASTE_NO_5',
'WASTE_NO_6',
'MANAGEMENT_METHOD_CODE',
'FEE'
)


INSERT INTO #tmp
SELECT DISTINCT 
	woh.workorder_id,
	woh.company_id,
	woh.profit_ctr_id,
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' THEN 'X' ELSE woh.workorder_status END AS workorder_status,
	0,
	RecordType = CASE WHEN (wod.manifest_page_num = 1 AND wod.manifest_line = 1) THEN 'H' ELSE 'D' END,
	ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(4)) AS ReportingYear,
	ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2), SPACE(2)) AS ReportingMonth,
	@EPA_ID AS DefaultEPAID,
	wom.manifest AS StateManDocNo,
	ISNULL(g.EPA_ID, SPACE(12)) AS GenEPAID,
	ISNULL(g.generator_name, SPACE(50)) AS GenName,
	LEFT(ISNULL(g.generator_address_1, SPACE(32)), 32) AS GenAddr1,
	LEFT(ISNULL(g.generator_address_2, SPACE(32)), 32) AS GenAddr2,
	LEFT(ISNULL(g.generator_city, SPACE(20)), 20) AS GenCity,
	ISNULL(g.generator_state, SPACE(2)) AS GenStateProv,
	ISNULL(g.generator_zip_code, SPACE(12)) AS GenPostalCode,
	LEFT(ISNULL(g.generator_country, SPACE(2)), 2) AS GenCountry,
	LEFT(ISNULL(g.gen_mail_addr1, SPACE(32)), 32) AS GenMailAddr1,
	LEFT(ISNULL(g.gen_mail_addr2, SPACE(32)), 32) AS GenMailAddr2,
	LEFT(ISNULL(g.gen_mail_city, SPACE(20)), 20) AS GenMailCity,
	ISNULL(g.gen_mail_state, SPACE(2)) AS GenMailStateProv,
	ISNULL(g.gen_mail_zip_code, SPACE(12)) AS GenMailPostalCode,
	LEFT(ISNULL(g.generator_country, SPACE(2)), 2) AS GenMailCountry,
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot1.transporter_code), SPACE(12)) AS Tran1EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot1.transporter_code), SPACE(32)) AS Tran1CompName,
	Tran1RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot2.transporter_code), SPACE(12)) AS Tran2EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot2.transporter_code), SPACE(32)) AS Tran2CompName,
	Tran2RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot3.transporter_code), SPACE(12)) AS Tran3EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot3.transporter_code), SPACE(32)) AS Tran3CompName,
	Tran3RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot4.transporter_code), SPACE(12)) AS Tran4EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot4.transporter_code), SPACE(32)) AS Tran4CompName,
	Tran4RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot5.transporter_code), SPACE(12)) AS Tran5EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot5.transporter_code), SPACE(32)) AS Tran5CompName,
	Tran5RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(12), TSDF.TSDF_EPA_ID), SPACE(12)) AS FacEPAID,
	ISNULL(CONVERT(varchar(32), TSDF.TSDF_name), SPACE(32)) AS FacName,
	FacRecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(240), wom.discrepancy_desc), SPACE(240)) AS DiscrepInd,
	DiscrepQty = '',
	DiscrepType = '',
	DiscrepResidue = '',
	DiscrepPartial = '',
	DiscrepFull = '',
	DiscrepOther = '',
	ManifestRef = '',
	AltFacEPAID = '',
	AltFacName = '',
	AltFacRecpDate = '',
	GenCertDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(3), wod.manifest_line), SPACE(3)) AS LineNum,
	--ISNULL(CONVERT(varchar(50), COALESCE(wod.DOT_shipping_name, ta.DOT_shipping_name)), SPACE(50)) AS DOTdesc,
	DOTdesc = ISNULL(CONVERT(varchar(50), REPLACE(COALESCE(wod.DOT_shipping_name, ta.DOT_shipping_name), CHAR(13)+CHAR(10), ' ')), SPACE(50)),
	ISNULL(CONVERT(varchar(15), wod.container_count), SPACE(15)) AS ContCnt,
	ISNULL(CONVERT(varchar(14), wod.container_code), SPACE(14)) AS ContType,
	--ISNULL(CONVERT(varchar(14), wodu.quantity), SPACE(14)) AS TotQty,
	ISNULL(CONVERT(varchar(14), CASE WHEN ISNULL(wodu.quantity, 0) > 0 AND ISNULL(wodu.quantity, 0) < 1 THEN 1 ELSE ROUND(ISNULL(wodu.quantity, 0), 0) END), SPACE(14)) AS TotQty,
	UnitWtVol = ISNULL(bu.manifest_unit, SPACE(1)),
	WasteNo1 = ISNULL(RIGHT(wc1.display_name, 4), SPACE(4)),
	WasteNo2 = ISNULL(RIGHT(wc2.display_name, 4), SPACE(4)),
	WasteNo3 = ISNULL(RIGHT(wc3.display_name, 4), SPACE(4)),
	WasteNo4 = ISNULL(RIGHT(wc4.display_name, 4), SPACE(4)),
	WasteNo5 = ISNULL(RIGHT(wc5.display_name, 4), SPACE(4)),
	WasteNo6 = ISNULL(RIGHT(wc6.display_name, 4), SPACE(4)),
	MgmtCode = ISNULL(COALESCE(wod.management_code, ta.management_code), SPACE(4)),
	--Fee = ISNULL(ta.transporter_fee_exempt_code_ma, SPACE(1))
	--Fee = ISNULL(tap.fee_exempt_code, SPACE(1))
	Fee = ISNULL((SELECT MIN(fee_exempt_code)
		FROM TSDFApprovalPrice tap
		WHERE tap.TSDF_approval_id = wod.TSDF_approval_id
		AND tap.profit_ctr_id = wod.profit_ctr_id
		AND tap.company_id = wod.company_id 
		AND tap.record_type = 'R'
		AND tap.resource_class_code = 'FEEMAHW'
		), SPACE(1))
FROM WorkOrderManifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
INNER JOIN BillUnit bu
	ON bu.bill_unit_code = wodu.bill_unit_code
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
LEFT OUTER JOIN WorkOrderTransporter wot2
	ON wot2.company_id = wom.company_id
	AND wot2.profit_ctr_id = wom.profit_ctr_ID
	AND wot2.workorder_id = wom.workorder_ID
	AND wot2.manifest = wom.manifest
	AND wot2.transporter_sequence_id = 2
LEFT OUTER JOIN WorkOrderTransporter wot3
	ON wot3.company_id = wom.company_id
	AND wot3.profit_ctr_id = wom.profit_ctr_ID
	AND wot3.workorder_id = wom.workorder_ID
	AND wot3.manifest = wom.manifest
	AND wot3.transporter_sequence_id = 3
LEFT OUTER JOIN WorkOrderTransporter wot4
	ON wot4.company_id = wom.company_id
	AND wot4.profit_ctr_id = wom.profit_ctr_ID
	AND wot4.workorder_id = wom.workorder_ID
	AND wot4.manifest = wom.manifest
	AND wot4.transporter_sequence_id = 4
LEFT OUTER JOIN WorkOrderTransporter wot5
	ON wot5.company_id = wom.company_id
	AND wot5.profit_ctr_id = wom.profit_ctr_ID
	AND wot5.workorder_id = wom.workorder_ID
	AND wot5.manifest = wom.manifest
	AND wot5.transporter_sequence_id = 5
INNER JOIN WorkOrderHeader woh 
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN TSDFApproval ta 
	ON wod.TSDF_code = ta.TSDF_code
	AND wod.TSDF_approval_id = ta.TSDF_approval_id
	AND wod.company_id = ta.company_id
	AND wod.profit_ctr_id = ta.profit_ctr_id
	AND ta.TSDF_approval_status = 'A'
--LEFT OUTER JOIN TSDFApprovalPrice tap
--	ON tap.company_id = ta.company_id
--	AND tap.profit_ctr_id = ta.profit_ctr_id
--	AND tap.TSDF_approval_id = ta.TSDF_approval_id
--	AND tap.record_type = 'R'
INNER JOIN Generator g 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF 
	ON ta.TSDF_code = TSDF.TSDF_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'F'
LEFT OUTER JOIN WorkOrderWasteCode wowc1
	ON wowc1.company_id = wod.company_id
	AND wowc1.profit_ctr_id = wod.profit_ctr_ID
	AND wowc1.workorder_id = wod.workorder_ID
	AND wowc1.workorder_sequence_id = wod.sequence_ID
	AND wowc1.sequence_id = 1
LEFT OUTER JOIN WorkOrderWasteCode wowc2
	ON wowc2.company_id = wod.company_id
	AND wowc2.profit_ctr_id = wod.profit_ctr_ID
	AND wowc2.workorder_id = wod.workorder_ID
	AND wowc2.workorder_sequence_id = wod.sequence_ID
	AND wowc2.sequence_id = 2
LEFT OUTER JOIN WorkOrderWasteCode wowc3
	ON wowc3.company_id = wod.company_id
	AND wowc3.profit_ctr_id = wod.profit_ctr_ID
	AND wowc3.workorder_id = wod.workorder_ID
	AND wowc3.workorder_sequence_id = wod.sequence_ID
	AND wowc3.sequence_id = 3
LEFT OUTER JOIN WorkOrderWasteCode wowc4
	ON wowc4.company_id = wod.company_id
	AND wowc4.profit_ctr_id = wod.profit_ctr_ID
	AND wowc4.workorder_id = wod.workorder_ID
	AND wowc4.workorder_sequence_id = wod.sequence_ID
	AND wowc4.sequence_id = 4
LEFT OUTER JOIN WorkOrderWasteCode wowc5
	ON wowc5.company_id = wod.company_id
	AND wowc5.profit_ctr_id = wod.profit_ctr_ID
	AND wowc5.workorder_id = wod.workorder_ID
	AND wowc5.workorder_sequence_id = wod.sequence_ID
	AND wowc5.sequence_id = 5
LEFT OUTER JOIN WorkOrderWasteCode wowc6
	ON wowc6.company_id = wod.company_id
	AND wowc6.profit_ctr_id = wod.profit_ctr_ID
	AND wowc6.workorder_id = wod.workorder_ID
	AND wowc6.workorder_sequence_id = wod.sequence_ID
	AND wowc6.sequence_id = 6
LEFT OUTER JOIN WasteCode wc1
	ON wc1.waste_code_uid = wowc1.waste_code_uid
LEFT OUTER JOIN WasteCode wc2
	ON wc2.waste_code_uid = wowc2.waste_code_uid 
LEFT OUTER JOIN WasteCode wc3
	ON wc3.waste_code_uid = wowc3.waste_code_uid  
LEFT OUTER JOIN WasteCode wc4
	ON wc4.waste_code_uid = wowc4.waste_code_uid 
LEFT OUTER JOIN WasteCode wc5
	ON wc5.waste_code_uid = wowc5.waste_code_uid 
LEFT OUTER JOIN WasteCode wc6
	ON wc6.waste_code_uid = wowc6.waste_code_uid 

WHERE 1=1
	AND wom.manifest_flag = 'T'
	AND (TSDF.TSDF_state = 'MA' OR g.generator_state = 'MA')
	AND NOT (ISNULL(wod.container_count, 0) = 0 AND ISNULL(wod.quantity_used, 0) = 0 AND wom.discrepancy_flag = 'T')
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
	
-- now insert profile wo 
UNION
SELECT DISTINCT 
	woh.workorder_id,
	woh.company_id,
	woh.profit_ctr_id,
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' THEN 'X' ELSE woh.workorder_status END AS workorder_status,
	0,
	RecordType = CASE WHEN (wod.manifest_page_num = 1 AND wod.manifest_line = 1) THEN 'H' ELSE 'D' END,
	ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(4)) AS ReportingYear,
	ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2), SPACE(2)) AS ReportingMonth,
	@EPA_ID AS DefaultEPAID,
	wom.manifest AS StateManDocNo,
	ISNULL(g.EPA_ID, SPACE(12)) AS GenEPAID,
	ISNULL(g.generator_name, SPACE(50)) AS GenName,
	LEFT(ISNULL(g.generator_address_1, SPACE(32)), 32) AS GenAddr1,
	LEFT(ISNULL(g.generator_address_2, SPACE(32)), 32) AS GenAddr2,
	LEFT(ISNULL(g.generator_city, SPACE(20)), 20) AS GenCity,
	ISNULL(g.generator_state, SPACE(2)) AS GenStateProv,
	ISNULL(g.generator_zip_code, SPACE(12)) AS GenPostalCode,
	LEFT(ISNULL(g.generator_country, SPACE(2)), 2) AS GenCountry,
	LEFT(ISNULL(g.gen_mail_addr1, SPACE(32)), 32) AS GenMailAddr1,
	LEFT(ISNULL(g.gen_mail_addr2, SPACE(32)), 32) AS GenMailAddr2,
	LEFT(ISNULL(g.gen_mail_city, SPACE(20)), 20) AS GenMailCity,
	ISNULL(g.gen_mail_state, SPACE(2)) AS GenMailStateProv,
	ISNULL(g.gen_mail_zip_code, SPACE(12)) AS GenMailPostalCode,
	LEFT(ISNULL(g.generator_country, SPACE(2)), 2) AS GenMailCountry,
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot1.transporter_code), SPACE(12)) AS Tran1EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot1.transporter_code), SPACE(32)) AS Tran1CompName,
	Tran1RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot2.transporter_code), SPACE(12)) AS Tran2EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot2.transporter_code), SPACE(32)) AS Tran2CompName,
	Tran2RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot2.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot3.transporter_code), SPACE(12)) AS Tran3EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot3.transporter_code), SPACE(32)) AS Tran3CompName,
	Tran3RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot3.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot4.transporter_code), SPACE(12)) AS Tran4EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot4.transporter_code), SPACE(32)) AS Tran4CompName,
	Tran4RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot4.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL((SELECT SUBSTRING(transporter_EPA_ID, 1, 12) FROM Transporter WHERE transporter_code = wot5.transporter_code), SPACE(12)) AS Tran5EPAID,
	ISNULL((SELECT SUBSTRING(transporter_name, 1, 32) FROM Transporter WHERE transporter_code = wot5.transporter_code), SPACE(32)) AS Tran5CompName,
	Tran5RecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wot5.transporter_sign_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(12), TSDF.TSDF_EPA_ID), SPACE(12)) AS FacEPAID,
	ISNULL(CONVERT(varchar(32), TSDF.TSDF_name), SPACE(32)) AS FacName,
	FacRecptDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), wom.date_delivered, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(240), wom.discrepancy_desc), SPACE(240)) AS DiscrepInd,
	DiscrepQty = '',
	DiscrepType = '',
	DiscrepResidue = '',
	DiscrepPartial = '',
	DiscrepFull = '',
	DiscrepOther = '',
	ManifestRef = '',
	AltFacEPAID = '',
	AltFacName = '',
	AltFacRecpDate = '',
	GenCertDate = REPLACE(ISNULL(SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 5, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 7, 2) + '/' + SUBSTRING(CONVERT(varchar(8), woh.start_date, 112), 1, 4), SPACE(10)), '//', '  '),
	ISNULL(CONVERT(varchar(3), wod.manifest_line), SPACE(3)) AS LineNum,
	--ISNULL(CONVERT(varchar(50), COALESCE(wod.DOT_shipping_name, p.DOT_shipping_name)), SPACE(50)) AS DOTdesc,
	DOTdesc = ISNULL(CONVERT(varchar(50), REPLACE(COALESCE(wod.DOT_shipping_name, p.DOT_shipping_name), CHAR(13)+CHAR(10), ' ')), SPACE(50)),
	ISNULL(CONVERT(varchar(15), wod.container_count), SPACE(15)) AS ContCnt,
	ISNULL(CONVERT(varchar(14), wod.container_code), SPACE(14)) AS ContType,
	--ISNULL(CONVERT(varchar(14), wodu.quantity), SPACE(14)) AS TotQty,
	ISNULL(CONVERT(varchar(14), CASE WHEN ISNULL(wodu.quantity, 0) > 0 AND ISNULL(wodu.quantity, 0) < 1 THEN 1 ELSE ROUND(ISNULL(wodu.quantity, 0), 0) END), SPACE(14)) AS TotQty,
	UnitWtVol = ISNULL(bu.manifest_unit, SPACE(1)),
	WasteNo1 = ISNULL(RIGHT(wc1.display_name, 4), SPACE(4)),
	WasteNo2 = ISNULL(RIGHT(wc2.display_name, 4), SPACE(4)),
	WasteNo3 = ISNULL(RIGHT(wc3.display_name, 4), SPACE(4)),
	WasteNo4 = ISNULL(RIGHT(wc4.display_name, 4), SPACE(4)),
	WasteNo5 = ISNULL(RIGHT(wc5.display_name, 4), SPACE(4)),
	WasteNo6 = ISNULL(RIGHT(wc6.display_name, 4), SPACE(4)),
	MgmtCode = ISNULL(COALESCE(wod.management_code, t.management_code), SPACE(4)),
	
	--Fee = ISNULL(p.transporter_fee_exempt_code_ma, SPACE(1))
	--Fee = ISNULL(pqd.fee_exempt_code, SPACE(1))
	Fee = ISNULL((SELECT MIN(fee_exempt_code)
		FROM ProfileQuoteDetail pqd
		WHERE pqd.profile_id = wod.profile_id
		AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
		AND pqd.company_id = wod.profile_company_id 
		AND pqd.record_type = 'R'
		AND pqd.resource_class_code = 'FEEMAHW'
		), SPACE(1))
FROM WorkOrderManifest wom
INNER JOIN WorkOrderDetail wod 
	ON wod.workorder_ID = wom.workorder_ID
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_ID = wom.profit_ctr_ID
	AND wod.manifest = wom.manifest
	AND wod.resource_type = 'D'
	AND wod.profile_id IS NOT NULL
	AND wod.bill_rate >= -1
INNER JOIN WorkOrderDetailUnit wodu
	ON wodu.company_id = wod.company_id
	AND wodu.profit_ctr_ID = wod.profit_ctr_ID
	AND wodu.workorder_id = wod.workorder_ID
	AND wodu.sequence_id = wod.sequence_ID
	AND wodu.manifest_flag = 'T'
INNER JOIN BillUnit bu
	ON bu.bill_unit_code = wodu.bill_unit_code
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
LEFT OUTER JOIN WorkOrderTransporter wot2
	ON wot2.company_id = wom.company_id
	AND wot2.profit_ctr_id = wom.profit_ctr_ID
	AND wot2.workorder_id = wom.workorder_ID
	AND wot2.manifest = wom.manifest
	AND wot2.transporter_sequence_id = 2
LEFT OUTER JOIN WorkOrderTransporter wot3
	ON wot3.company_id = wom.company_id
	AND wot3.profit_ctr_id = wom.profit_ctr_ID
	AND wot3.workorder_id = wom.workorder_ID
	AND wot3.manifest = wom.manifest
	AND wot3.transporter_sequence_id = 3
LEFT OUTER JOIN WorkOrderTransporter wot4
	ON wot4.company_id = wom.company_id
	AND wot4.profit_ctr_id = wom.profit_ctr_ID
	AND wot4.workorder_id = wom.workorder_ID
	AND wot4.manifest = wom.manifest
	AND wot4.transporter_sequence_id = 4
LEFT OUTER JOIN WorkOrderTransporter wot5
	ON wot5.company_id = wom.company_id
	AND wot5.profit_ctr_id = wom.profit_ctr_ID
	AND wot5.workorder_id = wom.workorder_ID
	AND wot5.manifest = wom.manifest
	AND wot5.transporter_sequence_id = 5
INNER JOIN WorkOrderHeader woh 
	ON wod.workorder_ID = woh.workorder_ID
	AND wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND (woh.workorder_status in ('A','C') OR woh.submitted_flag = 'T')
	AND (woh.submitted_flag = 'T' OR @work_order_status = 'C')
	AND woh.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND woh.start_date BETWEEN @date_from AND @date_to
INNER JOIN Profile p 
	ON wod.profile_id = p.profile_id
--	AND p.curr_status_code = 'A'
--LEFT OUTER JOIN ProfileQuoteDetail pqd
--	ON pqd.company_id = wod.profile_company_id
--	AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
--	AND pqd.profile_id = p.profile_id
--	AND pqd.record_type = 'R'
--	AND pqd.resource_class_code = 'FEEMAHW'
INNER JOIN ProfileQuoteApproval pqa 
	ON wod.profile_company_id = pqa.company_id
	AND wod.profile_profit_ctr_id = pqa.profit_ctr_id
	AND wod.profile_id = pqa.profile_id
INNER JOIN Generator g 
	ON woh.generator_id = g.generator_id
INNER JOIN TSDF 
	ON wod.TSDF_code = TSDF.TSDF_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'T'
INNER JOIN Treatment t 
	ON pqa.treatment_id = t.treatment_id
LEFT OUTER JOIN WorkOrderWasteCode wowc1
	ON wowc1.company_id = wod.company_id
	AND wowc1.profit_ctr_id = wod.profit_ctr_ID
	AND wowc1.workorder_id = wod.workorder_ID
	AND wowc1.workorder_sequence_id = wod.sequence_ID
	AND wowc1.sequence_id = 1
LEFT OUTER JOIN WorkOrderWasteCode wowc2
	ON wowc2.company_id = wod.company_id
	AND wowc2.profit_ctr_id = wod.profit_ctr_ID
	AND wowc2.workorder_id = wod.workorder_ID
	AND wowc2.workorder_sequence_id = wod.sequence_ID
	AND wowc2.sequence_id = 2
LEFT OUTER JOIN WorkOrderWasteCode wowc3
	ON wowc3.company_id = wod.company_id
	AND wowc3.profit_ctr_id = wod.profit_ctr_ID
	AND wowc3.workorder_id = wod.workorder_ID
	AND wowc3.workorder_sequence_id = wod.sequence_ID
	AND wowc3.sequence_id = 3
LEFT OUTER JOIN WorkOrderWasteCode wowc4
	ON wowc4.company_id = wod.company_id
	AND wowc4.profit_ctr_id = wod.profit_ctr_ID
	AND wowc4.workorder_id = wod.workorder_ID
	AND wowc4.workorder_sequence_id = wod.sequence_ID
	AND wowc4.sequence_id = 4
LEFT OUTER JOIN WorkOrderWasteCode wowc5
	ON wowc5.company_id = wod.company_id
	AND wowc5.profit_ctr_id = wod.profit_ctr_ID
	AND wowc5.workorder_id = wod.workorder_ID
	AND wowc5.workorder_sequence_id = wod.sequence_ID
	AND wowc5.sequence_id = 5
LEFT OUTER JOIN WorkOrderWasteCode wowc6
	ON wowc6.company_id = wod.company_id
	AND wowc6.profit_ctr_id = wod.profit_ctr_ID
	AND wowc6.workorder_id = wod.workorder_ID
	AND wowc6.workorder_sequence_id = wod.sequence_ID
	AND wowc6.sequence_id = 6
LEFT OUTER JOIN WasteCode wc1
	ON wc1.waste_code_uid = wowc1.waste_code_uid
LEFT OUTER JOIN WasteCode wc2
	ON wc2.waste_code_uid = wowc2.waste_code_uid 
LEFT OUTER JOIN WasteCode wc3
	ON wc3.waste_code_uid = wowc3.waste_code_uid  
LEFT OUTER JOIN WasteCode wc4
	ON wc4.waste_code_uid = wowc4.waste_code_uid 
LEFT OUTER JOIN WasteCode wc5
	ON wc5.waste_code_uid = wowc5.waste_code_uid 
LEFT OUTER JOIN WasteCode wc6
	ON wc6.waste_code_uid = wowc6.waste_code_uid 
WHERE 1=1
	AND wom.manifest_flag = 'T'
	AND (TSDF.TSDF_state = 'MA' OR g.generator_state = 'MA')
	AND NOT (ISNULL(wod.container_count, 0) = 0 AND ISNULL(wod.quantity_used, 0) = 0 AND wom.discrepancy_flag = 'T')
	AND wom.manifest BETWEEN @manifest_from AND @manifest_to
	
-- If transporter 2 is populated, then blank out TSDF name, EPA ID, and Received Date
-- per Don Johnson/Kenny Wenstrom August 2008.
UPDATE #tmp SET FacEPAID = '', FacName = '', FacRecptDate = ''
WHERE workorder_id > 0
AND (Tran2EPAID > '' OR Tran2CompName > '')


SET @intcounter = 0
UPDATE #tmp
SET @intcounter = line_id = @intcounter + 1

CREATE TABLE #return (
	line_id		int,
	description	text	)
-----------------------------------------------------------------------------------------------------------------------------------
-- -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
-----------------------------------------------------------------------------------------------------------------------------------
SET @line = 0

DECLARE cursor_populate_return CURSOR FOR 
SELECT ISNULL(
	RecordType + CHAR(9)
	+ ReportingYear + CHAR(9)
	+ ReportingMonth + CHAR(9)
	+ DefaultEPAID + CHAR(9)
	+ StateManDocNo + CHAR(9)
	+ GenEPAID + CHAR(9)
	+ GenName + CHAR(9)
	+ GenAddr1 + CHAR(9)
	+ GenAddr2 + CHAR(9)
	+ GenCity + CHAR(9)
	+ GenStateProv + CHAR(9)
	+ GenPostalCode + CHAR(9)
	+ GenCountry + CHAR(9)
	+ GenMailAddr1 + CHAR(9)
	+ GenMailAddr2 + CHAR(9)
	+ GenMailCity + CHAR(9)
	+ GenMailStateProv + CHAR(9)
	+ GenMailPostalCode + CHAR(9)
	+ GenMailCountry + CHAR(9)
	+ Tran1EPAID + CHAR(9)
	+ Tran1CompName + CHAR(9)
	+ Tran1RecptDate + CHAR(9)
	+ Tran2EPAID + CHAR(9)
	+ Tran2CompName + CHAR(9)
	+ Tran2RecptDate + CHAR(9)
	+ Tran3EPAID + CHAR(9)
	+ Tran3CompName + CHAR(9)
	+ Tran3RecptDate + CHAR(9)
	+ Tran4EPAID + CHAR(9)
	+ Tran4CompName + CHAR(9)
	+ Tran4RecptDate + CHAR(9)
	+ Tran5EPAID + CHAR(9)
	+ Tran5CompName + CHAR(9)
	+ Tran5RecptDate + CHAR(9)
	+ FacEPAID + CHAR(9)
	+ FacName + CHAR(9)
	+ FacRecptDate + CHAR(9)
	+ DiscrepInd + CHAR(9)
	+ DiscrepQty + CHAR(9)
	+ DiscrepType + CHAR(9)
	+ DiscrepResidue + CHAR(9)
	+ DiscrepPartial + CHAR(9)
	+ DiscrepFull + CHAR(9)
	+ DiscrepOther + CHAR(9)
	+ ManifestRef + CHAR(9)
	+ AltFacEPAID + CHAR(9)
	+ AltFacName + CHAR(9)
	+ AltFacRecpDate + CHAR(9)
	+ GenCertDate + CHAR(9)
	+ LineNum + CHAR(9)
	+ DOTDescr + CHAR(9)
	+ ContCnt + CHAR(9)
	+ ContType + CHAR(9)
	+ TotQty + CHAR(9)
	+ UnitWtVol + CHAR(9)
	+ WasteNo1 + CHAR(9)
	+ WasteNo2 + CHAR(9)
	+ WasteNo3 + CHAR(9)
	+ WasteNo4 + CHAR(9)
	+ WasteNo5 + CHAR(9)
	+ WasteNo6 + CHAR(9)
	+ MgmtCode + CHAR(9)
	+ Fee, '')
FROM #tmp
ORDER BY line_id


OPEN cursor_populate_return
FETCH NEXT FROM cursor_populate_return INTO @ls_description
WHILE @@FETCH_STATUS = 0 
BEGIN 
	SET @line = @line + 1
	INSERT INTO #return VALUES (@line, @ls_description)

	FETCH NEXT FROM cursor_populate_return INTO @ls_description
END
CLOSE cursor_populate_return
DEALLOCATE cursor_populate_return

-----------------------------------------------------------------------------------------------------------------------------------
-- -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
-----------------------------------------------------------------------------------------------------------------------------------

SELECT 
	#tmp.workorder_id,
	#tmp.company_id,
	#tmp.profit_ctr_id,
	#tmp.workorder_status,
	#tmp.StateManDocNo,
	#tmp.GenEPAID,
	#tmp.GenName,
	#tmp.Tran1CompName,
	#tmp.Tran1RecptDate,
	#tmp.Tran2CompName,
	#tmp.Tran2RecptDate,
	#tmp.FacName,
	#tmp.FacEPAID,
	#tmp.FacRecptDate,
	#tmp.GenCertDate,
	#tmp.LineNum,
	#tmp.ContCnt,
	#tmp.ContType,
	#tmp.TotQty,
	#tmp.UnitWtVol,
	#tmp.Fee,
	#return.Description
FROM #tmp 
INNER JOIN #return 
	ON #tmp.line_id = #return.line_id
ORDER BY #tmp.line_id, #tmp.GenName, #tmp.FacName, #tmp.company_id, #tmp.profit_ctr_id, #tmp.workorder_id,
	#tmp.StateManDocNo, #tmp.LineNum

DROP TABLE #tmp
DROP TABLE #return

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_ma_emor] TO [EQAI]
    AS [dbo];

