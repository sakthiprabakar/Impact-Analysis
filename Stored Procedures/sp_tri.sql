DROP PROCEDURE IF EXISTS [dbo].[sp_tri]
GO

CREATE PROCEDURE [dbo].[sp_tri]
	@company_id		int
,	@profit_ctr_id		int
,	@date_from		datetime
,	@date_to		datetime
,	@approval_code		varchar(15)
,	@treatment_id		int
,	@report_type		int
,	@category_type   varchar(15)
,	@debug			int

AS
/***********************************************************************
This procedure runs for the TRI Report and Worksheet.

Filename:	L:\Apps\SQL\EQAI\sp_tri.sql
PB Object(s):	r_tri_by_approval
		r_tri_summary
		r_tri_worksheet

Report_type is used to determine if this is the Summary or Worksheet.
IF report_type = 1, Summary
IF report_type = 2, Worksheet

The Summary report uses a field called record_type to distinguish the different types of detail/subtotal information.
record_type = 1, This is the raw data from the queries
record_type = 2, This information is the subtotal by constituent
record_type = 3, This information is the subtotal by treatmentprocess per constituent
record_type = 4, This information is the total by constituent for the whole report.
record_type = 5, This information is the total by treatmentprocess for the whole report.

--IF record_type = 2, This information is the SubTotal by category (i.e. Haz, NonHaz, TransTax, etc.) per constituent
--IF record_type = 3, This information is the SubTotal by location (i.e. 8A, 10B, WAYNE, etc.) per constituent
--IF record_type = 4, This information is the Total by category (i.e. Haz, NonHaz, TransTax, etc.) for the whole report
--IF record_type = 5, This information is the Total by category (i.e. Haz, NonHaz, TransTax, etc.) for the whole report

05/10/1999 LJT	Added a check to not select if constituent tri flag <> 'T'
06/09/1999 LJT	Added the consistency xref look up
05/17/2000 JDB	Added subtotal and east/west calculations for report type 1
06/09/2000 JDB	Modified to return one record per treatment per cas code (into #tri_work_table_4)
09/28/2000 LJT	Changed = NULL to is NULL and <> null to is not null
03/01/2001 JDB	Modified to return all locations and subtotal their weights; removed east/west subtotals
05/15/2001 JDB	Removed update with tri_consistency_xref table; rounded pounds_constituent to integer;
		Removed round of pounds_constituent into table #tri_work_table_2;
		Added density calculations for dust and semi-solid 
05/31/2001 JDB	Eliminated subtotal for APCM; added treatment IDs 3,6,9,12,15,39,40 to NonHaz subtotal;
		Added treatment ID 8 to Haz subtotal
03/27/2002 JDB	Removed table alias from Update statements
04/09/2002 JDB	Modified Location to be varchar(20) (was causing data to be truncated)
08/05/2002 SCC	Added trans_mode to receipt join
09/25/2002 JDB	Modified to use the treatment.profit_ctr_id field
02/06/2003 JDB	Modified the select into #tri_work_table_4 to use a 20 character blank string (was causing data to be truncated)
03/21/2003 JDB	Modified treatment code lists to accurately reflect the treatments (WDI split out to use its treatments)
07/16/2003 JDB	Modified treatment code lists to accurately reflect the treatments (EQRR split out to use its treatments)
05/14/2004 SCC	Modified to use ApprovalConstituent and join on profit_ctr_id
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table.
09/28/2004 MK 	Reversed the Constituents.TRI flag so TRI = TRUE and non-tri = False
10/15/2004 MK 	Rewrote to use receiptconstituents for unit and concentration where available. Added check for Containerconstituent
		records. Added group totals for location flag (E,W).  Use Constituent ID as primary key instead of CasCode. Changed
		concentration on Worksheet to average concentration per pounds received. Added debug flag
11/18/2004 MK	Modified to omit approval 000686 in Company 03 to prevent double billing between EQ companies
03/17/2005 JDB	Added ReceiptPrice table to get correct quantity/unit;
		Changed join to BillUnit table to be to ReceiptPrice instead of Approval;
		Added profit_ctr_id to retrieval arguments;
		Removed the following from the Union select:
			AND ContainerDestination.disposal_date > '06-05-1997'
			AND (Receipt.bulk_flag = 'F' AND Receipt.receipt_date > '07-31-1999')
04/21/2005 JDB	Changed to bypass records where the treatment has a reportable category of 4 - "Tranship".
06/29/2005 MK	Fixed report type loop from work table 3 to 4 to loop by constituent id rather than report type.
03/15/2006 RG   Removed join to wastecode on profit ctr
01/04/2007 TJS	Added parameters ra_approval_code and ra_treatment_id for the Approval and Treatment to limit by.  
		Also added the limit in the select statements
01/04/2008 JDB	Commented out update from tri_consistency_xref table.
03/01/2008 RG   converted first query from an select/into to an insert/select to avoid locing issues.
03/10/2008 RG  added treatment_category to report criteria
11/05/2009 JDB	Removed 'AND Treatment.reportable_category <> 4'
				from the WHERE clause per Sheila Cunningham.
11/04/2010 SK	added company_id as input arg, added joins to company,
		replaced 'approval' references, always send in a valid company_id & profit_ctr_id
03/11/2011 SK	Added TRI flag, removed report_category, removed join to ProcessLocation
03/15/2011 SK   Subtotals  & Total will be reported by TreatmentProcess. Took off the subtotal computation per location or per category.
03/17/2011 SK   Optimized the query for Perfomance Issue. 
02/02/2012 SK	Restored the fetch of location_report_flag as an outer join to ProcessLocation, so subtotal can be computed on the same
01/27/2013 AM   Added round to sum_pounds, subtotal_pounds, treatment_process_pounds and total_pounds
11/18/2014 AM   Added new subtotals for disposal service and modified code to get mid concentration.
04/24/2018 MPM	Added air permit status to the result set when @report_type = 2.
12/18/2020 MPM	DevOps 17908 - Corrected the constituent concentration calculation value so that it properly handles null
				min or max concentration values from the ReceiptConstituent table.
03/11/2022 AM DevOps:17098 - Added 'ug/kg', 'ppb' and 'ug/L' calculation
03/28/2022 MPM	DevOps 39189 - Widened the consistency and generator_name columns in #tri_work_table to match the columns' lengths in the ProfileLab and Generator tables.
07/06/2023 Nagaraj M Devops #67290 - Modified the ug/kg,ppb calculation from /0.0001 to * 0.000000001, and ug/L calculation from "0.001" to "* 8.3453 * 0.000000001"
03/18/2024 KS - DevOps 78200 - Updated the logic to fetch the ReceiptConstituent.concentration as following.
				If the 'Typical' value is stored (not null), then use the 'Typical' value for reporting purposes.
				If the 'Typical' value is null and the 'Min' value is null and 'Max' is not null, then use the 'Max' value for reporting purposes.
				If the 'Typical' value is null, and the 'Min' is not null and the 'Max' is not null, then use mid-point of 'Min' and 'Max' values for reporting purposes.
				If the 'Typical' value is null, and the 'Max' value is null, but the 'Min' value is not null, then use the 'Min' value for reporting purposes.
sp_tri 21, 00, '01/01/2015', '01/31/2015', 'ALL', -99, 1, 'category' , 0
sp_tri 21, 00, '04/20/2018', '04/25/2018', 'ALL', -99, 2, 'category' , 0

***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@company_name				varchar(35),
	@profit_ctr_name			varchar(50),
	@const_id					int,
	@report_group				varchar(8),
	@CAS_code					int,
	@const_desc					varchar(50),
	@record_type 				int,
	@treatment_process_pounds	float,
	@subtotal_pounds			float,
	@total_pounds				float,
	@rpt_grp_count				int,
	@rpt_grp_max				int,
	@rpt_const_max				int,
	@num_records				int,
	@subtotal					varchar(20),
	@treatment_process_id		int,
	@treatment_process			varchar(30),
	@treatment_process_id_max	int,
	@avg_concentration			float,
	@lbs_received				bigint,
	@const_avg_concentration	float,
	@const_lbs_received			bigint,
	@location_category			char(1),
	@location_category_max		char(1),
	@location_category_lbs		float, --bigint,
	@location					varchar(20),
	@location_max				varchar(20),
	@location_lbs				float, --bigint
	@disp_service_sub_totals	float,
	@disp_service_process  		varchar(20),
	@disposal_service_process_max varchar(20),
	@report_group_id			varchar(8)
				
CREATE TABLE #tri_work_table ( 
	company_id				int			null
,	profit_ctr_id			int			null
,	receipt_id				int			null
,	line_id					int			null
,	bulk_flag				char(1) 	null
,	container_id			int			null
,	treatment_id			int			null
,	treatment_desc			varchar(50) null
,	approval_code			varchar(16) null
,	concentration			float		null
,	unit					varchar(10) null
,	density					float		null
,	const_id				int			null
,	cas_code				int			null
,	const_desc				varchar(50) null
,	quantity				float		null
,	bill_unit_code			varchar(4)	null
,	container_size			varchar(15) null
,	pound_conv				float		null
,	container_count			int			null
,	pounds_received			float		null
,	consistency				varchar(50) null
,	c_density				float		null
,	pounds_constituent		float		null
,	ppm_concentration		float		null
,	location				varchar(15)	null
,	waste_type_code			varchar(2)	null
,	TRI_category			varchar(4)	null
,	location_report_flag	char(1)		null
,	generator_name			varchar(75) null
,	TRI_flag				char(1)		null
,	treatment_process_id	int			null
,	treatment_process		varchar(30)	null
,	disposal_service		varchar(20)	null
,	air_permit_status_code	varchar(10) null
,	air_permit_flag			char(1)		null
)

SET NOCOUNT ON

-- Insert into #tri_work_table
INSERT #tri_work_table
SELECT	
	Container.company_id,
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
	CASE WHEN Receipt.Bulk_flag = 'T' THEN (Receipt.quantity * CONVERT(money, ContainerDestination.container_percent)) / 100 
		  ELSE (1 * CONVERT(money, ContainerDestination.container_percent)) / 100 
	END AS quantity,
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
	Constituents.TRI_category,
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Generator.generator_name,
	TreatmentProcess.tri,
	TreatmentProcess.treatment_process_id,
	TreatmentProcess.treatment_process,
	Treatment.disposal_service_desc,
	AirPermitStatus.air_permit_status_code,
	IsNull(ProfitCenter.air_permit_flag, 'F') as air_permit_flag
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
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND (@treatment_id = -99 OR Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id))
JOIN TreatmentProcess
	ON TreatmentProcess.treatment_process_id = Treatment.treatment_process_id
	AND TreatmentProcess.tri = 'T'
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Receipt.company_id
	AND ReceiptConstituent.profit_ctr_id = Receipt.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Receipt.receipt_id
	AND ReceiptConstituent.line_id = Receipt.line_id
	AND (ReceiptConstituent.concentration IS NOT NULL OR ReceiptConstituent.min_concentration IS NOT NULL)
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.tri = 'T'
	AND Constituents.cas_code IS NOT NULL
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
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
LEFT OUTER JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
LEFT OUTER JOIN AirPermitStatus
	ON AirPermitStatus.air_permit_status_uid = ProfileQuoteApproval.air_permit_status_uid
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
WHERE	Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	AND NOT EXISTS (SELECT 1 FROM ContainerConstituent CC 
					WHERE Container.receipt_id = CC.receipt_id 
						AND Container.line_id = CC.line_id 
						AND Container.profit_ctr_id = CC.profit_ctr_id
						AND Container.company_id = CC.company_id)
						
UNION

SELECT	
	Container.company_id,
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
	CASE WHEN Receipt.Bulk_flag = 'T' THEN (Receipt.quantity * CONVERT(money, ContainerDestination.container_percent)) / 100 
		  ELSE (1 * CONVERT(money, ContainerDestination.container_percent)) / 100 
	END AS quantity,
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
	Constituents.TRI_category,
	ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,
	Generator.generator_name,
	TreatmentProcess.tri,
	TreatmentProcess.treatment_process_id,
	TreatmentProcess.treatment_process,
	Treatment.disposal_service_desc,
	AirPermitStatus.air_permit_status_code,
	IsNull(ProfitCenter.air_permit_flag, 'F') as air_permit_flag
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
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
	AND (@treatment_id = -99 OR Treatment.treatment_id = ISNULL(@treatment_id, treatment.treatment_id))
JOIN TreatmentProcess
	ON TreatmentProcess.treatment_process_id = Treatment.treatment_process_id
	AND TreatmentProcess.tri = 'T'
JOIN ReceiptConstituent
	ON ReceiptConstituent.company_id = Container.company_id
	AND ReceiptConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ReceiptConstituent.receipt_id = Container.receipt_id
	AND ReceiptConstituent.line_id = Container.line_id
	AND (ReceiptConstituent.concentration IS NOT NULL OR ReceiptConstituent.min_concentration IS NOT NULL)
JOIN Constituents
	ON Constituents.const_id = ReceiptConstituent.const_id
	AND Constituents.tri = 'T'
	AND Constituents.cas_code IS NOT NULL
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
LEFT OUTER JOIN WasteCode
	ON WasteCode.waste_code_uid = Profile.waste_code_uid
JOIN ContainerConstituent
	ON ContainerConstituent.company_id = Container.company_id
	AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id
	AND ContainerConstituent.receipt_id = Container.receipt_id
	AND ContainerConstituent.line_id = Container.line_id
	AND ContainerConstituent.container_id = Container.container_id
	AND ContainerConstituent.const_id = ReceiptConstituent.const_id
LEFT OUTER JOIN ProcessLocation
	ON ProcessLocation.company_id = ContainerDestination.company_id
	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND ProcessLocation.location = ContainerDestination.location
LEFT OUTER JOIN AirPermitStatus
	ON AirPermitStatus.air_permit_status_uid = ProfileQuoteApproval.air_permit_status_uid
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.receipt_status  = 'A' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))
	AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
ORDER BY treatment.treatment_desc, ProfileQuoteApproval.approval_code

-- UPDATE Container Size
UPDATE #tri_work_table SET container_size = bill_unit_code WHERE container_size = '' 
UPDATE #tri_work_table SET container_size = bill_unit_code WHERE bulk_flag = 'T'
UPDATE #tri_work_table 
SET container_size = rp.bill_unit_code
FROM ReceiptPrice rp
WHERE #tri_work_table.bulk_flag = 'F'
	AND #tri_work_table.receipt_id = rp.receipt_id
	AND #tri_work_table.line_id = rp.line_id
	AND #tri_work_table.profit_ctr_id = rp.profit_ctr_id
	AND #tri_work_table.company_id = rp.company_id
	AND #tri_work_table.container_size IS NULL
	AND rp.price_id = (SELECT MIN(price_id) FROM ReceiptPrice rp2 
						WHERE rp2.receipt_id = rp.receipt_id 
							AND rp2.line_id = rp.line_id
							AND rp2.profit_ctr_id = rp.profit_ctr_id
							AND rp2.company_id = rp.company_id)

-- UPDATE POUND FIELDS
UPDATE #tri_work_table 
SET pound_conv = b.pound_conv,
	pounds_received = #tri_work_table.quantity * b.pound_conv 
FROM BillUnit b
WHERE #tri_work_table.container_size = b.bill_unit_code
	AND b.pound_conv is not null
	AND ((#tri_work_table.bill_unit_code IS NULL)
		OR (#tri_work_table.bill_unit_code <> #tri_work_table.container_size)
		OR (#tri_work_table.pound_conv = 999999999999.99999))

--Remove items from #tri_work_table that have no valid pound_conv
DELETE FROM #tri_work_table where pound_conv = 999999999999.99999

CREATE INDEX trans_type ON #Tri_work_table (consistency)

-- UPDATE c_density on #tri_work_table
UPDATE  #tri_work_table SET c_density = 12.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'solid%'
UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'sludge%'
UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'semi-solid%'
UPDATE  #tri_work_table SET c_density = 8.3453 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'liquid%'
UPDATE  #tri_work_table SET c_density = 7.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'dust%'
UPDATE  #tri_work_table SET c_density = 5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'debris%'

/* default catch-all */
UPDATE  #tri_work_table SET c_density = 12.5 WHERE c_density IS NULL OR c_density = 0 

UPDATE #tri_work_table SET pounds_constituent = Round (  (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) / 1000000) ) , 5 )
WHERE unit IN ('ppm','ppmw','mg/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = ROund (  (ROUND(pounds_received, 5) * (ROUND(concentration, 5) / 100) ) ,5 )
WHERE unit = '%' AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tri_work_table SET pounds_constituent = Round ( ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 0.000008345)) , 5 )
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

IF @debug = 1 PRINT 'SELECT COUNT FROM #tri_work_table after all initial updates'
IF @debug = 1 SELECT COUNT(1) FROM #tri_work_table

-- SELECT COMPANY & PROFIT CTR
SELECT 
	@company_name = Company.company_name,
	@profit_ctr_name = ProfitCenter.profit_ctr_name
FROM Company
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Company.company_id
	AND ProfitCenter.profit_ctr_ID = @profit_ctr_id
WHERE Company.company_id = @company_id

IF @report_type = 1
/*** Report type 1 is the TRI Summary ***/
BEGIN
	-- CREATE #tri_work_table_2
	CREATE TABLE #tri_work_table_2 (
		record_type					int			NULL
	,	company_id					int			NULL
	,	profit_ctr_id				int			NULL
	,	const_id					int			NOT NULL
	,	report_group				varchar(8)	NOT NULL
	,	CAS_code					int			NULL
	,	const_desc					varchar(50)	NULL
	,	treatment_id				int			NULL
	,	treatment_desc				varchar(40)	NULL
	,	sum_pounds					float		NULL
	,	waste_type_code				varchar(2)	NULL
	,	location_report_flag		char(1)		NULL
	,	location					varchar(20)	NULL
	,	subtotal_pounds				float		NULL
	,	treatment_process_pounds	float		NULL
	,	total_pounds				float		NULL
	,	avg_concentration			float		NULL
	,	lbs_received				float		NULL 
	,	treatment_process_id		int			NULL
	,	treatment_process			varchar(30)	NULL
	,	tri_flag					char(1)		NULL
	,   disposal_service			varchar(20) NULL
	)
	
	-- INSERT #tri_work_table_2
	INSERT INTO #tri_work_table_2
	SELECT
		1 AS record_type,
		company_id,
		profit_ctr_id,
		const_id,
       	CASE WHEN TRI_category IS NULL OR TRI_category = '' THEN CONVERT(varchar(8), const_id) ELSE TRI_category END AS report_group,
		CAS_code,
   	 	const_desc,
   	 	treatment_id,
   		treatment_desc,
   		sum_pounds = Round ( SUM(pounds_constituent), 5 ) , 
   		waste_type_code,
   		location_report_flag,
   	 	location,
   	    0.00000 AS subtotal_pounds, 
   	    0.0  AS treatment_process_pounds,  
		0.0  AS total_pounds, 
   		avg_concentration = 0.00000,
		lbs_received = SUM(pounds_received),
		treatment_process_id,
		treatment_process,
		tri_flag,
        disposal_service
	FROM #tri_work_table 
	WHERE pounds_constituent > 0.000001
	GROUP BY company_id, profit_ctr_id, const_id, TRI_category, CAS_code, const_desc, treatment_id, treatment_desc, waste_type_code, 
		location_report_flag, location, treatment_process_id, treatment_process, TRI_flag, disposal_service
	HAVING SUM(pounds_constituent) >= 0.5
	
	IF @debug = 1 PRINT 'SELECT COUNT FROM #tri_work_table_2'	
	IF @debug = 1 SELECT COUNT(1) FROM #tri_work_table_2

	SELECT
		record_type,
		company_id,
		profit_ctr_id,
		const_id,
		report_group,
		cas_code,
		const_desc, 
		treatment_id, 
		treatment_desc, 
		sum_pounds = Round ( SUM(sum_pounds), 5 ), 
		' ' AS location_report_flag,
	   	'                    ' AS location, 
		Round ( subtotal_pounds, 5 ) as subtotal_pounds,
		Round ( treatment_process_pounds, 5 ) as treatment_process_pounds,
		Round ( total_pounds, 5 ) as total_pounds,
		ROUND((SUM(sum_pounds * 1000000)/SUM(lbs_received)), 5) AS avg_concentration,
		SUM(lbs_received) AS lbs_received,
		treatment_process_id,
		treatment_process,
		tri_flag,
		disposal_service
	INTO #tri_work_table_4
	FROM #tri_work_table_2
	GROUP BY record_type, company_id, profit_ctr_id,const_id, report_group, cas_code, const_desc, treatment_id, treatment_desc, 
		 subtotal_pounds, treatment_process_pounds, total_pounds, treatment_process_id, treatment_process, tri_flag, disposal_service

	-- UPDATE total_pounds per constituent
	UPDATE #tri_work_table_4 SET total_pounds = (SELECT ROUND(SUM(sum_pounds),5) FROM #tri_work_table_2 t2 
							WHERE t2.const_id = #tri_work_table_4.const_id)

	-- IF no rows in #tri_work_table_4 nothing more to do
	IF @@ROWCOUNT = 0 GOTO FINISH

	-- UPDATE pounds received per constituent
	UPDATE #tri_work_table_4 SET lbs_received = (SELECT ROUND(SUM(lbs_received),0) FROM #tri_work_table_2 t2 
							WHERE t2.const_id = #tri_work_table_4.const_id) 
							
	-- UPDATE avg concentration per constituent
	UPDATE #tri_work_table_4 SET avg_concentration = (SELECT ROUND(((SUM(sum_pounds) * 1000000)/SUM(lbs_received)),5)
							   FROM #tri_work_table_2 t2 WHERE t2.const_id = #tri_work_table_4.const_id)
							   
	 -------------------------------------------------------------------------------------------------------------------------------------
	 -- INSERT subtotals records for :
	 -- 1) per constituent in diff locations			eg: avg concentration of Benzene at location A(processlocation.location = 'A') = 2.345, 
	 --														avg concentration of Benzene at location B is 3.456
	 -- 2) per constituent in diff location categories	eg: avg concentration of Benzene on East side(location_report_flag = 'E') is 12.345,
	 --														avg concentration of Benzene on West(location_report_flag = 'W') is 34.567
			-- in 2 exclude the non-reportable location categories i.e where location_report_flag = 'N'
	 
	 -------------------------------------------------------------------------------------------------------------------------------------
	 -- Fetch max constituents so we know when to terminate loop
	 -- **** READ : some constituents are grouped under TRI categories, so remember constituents.const_id = report_group in most cases, except when the constiuents 
	 --				are grouped under a TRI category then we just want subtotals for the TRI category. In that case report_group = constituents.tri_category
	 --				so we use report_group for LOOPING (report_group = IsNull(constituents.TRI_category, constituent.const_id))

			SELECT @rpt_grp_count = 0
			SELECT @rpt_grp_max = (SELECT COUNT(DISTINCT report_group) FROM #tri_work_table_2)
			SELECT @rpt_const_max = (SELECT COUNT(DISTINCT const_id) FROM #tri_work_table_2)
			/******* START LOOP for each Constituent or constituent category if present ************************************************************************/
			Report_group:
				-- get the next constituent
				SELECT @const_id = MIN(const_id) from #tri_work_table_2
				SELECT @report_group_id = MIN(report_group) from #tri_work_table_2
				-- Is there a TRI_category for this constituent
				if @category_type = 'category'
				   SELECT @report_group = report_group	FROM #tri_work_table_2 where report_group = @report_group_id
				else
				   SELECT @report_group = report_group	FROM #tri_work_table_2 where const_id = @const_id
				-- for above constituent get its desc, cas code, total pounds, avg concentration etc
				SELECT 
					@CAS_code = cas_code
				,	@const_desc = const_desc
				FROM #tri_work_table_2 where const_id = @const_id
				if @category_type = 'category'
				  begin
					SELECT @total_pounds = Round ( SUM(sum_pounds) , 5 )  FROM #tri_work_table_2 WHERE report_group = @report_group_id
					SELECT @const_lbs_received = ROUND(SUM(lbs_received),0) FROM #tri_work_table_2 WHERE report_group = @report_group_id
					SELECT @const_avg_concentration = ROUND(((SUM(sum_pounds) * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE report_group = @report_group_id
				  end
				else
				  begin	
					SELECT @total_pounds = Round ( SUM(sum_pounds) , 5 )  FROM #tri_work_table_2 WHERE const_id = @const_id 
					SELECT @const_lbs_received = ROUND(SUM(lbs_received),0) FROM #tri_work_table_2 WHERE const_id = @const_id
					SELECT @const_avg_concentration = ROUND(((SUM(sum_pounds) * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE const_id = @const_id 
				  end
	 				-- 1) LOCATION CATEGORIES
				-- Fetch max location categories for above constituent
				SELECT @location_category = ''
				if @category_type = 'category'
				   SELECT @location_category_max = MAX(location_report_flag) FROM #tri_work_table_2 WHERE report_group = @report_group_id
				else
					SELECT @location_category_max = MAX(location_report_flag) FROM #tri_work_table_2 WHERE const_id = @const_id
				if @debug = 1 Print 'max location category = ' + @location_category_max + ' for  const ' + str(@const_id)
				/******* START LOOP for each location category for above constituent ************************************************************************/
				LocCategory:
				if @category_type = 'category'
				  begin
					SELECT @location_category = MIN(location_report_flag) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location_report_flag > @location_category AND location_report_flag <> 'N'
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location_report_flag = @location_category AND location_report_flag <> 'N'
				  end
				else
				  begin
					SELECT @location_category = MIN(location_report_flag) FROM #tri_work_table_2 WHERE const_id = @const_id AND location_report_flag > @location_category AND location_report_flag <> 'N'
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE const_id = @const_id AND location_report_flag = @location_category AND location_report_flag <> 'N'
				  end 
				  IF @num_records > 0 
					if @category_type = 'category'
						BEGIN
							SELECT @location_category_lbs = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location_report_flag = @location_category AND location_report_flag <> 'N' 
							SELECT @lbs_received = ROUND ( SUM(lbs_received), 5) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location_report_flag = @location_category AND location_report_flag <> 'N' AND lbs_received > 0
							SELECT @avg_concentration = ROUND(((@location_category_lbs * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location_report_flag = @location_category AND location_report_flag <> 'N' AND lbs_received > 0
						END
					else
						BEGIN
							SELECT @location_category_lbs = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_2 WHERE const_id = @const_id AND location_report_flag = @location_category AND location_report_flag <> 'N' 
							SELECT @lbs_received = ROUND ( SUM(lbs_received), 5) FROM #tri_work_table_2 WHERE const_id = @const_id AND location_report_flag = @location_category AND location_report_flag <> 'N' AND lbs_received > 0
							SELECT @avg_concentration = ROUND(((@location_category_lbs * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE const_id = @const_id AND location_report_flag = @location_category AND location_report_flag <> 'N' AND lbs_received > 0
						END
				  ELSE
						SELECT @location_category_lbs = 0
					-- The insertion of a 3 for the record_type field means that this record contains only the numerous location report flag subtotals for the const_id or TRI_category */
					IF @location_category IS NOT NULL
						INSERT #tri_work_table_4 VALUES(2, @company_id, @profit_ctr_id, @const_id, @report_group, @CAS_code, @const_desc, 0, '', 0, @location_category, '', @location_category_lbs  , 0, @total_pounds, @avg_concentration, 0, 0, '','T','')
				
					IF @location_category < @location_category_max GOTO LocCategory
				/******* END LOOP for each location category for above constituent ************************************************************************/
				
				/******* START LOOP for each disposal_service for above constituent ************************************************************************/
				SELECT @disp_service_process = ''
				if  @category_type = 'category'
				  SELECT @disposal_service_process_max = MAX(disposal_service) FROM #tri_work_table_2 WHERE report_group = @report_group_id
				else
				  SELECT @disposal_service_process_max = MAX(disposal_service) FROM #tri_work_table_2 WHERE const_id = @const_id  
			  DisposalService:
				 if  @category_type = 'category'
				  begin
				 	SELECT @disp_service_process = MIN(disposal_service) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND disposal_service > @disp_service_process 
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND disposal_service = @disp_service_process 
				  end
				 else 
				  Begin
					SELECT @disp_service_process = MIN(disposal_service) FROM #tri_work_table_2 WHERE const_id = @const_id AND disposal_service > @disp_service_process 
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE const_id = @const_id AND disposal_service = @disp_service_process 
				  end
					IF @num_records > 0
					  if @category_type = 'category'
						 BEGIN
							SELECT @disp_service_sub_totals = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_2 WHERE disposal_service = @disp_service_process AND report_group = @report_group_id
						 END 
					  else
						BEGIN
						   SELECT @disp_service_sub_totals = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_2 WHERE disposal_service = @disp_service_process AND const_id = @const_id  
						END 
					ELSE
						SELECT @disp_service_sub_totals = 0
				   IF @disp_service_process IS NOT NULL
						INSERT #tri_work_table_4 VALUES(5, @company_id, @profit_ctr_id, @const_id, @report_group, @CAS_code, @const_desc, 0, '', 0, '', '', @disp_service_sub_totals, 0, 0, 0, 0, 0, '', 'T',@disp_service_process )
				   IF @disp_service_process < @disposal_service_process_max GOTO DisposalService
				 /******* END LOOP for each disposal_service for above constituent ************************************************************************/
				 
				-- 2) LOCATIONS
				-- Fetch max locations for above constituent
				SELECT @location = ''
				if @category_type = 'category'
					SELECT @location_max = MAX(location) FROM #tri_work_table_2 WHERE report_group = @report_group_id
				else
				    SELECT @location_max = MAX(location) FROM #tri_work_table_2 WHERE const_id = @const_id
				/******* START LOOP for each location for above constituent ************************************************************************/
				Location:
				if @category_type = 'category'
				  begin
					SELECT @location = MIN(location) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location > @location
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location = @location
				  end
			    else
			      begin
					SELECT @location = MIN(location) FROM #tri_work_table_2 WHERE const_id = @const_id AND location > @location
					SELECT @num_records = COUNT(*) FROM #tri_work_table_2 WHERE const_id = @const_id AND location = @location
				  end
					IF @num_records > 0
						 if @category_type = 'category'
							BEGIN
							  SELECT @location_lbs = Round ( SUM(sum_pounds) , 5 ) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location = @location 
							  SELECT @lbs_received = Round ( SUM(lbs_received),5) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location = @location AND lbs_received > 0 
							  SELECT @avg_concentration = ROUND(((@location_category_lbs * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE report_group = @report_group_id AND location = @location AND lbs_received > 0
							END
						 else
							BEGIN
							  SELECT @location_lbs = Round ( SUM(sum_pounds) , 5 ) FROM #tri_work_table_2 WHERE const_id = @const_id AND location = @location 
							  SELECT @lbs_received = Round ( SUM(lbs_received),5) FROM #tri_work_table_2 WHERE const_id = @const_id AND location = @location AND lbs_received > 0 
							  SELECT @avg_concentration = ROUND(((@location_category_lbs * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_2 WHERE const_id = @const_id AND location = @location AND lbs_received > 0
						   END
					ELSE
						SELECT @location_lbs = 0
					-- The insertion of a 3 for the record_type field means that this record contains only the numerous location subtotals for the const_id or TRI_category */
					IF @location IS NOT NULL
						INSERT #tri_work_table_4 VALUES(3, @company_id, @profit_ctr_id, @const_id, @report_group, @CAS_code, @const_desc, 0, '', 0, '', @location, @location_lbs, 0, @total_pounds, @avg_concentration, 0, 0, '', 'T', '')
					
					IF @location < @location_max GOTO Location
				/******* END LOOP for each location for above constituent ************************************************************************/
			if @category_type = 'category'
			  DELETE FROM #tri_work_table_2 WHERE report_group = @report_group_id
			else
			  DELETE FROM #tri_work_table_2 WHERE const_id = @const_id

			SELECT @rpt_grp_count = @rpt_grp_count + 1
			IF @rpt_grp_count < @rpt_const_max GOTO Report_group
			
	/******* END LOOP for each Constituent or constituent category if present ************************************************************************/				   
							   
/*	-- How many TRI categories and constituents do we have ? Do Sub-totals
	--SELECT @rpt_grp_count	= 0
	--SELECT @rpt_grp_max	= (SELECT COUNT(DISTINCT report_group) FROM #tri_work_table_2)
	--SELECT @rpt_const_max	= (SELECT COUNT(DISTINCT const_id) FROM #tri_work_table_2)
	/**********************************************************************************************************************/
	-- Subtotals per constituent or per TRI category (const_id) record_type = 2
	--Report_group:
	--SELECT @const_id = MIN(const_id) from #tri_work_table_2

	--SELECT 
	--	@report_group	= report_group 
	--,	@CAS_code	= cas_code 
	--,	@const_desc	= const_desc 
	--FROM #tri_work_table_2 where const_id = @const_id
	
	--SELECT
	--	@total_pounds	= IsNull(ROUND(SUM(sum_pounds),0), 0.0)
	--,	@subtotal_pounds = IsNull(ROUND(SUM(sum_pounds),0), 0.0)
	--,	@const_lbs_received	= ROUND(SUM(lbs_received),0) 
	--,	@const_avg_concentration = ROUND(((SUM(sum_pounds) * 1000000)/SUM(lbs_received)),5)
	--FROM #tri_work_table_2 where const_id = @const_id

	--IF @const_id IS NOT NULL
	--BEGIN
		--The record type=2 means that this record contains only the numerous subtotals per Constituent or per category
		--INSERT #tri_work_table_4 VALUES(2, @company_id, @profit_ctr_id, @const_id, @report_group, @CAS_code, @const_desc, 0, '', 0, '', @subtotal_pounds, 0, @total_pounds, @const_avg_concentration, @const_lbs_received, 0, '', '')

    		-- Subtotals per treatment_process for Constituent @const_id ( record type = 3)
		--SELECT @treatment_process_id = 0
	--	SELECT @treatment_process_id_max = IsNull(MAX(treatment_process_id), 0) FROM #tri_work_table_2 WHERE const_id = @const_id
--		IF @debug = 1 PRINT 'max treatment process = ' + str(@treatment_process_id_max) + ' for  const ' + str(@const_id)
		/**********************************************************************************************************************/
		--TreatmentProcess:
		--SELECT @treatment_process_id = MIN(treatment_process_id) FROM #tri_work_table_2 WHERE const_id = @const_id AND treatment_process_id > @treatment_process_id
		--SELECT @num_records = COUNT(1) FROM #tri_work_table_2 WHERE const_id = @const_id AND treatment_process_id = @treatment_process_id
		--IF @num_records > 0
		--BEGIN
		 -- SELECT @treatment_process = treatment_process FROM #tri_work_table_2 WHERE const_id = @const_id AND treatment_process_id = @treatment_process_id
		 -- SELECT @treatment_process_pounds = ROUND(SUM(sum_pounds),0) FROM #tri_work_table_2 WHERE const_id = @const_id AND treatment_process_id = @treatment_process_id

		 -- SELECT @lbs_received = SUM(lbs_received)
		  --, @avg_concentration = ROUND(((@treatment_process_pounds * 1000000)/SUM(lbs_received)),5) 
		  --FROM #tri_work_table_2 WHERE const_id = @const_id AND treatment_process_id = @treatment_process_id AND lbs_received > 0
		--END
		--ELSE
		 -- SELECT @treatment_process_pounds = 0.0

		  --The record type =2 means that this record contains only the numerous treatment process subtotals for the const_id
		--  IF @treatment_process_id IS NOT NULL
			--INSERT #tri_work_table_4 VALUES(3, @company_id, @profit_ctr_id, @const_id, @report_group, @CAS_code, @const_desc, 0, '', 0, '', 0, @treatment_process_pounds, @total_pounds, @avg_concentration, @lbs_received, @treatment_process_id, @treatment_process, 'T')
		
		 -- IF @treatment_process_id < @treatment_process_id_max GOTO TreatmentProcess
		/**********************************************************************************************************************/
	
   	--	DELETE FROM #tri_work_table_2 WHERE const_id = @const_id
	--END

	--SELECT @rpt_grp_count = @rpt_grp_count + 1
	--IF @rpt_grp_count < @rpt_const_max GOTO Report_group
	/**********************************************************************************************************************/
*/

	-------------------------------------------------------------------------------------------------------------------------------------
	-- Totals for whole report per treatment process
	-------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT @treatment_process_id = 0
	SELECT @treatment_process_id_max = MAX(treatment_process_id) FROM #tri_work_table_4
	SELECT @total_pounds = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_4 WHERE record_type = 1 
	
	/********* START LOOP for totals for each treatment process *************************************************************************/
	Treatment_process_sum:
		SELECT @treatment_process_id = MIN(treatment_process_id) FROM #tri_work_table_4 WHERE treatment_process_id > @treatment_process_id
		SELECT @treatment_process_pounds = ROUND(SUM(sum_pounds),5) FROM #tri_work_table_4 WHERE treatment_process_id = @treatment_process_id AND record_type = 1 
		SELECT @treatment_process = treatment_process FROM #tri_work_table_4 WHERE treatment_process_id = @treatment_process_id 
		SELECT @lbs_received = Round ( SUM(lbs_received) , 5 ) FROM #tri_work_table_4 WHERE treatment_process_id = @treatment_process_id AND lbs_received > 0 AND record_type = 1  
		SELECT @avg_concentration = ROUND(((@treatment_process_pounds * 1000000)/SUM(lbs_received)),5) FROM #tri_work_table_4 WHERE treatment_process_id = @treatment_process_id AND lbs_received > 0 AND record_type = 1
		IF @treatment_process_id IS NOT NULL
			-- record_type = 4, means Totals for Treatment Process
			INSERT #tri_work_table_4 VALUES(4, @company_id, @profit_ctr_id, 0, 'ZZZZ', 0, '', 0, '', 0, '', '', 0, @treatment_process_pounds, @total_pounds, @avg_concentration, @lbs_received, @treatment_process_id, @treatment_process, 'T','')
		
		IF @treatment_process_id < @treatment_process_id_max GOTO Treatment_process_sum
	/********* END LOOP for totals for each treatment process *************************************************************************/
	
	IF @debug = 1 PRINT 'FINAL SELECT * FROM #tri_work_table_4 after all inserts'
	
FINISH:
	SELECT
		record_type,
		company_id,
		profit_ctr_id,
		const_id,
		report_group,
		cas_code,
		const_desc, 
		treatment_id, 
		treatment_desc, 
		ROUND(SUM(sum_pounds),5) AS sum_pounds, 
		location_report_flag,
	   	location, 
		ROUND(subtotal_pounds,5 )AS subtotal_pounds,  
		ROUND(treatment_process_pounds,5)AS treatment_process_pounds,  
		ROUND(SUM(total_pounds),5)AS total_pounds,  
		ROUND(avg_concentration,2)AS avg_concentration,
		lbs_received AS lbs_received,
		treatment_process_id,
		treatment_process,
		tri_flag,
		@company_name,
		@profit_ctr_name,
		disposal_service
	FROM #tri_work_table_4
	GROUP BY 
		record_type,
		company_id,
		profit_ctr_id,
		const_id,
		report_group,
		cas_code,
		const_desc, 
		treatment_id, 
		treatment_desc, 
		location_report_flag,
		location,
		subtotal_pounds,
		treatment_process_pounds,
		avg_concentration,
		lbs_received,
		treatment_process_id,
		treatment_process,
		tri_flag,
		disposal_service
	ORDER BY report_group, record_type, treatment_id, treatment_process
END

ELSE
/*** Report type 2 is the TRI Worksheet ***/
	SELECT
		company_id,
		profit_ctr_id,
		const_id,
		cas_code,
		const_desc,
		treatment_id,
		treatment_desc,
		approval_code,
		ROUND(SUM(concentration * pounds_received) / SUM(pounds_received), 5) AS concentration,
		unit,
		density,
		SUM(quantity) AS quantity,
		container_size AS bill_unit_code,
		pound_conv,
		ROUND(SUM(pounds_received), 5) AS pounds_received,
		consistency,
		c_density,
		ROUND(SUM(pounds_constituent), 5) AS pounds_constituent,
		tri_category,
		generator_name,
		treatment_process_id,
		treatment_process,
		@company_name AS company_name,
		@profit_ctr_name AS profit_ctr_name,
		disposal_service,
		air_permit_status_code,
		air_permit_flag
	FROM #tri_work_table
	WHERE pounds_constituent > 0.000005
	GROUP BY
		company_id,
		profit_ctr_id,
		const_id, 
		cas_code, 
		const_desc, 
		treatment_id, 
		treatment_desc, 
		approval_code, 
		air_permit_status_code,
		air_permit_flag,
		consistency,
		density, 
		container_size,
		c_density, 
		pound_conv, 
		unit, 
		tri_category, 
		generator_name,
		treatment_process_id,
		treatment_process,
		disposal_service
	ORDER BY const_id, CAS_code, treatment_id, approval_code 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_tri] TO [EQAI]
    AS [dbo];

