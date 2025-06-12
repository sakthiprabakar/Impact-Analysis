
CREATE PROCEDURE sp_biennial_report_output_OI (
	@biennial_id	int,
	@state			varchar(2)
)
AS
/* **********************************************************************************

Step 4 - OI Files

OI Form
The OI Form collects data identifying 1) handlers from whom waste was received and/or 
to whom waste was shipped and 2) all transporters used to ship waste during the 
reporting cycle.  These source, destination, and transporting entities are identified by 
their EPA ID, name, and address.   The EPA ID number of the waste handler is the 
primary key for the OI Form and not the page number as with GM or WR.  Therefore the 
page number for all the OI records can be the same.  Once imported, the page number  
is irrelevant because all the OI Form handlers are related to the report document itself 
rather than to a specific page. 

The purpose of this script is to create the data for the OI

01/21/2016	JPB	Added @int_* variables to avoid parameter sniffing slowness.
*********************************************************************************** */

declare
	@int_biennial_id	int				= @biennial_id,
	@int_state			varchar(2)		= @state


/* ********************************
-- Create the OI1 file

Source Form: OI
Description: Identification of All Handlers to Whom or From Whom Waste was 
			 Shipped, and Transporters 

This file captures information from the OI form.   
This flat file should never be included in submissions to RCRAInfo.  
 
Key Fields:  Handler ID Number (HANDLER_ID);  Page Number (OSITE_PGNUM).  Each 
record in the OI1 file must contain a unique combination of EPA ID Number and 
Page Number
 
Note:  The Page Number can be the same for all records.  Once the records are 
imported the Generator information is translated to the corresponding WR Form and 
the Transporter and Receiving Facility information appear as if they all were 
reported on a single page, regardless of the page number. 

Total Record Length = FEDERAL: 408 characters (1 record per line)
					  OHIO: 168 characters (1 record per line)
					  NOTE - OHIO Spec says 168 characters, but the math adds up to 169.
					  	-- People from OHIO can't do math. :)

-- IMPORTANT NOTES:
 1. The OHIO version of this file is different than the Federal version at the last field

EQ_Extract..sp_columns BiennialReportWork_OI
******************************** */

DELETE FROM EQ_Extract..BiennialReportWork_OI where biennial_id = @int_biennial_id


INSERT EQ_Extract..BiennialReportWork_OI
SELECT DISTINCT

	SD.biennial_id,
		-- Track the run

	1 as osite_pgnum_tmp,
		-- This is temporary, for numbering lines.

	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID,
		-- EPA ID of handler (our site)
		-- The first two characters of the Handler EPA ID Number must be a state postal code or ‘FC’ (foreign country) 
		-- Starts at column: 1
		-- Field length: 12
		-- Data type: Alphanumeric

	'00001' as OSITE_PGNUM,
		-- Page Number '00001', etc.
		--   Initially left with filler, numbered correctly via update below.
		-- Starts at column: 13
		-- Field length: 5
		-- Data type: Integer

	LEFT(SD.GENERATOR_EPA_ID + space(12), 12) as OFF_ID,
		-- Off-site Installation or Transporter EPA ID Number 
		-- The first two characters of the Handler EPA ID Number must be a state postal code or ‘FC’ (foreign country) 
		-- Starts at column: 18
		-- Field length: 12
		-- Data type: Alphanumeric

	'Y' AS WST_GEN_FLG,
		-- Handler Type = Generator 
		--   Checked = 'Y', 
		--   Unchecked and not implementer required = 'U',
		--   Unchecked and implementer required = 'N'
		-- Starts at column: 30
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO has a different spec for this field:
		-- "Handler Type = Generator"
		-- "Handler Type must be ‘Y’ or ‘N’."

	'N' AS WST_TRNS_FLG,
		-- Handler Type = Transporter 
		--   Checked = 'Y', 
		--   Unchecked and not implementer required = 'U',
		--   Unchecked and implementer required = 'N'
		-- Starts at column: 31
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO has a different spec for this field:
		-- "Handler Type = Transporter"
		-- "Handler Type must be ‘Y’ or ‘N’."

	'N' WST_TSDR_FLG,
		-- Handler Type = TSDR 
		--   Checked = 'Y', 
		--   Unchecked and not implementer required = 'U',
		--   Unchecked and implementer required = 'N'
		-- Starts at column: 32
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO has a different spec for this field:
		-- "Handler Type = Receiving Facility"
		-- "Handler Type must be ‘Y’ or ‘N’."

	LEFT(IsNull(SD.generator_name,' ') + SPACE(80), 80) as ONAME,
		-- Name of Off-site Installation or Transporter
		-- Starts at column: 33
		-- Field length: 40 (80 as of 2017)
		-- Data type: Alphanumeric

	LEFT('' /* Street Number!? */ + SPACE(12), 12) as OSTREETNO,
		-- Installation or Transporter Street Number 
		-- Starts at column: 113
		-- Field length: 12
		-- Data type: Alphanumeric
		

	LEFT(IsNull(SD.generator_address_1,' ') + SPACE(50), 50) as O1STREET,
		-- 1st Street Address Line of Installation or Transporter 
		-- Starts at column: 125
		-- Field length: 30 (50 as of 2017)
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_address_2,' ') + SPACE(50), 50) as O2STREET,
		-- 2nd Street Address Line of Installation or Transporter 
		-- Starts at column: 175
		-- Field length: 30 (50 as of 2017)
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_city,' ') + SPACE(25), 25) as OCITY,
		-- City
		-- Starts at column: 225
		-- Field length: 25
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_state,' ') + SPACE(2), 2) as OSTATE,
		-- State
		-- Starts at column: 250
		-- Field length: 2
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_zip_code,' ') + SPACE(14), 14) as OZIP,
		-- Zip Code 
		-- Starts at column: 252
		-- Field length: 9 (14 as of 2017)
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_country,' ') + SPACE(2), 2) as OCOUNTRY,
		-- Comments/Notes 
		-- Starts at column: 266
		-- Field length: 2
		-- Data type: Alphanumeric

	SPACE(1000) as NOTES
		-- Comments/Notes 
		-- Starts at column: 268
		-- Field length: 240 (1000 as of 2017)
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO Excludes this field.

FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @int_biennial_id
GROUP BY
	SD.generator_EPA_ID,
	SD.generator_name,
	SD.generator_address_1,
	SD.generator_address_2,
	SD.generator_city,
	SD.generator_state,
	SD.generator_country,
	SD.generator_zip_code,
	SD.biennial_id,
	SD.profit_ctr_epa_id

UNION ALL

SELECT DISTINCT
	SD.biennial_id,
	1 as osite_pgnum_tmp,
	SD.profit_ctr_epa_id AS HANDLER_ID,
	RIGHT(REPLICATE('0', 5 ) + '1', 5 ) as OSITE_PGNUM,
	LEFT(IsNull(SD.transporter_EPA_ID,' ') + SPACE(12), 12) as OFF_ID,
	'N' AS WST_GEN_FLG,
	'Y' AS WST_TRNS_FLG,
	'N' AS WST_TSDR_FLG,
	LEFT(IsNull(SD.transporter_name,' ') + SPACE(80), 80) as ONAME,
	LEFT('' + SPACE(12), 12) as OSTREETNO,
	LEFT(IsNull(SD.transporter_addr1,' ') + SPACE(50), 50) as O1STREET,
	LEFT(IsNull(SD.transporter_addr2,' ') + SPACE(50), 50) as O2STREET,
	LEFT(IsNull(SD.transporter_city,' ') + SPACE(25), 25) as OCITY,
	LEFT(IsNull(SD.transporter_state,' ') + SPACE(2), 2) as OSTATE,
	LEFT(IsNull(SD.transporter_zip_code,' ') + SPACE(14), 14) as OZIP,
	LEFT(IsNull(SD.transporter_country,' ') + SPACE(2), 2) as OCOUNTRY,
	SPACE(1000) as NOTES
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @int_biennial_id
GROUP BY
	SD.transporter_EPA_ID,
	SD.transporter_name,
	SD.transporter_addr1,
	SD.transporter_addr2,
	SD.transporter_city,
	SD.transporter_state,
	SD.transporter_zip_code,
	SD.transporter_country,
	SD.biennial_id,
	SD.profit_ctr_epa_id

UNION ALL

SELECT DISTINCT
	SD.biennial_id,
	1 as osite_pgnum_tmp,
	SD.profit_ctr_epa_id AS HANDLER_ID,
	RIGHT(REPLICATE('0', 5 ) + '1', 5 ) as OSITE_PGNUM,
	LEFT(IsNull(SD.tsdf_EPA_ID,' ') + SPACE(12), 12) as OFF_ID,
	'N' AS WST_GEN_FLG,
	'N' AS WST_TRNS_FLG,
	'Y' AS WST_TSDR_FLG,
	LEFT(IsNull(SD.tsdf_name,' ') + SPACE(80), 80) as ONAME,
	LEFT('' + SPACE(12), 12) as OSTREETNO,
	LEFT(IsNull(SD.tsdf_addr1,' ') + SPACE(50), 50) as O1STREET,
	LEFT(IsNull(SD.tsdf_addr2,' ') + SPACE(50), 50) as O2STREET,
	LEFT(IsNull(SD.tsdf_city,' ') + SPACE(25), 25) as OCITY,
	LEFT(IsNull(SD.tsdf_state,' ') + SPACE(2), 2) as OSTATE,
	LEFT(IsNull(SD.tsdf_zip_code,' ') + SPACE(14), 14) as OZIP,
	LEFT(IsNull(SD.tsdf_country,' ') + SPACE(2), 2) as OCOUNTRY,
	SPACE(240) as NOTES
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @int_biennial_id
GROUP BY
	SD.tsdf_EPA_ID,
	SD.tsdf_name,
	SD.tsdf_addr1,
	SD.tsdf_addr2,
	SD.tsdf_city,
	SD.tsdf_state,
	SD.tsdf_zip_code,
	SD.tsdf_country,
	SD.biennial_id,
	SD.profit_ctr_epa_id

-- Now number the rows --------------------------------------
declare @intcounter int
set @intcounter = 0
update EQ_Extract..BiennialReportWork_OI
set @intcounter = osite_pgnum_tmp = @intcounter + 1
where biennial_id = @int_biennial_id

-- Now format the row numbers -------------------------------
update EQ_Extract..BiennialReportWork_OI
set OSITE_PGNUM = RIGHT(REPLICATE('0', 5 ) + convert(varchar(10), osite_pgnum_tmp), 5 )
where biennial_id = @int_biennial_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_OI] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_OI] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_output_OI] TO [EQAI]
    AS [dbo];

