
CREATE PROCEDURE sp_biennial_report_output_IL_GM (
	@biennial_id	int
)
AS
/* **********************************************************************************

sp_biennial_report_output_IL_GM  1704

GM Files

If the site was a "Large Quantity Generator," click on the "Generation and Management" button 
to open Form GM. The USEPA ID, Illinois EPA ID, and Site Name fields should be filled with the 
values entered on Form IC and a sequential page number will be assigned. Complete all sections 
of the form. Make sure to enter data in all of the required fields: Hazardous Waste Code 1, 
Source Code, Form Code, Unit of Measure, and Density. You must enter information in at least 
one of the following (1) Section 3 for on-site management or (2) at least one site shipped to 
in Section 4.

Form GM 
(Generated and/or Managed) LQGs (any one or more months) must complete a separate Form GM for 
each stream of regulated RCRA hazardous waste they generated or shipped during the calendar year;
OR each waste stream managed on-site in RCRA/UIC units whether generated during this year or in 
previous years.
A complete and separate Form GM must be submitted for each RCRA hazardous waste stream if:
- The hazardous waste stream was generated on site from a production process or service activity.
- The hazardous waste stream was the result of a spill cleanup, equipment decommissioning, or 
	other remedial cleanup activity.
- The hazardous waste stream was derived from the management of a non-hazardous waste stream.
- The hazardous waste stream was removed from on-site storage.
- The hazardous waste stream was received from off-site, was subsequently shipped off-site and was 
	not recycled or treated on-site.
- The hazardous waste stream was a residual from the on-site treatment, disposal, or recycling 
	of previously existing hazardous waste streams.
- You are the generator of record (US Importer) for waste imported from a foreign country 
	(use appropriate source codes G63-G75)

Form GM is divided into sections that together document: the source, characteristics, and 
quantity of hazardous waste generated on-site; the quantity of hazardous waste managed on-site 
and the management methods; the quantity of hazardous waste shipped off-site and the off-site 
management methods.

2012-10-03 - JPB - Formatted numbers to omit decimal characters. eg. 207.5 = 2075

sp_biennial_report_output_IL_GM 1702

select max(biennial_id) from EQ_Extract..BiennialReportSourceData
SELECT * FROM EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id = 1704

*********************************************************************************** */


/* ********************************
-- Create the GM1 file

******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_IL_GM1 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_IL_GM1
SELECT DISTINCT

	@biennial_id as biennial_id,
		-- Track the run

	SD.approval_code,
		-- This field is NOT in the spec. 
		-- It is exported here to facilitate joins to this data in later SQL.

	1 as hz_pg_tmp,
		-- This is temporary, for numbering lines.

	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID,
		-- EPA ID of handler (our site)
		-- The first two characters of the Off-Site Handler EPA ID Number must be a state postal code or ‘FC’ (foreign country) 
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric

	'00001' as HZ_PG,
		-- Field for line numbers '00001', etc.
		--   Initially left with filler, numbered correctly via update below.
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer
		
-- FILLER
		-- Starts at column: 18
		-- field length: 5
		-- Blank spaces	

	'0311110001' as EQ_STATE_ID, -- for IL
		-- Starts at column: 21
		-- Field length: 10

-- WASTE_CODE_1
		-- Starts at Column: 31
		-- Field length: 4

-- WASTE_CODE_2
		-- Starts at Column: 35
		-- Field length: 4

-- WASTE_CODE_3
		-- Starts at Column: 39
		-- Field length: 4

-- WASTE_CODE_4
		-- Starts at Column: 43
		-- Field length: 4

-- WASTE_CODE_5
		-- Starts at Column: 47
		-- Field length: 4

	SD.EPA_source_code as SOURCE_CODE,
		-- EPA Source Code
		-- Starts at column: 51
		-- Field length: 3
		-- Data type: Alphanumeric

	REPLICATE(' ', 4) AS ORIGIN_MANAGEMENT_METHOD,
		-- Origin Management Method - ONLY required for source code G25.
		-- Starts at column: 54
		-- Field length: 4
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.EPA_FORM_CODE,' ') + SPACE(4), 4) as FORM_CODE,
		-- Waste Form Code
		-- Starts at column: 58
		-- Field length: 4
		-- Data type: Alphanumeric

	'X' AS WASTE_MINIMIZATION_CODE,
		-- Starts at Column: 62
		-- Field length: 1
		-- Values:	X: No waste minimization effors were implemented for this waste
		--			N: Waste Minimization efforts were unsuccessful in reducing quantity and/or toxicity
		--			S: Began to ship waste off-site for recycling
		--			R: Recycling on-site was implemented and was successful
		--			Y: Waste minimization was implemented and was successful in reducing quantity and/or toxicity.
	
		/*
		if only actual yards is present and not actual gals use actual yards
		IF only actual gals is present  and not actual yards use actual gals
		If both are present - If consistency contains "Liquid' use gals else use yards
		
		Code    Unit of Measure 
		1 Gallons 
		2 Cubic yards 
		3  Pounds 
		
		*/
		
		/* 2018-02-27
		-- NOTE: THIS MUST MATCH THE CASE USED IN THE CALC of QUANTITY BELOW
			CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then 2 -- yards
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
					THEN 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
					THEN 2 -- yards
				ELSE 3 -- pounds
			END
		*/
		3 as UNIT_OF_MEASURE, -- Change to always report pounds, 2018-02-27
		-- Unit of Measure:
		--   Gallons = '1'
		--   Cubic Yards = '2'
		--   Pounds = '3'
		-- Starts at column: 63
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "Unit of Measure must equal an Ohio EPA-defined unit of measure (P, T, G, Y, L, or K)
		-- "If Unit of Measure equals G, L, or Y, then Density must be > 0"
		-- "If Unit of Measure equals G, L, or Y, then Density Unit Of Measure 
		--    must equal 1 for lbs/gal or 2 for specific gravity"

	right('0000' + replace(CONVERT(VARCHAR(10), convert(numeric(10,2), ROUND ( isnull(SD.waste_density, '') , 2 , 1 ))), '.', ''), 4) as WST_DENSITY,
		-- The density of water in pounds per gallon
		-- Starts at column: 64
		-- Field length: 4
		-- Data type: Decimal, max of 3 characters before the decimal, max of 2 characters after the decimal 
		--    but in the case of 8.3453, those 6 characters seem to be ok.

	/*
	if only actual yards is present and not actual gals use actual yards
	IF only actual gals is present  and not actual yards use actual gals
	If both are present - If consistency contains "Liquid' use gals else use yards
	*/
	-- NOTE: THIS MUST MATCH THE CASE USED IN THE CALC of UNIT ABOVE
	RIGHT(space(10) + ISNULL(convert(varchar(10),  
--		(
--			SELECT 
			replace(
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
			, '.', '')
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
		-- Quantity Generated in Reporting Year
		-- Must be > 0.
		-- Starts at column: 68
		-- Field length: 10
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal

	'N' as ON_SITE_MANAGEMENT,
		-- Was this waste stream managed on-site? (Y/N)
		-- Starts at column: 78
		-- Field length: 1

-- ON_SITE_MANAGEMENT_METHOD_SITE_1
		-- Starts at Column: 79
		-- Field length: 4

-- QTY_MANAGED_ON_SITE_1
		-- Starts at Column: 83
		-- Field length: 10

-- ON_SITE_MANAGEMENT_METHOD_SITE_2
		-- Starts at Column: 93
		-- Field length: 4

-- QTY_MANAGED_ON_SITE_2
		-- Starts at Column: 97
		-- Field length: 10

	'Y' as OFF_SITE_SHIPMENT,
		-- Was this Waste Stream managed off-site? (Y/N)
		-- Starts at column: 107
		-- Field length: 1
		-- Data type: Alphanumeric

	LEFT(SD.TSDF_EPA_ID + space(12), 12) AS SITE_1_US_EPAID_NUMBER,
		-- Starts at Column: 108
		-- Field length: 12

	LEFT(COALESCE(ta.management_code, trmt.management_code, '') + SPACE(4), 4) as SITE_1_MANAGEMENT_METHOD,
		-- Starts at Column: 120
		-- Field length: 4

	/*
	if only actual yards is present and not actual gals use actual yards
	IF only actual gals is present  and not actual yards use actual gals
	If both are present - If consistency contains "Liquid' use gals else use yards
	*/
	-- NOTE: THIS MUST MATCH THE CASE USED IN THE CALC of UNIT ABOVE
	RIGHT(space(10) + ISNULL(convert(varchar(10),  
--		(
--			SELECT 
			Replace(
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
			, '.', '')
/*				
			FROM EQ_Extract..BiennialReportSourceData tmp_sd
			WHERE tmp_sd.approval_code = SD.approval_code
			AND tmp_sd.management_code = SD.management_code
			AND tmp_sd.biennial_id = sd.biennial_id
			GROUP BY tmp_sd.biennial_id, tmp_sd.approval_code, tmp_sd.management_code,
			sd.biennial_id, sd.approval_code, sd.management_code
		)
*/		
	),''), 10) as SITE_1_TOTAL_QUANTITY_SHIPPED,
		-- Starts at Column: 124
		-- Field length: 10

-- SITE_2_US_EPAID_NUMBER
		-- Starts at Column: 134
		-- Field length: 12

-- SITE_2_MANAGEMENT_METHOD
		-- Starts at Column: 146
		-- Field length: 4

-- SITE_2_TOTAL_QUANTITY_SHIPPED
		-- Starts at Column: 150
		-- Field length: 10
		
-- SITE_3_US_EPAID_NUMBER
		-- Starts at Column: 160
		-- Field length: 12

-- SITE_3_MANAGEMENT_METHOD
		-- Starts at Column: 172
		-- Field length: 4

-- SITE_3_TOTAL_QUANTITY_SHIPPED
		-- Starts at Column: 176
		-- Field length: 10

-- SITE_4_US_EPAID_NUMBER
		-- Starts at Column: 186
		-- Field length: 12

-- SITE_4_MANAGEMENT_METHOD
		-- Starts at Column: 198
		-- Field length: 4

-- SITE_4_TOTAL_QUANTITY_SHIPPED
		-- Starts at Column: 202
		-- Field length: 10
			
-- SITE_5_US_EPAID_NUMBER
		-- Starts at Column: 212
		-- Field length: 12

-- SITE_5_MANAGEMENT_METHOD
		-- Starts at Column: 224
		-- Field length: 4

-- SITE_5_TOTAL_QUANTITY_SHIPPED
		-- Starts at Column: 228
		-- Field length: 10

-- COMMENTS_INDICATOR			
		-- Starts at Column: 238
		-- Field length: 1
						
-- FILLER
		-- Starts at Column: 239
		-- Field length: 1

	LEFT(IsNull(SD.waste_desc,' ') + SPACE(50), 50) as DESCRIPTION
		-- Waste Stream Description
		-- Starts at Column: 240
		-- Field length: 50
		-- Data type: Alphanumeric

FROM EQ_Extract..BiennialReportSourceData SD
INNER JOIN Receipt r
	on r.receipt_id = SD.receipt_id
	and r.line_id = SD.line_id
	and r.company_id = SD.company_id
	and r.profit_ctr_id = SD.profit_ctr_id
	and r.trans_mode = SD.trans_mode
LEFT OUTER JOIN TSDFApproval ta
	on r.tsdf_approval_id = ta.tsdf_approval_id
	and r.company_id = ta.company_id
	and r.profit_ctr_id = ta.profit_ctr_id
LEFT OUTER JOIN ProfileQuoteApproval pqa
	on r.ob_profile_id = pqa.profile_id
	and r.ob_profile_company_id = pqa.company_id
	and r.ob_profile_profit_ctr_id = pqa.profit_ctr_id
LEFT OUTER JOIN Treatment trmt
	on pqa.treatment_id = trmt.treatment_id
	AND pqa.company_id = trmt.company_id
	AND pqa.profit_ctr_id = trmt.profit_ctr_id
WHERE biennial_id = @biennial_id
AND SD.TRANS_MODE = 'O'
GROUP BY
	SD.approval_code,
	LEFT(SD.profit_ctr_epa_id + space(12), 12),
	SD.EPA_source_code,
	LEFT(IsNull(SD.EPA_FORM_CODE,' ') + SPACE(4), 4),
	/* 2018-02-27
			CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then 2 -- yards
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency LIKE '%LIQUID%' 
					THEN 1 -- gallons
				when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.waste_consistency NOT LIKE '%LIQUID%' 
					THEN 2 -- yards
				ELSE 3 -- pounds
			END,
	*/
	right('0000' + replace(CONVERT(VARCHAR(10), convert(numeric(10,2), ROUND ( isnull(SD.waste_density, '') , 2 , 1 ))), '.', ''), 4),
	LEFT(SD.TSDF_EPA_ID + space(12), 12),
	LEFT(COALESCE(ta.management_code, trmt.management_code, '') + SPACE(4), 4),
	LEFT(IsNull(SD.waste_desc,' ') + SPACE(50), 50)


-- Now number the rows --------------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_IL_GM1
set @intcounter = hz_pg_tmp = @intcounter + 1
where biennial_id = @biennial_id

-- Now format the row numbers -------------------------------
update EQ_Extract..BiennialReportWork_IL_GM1
set hz_pg = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), hz_pg_tmp), 5 )
where biennial_id = @biennial_id


/* ********************************
-- Create the GM2 file

Not actually used in IL GM output, except for the waste codes.

******************************** */


DELETE FROM EQ_Extract..BiennialReportWork_IL_GM2 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_IL_GM2
SELECT DISTINCT

	@biennial_id,
		-- Track the run

	GM1.HZ_PG,
		-- Page Number (comes from GM1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer
		
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(4), 4) AS EPA_WASTE_CODE
		-- EPA Hazardous Waste Code
		-- Starts at column: 18
		-- Field length: 4
		-- Data type: Alphanumeric
		
FROM EQ_Extract..BiennialReportWork_IL_GM1 GM1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( GM1.biennial_id = SD.biennial_id
		AND GM1.APPROVAL_CODE = SD.APPROVAL_CODE
		AND GM1.DESCRIPTION = LEFT(IsNull(SD.waste_desc,' ') + SPACE(50), 50) AND SD.TRANS_MODE = 'O')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.TRANS_MODE = 'O'
		AND SW.origin = 'F')
WHERE GM1.biennial_id = @biennial_id


	--select io_tdr_id, approval_code, hz_pg_tmp, hz_ln_tmp, * from EQ_Extract..BiennialReportWork_IL_GM1 order by io_tdr_id, hz_pg_tmp, hz_ln_tmp


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_GM] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_GM] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_IL_GM] TO [EQAI]
    AS [dbo];

