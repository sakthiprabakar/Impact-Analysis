CREATE OR ALTER PROCEDURE sp_rpt_air_emissions_const_worksheet
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@approval_code		varchar(15)
,	@treatment_id		int
,	@treatment_category	int
AS
/*******************************************************************************************************************************
PB Object(s): r_air_emissions_const_worksheet_report

05/07/2018	AM	EQAI-49948  Report - Air Emissions Constituents Received
03/11/2022	AM	DevOps:17098 - Added 'ug/kg', 'ppb' and 'ug/L' calculation
04/20/2023	MPM	DevOps 27242 - Modified the calcuation of pounds_emission so that it's done in the same way as was done to the 
				HAP Report under DevOps 17354.
07/06/2023 Nagaraj M Devops #67290 - Modified the ug/kg, ppb calculation from /0.0001 to * 0.000000001, and ug/L calculation from "0.001" to "* 8.3453 * 0.000000001"
03/18/2024 KS - DevOps 78200 - Updated the logic to fetch the ReceiptConstituent.concentration as following.
				If the 'Typical' value is stored (not null), then use the 'Typical' value for reporting purposes.
				If the 'Typical' value is null and the 'Min' value is null and 'Max' is not null, then use the 'Max' value for reporting purposes.
				If the 'Typical' value is null, and the 'Min' is not null and the 'Max' is not null, then use mid-point of 'Min' and 'Max' values for reporting purposes.
				If the 'Typical' value is null, and the 'Max' value is null, but the 'Min' value is not null, then use the 'Min' value for reporting purposes.
05/29/2025 KS - Rally US116196 - Constituent - Integer data type preventing CAS # entry

NOTE: This is copied from sp_rpt_hap_const_received.
 
copy of the "HAP Constituents Received Worksheet" and name it, "Air Emissions Constituents Received Worksheet."  
Change the report to look at the Constituents.Air_Permit_Restricted = 'T' OR Constituents.HAP = 'T' OR Constituents.caavoc = 'T'

sp_rpt_air_emissions_const_worksheet 32, 0, '01/1/2016', '03/31/2016', 'ALL' , -99, -99
sp_rpt_air_emissions_const_worksheet 21, 0, '01/1/2018', '03/31/2018', 'ALL' , -99, -99 //26801
*******************************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @debug int,
		@pound_ton_conversion float

DROP TABLE IF EXISTS #tri_work_table;				
CREATE TABLE #tri_work_table ( 
	company_id				int			null
,	profit_ctr_id			int			null
,	receipt_id				int			null
,	line_id					int			null
,	bulk_flag				char(1)		null
,	container_id			int			null
,	treatment_id			int			null
,	treatment_desc			varchar(50) null
,	approval_code			varchar(16) null
,	concentration			float		null
,	unit					varchar(10) null
,	density					float		null
,	const_id				int			null
,	cas_code				bigint		null
,	const_desc				varchar(50) null
,	hap						char(1)		null
,	VOC						char(1)		null
,	quantity				float		null
,	bill_unit_code			varchar(4)	null
,	container_size			varchar(15) null
,	pound_conv				float		null
,	container_count			int			null
,	pounds_received			float		null
,	consistency				varchar(20) null
,	c_density				float		null
,	pounds_constituent		float		null
,	ppm_concentration		float		null
,	location				varchar(16) null
,	waste_type_code			varchar(2)	null
,	location_report_flag	char(1)		null
,	reportable_category		int			null
,	reportable_category_desc varchar(60) null
,	generator_name			varchar(50) null
,	process_location		varchar(15) null
,	location_type			char(1)		null
,	emission_factor			float		null
,	control_efficiency_value	float	null
,	pounds_emission			float		null
,	disposal_date			datetime
,	tracking_num			varchar(15)	null
,   air_permit_restricted   char(1)		null 
,	sequence_id				int			null
)

SET NOCOUNT ON
SET @debug = 0
IF @treatment_id = -99 SET @treatment_id = NULL
IF @treatment_category = -99 SET @treatment_category = NULL

SET @pound_ton_conversion = 0.0005	--  1 / 2000 = 0.0005


/*	MPM - 4/20/2023 - DevOps 27242 - Corrected the calculation of pounds_emission.  The formula is:

	VOC(e) = SUM{ V(i) x W(i) x D(i) }   x   Er   x   [1 - A(e)]

	Where	VOC(e) = Cumulative VOC/HAP emissions from the unit during the period
		i = Each iteration of waste stream treated during the period
		V(i) = Volume of waste stream i processed
		W(i) = Weight fraction of VOC/HAP present in waste stream i processed
		D(i) = Density of waste stream i processed in appropriate unit; assumed to average 8.5 lbs/gal
		Er = Emission factor for VOC/HAP released from waste during treatment process 
		A(e) = Control efficiency

	Er (emission_factor) determination:

		1. If the emission factor is set on the process location for where the waste was managed (ProcessLocation.emission_factor), 
			use that.
		2. Else, if the emission factor is not set on the process location but exists in the site emission factor table 
			(ProfitCenterCCVOCDDVOHAP) for the company_id, profit_ctr_id and location_report_flag values in the corresponding 
			ProcessLocation row, use that.
		3. Else, if there is no row in the site emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 1.

	A(e) (control_efficiency_value) determination:
		1. If the control efficiency value exists in the site emission factor table (ProfitCenterCCVOCDDVOHAP) for the company_id, 
			profit_ctr_id and location_report_flag values in the corresponding ProcessLocation row, use that.
		2. Else, if there is no row in the emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 1.

	The values for emission_factor and control_efficiency_value in #tri_work_table are set in the union of select statements below that 
	insert into #tri_work_table.
*/

INSERT INTO #tri_work_table
	(company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	bulk_flag,
	container_id,
	treatment_id,
	treatment_desc,
	approval_code,
	concentration,
	unit,
	density,
	const_id,
	cas_code,
	const_desc,
	hap,
	VOC,
	quantity,
	bill_unit_code,
	container_size,
	pound_conv,
	container_count,
	pounds_received,
	consistency,
	c_density,
	pounds_constituent,
	ppm_concentration,
	location,
	waste_type_code,
	location_report_flag,
	reportable_category,
	reportable_category_desc,
	generator_name,
	process_location,
	location_type,
	emission_factor,
	control_efficiency_value,
	pounds_emission,
	disposal_date,
	tracking_num,
	air_permit_restricted,
	sequence_id)
SELECT
	Receipt.company_id,	
	Container.profit_ctr_id,
	Container.receipt_id,
	Container.line_id,
	Receipt.bulk_flag,
	Container.container_id,
	ContainerDestination.treatment_id,
	Treatment.treatment_desc,
	ProfileQuoteApproval.approval_code,
	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration 		
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration,
	ReceiptConstituent.unit,
	ProfileLab.density,
	ReceiptConstituent.const_id,
	Constituents.cas_code,
	Constituents.const_desc,
	Constituents.hap, 
	Constituents.voc,
	(1 * CONVERT(money, ContainerDestination.container_percent)) / 100 AS quantity,
	Receipt.bill_unit_code,
	Container.container_size AS container_size,
	999999999999.99999 AS pound_conv,
	Receipt.container_count,
	999999999999.99999 AS pounds_received,
	ProfileLab.consistency,
	ProfileLab.density AS c_density,
	999999999999.99999 AS pounds_constituent,
	999999999999.99999 AS ppm_concentration,
	ContainerDestination.location,
	WasteCode.waste_type_code, 
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Treatment.reportable_category,
	TreatmentCategory.reportable_category_desc,
	Generator.generator_name,
	ContainerDestination.location,
	ContainerDestination.location_type,  
	COALESCE(ProcessLocation.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value,
	null as pounds_emission,
	ContainerDestination.disposal_date,
	ContainerDestination.tracking_num,
	Constituents.air_permit_restricted,
	ContainerDestination.sequence_id
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id	
JOIN ContainerDestination
	ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id =  Container.line_id
	AND ContainerDestination.container_id = Container.container_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id)
	AND Treatment.reportable_category = ISNULL(@treatment_category, treatment.reportable_category)
	AND Treatment.reportable_category <> 4
JOIN TreatmentCategory
	ON TreatmentCategory.reportable_category = Treatment.reportable_category
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Receipt.company_id
	AND ReceiptConstituent.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Receipt.receipt_id
	AND ReceiptConstituent.line_id = Receipt.line_id
	AND ReceiptConstituent.concentration IS NOT NULL
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.cas_code IS NOT NULL
	AND ( Constituents.Air_Permit_Restricted = 'T' OR Constituents.HAP = 'T' OR Constituents.caavoc = 'T' )
left outer JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = ProcessLocation.company_id
	AND pccc.profit_ctr_id = ProcessLocation.profit_ctr_id
	AND pccc.location_report_flag =  ProcessLocation.location_report_flag 
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.bulk_flag = 'F'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND NOT EXISTS (SELECT * FROM ContainerConstituent CC WHERE Container.receipt_id = CC.receipt_id 
					AND Container.line_id = CC.line_id AND Container.profit_ctr_id = CC.profit_ctr_id
					AND Container.company_id = CC.company_id)
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to 
		
UNION
SELECT
	Receipt.company_id,	
	Container.profit_ctr_id,
	Container.receipt_id,
	Container.line_id,
	Receipt.bulk_flag,
	Container.container_id,
	ContainerDestination.treatment_id,
	Treatment.treatment_desc,
	ProfileQuoteApproval.approval_code,
	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration 		
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration,
	ReceiptConstituent.unit,
	ProfileLab.density,
	ContainerConstituent.const_id,
	Constituents.cas_code,
	Constituents.const_desc,
	Constituents.hap,
	Constituents.voc, 
	(1 * CONVERT(money, ContainerDestination.container_percent)) / 100 AS quantity,
	Receipt.bill_unit_code,
	Container.container_size AS container_size,
	999999999999.99999 AS pound_conv,   
	Receipt.container_count,
	999999999999.99999 AS pounds_received,
	ProfileLab.consistency,  
	ProfileLab.density AS c_density,
	999999999999.99999 AS pounds_constituent,
	999999999999.99999 AS ppm_concentration,
	ContainerDestination.location,
	WasteCode.waste_type_code,   
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Treatment.reportable_category,
	TreatmentCategory.reportable_category_desc,
	Generator.generator_name,
	ContainerDestination.location,
	ContainerDestination.location_type,
	COALESCE(ProcessLocation.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value,
	null as pounds_emission,
	ContainerDestination.disposal_date,
	ContainerDestination.tracking_num,
	Constituents.air_permit_restricted,
	ContainerDestination.sequence_id
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id =  Container.line_id
	AND ContainerDestination.container_id = Container.container_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id)
	AND Treatment.reportable_category = ISNULL(@treatment_category, treatment.reportable_category)
	AND Treatment.reportable_category <> 4
JOIN TreatmentCategory
	ON TreatmentCategory.reportable_category = Treatment.reportable_category	
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Container.company_id
	AND ReceiptConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Container.receipt_id
	AND ReceiptConstituent.line_id = Container.line_id
	AND ReceiptConstituent.concentration IS NOT NULL	
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.cas_code IS NOT NULL
	AND ( Constituents.Air_Permit_Restricted = 'T' OR Constituents.HAP = 'T' OR Constituents.caavoc = 'T' )
JOIN ContainerConstituent
	ON ContainerConstituent.company_id = Container.company_id
	AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ContainerConstituent.receipt_id = Container.receipt_id
	AND ContainerConstituent.line_id = Container.line_id
	AND ContainerConstituent.container_id = Container.container_id
	AND ContainerConstituent.const_id = ReceiptConstituent.const_id
left outer JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid	
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = ProcessLocation.company_id
	AND pccc.profit_ctr_id = ProcessLocation.profit_ctr_id
	AND pccc.location_report_flag =  ProcessLocation.location_report_flag 
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.bulk_flag = 'F'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to  -- Added 4/6/16

UNION
SELECT	
	Receipt.company_id,
	Container.profit_ctr_id,
	Container.receipt_id,   
	Container.line_id,
	Receipt.bulk_flag,
	Container.container_id,   
	ContainerDestination.treatment_id,   
	Treatment.treatment_desc,   
	ProfileQuoteApproval.approval_code,
	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration 					 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration,
	ReceiptConstituent.unit,
	ProfileLab.density,
	ReceiptConstituent.const_id,
	Constituents.cas_code,
	Constituents.const_desc,
	Constituents.hap,
	Constituents.voc,
	(Receipt.quantity * CONVERT(money, ContainerDestination.container_percent)) / 100 AS quantity,
	Receipt.bill_unit_code,
	Container.container_size AS container_size,
	999999999999.99999 AS pound_conv,   
	Receipt.container_count,
	999999999999.99999 AS pounds_received,
	ProfileLab.consistency,  
	ProfileLab.density AS c_density,
	999999999999.99999 AS pounds_constituent,
	999999999999.99999 AS ppm_concentration,
	ContainerDestination.location,
	WasteCode.waste_type_code,   
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Treatment.reportable_category,
	TreatmentCategory.reportable_category_desc,
	Generator.generator_name,
	ContainerDestination.location,
	ContainerDestination.location_type,
	COALESCE(ProcessLocation.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value,
	null as pounds_emission,
	ContainerDestination.disposal_date,
	ContainerDestination.tracking_num,
	Constituents.air_permit_restricted,
	ContainerDestination.sequence_id
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id =  Container.line_id
	AND ContainerDestination.container_id = Container.container_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id)
	AND Treatment.reportable_category = ISNULL(@treatment_category, treatment.reportable_category)
	AND Treatment.reportable_category <> 4
JOIN TreatmentCategory
	ON TreatmentCategory.reportable_category = Treatment.reportable_category
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Receipt.company_id
	AND ReceiptConstituent.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Receipt.receipt_id
	AND ReceiptConstituent.line_id = Receipt.line_id
	AND ReceiptConstituent.concentration IS NOT NULL	
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.cas_code IS NOT NULL
	AND ( Constituents.Air_Permit_Restricted = 'T' OR Constituents.HAP = 'T' OR Constituents.caavoc = 'T' )
left outer JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid	
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = ProcessLocation.company_id
	AND pccc.profit_ctr_id = ProcessLocation.profit_ctr_id
	AND pccc.location_report_flag =  ProcessLocation.location_report_flag 
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.bulk_flag = 'T'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND NOT EXISTS (SELECT * FROM ContainerConstituent CC WHERE Container.receipt_id = CC.receipt_id 
					AND Container.line_id = CC.line_id AND Container.profit_ctr_id = CC.profit_ctr_id
					AND Container.company_id = CC.company_id)
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
		
UNION
SELECT	
	Receipt.company_id,
	Container.profit_ctr_id,
	Container.receipt_id,
	Container.line_id,
	Receipt.bulk_flag,
	Container.container_id,
	ContainerDestination.treatment_id,
	Treatment.treatment_desc,
	ProfileQuoteApproval.approval_code,
	CASE
		WHEN ReceiptConstituent.typical_concentration IS NOT NULL 
			THEN ReceiptConstituent.typical_concentration  
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN ReceiptConstituent.concentration 
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL 
			THEN ReceiptConstituent.min_concentration 		
		WHEN ReceiptConstituent.typical_concentration IS NULL AND ReceiptConstituent.min_concentration IS NOT NULL AND ReceiptConstituent.concentration IS NOT NULL 
			THEN (ReceiptConstituent.min_concentration + ReceiptConstituent.concentration)/2
	END AS concentration,
	ReceiptConstituent.unit,
	ProfileLab.density,
	ContainerConstituent.const_id,
	Constituents.cas_code,
	Constituents.const_desc,
	Constituents.hap,
	Constituents.voc,
	(Receipt.quantity * CONVERT(money, ContainerDestination.container_percent)) / 100 AS quantity,
	Receipt.bill_unit_code,
	Container.container_size AS container_size,
	999999999999.99999 AS pound_conv,   
	Receipt.container_count,
	999999999999.99999 AS pounds_received,
	ProfileLab.consistency,  
	ProfileLab.density AS c_density,
	999999999999.99999 AS pounds_constituent,
	999999999999.99999 AS ppm_concentration,
	ContainerDestination.location,
	WasteCode.waste_type_code,   
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Treatment.reportable_category,
	TreatmentCategory.reportable_category_desc,
	Generator.generator_name,
	ContainerDestination.location,
	ContainerDestination.location_type,
	COALESCE(ProcessLocation.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value,
	null as pounds_emission,
	ContainerDestination.disposal_date,
	ContainerDestination.tracking_num,
	Constituents.air_permit_restricted,
	ContainerDestination.sequence_id
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id =  Container.line_id
	AND ContainerDestination.container_id = Container.container_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id)
	AND Treatment.reportable_category = ISNULL(@treatment_category, treatment.reportable_category)
	AND Treatment.reportable_category <> 4
JOIN TreatmentCategory
	ON TreatmentCategory.reportable_category = Treatment.reportable_category	
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Container.company_id
	AND ReceiptConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Container.receipt_id
	AND ReceiptConstituent.line_id = Container.line_id
	AND ReceiptConstituent.concentration IS NOT NULL	
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.cas_code IS NOT NULL
	AND ( Constituents.Air_Permit_Restricted = 'T' OR Constituents.HAP = 'T' OR Constituents.caavoc = 'T' )
JOIN ContainerConstituent
	ON ContainerConstituent.company_id = Container.company_id
	AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ContainerConstituent.receipt_id = Container.receipt_id
	AND ContainerConstituent.line_id = Container.line_id
	AND ContainerConstituent.container_id = Container.container_id
	AND ContainerConstituent.const_id = ReceiptConstituent.const_id
left outer JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
	AND ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.approval_code = Receipt.approval_code
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid	
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = ProcessLocation.company_id
	AND pccc.profit_ctr_id = ProcessLocation.profit_ctr_id
	AND pccc.location_report_flag =  ProcessLocation.location_report_flag 
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.bulk_flag = 'T'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
ORDER BY treatment.treatment_desc, ProfileQuoteApproval.approval_code

IF @debug = 1 SELECT * FROM #tri_work_table

IF @debug = 1 PRINT 'UPDATE #tri_work_table SET container_size'
UPDATE #tri_work_table SET container_size = bill_unit_code WHERE container_size = '' 
UPDATE #tri_work_table SET container_size = bill_unit_code WHERE bulk_flag = 'T'

UPDATE #tri_work_table SET container_size = rp.bill_unit_code
FROM ReceiptPrice rp
WHERE #tri_work_table.bulk_flag = 'F'
	AND #tri_work_table.receipt_id = rp.receipt_id
	AND #tri_work_table.line_id = rp.line_id
	AND #tri_work_table.profit_ctr_id = rp.profit_ctr_id
	AND #tri_work_table.company_id = rp.company_id
	AND #tri_work_table.container_size IS NULL
	AND rp.price_id = (SELECT MIN(price_id) FROM ReceiptPrice rp2 WHERE rp2.receipt_id = rp.receipt_id 
						AND rp2.line_id = rp.line_id AND rp2.profit_ctr_id = rp.profit_ctr_id
						AND rp2.company_id = rp.company_id)

--IF @debug = 1 PRINT 'SELECT * FROM #tri_work_table WHERE container_size IS NULL OR container_size = '''
--IF @debug = 1 SELECT * FROM #tri_work_table WHERE container_size IS NULL OR container_size = ''

UPDATE #tri_work_table 
SET pound_conv = b.pound_conv
	--pounds_received = #tri_work_table.quantity * b.pound_conv 
FROM BillUnit b
WHERE #tri_work_table.container_size = b.bill_unit_code
	AND b.pound_conv is not null
	AND ((#tri_work_table.bill_unit_code IS NULL)
		OR (#tri_work_table.bill_unit_code <> #tri_work_table.container_size)
		OR (#tri_work_table.pound_conv = 999999999999.99999))
		
UPDATE #tri_work_table 
SET pounds_received = dbo.fn_receipt_weight_container(#tri_work_table.receipt_id, #tri_work_table.line_id, #tri_work_table.profit_ctr_id, #tri_work_table.company_id, #tri_work_table.container_id, #tri_work_table.sequence_id) 
FROM #tri_work_table

IF @debug = 1 SELECT * FROM #tri_work_table --where tri_category = 'N230'
--Remove items from #tri_work_table that have no valid pound_conv
DELETE FROM #tri_work_table where pound_conv = 999999999999.99999

CREATE INDEX trans_type ON #Tri_work_table (consistency)

/* the following is used to standardize the consistency values */

UPDATE  #tri_work_table SET c_density = 12.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'solid%'
UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'sludge%'
UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'semi-solid%'
UPDATE  #tri_work_table SET c_density = 8.3453 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'liquid%'
UPDATE  #tri_work_table SET c_density = 7.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'dust%'
UPDATE  #tri_work_table SET c_density = 5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'debris%'

/* default catch-all */
UPDATE  #tri_work_table SET c_density = 12.5 WHERE c_density IS NULL OR c_density = 0 

UPDATE #tri_work_table SET pounds_constituent = (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) / 1000000) )
WHERE unit IN ('ppm','ppmw','mg/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = (ROUND(pounds_received, 5) * (ROUND(concentration, 5) / 100) )
WHERE unit = '%' AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 0.000008345))
WHERE unit = 'mg/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

--DevOps:17098 - AM - Added 'ug/kg', 'ppb' and 'ug/L' calculation

UPDATE #tri_work_table SET pounds_constituent = Round ( (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) * 0.000000001) ) , 5 )
WHERE unit IN ('ppb','ug/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = Round ( ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 8.3453 * 0.000000001)) , 5 )
WHERE unit = 'ug/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = 0 WHERE pounds_constituent =  999999999999.99999

UPDATE #tri_work_table SET ppm_concentration = ROUND(((pounds_constituent * 1000000)/pounds_received),5)
WHERE pounds_received IS NOT NULL AND pounds_received > 0 AND pounds_constituent IS NOT NULL

UPDATE #tri_work_table SET ppm_concentration = 0 WHERE ppm_concentration =  999999999999.99999 

--Update #tri_work_table SET emission_factor = ( Round ( ( ( (concentration * pounds_received)/ pounds_received  ) * c_density), 5 ) )
--WHERE unit IN ('mg/kg', 'mg/L','ppm','ppmw') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

--Update #tri_work_table SET emission_factor = ( Round ( (( (concentration * pounds_received) / pounds_received) * c_density), 5 ) )
--WHERE unit = '%' AND concentration IS NOT NULL AND pounds_received IS NOT NULL

--UPDATE #tri_work_table SET pounds_emission = round((pounds_constituent * emission_factor),8)

-- MPM - 4/20/2023 - DevOps 27242 - Corrected the calculation of pounds_emission.  
-- The formula is: pounds_emission = pounds_constituent * emission_factor * (1 - control_efficiency_value)

UPDATE #tri_work_table SET pounds_emission = ROUND(pounds_constituent * emission_factor * (1 - control_efficiency_value), 8)

IF @debug = 1
BEGIN
	SELECT * FROM #tri_work_table
END
SELECT
	#tri_work_table.company_id,	
	#tri_work_table.profit_ctr_id,
	const_id,
	cas_code,
	const_desc,
	hap,
	voc,
	treatment_id,
	treatment_desc,
	approval_code,
	ROUND(SUM(concentration * pounds_received) / SUM(pounds_received), 8) AS concentration,
	unit,
	density,
	SUM(quantity) AS quantity,
	container_size AS bill_unit_code,
	pound_conv,
	ROUND(SUM(pounds_received), 8) AS pounds_received,
	consistency,
	c_density,
	ROUND(SUM(pounds_constituent), 8) AS pounds_constituent,
	generator_name,
	ROUND(SUM(pounds_emission), 8) AS pounds_emission,
	process_location,
	location_type,
	emission_factor,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	tracking_num,
	air_permit_restricted
FROM #tri_work_table
JOIN Company
	ON Company.company_id = #tri_work_table.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = #tri_work_table.company_id
	AND ProfitCenter.profit_ctr_id = #tri_work_table.profit_ctr_id
WHERE pounds_constituent > 0.000005
AND   disposal_date BETWEEN @date_from AND @date_to
GROUP BY 
	#tri_work_table.company_id,	
	#tri_work_table.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	const_id, 
	cas_code, 
	const_desc, 
	hap,
	voc,
	treatment_id, 
	treatment_desc, 
	approval_code, 
	consistency,
	density, 
	container_size,
	c_density, 
	pound_conv, 
	unit, 
	generator_name,
    process_location,
	location_type,
    emission_factor,
	tracking_num,
	air_permit_restricted
ORDER BY const_id, CAS_code, treatment_id, approval_code, process_location
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_air_emissions_const_worksheet] TO [EQAI];
GO
