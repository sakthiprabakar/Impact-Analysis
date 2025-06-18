USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_rpt_tap_with_weight_and_treatment_duration]    Script Date: 4/28/2025 9:36:41 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_tap_with_weight_and_treatment_duration]  
 @company_id   int  
, @profit_ctr_id  int  
, @date_from   datetime  
, @date_to   datetime  
, @approval_code  varchar(15) 
, @batch_location varchar(15) 
, @tracking_num varchar(15) 
, @treatment_id  int  
, @treatment_category int 
AS  

/*************************************************************************************  
This procedure runs for the HAP and TAP Constituent with Weight and Treatment Duration report  
  
PB Object(s): r_hap_report_with_weight_and_treatment_duration  
  
This report was created taking the sp_rpt_hap_worksheet as the base, however this report  
doesn't have the rolling tons and emission factors. It does, in addition, bring the  
Duration(s) of treatment from the batch_treatment_note table. It also takes the empty  
container weight into consideration while calculating the weight of the waste and uses  
this as a baseline for further calculations  
  
02/25/2025 RK	Initial version created for US142150  
03/25/2025 RK	Changes done for US146406 - Added location & tracking_num column as input parameter.
				Added Logic to handle scenarios where these values are passed as NULL.
04/04/2025 KM	Removed the multiplier of 1 MIL while calculating the value of
				chemical_weight_mg column for US149343
05/29/2025 KS - Rally US116196 - Constituent - Integer data type preventing CAS # entry
*************************************************************************************/  
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  

	DECLARE @kilogram_conversion_factor float  

	IF @treatment_id = -99 SET @treatment_id = NULL  
	IF @treatment_category = -99 SET @treatment_category = NULL 

	Declare @state_abbr Varchar(5)
	SELECT DISTINCT @state_abbr = TSDF_state FROM TSDF
	WHERE eq_company = @company_id
	and eq_profit_ctr = @profit_ctr_id
	and TSDF_status = 'A'

	DROP TABLE IF EXISTS #tri_work_table;
	CREATE TABLE #tri_work_table (   
	 company_id					 int		null  
	, profit_ctr_id				 int		null  
	, receipt_id    int   null  
	, line_id     int   null  
	, bulk_flag    char(1)  null  
	, container_id   int   null  
	, treatment_id   int   null  
	, treatment_desc   varchar(50) null  
	, approval_code   varchar(16) null  
	, concentration   float  null  
	, unit     varchar(10) null  
	, density     float  null  
	, const_id    int   null  
	, cas_code    bigint   null  
	, const_desc    varchar(50) null  
	, hap_tap_ind     char(1)  null  
	, quantity    float  null  
	, bill_unit_code   varchar(4) null  
	, container_size   varchar(15) null  
	, empty_container_weight decimal(10, 3) null  
	, total_empty_container_weight decimal(10, 3) null  
	, pound_conv    float  null  
	, container_count   int   null  
	, pounds_received   float  null  
	, net_pounds_received  float  null  
	, consistency    varchar(20) null  
	, c_density    float  null  
	, pounds_constituent  float  null  
	, ppm_concentration  float  null  
	, chemical_weight_mg  float  null  
	, location    varchar(16) null  
	, tracking_num			varchar(15)	null
	, waste_type_code   varchar(2) null  
	, location_report_flag char(1)  null  
	, reportable_category  int   null  
	, reportable_category_desc varchar(60) null  
	, generator_name   varchar(50) null  
	, process_location  varchar(15) null  
	, disposal_date   datetime  
	, sequence_id    int   null  
	, company_name NVARCHAR(35)  
	, profit_ctr_name NVARCHAR(50)  
	, TAP_585 char(1) 
	, TAP_586 char(1) 
	)  

	DROP TABLE IF EXISTS #ContainerDestination;
	CREATE TABLE #ContainerDestination(  
	 company_id INT   
	, profit_ctr_id INT   
	,  receipt_id INT   
	,  line_id INT   
	,  container_id INT  
	, treatment_id INT   
	, location NVARCHAR(15)
	, tracking_num NVARCHAR(15) -- Added for US146406
	, disposal_date DATETIME INDEX idx_tmp_disposal_date NONCLUSTERED  
	, sequence_id INT  
	, container_percent INT  
	, INDEX idx_tmp_company_id_profit_ctr_id_receipt_id_line_id_container_id NONCLUSTERED(company_id, profit_ctr_id, receipt_id, line_id, container_id)  
	, INDEX idx_tmp_company_id_profit_ctr_id_treatment_id NONCLUSTERED(company_id, profit_ctr_id, treatment_id)  
	, INDEX idx_tmp_company_id_profit_ctr_id_location NONCLUSTERED(company_id, profit_ctr_id, location));  
  
	-- Select all Container Destination records for the Company ID, Profit Center Id, and Disposal Date Range  
	INSERT INTO #ContainerDestination
		(company_id, profit_ctr_id, receipt_id, line_id, container_id, treatment_id, location, tracking_num, disposal_date, sequence_id, container_percent)  
	SELECT company_id, profit_ctr_id, receipt_id, line_id, container_id, treatment_id, location, tracking_num, disposal_date, sequence_id, container_percent    
	FROM ContainerDestination  
	 WHERE company_id = @company_id    
	 AND profit_ctr_id = @profit_ctr_id  
	 AND disposal_date BETWEEN @date_from  AND @date_to  
	 AND (@batch_location = 'ALL' OR location = ISNULL(@batch_location, location))  
	 AND (@tracking_num = 'ALL' OR tracking_num = ISNULL(@tracking_num, tracking_num))
  
	-- Insert   
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
	hap_tap_ind,
	quantity,
	bill_unit_code,
	container_size,
	empty_container_weight,
	total_empty_container_weight,
	pound_conv,
	container_count,
	pounds_received,
	net_pounds_received,
	consistency,
	c_density,
	pounds_constituent,
	ppm_concentration,
	chemical_weight_mg,
	location,
	tracking_num,
	waste_type_code,
	location_report_flag,
	reportable_category,
	reportable_category_desc,
	generator_name,
	process_location,
	disposal_date,
	sequence_id,
	company_name,
	profit_ctr_name,
	TAP_585,
	TAP_586
	)
	SELECT    
	 Receipt.company_id,     
	 Container.profit_ctr_id,    
	 Container.receipt_id,  
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	 'H' AS hap_tap_ind,
	 (1 * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,   
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,    
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,    
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration, 
	 0.00 AS chemical_weight_mg, 
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,     
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 NULL AS TAP_585,
	 NULL AS TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id  
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id  
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id  
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from  AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ProcessLocation    
	 ON ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND ProcessLocation.location = CONDEST.location    
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
	 AND (Constituents.hap = 'T')

	UNION
	SELECT    
	 Receipt.company_id,     
	 Container.profit_ctr_id,    
	 Container.receipt_id,  
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	 --Constituents.HAP,  
	 'T' AS hap_tap_ind,
	 (1 * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,   
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,    
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,    
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration,    
	 0.00 AS chemical_weight_mg,
	 CONDEST.location,    
	 CONDEST.tracking_num,
	 WasteCode.waste_type_code,     
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,  
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 HT.TAP_585,
	 HT.TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id  
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id  
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id  
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from  AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ProcessLocation    
	 ON ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND ProcessLocation.location = CONDEST.location    
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
	JOIN Constituent_HAP_TAP HT
	 ON HT.const_id = Constituents.const_id
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
	 AND (HT.TAP_FLAG = 'T')
  
	UNION    
	SELECT    
	 Receipt.company_id,     
	 Container.profit_ctr_id,    
	 Container.receipt_id,    
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	  --Constituents.HAP,  
	  'H' AS hap_tap_ind,
	 (1 * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,    
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration,
	 0.00 AS chemical_weight_mg,	 
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 NULL AS TAP_585,
	 NULL AS TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id   
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id   
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ContainerConstituent    
	 ON ContainerConstituent.company_id = Container.company_id    
	 AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id    
	 AND ContainerConstituent.receipt_id = Container.receipt_id    
	 AND ContainerConstituent.line_id = Container.line_id    
	 AND ContainerConstituent.container_id = Container.container_id    
	 AND ContainerConstituent.const_id = ReceiptConstituent.const_id    
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
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
	WHERE Receipt.company_id = @company_id    
	 AND Receipt.profit_ctr_id = @profit_ctr_id    
	 AND Receipt.receipt_status  = 'A'     
	 AND Receipt.trans_mode = 'I'     
	 AND Receipt.trans_type = 'D'    
	 AND Receipt.bulk_flag = 'F'    
	 AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))    
	 AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	 AND (Constituents.HAP = 'T')

	 UNION
	 SELECT    
	 Receipt.company_id,     
	 Container.profit_ctr_id,    
	 Container.receipt_id,    
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	  --Constituents.HAP,  
	  'T' AS hap_tap_ind,
	 (1 * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,    
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration,   
	 0.00 AS chemical_weight_mg,	 
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 HT.TAP_585,
	 HT.TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id   
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id   
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ContainerConstituent    
	 ON ContainerConstituent.company_id = Container.company_id    
	 AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id    
	 AND ContainerConstituent.receipt_id = Container.receipt_id    
	 AND ContainerConstituent.line_id = Container.line_id    
	 AND ContainerConstituent.container_id = Container.container_id    
	 AND ContainerConstituent.const_id = ReceiptConstituent.const_id    
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
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
	JOIN Constituent_HAP_TAP HT
	 ON HT.const_id = Constituents.const_id
	WHERE Receipt.company_id = @company_id    
	 AND Receipt.profit_ctr_id = @profit_ctr_id    
	 AND Receipt.receipt_status  = 'A'     
	 AND Receipt.trans_mode = 'I'     
	 AND Receipt.trans_type = 'D'    
	 AND Receipt.bulk_flag = 'F'    
	 AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))    
	 AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686')))
	 AND (HT.TAP_FLAG = 'T')
    
	UNION    
	SELECT     
	 Receipt.company_id,    
	 Container.profit_ctr_id,    
	 Container.receipt_id,       
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,       
	 CONDEST.treatment_id,       
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
	  --Constituents.HAP,  
	  'H' AS hap_tap_ind,
	 (Receipt.quantity * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,     
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration, 
	 0.00 AS chemical_weight_mg,
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 NULL AS TAP_585,
	 NULL AS TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id   
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id   
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
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
	 AND (Constituents.HAP = 'T')

	UNION

	SELECT     
	 Receipt.company_id,    
	 Container.profit_ctr_id,    
	 Container.receipt_id,       
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,       
	 CONDEST.treatment_id,       
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
	  --Constituents.HAP,  
	  'T' AS hap_tap_ind,
	 (Receipt.quantity * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,     
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration,  
	 0.00 AS chemical_weight_mg,
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 HT.TAP_585,
	 HT.TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id   
	JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id   
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id    
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
	JOIN Constituent_HAP_TAP HT
	 ON HT.const_id = Constituents.const_id
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
	 AND (HT.TAP_FLAG = 'T')

      
	UNION    
	SELECT     
	 Receipt.company_id,    
	 Container.profit_ctr_id,    
	 Container.receipt_id,    
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	  --Constituents.HAP,  
	  'H' AS hap_tap_ind,
	 (Receipt.quantity * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,       
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration, 
	 0.00 AS chemical_weight_mg,
	 CONDEST.location,    
	 CONDEST.tracking_num, --Added for US146406
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 NULL AS TAP_585,
	 NULL AS TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id    
	 JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id  
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ContainerConstituent    
	 ON ContainerConstituent.company_id = Container.company_id    
	 AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id    
	 AND ContainerConstituent.receipt_id = Container.receipt_id    
	 AND ContainerConstituent.line_id = Container.line_id    
	 AND ContainerConstituent.container_id = Container.container_id    
	 AND ContainerConstituent.const_id = ReceiptConstituent.const_id    
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id      
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
	WHERE Receipt.company_id = @company_id    
	 AND Receipt.profit_ctr_id = @profit_ctr_id    
	 AND Receipt.receipt_status  = 'A'     
	 AND Receipt.trans_mode = 'I'     
	 AND Receipt.trans_type = 'D'    
	 AND Receipt.bulk_flag = 'T'    
	 AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code))    
	 AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686'))) 
	 AND (Constituents.HAP = 'T')
 
	 UNION
	 SELECT     
	 Receipt.company_id,    
	 Container.profit_ctr_id,    
	 Container.receipt_id,    
	 Container.line_id,    
	 Receipt.bulk_flag,    
	 Container.container_id,    
	 CONDEST.treatment_id,    
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
	  --Constituents.HAP,  
	  'T' AS hap_tap_ind,
	 (Receipt.quantity * CONVERT(money, CONDEST.container_percent)) / 100 AS quantity,    
	 Receipt.bill_unit_code,    
	 Container.container_size AS container_size,    
	 0 as empty_container_weight,  
	 0 as total_empty_container_weight,  
	 999999999999.99999 AS pound_conv,       
	 Receipt.container_count,    
	 999999999999.99999 AS pounds_received,    
	 0 as net_pounds_received,  
	 ProfileLab.consistency,      
	 ProfileLab.density AS c_density,    
	 999999999999.99999 AS pounds_constituent,    
	 999999999999.99999 AS ppm_concentration,  
	 0.00 AS chemical_weight_mg,
	 CONDEST.location,    
	 CONDEST.tracking_num, 
	 WasteCode.waste_type_code,       
	 ISNULL(ProcessLocation.location_report_flag, 'N') AS location_report_flag,    
	 Treatment.reportable_category,    
	 TreatmentCategory.reportable_category_desc,    
	 Generator.generator_name,    
	 CONDEST.location as process_location,    
	 CONDEST.disposal_date,    
	 CONDEST.sequence_id,  
	 Company.company_name,  
	 profit_ctr_name,
	 HT.TAP_585,
	 HT.TAP_586
	FROM Company  
	JOIN Receipt  
	 ON Company.company_id = Receipt.company_id   
	JOIN Container    
	 ON Container.company_id = Receipt.company_id    
	 AND Container.profit_ctr_id = Receipt.profit_ctr_id    
	 AND Container.receipt_id = Receipt.receipt_id    
	 AND Container.line_id = Receipt.line_id    
	 JOIN ProfitCenter  
	 ON  ProfitCenter.company_id = Receipt.company_id   
	 AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id  
	JOIN #ContainerDestination CONDEST  
	 ON CONDEST.company_id = Container.company_id    
	 AND CONDEST.profit_ctr_id = Container.profit_ctr_id    
	 AND CONDEST.receipt_id = Container.receipt_id    
	 AND CONDEST.line_id =  Container.line_id    
	 AND CONDEST.container_id = Container.container_id    
	 AND CONDEST.disposal_date BETWEEN @date_from AND @date_to    
	JOIN Generator    
	 ON Generator.generator_id = Receipt.generator_id    
	JOIN Treatment    
	 ON Treatment.company_id = CONDEST.company_id    
	 AND Treatment.profit_ctr_id = CONDEST.profit_ctr_id    
	 AND Treatment.treatment_id = CONDEST.treatment_id    
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
	JOIN ContainerConstituent    
	 ON ContainerConstituent.company_id = Container.company_id    
	 AND ContainerConstituent.profit_ctr_id = Container.profit_ctr_id    
	 AND ContainerConstituent.receipt_id = Container.receipt_id    
	 AND ContainerConstituent.line_id = Container.line_id    
	 AND ContainerConstituent.container_id = Container.container_id    
	 AND ContainerConstituent.const_id = ReceiptConstituent.const_id    
	JOIN ProcessLocation    
	 ON  ProcessLocation.location = CONDEST.location    
	 AND ProcessLocation.company_id = CONDEST.company_id    
	 AND ProcessLocation.profit_ctr_id = CONDEST.profit_ctr_id      
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
	JOIN Constituent_HAP_TAP HT
	 ON HT.const_id = Constituents.const_id
	WHERE Receipt.company_id = @company_id    
	 AND Receipt.profit_ctr_id = @profit_ctr_id    
	 AND Receipt.receipt_status  = 'A'     
	 AND Receipt.trans_mode = 'I'     
	 AND Receipt.trans_type = 'D'    
	 AND Receipt.bulk_flag = 'T'    
	 AND (@approval_code = 'ALL' OR Receipt.approval_code = ISNULL(@approval_code, Receipt.approval_code)) 
	 AND ((@company_id <> 3) OR ((@company_id = 3) AND (Receipt.approval_code <> '000686'))) 
	 AND (HT.TAP_FLAG = 'T')
	ORDER BY treatment.treatment_desc, ProfileQuoteApproval.approval_code    


	-- Update Bill Unit from the ReceiptPrice table  
	UPDATE #tri_work_table SET container_size = rp.bill_unit_code    
	FROM ReceiptPrice rp    
	WHERE #tri_work_table.bulk_flag = 'F'    
	 AND #tri_work_table.receipt_id = rp.receipt_id    
	 AND #tri_work_table.line_id = rp.line_id    
	 AND #tri_work_table.profit_ctr_id = rp.profit_ctr_id    
	 AND #tri_work_table.company_id = rp.company_id    
	 AND (#tri_work_table.container_size IS NULL OR #tri_work_table.container_size = '')  
	 AND rp.price_id = (SELECT MIN(price_id) FROM ReceiptPrice rp2 WHERE rp2.receipt_id = rp.receipt_id     
		  AND rp2.line_id = rp.line_id AND rp2.profit_ctr_id = rp.profit_ctr_id    
		  AND rp2.company_id = rp.company_id)    
  
	-- Update Pound conversion factor and empty container weight from Bill Unit  
	UPDATE #tri_work_table     
	SET pound_conv = b.pound_conv,  
	empty_container_weight = b.empty_container_wt  
	FROM BillUnit b    
	WHERE #tri_work_table.container_size = b.bill_unit_code    
	 AND b.pound_conv is not null    
	 AND ((#tri_work_table.bill_unit_code IS NULL)    
	  OR (#tri_work_table.bill_unit_code <> #tri_work_table.container_size)    
	  OR (#tri_work_table.pound_conv = 999999999999.99999))    
  
	-- Calculate Pounds Received usig the SQL function  
	UPDATE #tri_work_table     
	SET pounds_received = dbo.fn_receipt_weight_container(#tri_work_table.receipt_id, #tri_work_table.line_id, #tri_work_table.profit_ctr_id, #tri_work_table.company_id, #tri_work_table.container_id, #tri_work_table.sequence_id)     
	FROM #tri_work_table  
  
	-- Delete the ones where the pound_conv is the original value  
	-- (happens only if the Bill unit code doesn't match with Bill Unit table)  
	DELETE FROM #tri_work_table where pound_conv = 999999999999.99999  
  
	-- Calculate Total Empty Container and Net Pounds Received  
	UPDATE #tri_work_table  
	SET total_empty_container_weight = IsNull(empty_container_weight, 0) ,  -- Muliplying with container_count removed 03/21/2025
	net_pounds_received = pounds_received - (IsNull(empty_container_weight, 0))  -- Muliplying with container_count removed 03/21/2025
	FROM #tri_work_table  

	-- Update density based on Consistency  
	UPDATE  #tri_work_table SET c_density = 12.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'solid%'    
	UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'sludge%'    
	UPDATE  #tri_work_table SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'semi-solid%'    
	UPDATE  #tri_work_table SET c_density = 8.3453 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'liquid%'    
	UPDATE  #tri_work_table SET c_density = 7.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'dust%'    
	UPDATE  #tri_work_table SET c_density = 5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'debris%'    
  
	-- Update Density as 12.5 (Solid) for those records that didn't get updated previously  
	UPDATE  #tri_work_table SET c_density = 12.5 WHERE c_density IS NULL OR c_density = 0  
  
	-- Update Pounds_Constituent using 'Net Pounds Received', 'Concentration' based on unit  
	UPDATE #tri_work_table SET pounds_constituent = (ROUND(net_pounds_received, 5) * ( ROUND(concentration, 5) / 1000000) )    
	WHERE unit IN ('ppm','ppmw','mg/kg') AND concentration IS NOT NULL AND net_pounds_received IS NOT NULL    
    
	UPDATE #tri_work_table SET pounds_constituent = (ROUND(net_pounds_received, 5) * (ROUND(concentration, 5) / 100) )    
	WHERE unit = '%' AND concentration IS NOT NULL AND net_pounds_received IS NOT NULL    
    
	UPDATE #tri_work_table SET pounds_constituent = ((ROUND(net_pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 0.000008345))    
	WHERE unit = 'mg/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND net_pounds_received IS NOT NULL    
  
	UPDATE #tri_work_table SET pounds_constituent = Round ( (ROUND(net_pounds_received, 5) * ( ROUND(concentration, 5) * 0.000000001) ) , 5 )    
	WHERE unit IN ('ppb','ug/kg') AND concentration IS NOT NULL AND net_pounds_received IS NOT NULL    
    
	UPDATE #tri_work_table SET pounds_constituent = Round ( ((ROUND(net_pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 8.3453 * 0.000000001)) , 5 )    
	WHERE unit = 'ug/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND net_pounds_received IS NOT NULL  
  
	-- Update Pounds_Constituent to 0 for those rows that didn't get updated previously  
	UPDATE #tri_work_table SET pounds_constituent = 0 WHERE pounds_constituent =  999999999999.99999    
  
	-- Update PPM concentration based on Pounds_Constituent and Net Pounds Received  
	UPDATE #tri_work_table SET ppm_concentration = ROUND(((pounds_constituent * 1000000)/net_pounds_received),5)    
	WHERE net_pounds_received IS NOT NULL AND net_pounds_received > 0 AND pounds_constituent IS NOT NULL    
  
	-- Update PPM_concentration to 0 for those rows that didn't get updated previously  
	UPDATE #tri_work_table SET ppm_concentration = 0 WHERE ppm_concentration =  999999999999.99999  

	-- Update Chemical Weight in Milligrams = Net Pounds Received * Concentration * KG Conversion Factor * 1,000,000  
	 SELECT @kilogram_conversion_factor = IsNull(kg_conv, 1) FROM BillUnit  
	 WHERE Upper(Trim(bill_unit_code)) = 'LBS'  
  
	 UPDATE #tri_work_table SET chemical_weight_mg = Round(net_pounds_received * concentration * @kilogram_conversion_factor, 5)  

	-- Final Select - Join Temp Table with Batch_Treatment_note table for Duration(s) of Treatment  
	SELECT   
	 DISTINCT  
	 worktable.company_id 'Company ID',  
	 worktable.company_name 'Company Name',  
	 worktable.profit_ctr_id 'Profit Center ID',  
	 worktable.profit_ctr_name 'Profit Center Name',  
	 worktable.disposal_date 'Disposal Date',  
	 worktable.treatment_id 'Treatment ID',  
	 worktable.treatment_desc 'Treatment Description',  
	 worktable.process_location,  
	 worktable.approval_code 'Approval Code',  
	 worktable.receipt_id 'Receipt ID',  
	 worktable.line_id 'Line ID',  
	 worktable.const_id 'Constituent ID',  
	 worktable.const_desc 'Constituent Description',  
	 worktable.cas_code 'CAS Code',  
	 worktable.pounds_received,  
	 worktable.total_empty_container_weight,  
	 worktable.net_pounds_received,  
	 worktable.concentration,  
	 worktable.ppm_concentration, 
	 worktable.chemical_weight_mg,
	 worktable.hap_tap_ind,  
	 treatmentnote.treatment_Start,  
	 treatmentnote.treatment_End,  
	 treatmentnote.duration_of_treatment,  
	 worktable.location, --Added for US146406
	 worktable.tracking_num, --Added for US146406
	 worktable.TAP_585,
	 worktable.TAP_586
	FROM #tri_work_table worktable LEFT OUTER JOIN dbo.batch_treatment_note treatmentnote  
	ON worktable.company_id = treatmentnote.company_id
	and worktable.profit_ctr_id = treatmentnote.profit_ctr_id
	and worktable.location = treatmentnote.location
	and worktable.tracking_num = treatmentnote.tracking_num
	WHERE worktable.pounds_constituent > 0.000005  
	ORDER BY worktable.company_id, worktable.profit_ctr_id, worktable.const_id, worktable.const_desc, worktable.treatment_id,
	worktable.treatment_desc, worktable.approval_code, worktable.location
END
GO

-- Grant execution permissions to users
GRANT EXECUTE ON [dbo].[sp_rpt_tap_with_weight_and_treatment_duration] TO EQAI
GO