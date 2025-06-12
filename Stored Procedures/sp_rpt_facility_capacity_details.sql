CREATE PROCEDURE sp_rpt_facility_capacity_details
	@company_id			int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
AS
/***********************************************************************
This procedure runs for the Facility Capacity details Report.

PB Object(s):	r_facility_capacity_details
				w_report_master_receiving

05/13/2010 KAM	Created sp to report tons of Non-Hazardous Solid Waste
				disposed of in each Michigan county, each state besides
				Michigan, and each country besides USA.
11/18/2010 SK	Added company_id as input argument, modified to run on Plt_AI
				Moved to Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name

sp_rpt_facility_capacity_details 21, '01/01/2010', '01/05/2010'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


--Get Michigan County data
 SELECT	
	'1 County' as type
,	company.company_id
,	company.company_name
,	Generator.generator_id
,	Generator.generator_county
,	Generator.generator_state
,	Generator.generator_country
,	county.county_name
,	receipt.bill_unit_code
,	receipt.quantity
,	billunit.pound_conv
,	pounds = (receipt.quantity * billunit.pound_conv)
,	receipt.receipt_id
,	receipt.line_id
,	generator.generator_name
INTO #fields
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
	AND Generator.generator_state = 'MI'
	AND Generator.generator_country = 'USA'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.haz_flag = 'F'
JOIN county
	ON county.county_code = Generator.generator_county
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
JOIN ProfileLab
	ON ProfileLab.free_liquid = 'F'
	AND ProfileLab.type = 'A'
	AND ProfileLab.profile_id = ProfileQuoteApproval.profile_id
WHERE Receipt.company_id = @company_id	
	AND Receipt.trans_type = 'D' 
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status = 'A'
    AND Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to

-- Get Other State data
UNION
SELECT
	'2 State' as type
,	company.company_id
,	company.company_name
,	Generator.generator_id
,	NULL
,	Generator.generator_state
,	Generator.generator_country
,	NULL
,	receipt.bill_unit_code
,	receipt.quantity
,	billunit.pound_conv
,	pounds = (receipt.quantity * billunit.pound_conv)
,	receipt.receipt_id
,	receipt.line_id
,	generator.generator_name	
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
	AND Generator.generator_state <> 'MI'
	AND Generator.generator_country = 'USA'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.haz_flag = 'F'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
JOIN ProfileLab
	ON ProfileLab.free_liquid = 'F'
	AND ProfileLab.type = 'A'
	AND ProfileLab.profile_id = ProfileQuoteApproval.profile_id
WHERE Receipt.company_id = @company_id	
	AND Receipt.trans_type = 'D' 
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status = 'A'
    AND Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
 
-- Calculate Other Country data
UNION
SELECT
	'3 Country' as type
,	company.company_id
,	company.company_name
,	Generator.generator_id
,	NULL
,	Generator.generator_state
,	Generator.generator_country
,	NULL
,	receipt.bill_unit_code
,	receipt.quantity
,	billunit.pound_conv
,	pounds = (receipt.quantity * billunit.pound_conv)
,	receipt.receipt_id
,	receipt.line_id
,	generator.generator_name		
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
	AND Generator.generator_country <> 'USA'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.haz_flag = 'F'
JOIN ProfileQuoteApproval
	ON ProfileQuoteApproval.profile_id = Receipt.profile_id
	AND ProfileQuoteApproval.company_id = Receipt.company_id
	AND ProfileQuoteApproval.profit_ctr_id = Receipt.profit_ctr_id
JOIN ProfileLab
	ON ProfileLab.free_liquid = 'F'
	AND ProfileLab.type = 'A'
	AND ProfileLab.profile_id = ProfileQuoteApproval.profile_id
WHERE Receipt.company_id = @company_id	
	AND Receipt.trans_type = 'D' 
	AND Receipt.trans_mode = 'I'
	AND Receipt.receipt_status = 'A'
    AND Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to

SELECT * FROM #fields 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_facility_capacity_details] TO [EQAI]
    AS [dbo];

