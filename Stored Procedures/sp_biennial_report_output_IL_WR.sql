﻿
CREATE PROCEDURE sp_biennial_report_output_IL_WR (
	@biennial_id	int
)
AS
/* **********************************************************************************

sp_biennial_report_output_IL_WR 1702

Step 2 - WR Files

WR Form
The Waste Received from Off-site (WR) Form (EPA 9026) identifies hazardous wastes tha
were received from other hazardous waste sites and the method(s) used to manage them.
The WR Form is divided into two parts, with the off-site generator’s identification 
information at the top and identical repeating sections below for reporting the quantities 
and characteristics of each hazardous waste received from that generator during the 
reporting year. 

The purpose of this script is to create the data for the WR1 and WR2 files

sp_biennial_report_output_IL_WR 162

SELECT * FROM EQ_Extract..BiennialReportWork_IL_WR1 where biennial_id = 162

*********************************************************************************** */


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
 
 2/17/2012 - Added new weight handling per Coletta, Lorraine.
	- In this handling, WEIGHT (est lbs) is ok to use, we don't have to use ONLY Gals or Yards)
	
 10/3/2012 - Per Hope Write @ IL EPA: No Decimals in numbers.
 
EQ_Extract..sp_help BiennialReportWork_IL_WR1
 
******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_IL_WR1 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_IL_WR1
SELECT DISTINCT

	@biennial_id,
		-- Track the run

	SD.approval_code,
		-- This field is NOT in the spec. 
		-- It is exported here to facilitate joins to this data in later SQL.
		
	1 as hz_pg_tmp,
		-- This is temporary, for numbering pages.

	1 as hz_ln_tmp,
		-- This is temporary, for numbering lines.

	'0311110001' as EQ_STATE_ID, -- for IL
	
	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID,
		-- EPA ID of handler (our site)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
	
	LEFT(ISNULL(SD.EPA_FORM_CODE,'') + space(4), 4) as FORM_CODE,
		-- Form Code 
		-- Starts at column: 19
		-- Field length: 4
		-- Data type: Alphanumeric
		/*
		if only actual yards is present and not actual gals use actual yards
		IF only actual gals is present  and not actual yards use actual gals
		If both are present - If consistency contains "Liquid' use gals else use yards
		
		Code    Unit of Measure 
		1 Gallons 
		2 Cubic yards 
		3  Pounds 
		
		*/
		-- NOTE: THIS MUST MATCH THE CASE USED IN THE CALC of QUANTITY BELOW
		/* 2018-02-27
			CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then 2 -- yards
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
					THEN 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
					THEN 2 -- yards
				ELSE 3 -- pounds
			END
		*/
		3 -- 2018-02-27
		as UNIT_OF_MEASURE,
	
-- 	LEFT(ISNULL(SD.waste_density,'') + space(6), 6) as WST_DENSITY,
	right('0000' + replace(CONVERT(VARCHAR(10), convert(numeric(10,2), ROUND ( isnull(SD.waste_density, '') , 2 , 1 ))), '.', ''), 4) as WST_DENSITY,
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
	
	'Y' AS INCLUDE_IN_NATIONAL_REPORT,
		-- Obsolete Field  - must leave blank (was RCRA-Radioactive Mix)
		-- Starts at column: 31
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! Ohio has a different spec that Federal for this field:
		-- "Include Information in the National Hazardous Waste Report"
		-- "Must be 'Y' for submissions to Ohio EPA"
		
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
		
	LEFT(SD.generator_state_id + space(10), 10) AS GEN_STATE_EPA_ID,
	
	--LEFT(SUBSTRING(REPLICATE(' ', 18 - DATALENGTH(CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_estimated))))))
	--+ CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_estimated)))), 1, 18),18) as IO_TDR_QTY,
	--RIGHT(space(18) + ISNULL(convert(varchar(18), CONVERT(DECIMAL(18,6), SUM(SD.lbs_haz_estimated))),''), 18) as IO_TDR_QTY,
	/*
	if only actual yards is present and not actual gals use actual yards
	IF only actual gals is present  and not actual yards use actual gals
	If both are present - If consistency contains "Liquid' use gals else use yards
	*/
	-- NOTE: THIS MUST MATCH THE CASE USED IN THE CALC of UNIT ABOVE
	RIGHT(space(10) + ISNULL(convert(varchar(10),  
--		(
--			SELECT 
				convert(numeric(10,1), 
				SUM(
					/* 2018-02-27
					CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then isnull(sd.yard_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
							THEN isnull(sd.gal_haz_actual, 0)
						when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
							THEN isnull(sd.yard_haz_actual, 0)
						ELSE isnull(lbs_haz_estimated, 0)
					END
					*/
					 isnull(lbs_haz_estimated, 0) -- 2018-02-27
				)
				)
/*				
			FROM EQ_Extract..BiennialReportSourceData tmp_sd
			WHERE tmp_sd.approval_code = SD.approval_code
			AND tmp_sd.management_code = SD.management_code
			AND tmp_sd.biennial_id = sd.biennial_id
			GROUP BY tmp_sd.biennial_id, tmp_sd.approval_code, tmp_sd.management_code,
			sd.biennial_id, sd.approval_code, sd.management_code
		)
*/		
	),''), 10) as IO_TDR_QTY,
		-- Quantity Received in Current Reporting Year 
		-- Must be > 0.
		-- Starts at column: 48
		-- Field length: 18
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal
		
	LEFT(IsNull(SD.waste_desc,' ') + SPACE(60), 60) as DESCRIPTION
		-- Waste Stream Description 
		-- Starts at column: 67
		-- Field length: 240
		-- Data type: Al4phanumeric

		-- NOTE!  OHIO has a different spec than Federal for this field:
		-- Starts at column: 66
		-- Field length: 60
			
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
AND SD.TRANS_MODE = 'I'
GROUP BY
	SD.approval_code,
	SD.EPA_FORM_CODE,
	/*
	CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then 2 -- yards
		when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then 1 -- gallons
		when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
			THEN 1 -- gallons
		when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
			THEN 2 -- yards
		ELSE 3 -- pounds
	END,
	*/
	SD.generator_state_id,
	SD.GENERATOR_STATE,
	SD.GENERATOR_EPA_ID,
	SD.waste_desc,
	SD.profit_ctr_epa_id,
	SD.waste_density,
	SD.management_code,
	SD.biennial_id,
	SD.waste_consistency
ORDER BY IO_TDR_ID, DESCRIPTION


/*
-- Number the rows like normal ------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_IL_WR1
set @intcounter = hz_pg_tmp = @intcounter + 1
WHERE biennial_id = @biennial_id

-- Now format the row numbers -------------------------------
update EQ_Extract..BiennialReportWork_IL_WR1
set hz_pg = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), hz_pg_tmp), 5 )
WHERE biennial_id = @biennial_id
*/

	create table #bar (hz_pg_tmp int identity(1,1), gen_epa_id varchar(12))
	
	insert #bar (gen_epa_id) 
	select distinct gen_epa_id 
	from EQ_Extract..BiennialReportWork_IL_WR1
	WHERE biennial_id = @biennial_id
	order by gen_epa_id
	 
 
	update EQ_Extract..BiennialReportWork_IL_WR1 
	set hz_pg_tmp = b.hz_pg_tmp 
	from EQ_Extract..BiennialReportWork_IL_WR1 f 
	inner join #bar b on f.gen_epa_id = b.gen_epa_id
	WHERE f.biennial_id = @biennial_id

	--select io_tdr_id, approval_code, hz_pg_tmp, hz_ln_tmp, * from EQ_Extract..BiennialReportWork_IL_WR1 

	declare @i int = 1
	update EQ_Extract..BiennialReportWork_IL_WR1 set @i = hz_ln_tmp = @i + 1 WHERE biennial_id = @biennial_id
	 
	update EQ_Extract..BiennialReportWork_IL_WR1 set 
		hz_ln_tmp = hz_ln_tmp - (
			select min(hz_ln_tmp) 
			from EQ_Extract..BiennialReportWork_IL_WR1 f2 
			where f2.hz_pg_tmp = EQ_Extract..BiennialReportWork_IL_WR1.hz_pg_tmp 
			and biennial_id = @biennial_id
			) +1
	WHERE biennial_id = @biennial_id
	 

	select hz_pg_tmp, max(hz_ln_tmp) as max_l, count(hz_ln_tmp) as count_l
	into #fix
	from EQ_Extract..BiennialReportWork_IL_WR1 f1
	where biennial_id = @biennial_id
	group by hz_pg_tmp 
	having max(hz_ln_tmp) > count(hz_ln_tmp)

	UPDATE EQ_Extract..BiennialReportWork_IL_WR1
	  SET hz_ln_tmp
	      = (SELECT COUNT(hz_ln_tmp)
	           FROM EQ_Extract..BiennialReportWork_IL_WR1 AS G1
	          WHERE G1.hz_ln_tmp < f.hz_ln_tmp
	          and G1.hz_pg_tmp = f.hz_pg_tmp
	          and G1.biennial_id = f.biennial_id) + 1
	from EQ_Extract..BiennialReportWork_IL_WR1 f inner join #fix x on f.hz_pg_tmp = x.hz_pg_tmp
	where biennial_id = @biennial_id
	 
	update EQ_Extract..BiennialReportWork_IL_WR1 set hz_pg_tmp = 1 WHERE biennial_id = @biennial_id

	set @i = 1
	WHILE EXISTS (select 1 from EQ_Extract..BiennialReportWork_IL_WR1 where hz_ln_tmp > 5) BEGIN
		update EQ_Extract..BiennialReportWork_IL_WR1 set 
			hz_pg_tmp = hz_pg_tmp +1, 
			hz_ln_tmp = hz_ln_tmp -5 
		where hz_pg_tmp = @i and hz_ln_tmp >5
		set @i = @i + 1
	END	 
	 
	--select io_tdr_id, approval_code, hz_pg_tmp, hz_ln_tmp, * from EQ_Extract..BiennialReportWork_IL_WR1 order by io_tdr_id, hz_pg_tmp, hz_ln_tmp



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

DELETE FROM EQ_Extract..BiennialReportWork_IL_WR2 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_IL_WR2
SELECT DISTINCT

	@biennial_id,
		-- Track the run
	WR1.gen_epa_id,
	WR1.approval_code,
		
	WR1.hz_pg_tmp,
	WR1.hz_ln_tmp,
	1 as sequence_id,
		
	WR1.EQ_EPA_ID,
		-- EPA ID Number (comes from WR1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(4), 4) AS EPA_WASTE_CODE
		-- EPA Hazardous Waste Code
		-- Starts at column: 19
		-- Field length: 4
		-- Data type: Alphanumeric

FROM EQ_Extract..BiennialReportWork_IL_WR1 WR1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( WR1.biennial_id = SD.biennial_id
		AND WR1.gen_epa_id = SD.generator_epa_id
		AND WR1.APPROVAL_CODE = SD.APPROVAL_CODE 
		AND WR1.DESCRIPTION = SD.WASTE_DESC 
		AND WR1.management_method = SD.management_code
		AND WR1.form_code = sd.epa_form_code
		AND SD.TRANS_MODE = 'I')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID 
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID 
		AND SD.TRANS_MODE = 'I' and isnull(SW.origin, 'F') = 'F')
WHERE wr1.biennial_id = @biennial_id


UNION

SELECT DISTINCT

	@biennial_id,
	WR1.gen_epa_id,
	WR1.approval_code,
	WR1.hz_pg_tmp,
	WR1.hz_ln_tmp,
	1 as sequence_id,
	WR1.EQ_EPA_ID,
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(4), 4) AS EPA_WASTE_CODE
FROM EQ_Extract..BiennialReportWork_IL_WR1 WR1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( WR1.biennial_id = SD.biennial_id
		AND WR1.gen_epa_id = SD.generator_epa_id
		AND WR1.APPROVAL_CODE = SD.APPROVAL_CODE 
		AND WR1.DESCRIPTION = SD.WASTE_DESC 
		AND WR1.management_method = SD.management_code
		AND WR1.form_code = sd.epa_form_code
		AND SD.TRANS_MODE = 'I')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.enviroware_manifest_document = SW.enviroware_manifest_document 
		AND SD.enviroware_manifest_document_line= SW.enviroware_manifest_document_line
		AND SD.TRANS_MODE = 'I' and isnull(sw.origin, 'F') = 'F')
WHERE wr1.biennial_id = @biennial_id


-- Number the rows like normal ------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_IL_WR2
set @intcounter = sequence_id = @intcounter + 1
WHERE biennial_id = @biennial_id

update EQ_Extract..BiennialReportWork_IL_WR2 set 
	sequence_id = sequence_id - (
		select min(sequence_id) 
		from EQ_Extract..BiennialReportWork_IL_WR2 f2 
		where f2.hz_pg_tmp = EQ_Extract..BiennialReportWork_IL_WR2.hz_pg_tmp 
		and f2.hz_ln_tmp = EQ_Extract..BiennialReportWork_IL_WR2.hz_ln_tmp
		and f2.biennial_id = @biennial_id
		) +1
WHERE biennial_id = @biennial_id

-- Fix Sequence Gaps
	select gen_epa_id, approval_code, hz_pg_tmp, hz_ln_tmp, 
		max(sequence_id) as max_l, count(sequence_id) as count_l
	into #fix2
	from EQ_Extract..BiennialReportWork_IL_WR2 f1
	where biennial_id = @biennial_id
	group by gen_epa_id, approval_code, hz_pg_tmp, hz_ln_tmp 
	having max(sequence_id) > count(sequence_id)

	UPDATE EQ_Extract..BiennialReportWork_IL_WR2
	  SET sequence_id
	      = (SELECT COUNT(sequence_id)
	           FROM EQ_Extract..BiennialReportWork_IL_WR2 AS G1
	          WHERE G1.sequence_id < f.sequence_id
	          and G1.gen_epa_id = f.gen_epa_id
	          and G1.approval_code = f.approval_code
	          and G1.hz_pg_tmp = f.hz_pg_tmp
	          and G1.hz_ln_tmp = f.hz_ln_tmp
	          and G1.biennial_id = f.biennial_id
	          ) + 1
	from EQ_Extract..BiennialReportWork_IL_WR2 f 
	inner join #fix2 x on 
	          x.gen_epa_id = f.gen_epa_id
	          and x.approval_code = f.approval_code
	          and x.hz_pg_tmp = f.hz_pg_tmp
	          and x.hz_ln_tmp = f.hz_ln_tmp
	where f.biennial_id = @biennial_id


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




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_WR] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_WR] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_WR] TO [EQAI]
    AS [dbo];

