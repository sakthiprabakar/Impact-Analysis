﻿-- drop proc sp_biennial_report_output_WR
go
CREATE PROCEDURE sp_biennial_report_output_WR (
	@biennial_id	int,
	@state			varchar(2),
	@debug			int = 0
)
AS
/* **********************************************************************************
sp_biennial_report_output_WR 194
Step 2 - WR Files

WR Form
The Waste Received from Off-site (WR) Form (EPA 9026) identifies hazardous wastes tha
were received from other hazardous waste sites and the method(s) used to manage them.
The WR Form is divided into two parts, with the off-site generator’s identification 
information at the top and identical repeating sections below for reporting the quantities 
and characteristics of each hazardous waste received from that generator during the 
reporting year. 

The purpose of this script is to create the data for the WR1 and WR2 files

01/21/2015 - Added internal variables to avoid parameter sniffing that was making this REALLY SLOW.

sp_biennial_report_output_WR 2025, 'MI', 0

*********************************************************************************** */

declare @int_biennial_id int, @int_state varchar(2), @int_debug int

select @int_biennial_id = @biennial_id, @int_state = @state, @int_debug = @debug

declare @starttime datetime = getdate()

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR Started' as description


/* ********************************
-- Create the WR1 file

Source Form: WR
Description: Waste Received From Off-Site 

This file captures the information contained in Item A and Items D through H of 
the WR form.  The relationship of these data records to the reported site is n:1, 
that is, there can be multiple received waste for each site. 
 
Key Fields:  Handler ID; Page Number; Waste Number.  Each record in the WR1 file 
must contain a unique combination of the Handler ID, Page Number and Waste Number. 
 
Note:  The WR1 file is REQUIRED for handlers who received RCRA hazardous waste 
from off-site. 

Total Record Length = FEDERAL: 546 characters (1 record per line)
					  OHIO: 125 characters (1 record per line)

-- IMPORTANT NOTES:
 1. OHIO Version is significantly different in order, length and inclusion of fields.
 
******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_WR1 where biennial_id = @int_biennial_id

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR1 Delete Complete' as description

INSERT EQ_Extract..BiennialReportWork_WR1
SELECT DISTINCT

	@int_biennial_id,
		-- Track the run

	SD.approval_code,
		-- This field is NOT in the spec. 
		-- It is exported here to facilitate joins to this data in later SQL.

	SD.eq_generator_id,
		-- This field is NOT in the spec. 
		-- It is exported here to facilitate joins to this data in later SQL.
			
	1 as hz_pg_tmp,
		-- This is temporary, for numbering lines.

	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID,
		-- EPA ID of handler (our site)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
	
	'00001' as HZ_PG,
		-- Field for line numbers '00001', etc.
		--   Initially left with filler, numbered correctly via update below.
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer
	
	'1' as SUB_PG_NUM,
		-- Waste Number - Printed on the Form (1,2,3) 
		--   NOTE!  OHIO: Waste Number (sub-page) must equal ‘1’. 
		-- Starts at column: 18
		-- Field length: 1
		-- Data type: Integer
	
	LEFT(ISNULL(SD.EPA_FORM_CODE,'') + space(4), 4) as FORM_CODE,
		-- Form Code 
		-- Starts at column: 19
		-- Field length: 4
		-- Data type: Alphanumeric

	CASE @int_state
		WHEN 'OH' THEN 'P'
		ELSE '1'
	END AS UNIT_OF_MEASURE,
		-- Unit of Measure:
		--   Pounds = '1'
		--   Short Tons = '2'
		--   Kilograms = '3'
		--   Metric Tonnes = '4'
		--   Gallons = '5'
		--   Liters = '6'
		--   Cubic Yards = '7'
		-- Starts at column: 23
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "Unit of Measure must equal an Ohio EPA-defined unit of measure (P, T, G, Y, L, or K)
		-- "If Unit of Measure equals G, L, or Y, then Density must be > 0"
		-- "If Unit of Measure equals G, L, or Y, then Density Unit Of Measure 
		--    must equal 1 for lbs/gal or 2 for specific gravity"
	
	-- LEFT(ISNULL(SD.waste_density,'') + space(6), 6) as WST_DENSITY,
	SUBSTRING(REPLICATE(' ', 6 - DATALENGTH(CONVERT(VARCHAR(6),(CONVERT(DECIMAL(6,2), SD.waste_density)))))
	+ CONVERT(VARCHAR(6),(CONVERT(DECIMAL(6,2), SD.waste_density))), 1, 6) as WST_DENSITY,
		-- The density of water in pounds per gallon
		-- Starts at column: 24
		-- Field length: 6
		-- Data type: Decimal, max of 3 characters before the decimal, max of 2 characters after the decimal 
		--    but in the case of 8.3453, those 6 characters seem to be ok.

		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "If Unit of Measure equals G, L, or Y, then Density must be > 0"

	'1' AS DENSITY_UNIT_OF_MEASURE,
		-- Density unit of measure... pounds, per above.
		-- Starts at column: 30
		-- Field length: 1
		-- Data type: Alphanumeric

		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "If Unit of Measure equals G, L, or Y, then Density Unit Of Measure 
		--    must equal 1 for lbs/gal or 2 for specific gravity"
	CASE @int_state
		WHEN 'OH' THEN 'Y'
		ELSE ' '
	END AS OBSOLETE_FIELD,
		-- Obsolete Field  - must leave blank (was RCRA-Radioactive Mix)
		-- Starts at column: 31
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! Ohio has a different spec that Federal for this field:
		-- "Include Information in the National Hazardous Waste Report"
		-- "Must be 'Y' for submissions to Ohio EPA" -- INCLUDE_IN_NATIONAL_REPORT
		
	LEFT(ISNULL(SD.management_code,'') + space(4), 4) as MANAGEMENT_METHOD,
		-- Management Method 
		-- Starts at column: 32
		-- Field length: 4
		-- Data type: Alphanumeric

		-- 2/15/2011 - JPB: DOn't hard code this, validate for it instead.
		-- was: 'H141' as MANAGEMENT_METHOD,
	
	LEFT(SD.GENERATOR_EPA_ID + space(12), 12) as IO_TDR_ID,
		-- Off-site Source EPA ID Number
		-- The first two characters of the Off-Site Handler EPA ID Number must be a state postal code or ‘FC’ (foreign country) 
		-- Starts at column: 36
		-- Field length: 12
		-- Data type: Alphanumeric
	
	--LEFT(SUBSTRING(REPLICATE(' ', 18 - DATALENGTH(CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_estimated))))))
	--+ CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_estimated)))), 1, 18),18) as IO_TDR_QTY,
	RIGHT(space(18) + ISNULL(convert(varchar(18), CONVERT(DECIMAL(18,6), SUM(SD.lbs_haz_estimated))),''), 18) as IO_TDR_QTY,
		-- Quantity Received in Current Reporting Year 
		-- Must be > 0.
		-- Starts at column: 48
		-- Field length: 18
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal

	'Y' AS INCLUDE_IN_NATIONAL_REPORT,
		-- Include n the National Report (Yes = 'Y', No = 'N') 
		-- Starts at column: 66
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE!  OHIO Does not specify this field, it should not be included here in the OHIO versions!
	
	CASE @int_state
		WHEN 'OH' THEN LEFT(IsNull(SD.waste_desc,' ') + SPACE(60), 60) 
		ELSE LEFT(IsNull(SD.waste_desc,' ') + SPACE(240), 240) 
	END as DESCRIPTION,
		-- Waste Stream Description 
		-- Starts at column: 67
		-- Field length: 240
		-- Data type: Alphanumeric

		-- NOTE!  OHIO has a different spec than Federal for this field:
		-- Starts at column: 66
		-- Field length: 60
			
	CASE SD.EPA_FORM_CODE WHEN 'W219' THEN 'TOXIC WASTE' + SPACE(229)
	WHEN 'W319' THEN 'MISCELLANEOUS WASTE' + SPACE(221)
	ELSE SPACE(240) END as NOTES
		-- Comments/Notes
		-- Starts at column: 307
		-- Field length: 240
		-- Data type: Alphanumeric

		-- NOTE!  OHIO has a different spec than Federal for this field:
		-- No such field, do not include it on OHIO versions!

FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @int_biennial_id
AND SD.TRANS_MODE = 'I'
AND NOT (
	SD.profit_ctr_epa_id = SD.generator_epa_id
	AND SD.generator_country = 'US'
	)
GROUP BY
	SD.approval_code,
	SD.eq_generator_id,
	SD.EPA_FORM_CODE,
	SD.GENERATOR_STATE,
	SD.GENERATOR_EPA_ID,
	SD.waste_desc,
	SD.profit_ctr_epa_id,
	SD.waste_density,
	SD.management_code
ORDER BY IO_TDR_ID, DESCRIPTION

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR1 Insert Complete' as description

-- Number the rows like normal ------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_WR1
set @intcounter = hz_pg_tmp = @intcounter + 1
WHERE biennial_id = @int_biennial_id

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR1 Row Number Complete' as description

/*
-- 1/30/2020 - No longer in use? FL supposedly using EPA system now
IF @int_state = 'FL' BEGIN
	-- Number the pages (2 passes) ------------------------------
	update EQ_Extract..BiennialReportWork_WR1
	set SUB_PG_NUM = hz_pg_tmp % 3
	WHERE biennial_id = @int_biennial_id

	update EQ_Extract..BiennialReportWork_WR1
	set SUB_PG_NUM = 3
	WHERE biennial_id = @int_biennial_id
	AND SUB_PG_NUM = 0

	-- Now revise the row numbers to match the pages ------------
	update EQ_Extract..BiennialReportWork_WR1
	set hz_pg_tmp = floor(hz_pg_tmp / 3)+1
	WHERE biennial_id = @int_biennial_id
	AND sub_pg_num <> 3

	update EQ_Extract..BiennialReportWork_WR1
	set hz_pg_tmp = hz_pg_tmp / 3
	WHERE biennial_id = @int_biennial_id
	AND sub_pg_num = 3
	
if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR1 FL Row Handling Complete' as description
	
END
*/

-- Now format the row numbers -------------------------------
update EQ_Extract..BiennialReportWork_WR1
set hz_pg = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), hz_pg_tmp), 5 )
WHERE biennial_id = @int_biennial_id

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR1 Row Number Format Complete' as description



/* ********************************
-- Create the WR2 file

Source Form: WR
Description: EPA Hazardous Waste Codes

This file captures the information contained in Item B of the WR form.  The 
relationship of these data records to the reported waste is n:1, that is, there 
can be multiple waste codes for each reported waste. 
 
Key Fields: Handler ID; Page Number; Waste Number; EPA Waste Code.  Each record 
in the WR2 file must contain a unique combination of the Handler ID, Page Number, 
Waste Number, and EPA Waste Code. 
 
Note: For each waste stream, EPA Hazardous Waste Code information (WR2) is REQUIRED. 

Total Record Length = 22 characters (1 record per line)

******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_WR2 where biennial_id = @int_biennial_id

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR2 Delete Complete' as description

INSERT EQ_Extract..BiennialReportWork_WR2
SELECT DISTINCT

	@int_biennial_id,
		-- Track the run
		
	WR1.HANDLER_ID,
		-- EPA ID Number (comes from WR1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	WR1.HZ_PG,
		-- Page Number (comes from WR1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer

	WR1.SUB_PG_NUM,
		-- Waste Number  (comes from WR1 table, so they match)
		-- Starts at column: 18
		-- Field length: 1
		-- Data type: Integer
		
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(4), 4) AS EPA_WASTE_CODE
		-- EPA Hazardous Waste Code
		-- Starts at column: 19
		-- Field length: 4
		-- Data type: Alphanumeric

FROM EQ_Extract..BiennialReportWork_WR1 WR1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( WR1.biennial_id = SD.biennial_id
		AND WR1.APPROVAL_CODE = SD.APPROVAL_CODE 
		AND WR1.DESCRIPTION = SD.WASTE_DESC AND SD.TRANS_MODE = 'I')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID 
		AND SD.COMPANY_ID = SW.COMPANY_ID AND SD.PROFIT_CTR_ID = SW.PROFIT_CTR_ID
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID 
		AND SD.TRANS_MODE = 'I'
		AND SW.origin = 'F'
		)
WHERE wr1.biennial_id = @int_biennial_id
AND NOT (
	SD.profit_ctr_epa_id = SD.generator_epa_id
	AND SD.generator_country = 'US'
	)

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR2 Insert Complete' as description

/*
-- Removed this Enviroware specific update 2/10/2012 - JPB

UNION

SELECT DISTINCT

	@int_biennial_id,		
	WR1.HANDLER_ID,
	WR1.HZ_PG,
	WR1.SUB_PG_NUM,
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(4), 4) AS EPA_WASTE_CODE

FROM EQ_Extract..BiennialReportWork_WR1 WR1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( WR1.biennial_id = SD.biennial_id
		AND WR1.APPROVAL_CODE = SD.APPROVAL_CODE 
		AND WR1.DESCRIPTION = SD.WASTE_DESC AND SD.TRANS_MODE = 'I')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.enviroware_manifest_document = SW.enviroware_manifest_document 
		AND SD.enviroware_manifest_document_line = SW.enviroware_manifest_document_line 
		AND SD.TRANS_MODE = 'I')
WHERE wr1.biennial_id = @int_biennial_id
AND NOT (
	SD.profit_ctr_epa_id = SD.generator_epa_id
	AND SD.generator_country = 'US'
	)

*/


/* ********************************
-- Create the WR3 file
-- OHIO does not have state-specific waste codes and therefore file GM3 should not be submitted

Source Form: WR
Description: State Hazardous Waste Codes for Each Reported Waste Received

This file contains the State hazardous waste codes for each WR form page as 
described in Form WR, Block C.  The relationship of these data records to the 
reported waste is n:1, that is, there can be multiple State waste codes for each 
unique reported waste.

Key Fields:  Handler ID Number (HANDLER_ID); Page Number (HZ_PG); 
Waste Number (SUB_PG_NUM); State Hazardous Waste Code (WASTE_CODE).  Each record 
in the WR3 file must contain a unique combination of the Handler ID Number, 
Page Number, Waste Number, and State Hazardous Waste Code.

Note: For each waste stream, either EPA Hazardous Waste Code information (GM2) is 
REQUIRED or State Hazardous Waste Code information (GM3) is REQUIRED.    

Total Record Length = 22 characters (1 record per line)

******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_WR3 where biennial_id = @int_biennial_id

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR3 Delete Complete' as description

INSERT EQ_Extract..BiennialReportWork_WR3
SELECT DISTINCT

	@int_biennial_id,
		-- Track the run

	WR1.HANDLER_ID,
		-- EPA ID Number (comes from WR1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	WR1.HZ_PG,
		-- Page Number (comes from WR1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Alphanumeric

	WR1.SUB_PG_NUM,
		-- Waste Number  (comes from WR1 table, so they match)
		-- Starts at column: 18
		-- Field length: 1
		-- Data type: Integer
				
	LEFT(IsNull(wc.Display_Name,' ') + SPACE(6), 6) AS STATE_WASTE_CODE
		-- State Hazardous Waste Code
		-- Starts at column: 18
		-- Field length: 6
		-- Data type: Alphanumeric
	
FROM EQ_Extract..BiennialReportWork_WR1 WR1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( WR1.biennial_id = SD.biennial_id
		AND WR1.APPROVAL_CODE = SD.APPROVAL_CODE
		AND WR1.DESCRIPTION = SD.WASTE_DESC AND SD.TRANS_MODE = 'I')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
		AND SD.COMPANY_ID = SW.COMPANY_ID AND SD.PROFIT_CTR_ID = SW.PROFIT_CTR_ID
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.TRANS_MODE = 'I'
		AND SW.origin = 'S')
	JOIN WasteCode wc ON SW.waste_code_uid = wc.waste_code_uid
		AND wc.waste_code_origin = 'S'
		-- AND wc.state = @int_state
		AND IsNull(wc.haz_flag,'F') = 'T'
		and len(ltrim(rtrim(wc.display_name))) <= 6
WHERE WR1.biennial_id = @int_biennial_id
AND NOT (
	SD.profit_ctr_epa_id = SD.generator_epa_id
	AND SD.generator_country = 'US'
	)

if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'sp_biennial_report_output_WR WR3 Insert Complete' as description



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_WR] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_WR] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_WR] TO [EQAI]
    AS [dbo];

