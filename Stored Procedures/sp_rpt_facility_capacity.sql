CREATE PROCEDURE sp_rpt_facility_capacity
	@company_id			int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
AS
/***********************************************************************
This procedure runs for the Facility Capacity Report.

Filename:	F:\EQAI\SQL\EQAI\sp_rpt_facility_capacity.sql
PB Object(s):	r_facility_capacity
				
02/08/2000 JDB	Created sp to report tons of Non-Hazardous Solid Waste
				disposed of in each Michigan county, each state besides
				Michigan, and each country besides USA.
02/29/2000 JDB	Changed table fac_cap_sum_fields to be a temporary
				table #fac_cap_sum_fields.
09/28/2000 LJT	Changed = NULL to is NULL and <> null to is not null
08/05/2002 SCC	Added trans_mode to receipt join
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table.
11/11/2004 MK	Changed generator_code to generator_id
03/15/2006 RG	removed join to waste code on profit ctr
05/11/2010 KAM  Update to remove the specific waste codes and to use the profile
				consistancy and the haz flag from the waste code
11/05/2010 SK	Added company_id as input arg, always send in a valid company_id(non zero)
08/21/2013 SM	Added wastecode table and displaying Display name

sp_rpt_facility_capacity 21, '01/01/2010', '02-23-2010'

***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@company_name		varchar(35),
	@country			varchar(3),
	@country_count		int,
	@country_count_max	int,
	@state				varchar(2),
	@state_count		int,
	@state_count_max 	int,
	@county				int,
	@county_count		int,
	@county_count_max 	int,
	@tons				float(15)
	
CREATE TABLE #fac_cap_sum_fields (
	country			varchar(3)	null
,	state			varchar(2)	null
,	county			int			null
,	tons			float(15)	null
,	company_id		int			null
,	michigan		varchar(1)	null
,	usa				varchar(1)	null
,	company_name	varchar(35)	null
)

-- Get company_name for input company_id
SELECT @company_name = Company.company_name FROM Company WHERE company_id = @company_id

-----------------------------------------------------------------------------
--Run the query to get data for all counties, all states, all countries
-----------------------------------------------------------------------------
SELECT 
	Receipt.company_id, 
    Generator.generator_id,   
	Generator.generator_county,
	Generator.generator_state,  
	Generator.generator_country,   
    county.county_name,   
    receipt.receipt_id,   
	receipt.bill_unit_code,   
	receipt.quantity,
    billunit.pound_conv, 
	pounds = (receipt.quantity * billunit.pound_conv),
	processed = 0
INTO #results
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
	--AND Generator.generator_state = 'MI'
	--AND Generator.generator_country = 'USA'
JOIN WasteCode
	ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	AND WasteCode.haz_flag = 'F'
LEFT OUTER JOIN county
	ON county.county_code = Generator.generator_county
	--AND county.state = Generator.generator_state
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


-----------------------------------------------------------------------------
-- Insert Summary Values for Michigan Counties  
-----------------------------------------------------------------------------
SELECT @county_count = 0
SELECT @county_count_max = (SELECT COUNT(generator_county) FROM #results 
								WHERE generator_state = 'MI' AND generator_country = 'USA')

-- LOOP START
Michigan_Counties:

SELECT @county = (SELECT MIN(generator_county) FROM #results WHERE processed = 0 
					AND generator_state = 'MI' AND generator_country = 'USA')
					
SELECT @tons = Round((SELECT SUM(pounds) FROM #results WHERE generator_county = @county 
						AND generator_state = 'MI' AND generator_country = 'USA') / 2000,4)
						
UPDATE #results 
SET processed = 1 
WHERE generator_county = @county 
	AND generator_state = 'MI' 
	AND generator_country = 'USA'
	
INSERT INTO #fac_cap_sum_fields VALUES ('USA', 'MI', @county, @tons, @company_id, 'T', 'T', @company_name)

SELECT @county_count = @county_count + 1
IF @county_count <= @county_count_max GOTO Michigan_Counties
-- LOOP END
-- dont keep null counties
DELETE FROM #fac_cap_sum_fields WHERE county is null AND state = 'MI' AND Country = 'USA'


-----------------------------------------------------------------------------
-- Insert Summary Values for other states in USA
-----------------------------------------------------------------------------
SELECT @state_count = 0
SELECT @state_count_max = (SELECT COUNT(generator_state) FROM #results 
							WHERE generator_state <> 'MI' AND generator_country = 'USA')

-- LOOP START
US_States:

SELECT @state	= (SELECT MIN(generator_state) FROM #results WHERE processed = 0 
					AND generator_state <> 'MI' AND generator_country = 'USA')
					
SELECT @tons	= Round((SELECT SUM(pounds) FROM #results WHERE generator_state = @state
							AND generator_country = 'USA') / 2000,4)

UPDATE #results 
SET processed = 1 
WHERE generator_state = @state
	AND generator_country = 'USA'
	
INSERT INTO #fac_cap_sum_fields VALUES ('USA', @state, null, @tons, @company_id, 'F', 'T', @company_name)

SELECT @state_count = @state_count + 1
IF @state_count <= @state_count_max GOTO US_States
-- LOOP END
-- dont keep null states
DELETE FROM #fac_cap_sum_fields WHERE state is null AND country = 'USA'


-----------------------------------------------------------------------------
-- Insert Summary Values for other Countries
-----------------------------------------------------------------------------
SELECT @country_count = 0
SELECT @country_count_max = (SELECT COUNT(generator_state) FROM #results WHERE generator_country <> 'USA')

-- LOOP START
Countries:

SELECT @country = (SELECT MIN(generator_country) FROM #results WHERE generator_country <> 'USA' AND processed = 0)

SELECT @tons = Round((SELECT SUM(pounds) FROM #results WHERE generator_country = @country) / 2000,4)

UPDATE #results
SET processed = 1 
WHERE generator_country = @country

INSERT INTO #fac_cap_sum_fields VALUES (@country, null, null, @tons, @company_id, 'F', 'F', @company_name)

SELECT @country_count = @country_count + 1
IF @country_count <= @country_count_max GOTO Countries
-- LOOP END
-- dont keep null countries
DELETE FROM #fac_cap_sum_fields WHERE country is null

-----------------------------------------------------------------------------
-- Select Summary Results
-----------------------------------------------------------------------------
SELECT * FROM #fac_cap_sum_fields 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_facility_capacity] TO [EQAI]
    AS [dbo];

