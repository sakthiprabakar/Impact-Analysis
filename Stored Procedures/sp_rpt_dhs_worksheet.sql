CREATE PROCEDURE [dbo].[sp_rpt_dhs_worksheet]
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@approval_code		varchar(50)
,	@treatment_id		int
AS
/***********************************************************************
This procedure runs for the DHS (Department of Homeland Security)
Worksheet by Approval.

PB Object(s):	r_dhs_by_approval
				w_report_master_hz_reports

01/11/2008 JDB	Created; copied from sp_tri.  Commented out update from
				tri_consistency_xref table.  Added join to WasteCodeCAS
				and ReceiptWasteCode.
11/05/2009 JDB	Removed 'AND Treatment.reportable_category <> 4'
				from the WHERE clause per Sheila Cunningham.
12/02/2009 JDB	Removed joins to Container tables because they need to know when
				the DHS constituents get here regardless of where they go later.
				Date range uses receipt_date now.
11/17/2010 SK	Added company_ID as input arg and joins to company_id
				SP only used for report "DHS Worksheet by Approval" in PB, hence from old sp sp_rpt_dhs.sql
				removed all code for DHS summary(including arg reporttype). 
				Report runs only for a non-zero valid company
				created new on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
12/24/2013 AM   Added manifest columns and get pounds_received from fn_receipt_weight_line.
04/24/2018 MPM	Added air permit status.
03/11/2022 AM DevOps:17098 - Added 'ug/kg', 'ppb' and 'ug/L' calculation
05/27/2022 AM DevOPs:42193 - Corrected #tri_work_table name to #dhs_work_table
07/06/2023 Nagaraj M Devops #67290 - Modified the ug/kg, ppb calculation from /0.0001 to * 0.000000001, and ug/L calculation from "0.001" to "* 8.3453 * 0.000000001"							
03/18/2024 KS - DevOps 78200 - Updated the logic to fetch the ReceiptConstituent.concentration as following.
				If the 'Typical' value is stored (not null), then use the 'Typical' value for reporting purposes.
				If the 'Typical' value is null and the 'Min' value is null and 'Max' is not null, then use the 'Max' value for reporting purposes.
				If the 'Typical' value is null, and the 'Min' is not null and the 'Max' is not null, then use mid-point of 'Min' and 'Max' values for reporting purposes.
				If the 'Typical' value is null, and the 'Max' value is null, but the 'Min' value is not null, then use the 'Min' value for reporting purposes.
sp_rpt_dhs_worksheet 21, 0, '1/1/2009', '1/31/2009', 'ALL', -99
sp_rpt_dhs_worksheet 21, 0, '4/1/2018', '4/24/2018', 'ALL', -99

***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON

-- Non-bulk, no ContainerConstituent
SELECT	
	Receipt.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.bulk_flag
,	Receipt.treatment_id
,	Treatment.treatment_desc
,	ProfileQuoteApproval.approval_code
,	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration 					 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration
,	ReceiptConstituent.unit
,	ProfileLab.density
,	ReceiptConstituent.const_id
,	Constituents.cas_code
,	Constituents.const_desc
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.bill_unit_code AS container_size
,	999999999999.99999 AS pound_conv
,	Receipt.container_count
,	999999999999.99999 AS pounds_received
,	Receipt.company_id
,	Company.company_name
,	ProfileLab.consistency
,	ProfileLab.density AS c_density
,	999999999999.99999 AS pounds_constituent
,	999999999999.99999 AS ppm_concentration
,	WasteCode.waste_type_code
,	'' AS tri_category
,	Treatment.reportable_category
,	TreatmentCategory.reportable_category_desc
,	Generator.generator_name
,   Receipt.manifest_quantity
,   Receipt.manifest_unit
,   Receipt.manifest_line
,   Receipt.manifest 
,	aps.air_permit_status_code
,	IsNull(ProfitCenter.air_permit_flag, 'F') as air_permit_flag
INTO #dhs_work_table 
FROM Receipt
INNER JOIN ReceiptConstituent 
	ON Receipt.company_id = ReceiptConstituent.company_id
	AND Receipt.profit_ctr_id = ReceiptConstituent.profit_ctr_id
	AND Receipt.receipt_id = ReceiptConstituent.receipt_id
	AND Receipt.line_id = ReceiptConstituent.line_id
	AND ReceiptConstituent.concentration IS NOT NULL
INNER JOIN ReceiptWasteCode 
	ON Receipt.company_id = ReceiptWasteCode.company_id
	AND Receipt.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
	AND Receipt.receipt_id = ReceiptWasteCode.receipt_id
	AND Receipt.line_id = ReceiptWasteCode.line_id
INNER JOIN ProfileQuoteApproval
	 ON Receipt.company_id = ProfileQuoteApproval.company_id
	AND Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND Receipt.approval_code = ProfileQuoteApproval.approval_code
INNER JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN ProfileLab
	ON ProfileLab.profile_id = ProfileQuoteApproval.profile_id
	AND ProfileLab.type = 'A'
INNER JOIN Company 
	ON Receipt.company_id = Company.company_id
INNER JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN Generator 
	ON Receipt.generator_id = Generator.generator_id
INNER JOIN Treatment 
	ON Receipt.company_id = Treatment.company_id
	AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
	AND Receipt.treatment_id = Treatment.treatment_id
INNER JOIN TreatmentCategory 
	ON Treatment.reportable_category = TreatmentCategory.reportable_category
INNER JOIN WasteCode 
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
INNER JOIN Constituents 
	ON ReceiptConstituent.const_id = Constituents.const_id
	AND Constituents.DHS = 'T'
	AND Constituents.cas_code IS NOT NULL
INNER JOIN WasteCodeCAS 
	ON Constituents.cas_code = WasteCodeCAS.cas_code
	AND WasteCodeCAS.waste_code_uid = ReceiptWasteCode.waste_code_uid
LEFT OUTER JOIN AirPermitStatus aps
	ON aps.air_permit_status_uid = ProfileQuoteApproval.air_permit_status_uid
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND (@treatment_id = -99 OR Receipt.treatment_id = ISNULL(@treatment_id, Receipt.treatment_id))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND ((Company.company_id <> 3) OR ((Company.company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.bulk_flag = 'F'

UNION

-- Bulk, no ContainerConstituent
SELECT	
	Receipt.profit_ctr_id
,	ProfitCenter.profit_ctr_name
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.bulk_flag
,	Receipt.treatment_id
,	Treatment.treatment_desc
,	ProfileQuoteApproval.approval_code   
,	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration
,	ReceiptConstituent.unit
,	ProfileLab.density
,	ReceiptConstituent.const_id
,	Constituents.cas_code
,	Constituents.const_desc
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.bill_unit_code AS container_size
,	999999999999.99999 AS pound_conv
,	Receipt.container_count
,	999999999999.99999 AS pounds_received
,	Receipt.company_id
,	Company.company_name
,	ProfileLab.consistency
,	ProfileLab.density AS c_density
,	999999999999.99999 AS pounds_constituent
,	999999999999.99999 AS ppm_concentration
,	WasteCode.waste_type_code
,	'' AS tri_category
,	Treatment.reportable_category
,	TreatmentCategory.reportable_category_desc
,	Generator.generator_name
,   Receipt.manifest_quantity
,   Receipt.manifest_unit
,   Receipt.manifest_line
,    Receipt.manifest 
,	aps.air_permit_status_code
,	IsNull(ProfitCenter.air_permit_flag, 'F') as air_permit_flag
FROM Receipt
INNER JOIN ReceiptConstituent 
	ON Receipt.company_id = ReceiptConstituent.company_id
	AND Receipt.profit_ctr_id = ReceiptConstituent.profit_ctr_id
	AND Receipt.receipt_id = ReceiptConstituent.receipt_id
	AND Receipt.line_id = ReceiptConstituent.line_id
	AND ReceiptConstituent.concentration IS NOT NULL
INNER JOIN ReceiptWasteCode 
	ON Receipt.company_id = ReceiptWasteCode.company_id
	AND Receipt.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
	AND Receipt.receipt_id = ReceiptWasteCode.receipt_id
	AND Receipt.line_id = ReceiptWasteCode.line_id
INNER JOIN ProfileQuoteApproval
	 ON Receipt.company_id = ProfileQuoteApproval.company_id
	AND Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND Receipt.approval_code = ProfileQuoteApproval.approval_code
INNER JOIN Profile
	ON Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN ProfileLab
	ON ProfileLab.profile_id = ProfileQuoteApproval.profile_id
	AND ProfileLab.type = 'A'
INNER JOIN Company 
	ON Receipt.company_id = Company.company_id
INNER JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
INNER JOIN Generator 
	ON Receipt.generator_id = Generator.generator_id
INNER JOIN Treatment 
	ON Receipt.company_id = Treatment.company_id
	AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
	AND Receipt.treatment_id = Treatment.treatment_id
INNER JOIN TreatmentCategory 
	ON Treatment.reportable_category = TreatmentCategory.reportable_category
INNER JOIN WasteCode 
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
INNER JOIN Constituents 
	ON ReceiptConstituent.const_id = Constituents.const_id
	AND Constituents.DHS = 'T'
	AND Constituents.cas_code IS NOT NULL
INNER JOIN WasteCodeCAS 
	ON Constituents.cas_code = WasteCodeCAS.cas_code
	AND WasteCodeCAS.waste_code_uid = ReceiptWasteCode.waste_code_uid
LEFT OUTER JOIN AirPermitStatus aps
	ON aps.air_permit_status_uid = ProfileQuoteApproval.air_permit_status_uid
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND (@treatment_id = -99 OR Receipt.treatment_id = ISNULL(@treatment_id, Receipt.treatment_id))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND ((Company.company_id <> 3) OR ((Company.company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.bulk_flag = 'T'
ORDER BY treatment.treatment_desc,  ProfileQuoteApproval.approval_code

UPDATE #dhs_work_table SET container_size = bill_unit_code WHERE container_size = '' 
UPDATE #dhs_work_table SET container_size = bill_unit_code WHERE bulk_flag = 'T'

UPDATE #dhs_work_table SET container_size = rp.bill_unit_code
FROM ReceiptPrice rp
WHERE #dhs_work_table.bulk_flag = 'F'
	AND #dhs_work_table.receipt_id = rp.receipt_id
	AND #dhs_work_table.line_id = rp.line_id
	AND #dhs_work_table.profit_ctr_id = rp.profit_ctr_id
	AND #dhs_work_table.company_id = rp.company_id
	AND #dhs_work_table.container_size IS NULL
	AND rp.price_id = ( SELECT MIN(price_id) FROM ReceiptPrice rp2 
						WHERE rp2.receipt_id = rp.receipt_id 
							AND rp2.line_id = rp.line_id
							AND rp2.profit_ctr_id = rp.profit_ctr_id
							AND rp2.company_id = rp.company_id )

UPDATE #dhs_work_table 
	SET pound_conv = b.pound_conv
-- 	pounds_received = #dhs_work_table.quantity * b.pound_conv -  Anitha - Commented this line of code to get pounds_received from fn_receipt_weight_line
FROM BillUnit b
WHERE #dhs_work_table.container_size = b.bill_unit_code
AND b.pound_conv IS NOT NULL
AND ((#dhs_work_table.bill_unit_code IS NULL)
		OR (#dhs_work_table.bill_unit_code <> #dhs_work_table.container_size)
		OR (#dhs_work_table.pound_conv = 999999999999.99999))

--Remove items from #dhs_work_table that have no valid pound_conv
DELETE FROM #dhs_work_table where pound_conv = 999999999999.99999

CREATE INDEX trans_type ON #dhs_work_table (consistency)

/* the following is used to standardize the consistency values */		-- Commented out 1/4/08 JDB
-- UPDATE #dhs_work_table SET consistency = tri_consistency_xref.after_value 
-- FROM tri_consistency_xref
-- WHERE #dhs_work_table.consistency = tri_consistency_xref.before_value

UPDATE  #dhs_work_table SET c_density = 12.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'solid%'
UPDATE  #dhs_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'sludge%'
UPDATE  #dhs_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'semi-solid%'
UPDATE  #dhs_work_table SET c_density = 8.3453 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'liquid%'
UPDATE  #dhs_work_table SET c_density = 7.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'dust%'
UPDATE  #dhs_work_table SET c_density = 5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'debris%'

-- Anitha added below line of code to get pounds_received
UPDATE  #dhs_work_table SET pounds_received = ISNULL( dbo.fn_receipt_weight_line(receipt_id, line_id, @profit_ctr_id, @company_id),0 )

/* default catch-all */
UPDATE  #dhs_work_table SET c_density = 12.5 WHERE c_density IS NULL OR c_density = 0 

UPDATE #dhs_work_table SET pounds_constituent = (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) / 1000000) )
WHERE unit IN ('ppm','ppmw','mg/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #dhs_work_table SET pounds_constituent = (ROUND(pounds_received, 5) * (ROUND(concentration, 5) / 100) )
WHERE unit = '%' AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #dhs_work_table SET pounds_constituent = ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 0.000008345))
WHERE unit = 'mg/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

--DevOps:17098 - AM - Added 'ug/kg', 'ppb' and 'ug/L' calculation

UPDATE #dhs_work_table SET pounds_constituent = Round ( (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) * 0.000000001) ) , 5 )
WHERE unit IN ('ppb','ug/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #dhs_work_table SET pounds_constituent = Round ( ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 8.3453 * 0.000000001)) , 5 )
WHERE unit = 'ug/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #dhs_work_table SET pounds_constituent = 0 
WHERE pounds_constituent =  999999999999.99999

UPDATE #dhs_work_table SET ppm_concentration = ROUND(((pounds_constituent * 1000000)/pounds_received),5)
WHERE pounds_received IS NOT NULL AND pounds_received > 0 AND pounds_constituent IS NOT NULL

UPDATE #dhs_work_table SET ppm_concentration = 0 
WHERE ppm_concentration =  999999999999.99999

-- Select Results for DHS WorkSheet By Approval	
SELECT	
	profit_ctr_id
,	profit_ctr_name
,	const_id
,	cas_code
,	const_desc
,	treatment_id
,	treatment_desc
,	approval_code
,	ROUND(SUM(concentration * pounds_received) / SUM(pounds_received), 5) AS concentration
,	unit
,	density
,	SUM(quantity) AS quantity
,	container_size AS bill_unit_code
,	pound_conv
,	ROUND( pounds_received, 5) AS pounds_received --  removed sum 
,	company_id
,	company_name
,	consistency
,	c_density
,	ROUND(pounds_constituent, 5) AS pounds_constituent
,	tri_category
,	generator_name
,   manifest_quantity
,   manifest_unit 
,   manifest_line
,   manifest 
,	air_permit_status_code
,	air_permit_flag
FROM #dhs_work_table
WHERE pounds_constituent > 0.000005
GROUP BY 
	profit_ctr_id
,	profit_ctr_name
,	company_id
,	company_name
,	const_id
,	cas_code
,	const_desc
,	treatment_id
,	treatment_desc
,	approval_code
,	air_permit_status_code
,	air_permit_flag
,	consistency
,	density
,	container_size
,	c_density
,	pound_conv
,	unit
,	tri_category
,	generator_name
,   manifest_quantity
,   manifest_unit 
,   manifest_line
,   manifest 
,   pounds_received
,   pounds_constituent
ORDER BY const_id, CAS_code, treatment_id, approval_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_dhs_worksheet] TO [EQAI]
    AS [dbo];

