
CREATE PROCEDURE sp_biennial_report_output_FL_GM (
	@biennial_id	int
)
AS
/* **********************************************************************************

Step 3 - GM Files

GM Form
The Generation and Management (GM) Form (EPA 9028) is used for reporting on-site
hazardous waste generation, management, and off-site shipment.  The GM Form is
divided into four sections that document 1) the source, characteristics, and quantity of
hazardous waste generated; 2) the quantity of hazardous waste managed on-site along
with the management method used; 3) the quantity of hazardous waste shipped off-site for
treatment, disposal, or recycling along with the off-site management method; and 4) the
quantity of hazardous waste remaining on-site in permitted storage units or inactive
disposal units.

The purpose of this script is to create the data for the GM1, GM2, and GM4 files
*********************************************************************************** */


/* ********************************
-- Create the GM1 file

Source Form: GM
Description: Waste measurement Information

This file captures data elements that have 1:1 relationship to the reported waste.  
These data elements are as follows:  GM Sections 1.A and 1.D through 1.G.

Key Fields:  Handler ID; Page Number.  Each record in the GM1 file must contain a 
unique combination of the Handler ID and Page Number.

Note:  The GM1 file is REQUIRED for handlers that generated RCRA hazardous waste 
that was accumulated on-site; managed on-site in a treatment, storage, or disposal 
unit; shipped off-site for management; and/or remained on-site at the end of the 
year in a permitted storage area or inactive disposal unit.

Total Record Length = 538 characters (1 record per line)

-- IMPORTANT NOTES:
 1. The Federal spec includes an Obsolete Field - but OHIO replaces it with another value.
 2. Ohio takes 240 characters in description, but only reads the first 60.
 
******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_FL_GM1 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_FL_GM1
SELECT DISTINCT

	@biennial_id,
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

	LEFT(IsNull(SD.EPA_FORM_CODE,' ') + SPACE(4), 4) as FORM_CODE,
		-- Waste Form Code
		-- Starts at column: 18
		-- Field length: 4
		-- Data type: Alphanumeric

	'1' AS UNIT_OF_MEASURE,
		-- Unit of Measure:
		--   Pounds = '1'
		--   Short Tons = '2'
		--   Kilograms = '3'
		--   Metric Tonnes = '4'
		--   Gallons = '5'
		--   Liters = '6'
		--   Cubic Yards = '7'
		-- Starts at column: 22
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "Unit of Measure must equal an Ohio EPA-defined unit of measure (P, T, G, Y, L, or K)
		-- "If Unit of Measure equals G, L, or Y, then Density must be > 0"
		-- "If Unit of Measure equals G, L, or Y, then Density Unit Of Measure 
		--    must equal 1 for lbs/gal or 2 for specific gravity"
		
	SD.waste_density as WST_DENSITY,
		-- The density of water in pounds per gallon
		-- Starts at column: 23
		-- Field length: 6
		-- Data type: Decimal, max of 3 characters before the decimal, max of 2 characters after the decimal 
		--    but in the case of 8.3453, those 6 characters seem to be ok.

		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "If Unit of Measure equals G, L, or Y, then Density must be > 0"

	'1' AS DENSITY_UNIT_OF_MEASURE,
		-- Density unit of measure... pounds, per above.
		-- Starts at column: 29
		-- Field length: 1
		-- Data type: Alphanumeric

		-- NOTE! Ohio has a different spec than Federal for this field:
		-- "If Unit of Measure equals G, L, or Y, then Density Unit Of Measure 
		--    must equal 1 for lbs/gal or 2 for specific gravity"

	REPLICATE(' ', 4) AS ORIGIN_MANAGEMENT_METHOD,
		-- Origin Management Method - ONLY required for source code G25.
		-- Starts at column: 30
		-- Field length: 4
		-- Data type: Alphanumeric

	' ' AS OBSOLETE_FIELD,
		-- Obsolete field - was RCRA-Radioactive Mix
		-- Starts at column: 34
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO re-uses this obsolete field space for "Waste Minimization Code"
		--	"Waste Minimization Code must equal an US EPA defined waste minimization code".
		-- 
		--  That may not just be an Ohio thing. Found at US EPA Web Site:
		--  
		--  N = Waste minimization efforts were unsuccessful in reducing quantity and/or toxicity
		--  R = Recycling on-site was implemented and was successful
		--  S = Began to ship waste off-site for recycling
		--  X = No waste minimization efforts were implemented for this waste
		--  Y = Waste minimization was implemented and was successful in reducing quantity and/or toxicity
		--  (blank) = Not provided
		--  
		--  Notes: 	This data element was collected beginning with the 2009 BR Cycle.
		--  	If the BR Report Cycle >= 2009 then the Waste Minimization Code Owner must be provided.
		--  	If the BR Report Cycle < 2009 then the Waste Minimization Code Owner must not be provided.
		--  	If the BR Report Cycle >= 2009 then the Waste Minimization Code must be provided.
		--  	If the BR Report Cycle < 2009 then the Waste Minimization Code must not be provided

	EPA_source_code as SOURCE_CODE,
		-- EPA Source Code
		-- Starts at column: 35
		-- Field length: 3
		-- Data type: Alphanumeric

	SUBSTRING(REPLICATE(' ', 18 - DATALENGTH(CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6), SUM(SD.lbs_haz_actual))))))
		+ CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6), SUM(SD.lbs_haz_actual)))), 1, 18) as GEN_QTY,
		-- Quantity Generated in Reporting Year
		-- Must be > 0.
		-- Starts at column: 38
		-- Field length: 18
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal

	'Y' AS INCLUDE_IN_NATIONAL_REPORT,
		-- Include in the National Waste Report (Y/N)
		-- Starts at column: 56
		-- Field length: 1
		-- Data type: Alphanumeric

		-- NOTE! Must be 'Y' for Ohio

	LEFT(IsNull(SD.waste_desc,' ') + SPACE(240), 240) as DESCRIPTION,
		-- Waste Stream Description
		-- Starts at column: 57
		-- Field length: 240
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO says: "The length of Waste Stream Description is only 60 characters
		--   in Ohio EPA's database but 240 in US EPA's spec.  Only the first 60 characters
		--   will be saved during the import.  Be sure to allow a column width of 240 and
		--   not 60 or the remaining fields won't be imported properly.

	SPACE(240) as NOTES,
		-- Comments/Notes
		--   Not a required field data-wise, but space for it must still be allocated.
		-- Starts at column: 297
		-- Field length: 240
		-- Data type: Alphanumeric

	'N' as ON_SITE_MANAGEMENT,
		-- Was this waste stream managed on-site? (Y/N)
		-- Starts at column: 537
		-- Field length: 1
		-- Data type: Alphanumeric

		--   If On-Site Management indicator = Y then at least one corresponding record
		--   must exist in GM5.
		--   If On-Site Management indicator = N then NO corresponding record may exist
		--   in GM5.

	'Y' as OFF_SITE_SHIPMENT
		-- Was this Waste Stream managed off-site? (Y/N)
		-- Starts at column: 538
		-- Field length: 1
		-- Data type: Alphanumeric

		--   If Off-Site Management indicator = 'Y' then at least one corresponding record
		--   must exist in GM4.
		--   If off-site Managmenent indicator equals 'N' then no corresponding record may
		--   exist in GM4.

FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
AND SD.TRANS_MODE = 'O'
GROUP BY
	SD.approval_code,
	SD.EPA_FORM_CODE,
	SD.EPA_source_CODE,
	SD.waste_desc,
	SD.profit_ctr_epa_id,
	SD.waste_density


-- Now number the rows --------------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_FL_GM1
set @intcounter = hz_pg_tmp = @intcounter + 1
where biennial_id = @biennial_id

-- Now format the row numbers -------------------------------
update EQ_Extract..BiennialReportWork_FL_GM1
set hz_pg = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), hz_pg_tmp), 5 )
where biennial_id = @biennial_id




/* ********************************
-- Create the GM2 file

Source Form: GM
Description: EPA Hazardous Waste Codes for each GM page 

This file captures the information contained in Section 1, Block B of the GM form.
The relationship of these data records to the reported waste is n:1, that is, 
there can be multiple EPA waste codes for each unique reported waste.   

Key Fields: Handler ID Number (HANDLER_ID);  Page Number (HZ_PG); 
EPA Hazardous Waste Code (EPA_WASTE_CODE).  Each record in the GM2 file must 
contain a unique combination of the Handler ID Number, Page Number, and EPA 
Hazardous Waste Code.  

Note: For each waste stream, either EPA Hazardous Waste Code information (GM2) 
is REQUIRED or State Hazardous Waste Code information (GM3) is REQUIRED.     

Total Record Length = 21 characters (1 record per line)

******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_FL_GM2 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_FL_GM2
SELECT DISTINCT

	@biennial_id,
		-- Track the run

	GM1.HANDLER_ID,
		-- EPA ID Number (comes from GM1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
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
		
FROM EQ_Extract..BiennialReportWork_FL_GM1 GM1
	JOIN EQ_Extract..BiennialReportSourceData SD ON ( GM1.biennial_id = SD.biennial_id
		AND GM1.APPROVAL_CODE = SD.APPROVAL_CODE
		AND GM1.DESCRIPTION = SD.WASTE_DESC AND SD.TRANS_MODE = 'O')
	JOIN EQ_Extract..BiennialReportSourceWasteCode SW ON ( SD.biennial_id = SW.biennial_id
		AND SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.TRANS_MODE = 'O')
WHERE GM1.biennial_id = @biennial_id


/* ********************************
-- Create the GM3 file - This wasn't created in 2005
-- below was never made functional because they don't report state codes
-- OHIO does not have state-specific waste codes and therefore file GM3 should not be submitted

Source Form: GM
Description: State Hazardous Waste Codes for each GM page  

This file captures the information contained in Section 1, Block C of the GM form.
The relationship of these data records to the reported waste is n:1, that is, 
there can be multiple State waste codes for each unique reported waste.  

Key Fields: Handler ID Number (HANDLER_ID);  Page Number (HZ_PG); 
State Hazardous Waste Code (WASTE_CODE).  Each record in the GM3 file must contain 
a unique combination of the Handler ID Number, Page Number, and State Hazardous 
Waste Code.  
 
Note: For each waste stream, either EPA Hazardous Waste Code information (GM2) 
is REQUIRED or State Hazardous Waste Code information (GM3) is REQUIRED.    

Total Record Length = 23 characters (1 record per line)

******************************** */

/*

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[BIENNIAL_REPORT_2009_GM3]') and OBJECTPROPERTY(id, N'IsTable') = 1)
	DROP TABLE [dbo].[BIENNIAL_REPORT_2009_GM3]
GO

SELECT DISTINCT

	GM1.HANDLER_ID,
		-- EPA ID Number (comes from GM1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	GM1.HZ_PG,
		-- Page Number (comes from GM1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Alphanumeric
		
	LEFT(IsNull(SW.WASTE_CODE,' ') + SPACE(6), 6) AS STATE_WASTE_CODE
		-- State Hazardous Waste Code
		-- Starts at column: 18
		-- Field length: 6
		-- Data type: Alphanumeric
	
INTO BIENNIAL_REPORT_2009_GM3
FROM BIENNIAL_REPORT_2009_GM1 GM1
	JOIN BIENNIAL_REPORT_2009_SOURCE_DATA SD ON ( GM1.APPROVAL_CODE = SD.APPROVAL_CODE
		AND GM1.DESCRIPTION = SD.WASTE_DESC AND SD.TRANS_MODE = 'O')
	JOIN BIENNIAL_REPORT_2009_SOURCE_WASTE SW ON ( SD.RECEIPT_ID = SW.RECEIPT_ID AND SD.LINE_ID = SW.LINE_ID
		AND SD.CONTAINER_ID = SW.CONTAINER_ID AND SD.SEQUENCE_ID = SW.SEQUENCE_ID AND SD.TRANS_MODE = 'O')

*/

/* ********************************
-- Create the GM4 file

Source Form: GM
Description: Off-Site Management Information for the Reported Waste 

This file captures off-site treatment information for the reported waste as 
represented in GM Sections 3.B through 3.D.  The relationship of these data records 
to the reported waste is n:1, that is, there can be multiple off-site information 
for each reported waste. 

Key Fields: Handler ID; Page Number; Off-Site Sequence Number.  Each record in 
the GM4 file must contain a unique combination of the Handler ID, Page Number, 
and Off-Site Sequence Number. 
 
Note:  The GM4 file is REQUIRED for handlers which generated RCRA hazardous waste
that was shipped off-site for management. 

Total Record Length = 56 characters (1 record per line)

******************************** */


DELETE FROM EQ_Extract..BiennialReportWork_FL_GM4 where biennial_id = @biennial_id

INSERT EQ_Extract..BiennialReportWork_FL_GM4
SELECT DISTINCT

	@biennial_id,
		-- Track the run

	GM1.HANDLER_ID,
		-- EPA ID Number (comes from GM1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	GM1.HZ_PG,
		-- Page Number (comes from GM1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer
		
	1 as IO_PG_NUM_SEQ_tmp,
		-- Off-site Sequence Number
		-- This is temporary, for numbering lines.

	'     ' as IO_PG_NUM_SEQ,
		-- Field for off-site sequence numbers '00001', etc.
		--   Initially left blank, numbered correctly via update below.
		-- Starts at column: 18
		-- Field length: 5
		-- Data type: Integer
	
	LEFT(IsNull(SD.management_code,' ') + SPACE(4), 4) as MANAGEMENT_METHOD,
		-- Off-site Management Method
		-- Starts at column: 23
		-- Field length: 4
		-- Data type: Alphanumeric
		
	LEFT(IsNull(SD.TSDF_EPA_ID,' ') + SPACE(12), 12) AS IO_TDR_ID,
		-- EPA ID No. of Off-site Facility Shipped To
		-- The first two characters of the Off-Site Handler EPA ID Number must be a state postal code or ‘FC’ (foreign country) 
		-- Starts at column: 27
		-- Field length: 12
		-- Data type: Alphanumeric
	
	SUBSTRING(REPLICATE(' ', 18 - DATALENGTH(CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_actual))))))
	+ CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.lbs_haz_actual)))), 1, 18) as IO_TDR_QTY
		-- Total Quantity Shipped to EPA ID in Field 5 in current reporting year
		-- Starts at column: 38
		-- Field length: 18
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal
		
from
	EQ_Extract..BiennialReportWork_FL_GM1 GM1
	INNER JOIN EQ_Extract..BiennialReportSourceData SD ON ( GM1.biennial_id = SD.biennial_id
		AND GM1.approval_code = SD.approval_code
		AND GM1.description = SD.waste_desc AND SD.TRANS_MODE = 'O')
group by
	GM1.HANDLER_ID,
	GM1.HZ_PG,
	SD.MANAGEMENT_CODE,
	SD.TSDF_EPA_ID
ORDER BY HZ_PG

-- Number the rows ------------------------------------------
--declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_FL_GM4
set @intcounter = IO_PG_NUM_SEQ_tmp = @intcounter + 1
where biennial_id = @biennial_id

-- Format the row numbers -----------------------------------
update EQ_Extract..BiennialReportWork_FL_GM4
set IO_PG_NUM_SEQ = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), IO_PG_NUM_SEQ_tmp), 5 )
where biennial_id = @biennial_id



/* ********************************
-- Create the GM5 file

Source Form: GM
Description: On-site Management Information for the Reported Waste on Each GM

This file captures on-site treatment information as contained in Section 2 of the 
GM form.  The relationship of the data element to the reported waste is n:1, that 
is, there can be multiple on-site information for each unique reported waste.  

Key Fields: Handler ID Number (HANDLER_ID);  Page Number (HZ_PG); 
On-site Sequence Number (SYS_PG_NUM_SEQ).  Each record in the GM5 file must contain 
a unique combination of the Handler ID Number, Page Number, and On-site Sequence 
Number. 
 
Note: The GM5 File is REQUIRED for handlers that generated RCRA hazardous waste 
that, in 2005, was accumulated on-site or managed on-site in a treatment, storage, 
or disposal unit. 

Total Record Length = 44 characters (1 record per line)

******************************** */

-- NOTE:
-- Went back through SQL to 2007, EQ never creates this file.  
-- That's because we hard-code the On-Site Management flag in GM1 to 'N'o.

/*

THIS QUERY HAS NOT BE VERIFIED CORRECT! - 2/15/2011 - JPB

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[BIENNIAL_REPORT_2009_GM5]') and OBJECTPROPERTY(id, N'IsTable') = 1)
	DROP TABLE [dbo].[BIENNIAL_REPORT_2009_GM5]
GO

SELECT DISTINCT

	GM1.HANDLER_ID,
		-- EPA ID Number (comes from GM1 table, so they match)
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric
		
	GM1.HZ_PG,
		-- Page Number (comes from GM1 table, so they match)
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer
		
	1 as SYS_PG_NUM_SEQ_tmp,
		-- On-site Sequence Number
		-- This is temporary, for numbering lines.

	'     ' as SYS_PG_NUM_SEQ,
		-- Field for on-site sequence numbers '00001', etc.
		--   Initially left blank, numbered correctly via update below.
		-- Starts at column: 18
		-- Field length: 5
		-- Data type: Integer
	
	LEFT(IsNull(SD.management_code,' ') + SPACE(4), 4) as MANAGEMENT_METHOD,
		-- On-site Management Method
		-- Starts at column: 23
		-- Field length: 4
		-- Data type: Alphanumeric
		
	SUBSTRING(REPLICATE(' ', 18 - DATALENGTH(CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.LBS_HAZ_WASTE))))))
	+ CONVERT(VARCHAR(18),(CONVERT(DECIMAL(18,6),SUM(SD.LBS_HAZ_WASTE)))), 1, 18) as IO_TDR_QTY
		-- Total Quantity Treated, Disposed or Recycled On-Site in current reporting year
		-- Starts at column: 27
		-- Field length: 18
		-- Data type: Decimal, max of 11 characters before the decimal, max of 6 characters after the decimal
		
INTO BIENNIAL_REPORT_2009_GM5
from
	BIENNIAL_REPORT_2009_GM1 GM1
	INNER JOIN BIENNIAL_REPORT_2009_SOURCE_DATA SD ON ( GM1.approval_code = SD.approval_code
		and GM1.description = SD.waste_desc AND SD.TRANS_MODE = 'O')
WHERE GM1.ON_SITE_MANAGEMENT = 'Y'
group by
	GM1.HANDLER_ID,
	GM1.HZ_PG,
	SD.MANAGEMENT_CODE,
	SD.TSDF_EPA_ID
ORDER BY HZ_PG

-- Number the rows ------------------------------------------
declare @intcounter int
set @intcounter = 0
update BIENNIAL_REPORT_2009_GM5
set @intcounter = SYS_PG_NUM_SEQ_tmp = @intcounter + 1
GO

-- Format the row numbers -----------------------------------
update BIENNIAL_REPORT_2009_GM5
set SYS_PG_NUM_SEQ = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), SYS_PG_NUM_SEQ_tmp), 5 )
GO

-- Get rid of the temp row number ---------------------------
alter table BIENNIAL_REPORT_2009_GM5 drop column IO_PG_NUM_SEQ_tmp
GO
*/



/* ********************************
-- Create the GM6 file

Source Form: GM
Description: On-site Storage and Inactive Disposal Units for Reported Waste 

This file captures the logic fields associated with GM Section 4, waste remaining 
on-site at the end of the year in permitted storage units or in storage or disposal 
units undergoing a formal closure.  The relationship of these data records to the 
reported waste is 1:1. 

Key Fields: Handler ID and Page Number.  Each record in the GM6 file must contain 
a unique combination of the Handler ID and Page Number. 
 
Note:  The GM6 file is optional. 

Total Record Length = 21 characters (1 record per line)

******************************** */

-- NOTE:
-- Went back through SQL to 2007, EQ never creates this file.  
-- That's because we hard-code the On-Site Management flag in GM1 to 'N'o.



/* ********************************
-- Create the GM6A file

Source Form: GM
Description: Handling Methods and Quantities for Waste Reported in the GM6 File 

 
This file captures the quantity and handling method for waste remaining on-site 
at the end of the year in permitted storage units or in storage or disposal units 
undergoing a formal closure, for the reported waste represented in GM Section 4.
The relationship of these data records to the reported waste is n:1, that is, 
there can be multiple records for each reported waste. 
 
Key Fields:  Handler ID and Page Number.  Each record in the GM6A file must have 
a parent record in GM6 with the same combination of the Handler ID and Page Number. 
 
Note:  The GM6A file is required if a GM6 file is included with the imported files. 
 
Total Record Length = 46 characters (1 record per line)

******************************** */

-- NOTE:
-- Went back through SQL to 2007, EQ never creates this file.  
-- That's because we hard-code the On-Site Management flag in GM1 to 'N'o.



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_FL_GM] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_FL_GM] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_FL_GM] TO [EQAI]
    AS [dbo];

