DROP PROCEDURE IF EXISTS sp_receipt_container_log
GO

CREATE PROCEDURE sp_receipt_container_log
	@receipt_id	int,
	@profit_ctr_id	int,
	@company_id int
AS
/***************************************************************************
Receipt Process Sheet

Filename:	L:\Apps\SQL\EQAI\sp_receipt_container_log.sql
PB Object(s):	d_receipt_form_container_log

01/10/2006 MK	Created from sp_receipt_process_nonbulk - removed join to container
03/15/2006 RG	removed join to wastecode profitctr
06/30/2006 RG	modifed for approval to profile
07/03/2006 SCC	Changed to join receipt to profile tables using company,profit_ctr, approval_code, too
05/08/2007 JDB	Removed territory_code from select (not used)	
05/17/2007 SCC	Changed to create tmp tables and insert into them
09/25/2007 SCC	Modified for performance improvements
10/17/2008 KAM  Added the receipt ccvoc value into the returned columns so it can be diplayed on the report
08/28/2013 Anitha Changed waste_code to display_name	
10/07/2013 Anitha Modified code to get secondary waste codes from receiptwastecode table instead of receipt table.
06/16/2014 AM  Moved to plt_ai.
07/08/2014 SK Added Missing joins on company_id
07/08/2016 RB Added color and consistency to report
02/27/2017 MPM	Replaced manifest_line_id with manifest_line.
03/27/2017 MPM	Added generator_address_1 through dot_shipping_desc.
04/27/2017 MPM	Added DisposalService.cwt_category_required_flag.
12/20/2017 AM   Added safety Codes.
12/21/2017 AM   Added safety Codes description.
04/25/2018 AM   Added air_permit_status_code
10/04/2018 MPM	Task 5169 - Added thermal_blending_required_flag and thermal_blending_ratio.
09/03/2021 MPM	DevOps 16290 - Updated the value of #log.total_quantity.
04/15/2022 MPM	DevOps 41397 - Increased the column widths for #log.customer_name, #log.generator_name, 
				and #log.generator_address_1 to match the widths of those columns in the 
				Customer and Generator tables to avoid truncation errors.

sp_receipt_container_log 1178742, 0 , 21
sp_receipt_container_log 1171941, 0 , 21
sp_receipt_container_log 2086343, 0 , 21

***************************************************************************/
DECLARE	@process_count int, 
	@qty int, 
	@approval varchar(15),
	@line_id int,
	@count_waste_code int,
	@count_waste_code_idx int,
	@secondary_waste_codes varchar(255),
	@display_name varchar(10),
	@container_count int,
	@container_flag char(1),
	@process_id int,
    @count_safety_code int,
    @safety_codes varchar(max),
    @count_safety_code_idx int,
    @code varchar(3),
    @description varchar (38)
    
CREATE TABLE #log (
	generator_name		varchar(75) NULL,
	manifest		varchar(15) NULL,
	quantity		float NULL,
	container_count		int NULL,
	total_quantity		float NULL,
	approval_code		varchar(15) NULL,
	receipt_date		datetime NULL,
	service_desc		varchar(60) NULL,
	bulk_flag		char(1) NULL,
	bill_unit_code		varchar(4) NULL,
	waste_common_approval	varchar(50) NULL,
	waste_common_wastecode	varchar(60) NULL,
	display_name            varchar(10) NULL,
	manifest_line	int NULL,
	hand_instruct		text NULL, 
	line_id			int NULL,
	OTS_flag		char(1) NULL,
	approval_comments	text NULL,
	lab_comments		text NULL,
	treatment_id		int NULL, 
	secondary_waste_codes	varchar(255) NULL,
	treatment_desc		varchar(50) NULL,
	manifest_page_num	int NULL,
	profit_ctr_name		varchar(50) NULL,
	generator_id		int NULL,
	generator_EPA_ID	varchar(15) NULL,
	time_in			datetime NULL, 
	date_scheduled		datetime NULL,
	truck_code		varchar(10) NULL, 
	hauler			varchar(20) NULL,
	manifest_comment	varchar(100) NULL,
	ccvoc			float NULL,
	ddvoc			float NULL,
	tank_type		char(1) NULL,
	company_id		int NULL,
	location_control	char(1) NULL,
	process_id		int NULL,
	profile_id		int NULL,
	color			varchar(25) NULL,
	consistency		varchar(50) NULL,
	generator_address_1	varchar(85) NULL,
	generator_address_2	varchar(40) NULL,
	generator_address_3	varchar(40) NULL,
	generator_address_4	varchar(40) NULL,
	generator_city		varchar(40) NULL,
	generator_state		varchar(2) NULL,
	generator_zip_code	varchar(15) NULL,
	gen_process			varchar(max) NULL,
	csr_name			varchar(40) NULL,
	customer_id			int NULL,
	customer_name		varchar(75) NULL,
	purchase_order		varchar(20) NULL,
	release				varchar(20) NULL,
	facility_description varchar(20) NULL,
	print_facility_desc_flag char(1) NULL,
	cwt_category		varchar(10) NULL,
	manifest_quantity	float NULL,
	manifest_unit		varchar(4) NULL,
	dot_shipping_desc	varchar(400) NULL,
	cwt_category_required_flag	char(1) NULL,
	safety_codes		varchar(max)NULL,
	safety_codes_process_id int,
	air_permit_status_code varchar(10),
	thermal_blending_required_flag	char(1) NULL,
	thermal_blending_ratio	int NULL
)

CREATE TABLE #log_waste (
	display_name            varchar(10) NULL,
	process_flag		int NULL
)

CREATE TABLE #log_safety_code(
	code                varchar(3) NULL,
	process_flag		int NULL,
	description			varchar(38)
)

INSERT #log
  SELECT Generator.generator_name, 
	Receipt.manifest,
	Receipt.quantity,
	Receipt.container_count,
	Receipt.container_count AS total_quantity,
	Receipt.approval_code,
	Receipt.receipt_date,
	Receipt.service_desc,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	waste_common_approval = Profile.approval_desc,
	waste_common_wastecode = Wastecode.waste_code_desc,
	wastecode.display_name,
	Receipt.manifest_line,
	Profile.hand_instruct, 
	Receipt.line_id,
	Profile.OTS_flag,
	Profile.approval_comments,
	Receipt.lab_comments,
	Receipt.treatment_id, 
	CONVERT(varchar(255), '') AS secondary_waste_codes,
	Treatment.treatment_desc,
	Receipt.manifest_page_num,
	ProfitCenter.profit_ctr_name,
	Generator.generator_id,
	Generator.EPA_ID AS generator_EPA_ID,
	Receipt.time_in, 
	Receipt.date_scheduled,
	Receipt.truck_code, 
	Receipt.hauler,
	Receipt.manifest_comment,
	Receipt.ccvoc,
	Receipt.ddvoc,
	Treatment.tank_type,
	Receipt.company_id,
	convert(char(1),null) as location_control,
	process_id = 0,
	Profile.profile_id,
	ProfileLab.color,
	ProfileLab.consistency,
	Generator.generator_address_1,
	Generator.generator_address_2,
	Generator.generator_address_3,
	Generator.generator_address_4,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code,
	Profile.gen_process,
	IsNull(csr.user_name, ''),
	Customer.customer_ID,
	Customer.cust_name,
	Receipt.purchase_order,
	Receipt.release,
	TreatmentDetail.facility_description,
	IsNull(ProfitCenter.print_facility_treatment_desc_on_container_labels_flag, 'F'),
	CWTCategory.cwt_category,
	Receipt.manifest_quantity,
	BillUnit.bill_unit_code,
	dbo.fn_dot_shipping_desc(Profile.profile_id),
	DisposalService.cwt_category_required_flag,
	CONVERT(varchar(255), '') AS safety_code,
	safety_codes_process_id = 0,
	IsNull ( AirPermitStatus.air_permit_status_code, ''),
	ISNULL(ProfileQuoteApproval.thermal_blending_required_flag, 'F'),
	ProfileQuoteApproval.thermal_blending_ratio
FROM Receipt
	JOIN Customer ON ( Receipt.customer_id = Customer.customer_id ) 
        JOIN ProfitCenter on (Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id )
		AND (Receipt.company_id = ProfitCenter.company_id)
	LEFT OUTER JOIN Wastecode ON ( Receipt.waste_code_uid = WasteCode.waste_code_uid )
	LEFT OUTER JOIN Treatment ON ( Receipt.treatment_id = Treatment.treatment_id ) 
		AND Treatment.company_id = Receipt.company_id
		AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	LEFT OUTER JOIN TreatmentDetail ON TreatmentDetail.treatment_id = Treatment.treatment_id
		AND TreatmentDetail.company_id = Receipt.company_id
		AND TreatmentDetail.profit_ctr_id = Receipt.profit_ctr_id
	LEFT OUTER JOIN Generator on (Generator.generator_id = receipt.generator_id ) 
 	LEFT OUTER JOIN ProfileQuoteApproval ON (Receipt.profile_id = ProfileQuoteApproval.profile_id)
		AND (Receipt.company_id = ProfileQuoteApproval.company_id)
		AND (Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
		AND (Receipt.approval_code = ProfileQuoteApproval.approval_code)
    LEFT OUTER JOIN Profile ON ( Receipt.profile_id = Profile.profile_id ) 
		AND (Profile.curr_status_code = 'A')
	LEFT OUTER JOIN ProfileLab ON (Receipt.profile_id = ProfileLab.profile_id
		AND ProfileLab.type = 'A')
	LEFT OUTER JOIN CustomerBilling ON (Receipt.customer_id = CustomerBilling.customer_id
		AND Receipt.billing_project_id = CustomerBilling.billing_project_id)
   LEFT OUTER JOIN usersxeqcontact csrx ON customerbilling.customer_service_id = csrx.type_id
          AND csrx.eqcontact_type = 'CSR'
   LEFT OUTER JOIN users csr ON csrx.user_code = csr.user_code
   LEFT OUTER JOIN CWTCategory ON CWTCategory.cwt_category_uid = ProfileQuoteApproval.cwt_category_uid
   LEFT OUTER JOIN BillUnit ON BillUnit.manifest_unit = Receipt.manifest_unit
   LEFT OUTER JOIN DisposalService ON DisposalService.disposal_service_id = ProfileQuoteApproval.disposal_service_id
   LEFT OUTER JOIN AirPermitStatus  ON  ( AirPermitStatus.company_id = ProfileQuoteApproval.company_id)
		AND (AirPermitStatus.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
		AND (AirPermitStatus.air_permit_status_uid = ProfileQuoteApproval.air_permit_status_uid)  
WHERE (Receipt.trans_type = 'D' OR Receipt.trans_type = 'W')
AND Receipt.trans_mode = 'I'
AND Receipt.approval_code IS NOT NULL
AND Receipt.receipt_id = @receipt_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND (Receipt.bulk_flag IS NULL OR Receipt.bulk_flag = 'F')

update #log
set location_control = ProfileQuoteApproval.location_control
from #log inner join ProfileQuoteApproval on (#log.profile_id = ProfileQuoteApproval.profile_id)
where ProfileQuoteApproval.profit_ctr_id = @profit_ctr_id
and ProfileQuoteApproval.company_id = @company_id

-- How many records do we need to process?
SELECT @process_count = COUNT(*) FROM #log where process_id = 0

--print 'Process count: ' + str(@process_count)

WHILE @process_count > 0
BEGIN
	Select @line_id = min(line_id) from #log where process_id = 0

	SET ROWCOUNT 1
	SELECT @approval = approval_code, @container_count = container_count
	FROM #log WHERE line_id = @line_id

--	print 'Line id: ' + str(@line_id) + ', Approval: ' + @approval 

	-- Get list of secondary waste codes
	SET ROWCOUNT 0

	INSERT #log_waste
  	SELECT DISTINCT WasteCode.display_name, 0 as process_flag
	FROM Receiptwastecode , WasteCode
   	WHERE Receiptwastecode.waste_code_uid = wastecode.waste_code_uid 
        AND Receiptwastecode.receipt_id = @receipt_id
     	AND Receiptwastecode.line_id = @line_id
     	AND Receiptwastecode.profit_ctr_id = @profit_ctr_id
		AND Receiptwastecode.company_id = @company_id
	AND ReceiptWasteCode.primary_flag = 'F'
	ORDER BY WasteCode.display_name
	
	SELECT @count_waste_code = COUNT(*) FROM #log_waste
	IF @count_waste_code > 51 SELECT @count_waste_code = 51

	-- Build list of secondary codes
	SET ROWCOUNT 1
	SELECT @secondary_waste_codes = '', @count_waste_code_idx = @count_waste_code
	WHILE @count_waste_code_idx > 0
	BEGIN
		SELECT @display_name = display_name FROM #log_waste WHERE process_flag = 0
		IF @count_waste_code_idx = @count_waste_code
			SELECT @secondary_waste_codes = @display_name
		ELSE
			SELECT @secondary_waste_codes = @secondary_waste_codes + ' ' + @display_name
		SELECT @count_waste_code_idx = @count_waste_code_idx - 1
		UPDATE #log_waste SET process_flag = 1 WHERE process_flag = 0
	END 
	TRUNCATE TABLE #log_waste	

	SET ROWCOUNT 0
	UPDATE #log SET secondary_waste_codes = @secondary_waste_codes, process_id = 1 where line_id = @line_id
	SELECT @process_count = COUNT(*) FROM #log where process_id = 0
END
SET ROWCOUNT 0


-- Safteycode
-- How many records do we need to process?
SELECT @process_count = COUNT(*) FROM #log where safety_codes_process_id = 0

WHILE @process_count > 0
BEGIN
	Select @line_id = min(line_id) from #log where safety_codes_process_id = 0
	
	SET ROWCOUNT 0

	INSERT #log_safety_code
  	SELECT DISTINCT SafetyCode.code,0 as process_flag, SafetyCode.description
	FROM ProfileSafetyCode, SafetyCode, #log
   	WHERE  ProfileSafetyCode.profile_id  = #log.profile_id 
        AND ProfileSafetyCode.safety_code = SafetyCode.code 
        AND #log.line_id = @line_id 
     	AND ProfileSafetyCode.profit_ctr_id = @profit_ctr_id
		AND ProfileSafetyCode.company_id = @company_id
	ORDER BY SafetyCode.code
	
	SELECT @count_safety_code = COUNT(*) FROM #log_safety_code
	
	--IF @count_safety_code > 51 SELECT @count_safety_code = 51

		-- Build list of safety codes
	SET ROWCOUNT 1
	SELECT @safety_codes = '', @count_safety_code_idx = @count_safety_code
	WHILE @count_safety_code_idx > 0
	BEGIN
		SELECT @code = #log_safety_code.code, @description = #log_safety_code.description  FROM #log_safety_code WHERE process_flag = 0 
		IF @count_safety_code_idx = @count_safety_code
			SELECT @safety_codes = @safety_codes  + @description
		ELSE
		  SELECT @safety_codes = @safety_codes +  + ', ' + @description  --' ' + @code  + 
		SELECT @count_safety_code_idx = @count_safety_code_idx - 1
		UPDATE #log_safety_code SET process_flag = 1 WHERE process_flag = 0
	END 
	TRUNCATE TABLE #log_safety_code	

	SET ROWCOUNT 0
	UPDATE #log SET safety_codes = @safety_codes, safety_codes_process_id = 1 where line_id = @line_id

	SELECT @process_count = COUNT(*) FROM #log where safety_codes_process_id = 0
END
SET ROWCOUNT 0

SELECT * FROM #log ORDER BY line_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_container_log] TO [EQAI]
    AS [dbo];
GO

