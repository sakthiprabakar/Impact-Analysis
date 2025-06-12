
CREATE PROCEDURE sp_biennial_validate_duplicated_generator (
	@biennial_id	int,
	@state			varchar(2) = ''
)
AS
/* **********************************************************************************

Just like the OI extract, but here we're looking for duplicates we couldn't combine.
sp_biennial_validate_duplicated_generator 1499, 'PA'
SELECT * FROM EQ_Extract..BiennialReportSourceDataValidation where biennial_id = 1499
*********************************************************************************** */

-- Only OHIO is a stickler for this... but it'd be nice if EVERYONE cleaned their data.

-- create a clone of the table for sorting out duplicates...
select * INTO #tmp_OI FROM EQ_Extract..BiennialReportWork_OI where biennial_id = @biennial_id
AND 1=0 -- guarantee we won't get any rows.

-- and a clone of the clone for removing duplicates
select * into #dup from #tmp_OI WHERE 1=0

-- insert into the clone
INSERT #tmp_OI
SELECT DISTINCT

	SD.biennial_id,
		-- Track the run

	1 as osite_pgnum_tmp,
		-- This is temporary, for numbering lines.

	LEFT(SD.profit_ctr_epa_id + space(12), 12) AS HANDLER_ID,
		-- EPA ID of handler (our site)
		-- The first two characters of the Handler EPA ID Number must be a state postal code or æFCÆ (foreign country) 
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
		-- The first two characters of the Handler EPA ID Number must be a state postal code or æFCÆ (foreign country) 
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
		-- "Handler Type must be æYÆ or æNÆ."

	CASE @state
		WHEN 'OH' THEN 'N'
		ELSE 'U'
	END AS WST_TRNS_FLG,
		-- Handler Type = Transporter 
		--   Checked = 'Y', 
		--   Unchecked and not implementer required = 'U',
		--   Unchecked and implementer required = 'N'
		-- Starts at column: 31
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO has a different spec for this field:
		-- "Handler Type = Transporter"
		-- "Handler Type must be æYÆ or æNÆ."

	CASE @state
		WHEN 'OH' THEN 'N'
		ELSE 'U'
	END AS WST_TSDR_FLG,
		-- Handler Type = TSDR 
		--   Checked = 'Y', 
		--   Unchecked and not implementer required = 'U',
		--   Unchecked and implementer required = 'N'
		-- Starts at column: 32
		-- Field length: 1
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO has a different spec for this field:
		-- "Handler Type = Receiving Facility"
		-- "Handler Type must be æYÆ or æNÆ."

	LEFT(IsNull(SD.generator_name,' ') + SPACE(80), 80) as ONAME,
		-- Name of Off-site Installation or Transporter
		-- Starts at column: 33
		-- Field length: 40
		-- Data type: Alphanumeric

	'' as OStreetNO,

	LEFT(IsNull(SD.generator_address_1,' ') + SPACE(50), 50) as O1STREET,
		-- 1st Street Address Line of Installation or Transporter 
		-- Starts at column: 73
		-- Field length: 30
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_address_2,' ') + SPACE(50), 50) as O2STREET,
		-- 2nd Street Address Line of Installation or Transporter 
		-- Starts at column: 103
		-- Field length: 30
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_city,' ') + SPACE(25), 25) as OCITY,
		-- City
		-- Starts at column: 133
		-- Field length: 25
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_state,' ') + SPACE(2), 2) as OSTATE,
		-- State
		-- Starts at column: 158
		-- Field length: 2
		-- Data type: Alphanumeric

	LEFT(IsNull(SD.generator_zip_code,' ') + SPACE(9), 9) as OZIP,
		-- Zip Code 
		-- Starts at column: 160
		-- Field length: 9
		-- Data type: Alphanumeric

	NULL as OCOUNTRY,

	SPACE(1000) as NOTES
		-- Comments/Notes 
		-- Starts at column: 169
		-- Field length: 240
		-- Data type: Alphanumeric
		
		-- NOTE! OHIO Excludes this field.

FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
GROUP BY
	SD.generator_EPA_ID,
	SD.generator_name,
	SD.generator_address_1,
	SD.generator_address_2,
	SD.generator_city,
	SD.generator_state,
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
	CASE @state WHEN 'OH' THEN 'N' ELSE 'U' END AS WST_GEN_FLG,
	'Y' AS WST_TRNS_FLG,
	CASE @state WHEN 'OH' THEN 'N' ELSE 'U' END AS WST_TSDR_FLG,
	LEFT(IsNull(SD.transporter_name,' ') + SPACE(80), 80) as ONAME,
	'' as OSTREETNO,
	LEFT(IsNull(SD.transporter_addr1,' ') + SPACE(50), 50) as O1STREET,
	LEFT(IsNull(SD.transporter_addr2,' ') + SPACE(50), 50) as O2STREET,
	LEFT(IsNull(SD.transporter_city,' ') + SPACE(25), 25) as OCITY,
	LEFT(IsNull(SD.transporter_state,' ') + SPACE(2), 2) as OSTATE,
	LEFT(IsNull(SD.transporter_zip_code,' ') + SPACE(9), 9) as OZIP,
	'' as OCOUNTRY,
	SPACE(240) as NOTES
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
GROUP BY
	SD.transporter_EPA_ID,
	SD.transporter_name,
	SD.transporter_addr1,
	SD.transporter_addr2,
	SD.transporter_city,
	SD.transporter_state,
	SD.transporter_zip_code,
	SD.biennial_id,
	SD.profit_ctr_epa_id

UNION ALL

SELECT DISTINCT
	SD.biennial_id,
	1 as osite_pgnum_tmp,
	SD.profit_ctr_epa_id AS HANDLER_ID,
	RIGHT(REPLICATE('0', 5 ) + '1', 5 ) as OSITE_PGNUM,
	LEFT(IsNull(SD.tsdf_EPA_ID,' ') + SPACE(12), 12) as OFF_ID,
	CASE @state WHEN 'OH' THEN 'N' ELSE 'U' END AS WST_GEN_FLG,
	CASE @state WHEN 'OH' THEN 'N' ELSE 'U' END AS WST_TRNS_FLG,
	'Y' AS WST_TSDR_FLG,
	LEFT(IsNull(SD.tsdf_name,' ') + SPACE(80), 80) as ONAME,
	'' as OSTREETNO,
	LEFT(IsNull(SD.tsdf_addr1,' ') + SPACE(50), 50) as O1STREET,
	LEFT(IsNull(SD.tsdf_addr2,' ') + SPACE(50), 50) as O2STREET,
	LEFT(IsNull(SD.tsdf_city,' ') + SPACE(25), 25) as OCITY,
	LEFT(IsNull(SD.tsdf_state,' ') + SPACE(2), 2) as OSTATE,
	LEFT(IsNull(SD.tsdf_zip_code,' ') + SPACE(9), 9) as OZIP,
	'' as OCOUNTRY,
	SPACE(240) as NOTES
FROM EQ_Extract..BiennialReportSourceData SD
WHERE biennial_id = @biennial_id
GROUP BY
	SD.tsdf_EPA_ID,
	SD.tsdf_name,
	SD.tsdf_addr1,
	SD.tsdf_addr2,
	SD.tsdf_city,
	SD.tsdf_state,
	SD.tsdf_zip_code,
	SD.biennial_id,
	SD.profit_ctr_epa_id

-- Detect duplicate rows we can combine ---------------------

-- This is neat logic..
-- Since MAX returns the biggest char/int value in a set, and 'Y' comes after both 'N' OR 'U' OR NULL
-- then if you have ANY row for this duplicated OI record that has a Y, you get that Y.  Or N. Or whichever
-- has the highest value.  Pretty cool.

insert #dup
select 
	o.biennial_id,
	o.osite_pgnum_tmp,
	o.HANDLER_ID,
	o.OSITE_PGNUM,
	o.OFF_ID, 
	MAX(o.WST_GEN_FLG) as WST_GEN_FLG, 
	MAX(o.WST_TRNS_FLG) as WST_TRNS_FLG, 
	MAX(o.WST_TSDR_FLG) as WST_TSDR_FLG, 
	o.ONAME, 
	NULL, -- OSTREETNO
	NULL, -- O1STREET
	NULL, -- O2STREET
	o.OCITY, 
	o.OSTATE, 
	o.OZIP,
	NULL, -- OCOUNTRY
	o.NOTES
FROM #tmp_OI o
INNER JOIN (
	select OFF_ID, ONAME, OCITY, OSTATE, OZIP
	FROM #TMP_OI
	GROUP BY OFF_ID, ONAME, OCITY, OSTATE, OZIP
	HAVING COUNT(*) > 1
) d on
	o.off_id = d.off_id
	AND o.oname = d.oname
	AND o.ocity = d.ocity
	AND o.ostate = d.ostate
	AND o.ozip = d.ozip
group by 
	o.biennial_id,
	o.osite_pgnum_tmp,
	o.HANDLER_ID,
	o.OSITE_PGNUM,
	o.OFF_ID, 
	o.ONAME, 
	o.OCITY, 
	o.OSTATE, 
	o.OZIP,
	o.NOTES

UPDATE #dup set 
	O1STREET = (select top 1 O1STREET from #tmp_OI where off_id = #dup.off_id),
	O2STREET = (select top 1 O2STREET from #tmp_OI where off_id = #dup.off_id)

-- Now #dup has the combined data, and it's still duplicated in #tmp_OI. Gotta drop those out.
delete from #tmp_OI from #tmp_OI o 
inner join #dup d
	ON o.off_id = d.off_id
	AND o.oname = d.oname
	AND o.ocity = d.ocity
	AND o.ostate = d.ostate
	AND o.ozip = d.ozip

-- Now move #dup into #tmp_OI in their place
insert #tmp_OI
select * from #dup

-- Finally, the Important part for Validation -----------------------------
-- Any other dupes left?

/*
look at all the data for all of them...
	select 
		o.*
	FROM #tmp_OI o
	where o.off_id in (
		select OFF_ID
		FROM #TMP_OI
		GROUP BY OFF_ID
		HAVING COUNT(*) > 1
	)
	and  o.off_id = 'PAD086214574'
	order by o.off_id
*/

select replace(replace(
	'EPAID ' 
	+ o.off_id + ': ' 
	+ CASE WHEN d.WST_GEN_FLG = 'Y' then 'Gen.+' else '' end
	+ CASE WHEN d.WST_TRNS_FLG = 'Y' then 'Transp.+' else '' end
	+ CASE WHEN d.WST_TSDR_FLG = 'Y' then 'TSDF+' else '' end
	+ ' with diff. name/addr/etc in each'
	, '+ ', ' '), '+', ' + ') as validation_message
into #val
from #tmp_OI o
INNER JOIN (
	select OFF_ID, --ONAME, OCITY, OSTATE, OZIP
	MAX(WST_GEN_FLG) as WST_GEN_FLG, 
	MAX(WST_TRNS_FLG) as WST_TRNS_FLG, 
	MAX(WST_TSDR_FLG) as WST_TSDR_FLG
	FROM #TMP_OI
	GROUP BY OFF_ID --, ONAME, OCITY, OSTATE, OZIP
	HAVING COUNT(*) > 1
) d on
	o.off_id = d.off_id
group by o.off_id,
d.WST_GEN_FLG ,
d.WST_TRNS_FLG,
d.WST_TSDR_FLG
order by o.off_id

update #val set validation_message = replace(validation_message, ': ', ': Multiple ')
where validation_message not like '%+%'

insert EQ_Extract..BiennialReportSourceDataValidation (validation_message, rowid, biennial_id, data_source)
select validation_message, 1, @biennial_id, 'EQAI'
from #val



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicated_generator] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicated_generator] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_duplicated_generator] TO [EQAI]
    AS [dbo];

