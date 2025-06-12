CREATE PROCEDURE sp_rpt_receipt_load_cover_sheet
	@company_id		int,
	@profit_ctr_id	int,
	@receipt_id		int,
	@line_ids		varchar(max),
	@all_lines		char(1)
	
AS 
/***************************************************************************
Receipt Load Cover Sheet

PB Object(s):	d_receipt_form_container_log

10/05/2018 MPM	Created from sp_receipt_container_log.

exec sp_rpt_receipt_load_cover_sheet 42, 0, 321302, null
exec sp_rpt_receipt_load_cover_sheet 42, 0, 321302, 2
exec sp_rpt_receipt_load_cover_sheet 27, 0, 139364, null
exec sp_rpt_receipt_load_cover_sheet 45, 0, 602339, null
exec sp_rpt_receipt_load_cover_sheet 46, 0, 600017, null
exec sp_rpt_receipt_load_cover_sheet 45, 0, 601618, '1, 2', 'T'
exec sp_rpt_receipt_load_cover_sheet 45, 0, 601618, '2', 'F'

***************************************************************************/
DECLARE	@process_count int, 
	@count_waste_code int,
	@count_waste_code_idx int,
	@secondary_waste_codes varchar(255),
	@display_name varchar(10),
    @count_safety_code int,
    @safety_codes varchar(max),
    @count_safety_code_idx int,
    @code varchar(3),
    @description varchar (38),
    @line_id int

	CREATE TABLE #line_ids (
		line_id		int
	)
	
	INSERT #line_ids
	SELECT row
	from dbo.fn_SplitXsvText(',', 1, @line_ids)
	WHERE isnull(row,'') <> ''    
	
CREATE TABLE #log (
	company_id		int NULL,
	profit_ctr_id	int NULL,
	receipt_id		int NULL,
	line_id			int NULL,
	manifest		varchar(15) NULL,
	quantity		float NULL,
	container_count		int NULL,
	approval_code		varchar(15) NULL,
	bill_unit_code		varchar(4) NULL,
	waste_common_approval	varchar(50) NULL,
	receipt_waste_code      varchar(10) NULL,
	manifest_line	int NULL,
	hand_instruct		text NULL, 
	OTS_flag		char(1) NULL,
	treatment_id		int NULL, 
	secondary_waste_codes	varchar(255) NULL,
	treatment_process		varchar(30) NULL,
	manifest_page_num	int NULL,
	profit_ctr_name		varchar(50) NULL,
	generator_id		int NULL,
	generator_EPA_ID	varchar(15) NULL,
	ccvoc			float NULL,
	process_id		int NULL,
	profile_id		int NULL,
	color			varchar(25) NULL,
	consistency		varchar(50) NULL,
	generator_name		varchar(40) NULL,
	generator_address_1	varchar(40) NULL,
	generator_address_2	varchar(40) NULL,
	generator_address_3	varchar(40) NULL,
	generator_address_4	varchar(40) NULL,
	generator_city		varchar(40) NULL,
	generator_state		varchar(2) NULL,
	generator_zip_code	varchar(15) NULL,
	safety_codes		varchar(max)NULL,
	safety_codes_process_id int,
	tax_group			varchar(10)	NULL,
	all_lines			char(1)	NULL
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
  SELECT Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.manifest,
	Receipt.quantity,
	Receipt.container_count,
	Receipt.approval_code,
	Receipt.bill_unit_code,
	waste_common_approval = Profile.approval_desc,
	wastecode.display_name as receipt_waste_code,
	Receipt.manifest_line,
	Profile.hand_instruct, 
	Profile.OTS_flag,
	Receipt.treatment_id, 
	CONVERT(varchar(255), '') AS secondary_waste_codes,
	Treatment.treatment_process_process, 
	Receipt.manifest_page_num,
	ProfitCenter.profit_ctr_name,
	Generator.generator_id,
	Generator.EPA_ID AS generator_EPA_ID,
	Receipt.ccvoc,
	process_id = 0,
	Profile.profile_id,
	ProfileLab.color,
	ProfileLab.consistency,
	Generator.generator_name, 
	Generator.generator_address_1,
	Generator.generator_address_2,
	Generator.generator_address_3,
	Generator.generator_address_4,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code,
	CONVERT(varchar(255), '') AS safety_code,
	safety_codes_process_id = 0,
	CONVERT(varchar(10), '') AS tax_group,
	@all_lines
FROM Receipt
    JOIN ProfitCenter 
        ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id 
		AND Receipt.company_id = ProfitCenter.company_id
	LEFT OUTER JOIN Wastecode 
		ON Receipt.waste_code_uid = WasteCode.waste_code_uid
	LEFT OUTER JOIN Treatment 
		ON Receipt.treatment_id = Treatment.treatment_id 
		AND Treatment.company_id = Receipt.company_id
		AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	LEFT OUTER JOIN Generator 
		ON Generator.generator_id = receipt.generator_id 
    LEFT OUTER JOIN Profile 
		ON Receipt.profile_id = Profile.profile_id 
		AND Profile.curr_status_code = 'A'
	LEFT OUTER JOIN ProfileLab 
		ON Receipt.profile_id = ProfileLab.profile_id
		AND ProfileLab.type = 'A'
WHERE (Receipt.trans_type = 'D' OR Receipt.trans_type = 'W')
AND Receipt.trans_mode = 'I'
AND Receipt.approval_code IS NOT NULL
AND Receipt.receipt_id = @receipt_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND Receipt.line_id in (select line_id from #line_ids)
AND (Receipt.bulk_flag IS NULL OR Receipt.bulk_flag = 'F')

-- Update the tax_group
update #log
set tax_group = (select distinct TaxCode.tax_group
					FROM Receipt
					JOIN ProfileQuoteApproval 
						ON Receipt.company_id = ProfileQuoteApproval.company_id
						AND Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
						AND Receipt.profile_id = ProfileQuoteApproval.profile_id
						AND Receipt.trans_type = 'D'
					JOIN ProfileQuoteDetail 
						ON ProfileQuoteApproval.company_id = ProfileQuoteDetail.company_id
						AND ProfileQuoteApproval.profit_ctr_id = ProfileQuoteDetail.profit_ctr_id
						AND ProfileQuoteApproval.profile_id = ProfileQuoteDetail.profile_id
						AND Receipt.bill_unit_code = ProfileQuoteDetail.bill_unit_code	
						AND ProfileQuoteDetail.record_type = 'S'
						AND IsNull(ProfileQuoteDetail.fee_exempt_flag, 'F') = 'F'
					JOIN Product
						ON Product.company_ID = ProfileQuoteDetail.company_id
						AND Product.profit_ctr_ID = ProfileQuoteDetail.profit_ctr_id
						AND Product.product_ID = ProfileQuoteDetail.product_id	
					JOIN TaxCode
						ON TaxCode.company_id = Product.company_id
						AND TaxCode.profit_ctr_id = Product.profit_ctr_id
						AND TaxCode.tax_code_uid = Product.tax_code_uid
					WHERE Receipt.company_id = #log.company_id
						AND Receipt.profit_ctr_id = #log.profit_ctr_id
						AND Receipt.receipt_id = #log.receipt_id
						AND Receipt.line_id = #log.line_id)	

-- How many records do we need to process?
SELECT @process_count = COUNT(*) FROM #log where process_id = 0

--print 'Process count: ' + str(@process_count)

WHILE @process_count > 0
BEGIN
	Select @line_id = min(line_id) from #log where process_id = 0

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

-- Safety codes
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
			SELECT @safety_codes = @safety_codes  + @code
		ELSE
		  SELECT @safety_codes = @safety_codes +  + ', ' + @code   
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
    ON OBJECT::[dbo].[sp_rpt_receipt_load_cover_sheet] TO [EQAI]
    AS [dbo];
GO

