USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_rpt_hap_with_weight_and_treatment_duration]    Script Date: 4/28/2025 8:41:30 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_hap_with_weight_and_treatment_duration]
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@approval_code		varchar(15)
,	@batch_location		varchar(15)
,	@tracking_num		varchar(15)
,	@treatment_id		int
,	@treatment_category	int
AS
/*************************************************************************************
This procedure runs for the HAP Constituent with Weight and Treatment Duration report

PB Object(s):	r_hap_report_with_weight_and_treatment_duration

This report was created taking the sp_rpt_hap_worksheet as the base, however this report
doesn't have the rolling tons and emission factors. It does, in addition, bring the
Duration(s) of treatment from the batch_treatment_note table. It also takes the empty
container weight into consideration while calculating the weight of the waste and uses
this as a baseline for further calculations

02/22/2025	KM	Initial version created for US140683
04/04/2025	KM	Removed the multiplier of 1 MIL while calculating the value of
				chemical_weight_mg column for US149085
05/29/2025	KS - Rally US116196 - Constituent - Integer data type preventing CAS # entry
06/16/2025 KS - Rally US157223 - Stored Procedure update to fix datatypes and refactoring the UNIONs.
*************************************************************************************/
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @kilogram_conversion_factor DECIMAL(18, 5)

	IF @treatment_id = -99 SET @treatment_id = NULL
	IF @treatment_category = -99 SET @treatment_category = NULL

	DROP TABLE IF EXISTS #tri_work_table;
	CREATE TABLE #tri_work_table ( 
		company_id				int			null
	,	profit_ctr_id			int			null
	,	receipt_id				int			null
	,	line_id					int			null
	,	bulk_flag				char(1)		null
	,	container_id			int			null
	,	treatment_id			int			null
	,	treatment_desc			varchar(32) null
	,	approval_code			varchar(16) null
	,	concentration			decimal(18, 5) null
	,	unit					varchar(10) null
	,	density					decimal(18, 5) null
	,	const_id				int			null
	,	cas_code				bigint		null
	,	const_desc				varchar(50) null
	,	hap_ind					char(1)		null
	,	quantity				decimal(18, 5) null
	,	bill_unit_code			varchar(4)	null
	,	container_size			varchar(15) null
	,	empty_container_weight	decimal(10, 3) null
	,	total_empty_container_weight	decimal(10, 3) null
	,	pound_conv				decimal(18, 5) null
	,	container_count			int			null
	,	pounds_received			decimal(18, 5) null
	,	net_pounds_received		decimal(18, 5) null
	,	consistency				varchar(50) null
	,	c_density				decimal(18, 3) null
	,	pounds_constituent		decimal(30, 17) null
	,	ppm_concentration		decimal(18, 5) null
	,	chemical_weight_mg		decimal(18, 5) null
	,	location				varchar(16) null
	,	tracking_num			varchar(15)	null
	,	waste_type_code			varchar(2)	null
	,	location_report_flag	char(1)		null
	,	reportable_category		int			null
	,	reportable_category_desc varchar(60) null
	,	generator_name			varchar(50) null
	,	process_location		varchar(15) null
	,	disposal_date			datetime
	,	sequence_id				int			null
	,	company_name VARCHAR(35)
	,	profit_ctr_name VARCHAR(50)
	)

	DROP TABLE IF EXISTS #ContainerDestination;
	CREATE TABLE #ContainerDestination(
		company_id INT 
	,	profit_ctr_id INT 
	, 	receipt_id INT 
	, 	line_id INT 
	, 	container_id INT
	,	treatment_id INT 
	,	location VARCHAR(15)
	,	tracking_num VARCHAR(15)
	,	disposal_date DATETIME INDEX idx_tmp_disposal_date NONCLUSTERED
	,	sequence_id INT
	,	container_percent INT
	,	INDEX idx_tmp_company_id_profit_ctr_id_receipt_id_line_id_container_id NONCLUSTERED(company_id, profit_ctr_id, receipt_id, line_id, container_id)
	,	INDEX idx_tmp_company_id_profit_ctr_id_treatment_id NONCLUSTERED(company_id, profit_ctr_id, treatment_id)
	,	INDEX idx_tmp_company_id_profit_ctr_id_location NONCLUSTERED(company_id, profit_ctr_id, location));

	-- Select all Container Destination records for the Company ID, Profit Center Id, and Disposal Date Range
	INSERT INTO #ContainerDestination
		(company_id, profit_ctr_id, receipt_id, line_id, container_id, treatment_id, location, tracking_num, disposal_date, sequence_id, container_percent)
	SELECT	company_id, profit_ctr_id, receipt_id, line_id, container_id, treatment_id, location, tracking_num, disposal_date, sequence_id, container_percent  
	FROM	ContainerDestination
	 WHERE	company_id = @company_id  
	 AND	profit_ctr_id = @profit_ctr_id  
	 AND	disposal_date BETWEEN @date_from  AND @date_to
	 AND	(@batch_location = 'ALL' OR location = ISNULL(@batch_location, location))
	 AND	(@tracking_num = 'ALL' OR tracking_num = ISNULL(@tracking_num, tracking_num))

	-- CTE for common tables data 
	;WITH core_data_cte AS 
	(
	SELECT  
	 r.company_id,   
	 con.profit_ctr_id,  
	 con.receipt_id,
	 con.line_id,  
	 r.bulk_flag,  
	 con.container_id,
	 condest.treatment_id,
	 t.treatment_desc,
	 pqa.approval_code,
	 CASE
		WHEN rc.typical_concentration IS NOT NULL 
			THEN rc.typical_concentration  
		WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NULL AND rc.concentration IS NOT NULL 
			THEN rc.concentration
		WHEN rc.typical_concentration IS NULL AND rc.concentration IS NULL AND rc.min_concentration IS NOT NULL 
			THEN rc.min_concentration 				 
		WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NOT NULL AND rc.concentration IS NOT NULL 
			THEN (rc.min_concentration + rc.concentration)/2
	 END AS concentration,
	 rc.unit,
	 plab.density,
	 rc.const_id,  
	 const.cas_code,  
	 const.const_desc,  
	 const.HAP,   
	 condest.container_percent,
	 r.quantity,
	 r.bill_unit_code,  
	 con.container_size AS container_size,
	 0 as empty_container_weight,
	 0 as total_empty_container_weight,
	 999999999999.99999 AS pound_conv, 	 
	 r.container_count,  
	 999999999999.99999 AS pounds_received,  
	 0 as net_pounds_received,
	 plab.consistency,  
	 plab.density AS c_density,  
	 999999999999.99999 AS pounds_constituent,  
	 999999999999.99999 AS ppm_concentration,
	 0.00 AS chemical_weight_mg,
	 condest.location,  
	 condest.tracking_num,
	 wc.waste_type_code,   
	 ISNULL(pl.location_report_flag, 'N') AS location_report_flag,  
	 t.reportable_category,  
	 tc.reportable_category_desc,  
	 g.generator_name, 
	 condest.location as process_location,  
	 condest.disposal_date,  
	 condest.sequence_id,
	 c.company_name,
	 profit_ctr_name
	FROM Company c
	JOIN Receipt r
	 ON c.company_id = r.company_id
	JOIN Container con 
	 ON con.company_id = r.company_id  
	 AND con.profit_ctr_id = r.profit_ctr_id  
	 AND con.receipt_id = r.receipt_id  
	 AND con.line_id = r.line_id
	JOIN ProfitCenter pc
	 ON  pc.company_id = r.company_id 
	 AND pc.profit_ctr_id = r.profit_ctr_id
	JOIN #ContainerDestination condest
	 ON condest.company_id = con.company_id  
	 AND condest.profit_ctr_id = con.profit_ctr_id  
	 AND condest.receipt_id = con.receipt_id  
	 AND condest.line_id =  con.line_id  
	 AND condest.container_id = con.container_id
	JOIN Generator g
	 ON g.generator_id = r.generator_id  
	JOIN Treatment t
	 ON t.company_id = condest.company_id  
	 AND t.profit_ctr_id = condest.profit_ctr_id  
	 AND t.treatment_id = condest.treatment_id  
	 AND t.treatment_id = ISNULL(@treatment_id, t.treatment_id)
	 AND t.reportable_category = ISNULL(@treatment_category, t.reportable_category)
	 AND t.reportable_category <> 4  
	JOIN TreatmentCategory  tc 
	 ON tc.reportable_category = t.reportable_category 
	JOIN ReceiptConstituent rc 
	 ON rc.company_id = con.company_id  
	 AND rc.profit_ctr_id = con.profit_ctr_id  
	 AND rc.receipt_id = con.receipt_id  
	 AND rc.line_id = con.line_id  
	 AND rc.concentration IS NOT NULL 
	JOIN Constituents const 
	 ON const.const_id = rc.const_id  
	 AND const.cas_code IS NOT NULL  
	 AND const.hap = 'T'  
	JOIN ProcessLocation pl 
	 ON pl.company_id = condest.company_id  
	 AND pl.profit_ctr_id = condest.profit_ctr_id  
	 AND pl.location = condest.location  
	JOIN Profile p
	 ON p.profile_id = r.profile_id  
	 AND p.curr_status_code = 'A'  
	JOIN ProfileQuoteApproval pqa
	 ON pqa.company_id = r.company_id  
	 AND pqa.profit_ctr_id = r.profit_ctr_id  
	 AND pqa.profile_id = r.profile_id  
	 AND pqa.approval_code = r.approval_code  
	JOIN ProfileLab plab  
	 ON plab.profile_id = p.profile_id  
	 AND plab.type = 'A'  
	JOIN WasteCode wc
	 ON wc.waste_code_uid = p.waste_code_uid  	 
	WHERE r.company_id = @company_id  
	 AND r.profit_ctr_id = @profit_ctr_id  
	 AND r.receipt_status  = 'A'   
	 AND r.trans_mode = 'I'   
	 AND r.trans_type = 'D'  
	 AND r.bulk_flag IN ('T', 'F' )
	 AND (@approval_code = 'ALL' OR r.approval_code = ISNULL(@approval_code, r.approval_code))  
	 AND ((@company_id <> 3) OR ((@company_id = 3) AND (r.approval_code <> '000686')))
	 )
	 
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
	 hap_ind, 
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
	 profit_ctr_name)
	 SELECT 
	 cte.company_id,   
	 cte.profit_ctr_id,  
	 cte.receipt_id,
	 cte.line_id,  
	 bulk_flag,  
	 cte.container_id,
	 treatment_id,
	 treatment_desc,
	 approval_code,
	 concentration,
	 unit,
	 density,
	 cte.const_id,
	 cas_code,
	 const_desc,
	 hap, 
	 CASE 
		WHEN bulk_flag = 'F' 
			THEN (1 * CONVERT(money, container_percent)) / 100
		WHEN bulk_flag = 'T' 
			THEN (quantity * CONVERT(money, container_percent)) / 100 END AS quantity,
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
	 cte.sequence_id,
	 company_name,
	 profit_ctr_name
	 FROM core_data_cte cte
	 LEFT JOIN ContainerConstituent cc
	 ON cte.receipt_id = cc.receipt_id   
		 AND cte.line_id = cc.line_id AND cte.profit_ctr_id = cc.profit_ctr_id  
		 AND cte.company_id = cc.company_id
	 WHERE cc.const_id IS NULL
	 UNION
	 SELECT 
	 cte.company_id,   
	 cte.profit_ctr_id,  
	 cte.receipt_id,
	 cte.line_id,  
	 bulk_flag,  
	 cte.container_id,
	 treatment_id,
	 treatment_desc,
	 approval_code,
	 concentration,
	 unit,
	 density,
	 cc.const_id,
	 cas_code,
	 const_desc,
	 hap,  
	 CASE 
		WHEN bulk_flag = 'F' 
			THEN (1 * CONVERT(money, container_percent)) / 100
		WHEN bulk_flag = 'T' 
			THEN (quantity * CONVERT(money, container_percent)) / 100 END AS quantity,
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
	 cte.sequence_id,
	 company_name,
	 profit_ctr_name
	 FROM core_data_cte cte
	 JOIN ContainerConstituent cc
	 ON cc.company_id = cte.company_id  
	 AND cc.profit_ctr_id = cte.profit_ctr_id  
	 AND cc.receipt_id = cte.receipt_id  
	 AND cc.line_id = cte.line_id  
	 AND cc.container_id = cte.container_id  
	 AND cc.const_id = cte.const_id

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
	SET total_empty_container_weight = IsNull(empty_container_weight, 0) , -- Removed muliplying with container_count
	net_pounds_received = pounds_received - (IsNull(empty_container_weight, 0)) --Removed muliplying with container_count
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
	SELECT @kilogram_conversion_factor = IsNull(kg_conv, 1) from BillUnit
	where Upper(Trim(bill_unit_code)) = 'LBS'

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
	 worktable.hap_ind,
	 treatmentnote.treatment_Start,
	 treatmentnote.treatment_End,
	 treatmentnote.duration_of_treatment,
	 worktable.location,
	 worktable.tracking_num
	FROM #tri_work_table worktable 
	LEFT OUTER JOIN dbo.batch_treatment_note treatmentnote
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
GRANT EXECUTE ON [dbo].[sp_rpt_hap_with_weight_and_treatment_duration] TO EQAI
GO