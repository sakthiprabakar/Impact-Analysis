
CREATE PROCEDURE sp_biennial_validate_address
	@biennial_id int,
	@debug		int = 0
AS

/******************************************************************************
sp_biennial_validate_address

History:
	1/23/2018	JPB	Created to validate that Street1, City, State and Zip are present and in required format

Example:
	sp_biennial_validate_address 2015;

select top 1000 * from EQ_Extract..BiennialReportSourceData
select max(biennial_id) FROM EQ_Extract..BiennialReportSourceData src WHERE isnull(generator_address_1, '') = ''
SELECT  * FROM  EQ_Extract.dbo.BiennialReportSourceDataValidation WHERE biennial_id = 2015

SELECT  * FROM  generator where generator_id = 100253

SELECT  * FROM  tsdf where tsdf_code = 'CYANIDE DEST'
******************************************************************************/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)

if @debug > 0 select getdate(), 'sp_biennial_validate_address: started'	

-- declare @biennial_id int = 2022
	
if object_id('tempdb..#test') is not null drop table #test
create table #test (
	validation_message	varchar(255),
	address_type		varchar(40),
)

	insert #test
	select distinct
		'TSDF (our facility) Missing Street1 Address: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(TSDF_addr1, ''))) = ''
	and trans_mode = 'I'

	insert #test
	select distinct
		'TSDF (our facility) Missing City: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(TSDF_city, ''))) = ''
	and trans_mode = 'I'

	insert #test
	select distinct
		'TSDF (our facility) Missing State: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(TSDF_state, ''))) = ''
	and trans_mode = 'I'

	insert #test
	select distinct
		'TSDF (our facility) Missing Zip Code: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(TSDF_zip_code, ''))) = ''
	and trans_mode = 'I'
	
	insert #test
	select distinct
		'TSDF (our facility) US Zip Code ''' + isnull(src.tsdf_zip_code, '') + ''' Must be nnnnn or nnnnn-nnnn Format: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	and trans_mode = 'I'
	and (
		1=0
		or len(ltrim(rtrim(replace(isnull(src.TSDF_zip_code, ''), ' ', '')))) not in (5, 10)
		or (
			ISNUMERIC(SUBSTRING(src.TSDF_zip_code, 1, 5)) = 0
			and
			ISNUMERIC(RIGHT(src.TSDF_zip_code, 4)) = 0
		)
		or (
			len(ltrim(rtrim(replace(isnull(src.TSDF_zip_code, ''), ' ', '')))) = 10
			and substring(src.TSDF_zip_code, 6, 1) <> '-'
		)
	)

	insert #test
	select distinct
		'TSDF (our facility) Bad/Missing Country: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id), 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(TSDF_country, ''))) = ''
	and trans_mode = 'I'

	insert #test
	select distinct
		'TSDF (our facility) Bad/Missing EPA Country or State: Company ' + convert(varchar(4), company_id) + ', ProfitCenter ' + convert(varchar(4), profit_ctr_id) + ' Alert IT re: PhoneListLocation', 
		'TSDF (ProfitCenter)'
	FROM EQ_Extract..BiennialReportSourceData src
	LEFT JOIN StateAbbreviation lfs 
		on (isnull(src.TSDF_country, '') = lfs.country_code or isnull(src.TSDF_country, '') = lfs.epa_country_code)
		and isnull(src.TSDF_state, '') = lfs.abbr
	WHERE src.biennial_id = @biennial_id
	AND (ltrim(rtrim(isnull(lfs.epa_state_code, ''))) <> isnull(src.TSDF_state, 'XX')
	OR ltrim(rtrim(isnull(lfs.epa_country_code, ''))) <> isnull(src.TSDF_country, 'XX'))
	and trans_mode = 'I'
	

	insert #test
	select distinct
		'TSDF (external TSDF) Missing Street1 Address: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(src.TSDF_addr1, ''))) = ''
	and src.trans_mode = 'O'

	insert #test
	select distinct
		'TSDF (external TSDF) Missing City: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(src.TSDF_city, ''))) = ''
	and src.trans_mode = 'O'


	insert #test
	select distinct
		'TSDF (external TSDF) Missing State: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(src.TSDF_state, ''))) = ''
	and src.trans_mode = 'O'

	insert #test
	select distinct
		'TSDF (external TSDF) Missing Zip Code: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(src.TSDF_zip_code, ''))) = ''
	and src.trans_mode = 'O'

	insert #test
	select distinct
		'TSDF (external TSDF) US Zip Code ''' + isnull(src.tsdf_zip_code, '') + ''' Must be nnnnn or nnnnn-nnnn Format: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	join tsdf tsdf
		on r.tsdf_code = tsdf.tsdf_code
		and isnull(tsdf.tsdf_country_code, 'USA') = 'USA'
	WHERE src.biennial_id = @biennial_id
	and src.trans_mode = 'O'
	and (
		1=0
		or len(ltrim(rtrim(replace(isnull(src.TSDF_zip_code, ''), ' ', '')))) not in (5, 10)
		or (
			ISNUMERIC(SUBSTRING(src.TSDF_zip_code, 1, 5)) = 0
			and
			ISNUMERIC(RIGHT(src.TSDF_zip_code, 4)) = 0
		)
		or (
			len(ltrim(rtrim(replace(isnull(src.TSDF_zip_code, ''), ' ', '')))) = 10
			and substring(src.TSDF_zip_code, 6, 1) <> '-'
		)
	)

	insert #test
	select distinct
		'TSDF (external TSDF) Bad/Missing Country: TSDF Code ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(src.TSDF_country, ''))) = ''
	and src.trans_mode = 'O'

	insert #test
	select distinct
		'TSDF (external TSDF) Bad/Missing EPA Country or State: TSDF CODE ''' + r.tsdf_code + '''', 
		'TSDF'
	FROM EQ_Extract..BiennialReportSourceData src
	join Receipt r 
		on src.receipt_id = r.receipt_id 
		and src.line_id = r.line_id 
		and src.company_id = r.company_id 
		and src.profit_ctr_id = r.profit_ctr_id
	LEFT JOIN StateAbbreviation lfs 
		on (isnull(src.TSDF_country, '') = lfs.country_code or isnull(src.TSDF_country, '') = lfs.epa_country_code)
		and isnull(src.TSDF_state, '') = lfs.abbr
	WHERE src.biennial_id = @biennial_id
	AND (ltrim(rtrim(isnull(lfs.epa_state_code, ''))) <> isnull(src.TSDF_state, 'XX')
	OR ltrim(rtrim(isnull(lfs.epa_country_code, ''))) <> isnull(src.TSDF_country, 'XX'))
	and src.trans_mode = 'O'



	insert #test
	select distinct
		'Generator Missing Street1 Address: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(generator_address_1, ''))) = ''


	insert #test
	select distinct
		'Generator Missing City: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(generator_city, ''))) = ''

	insert #test
	select distinct
		'Generator Missing State: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(generator_state, ''))) = ''

	insert #test
	select distinct
		'Generator Missing Zip Code: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(generator_zip_code, ''))) = ''
	
	insert #test
	select distinct
		'Generator US Zip Code ''' + isnull(src.generator_zip_code, '') + ''' Must be nnnnn or nnnnn-nnnn Format: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	inner join generator g on src.eq_generator_id = g.generator_id and isnull(g.generator_country, 'USA') = 'USA'
	WHERE src.biennial_id = @biennial_id
	and (
		1=0
		or len(ltrim(rtrim(replace(isnull(src.generator_zip_code, ''), ' ', '')))) not in (5, 10)
		or (
			ISNUMERIC(SUBSTRING(src.generator_zip_code, 1, 5)) = 0
			and
			ISNUMERIC(RIGHT(src.generator_zip_code, 4)) = 0
		)
		or (
			len(ltrim(rtrim(replace(isnull(src.generator_zip_code, ''), ' ', '')))) = 10
			and substring(src.generator_zip_code, 6, 1) <> '-'
		)
	)

	insert #test
	select distinct
		'Generator Bad/Missing Country: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ltrim(rtrim(isnull(generator_country, ''))) = ''

	insert #test
	select distinct
		'Generator Bad/Missing EPA Country or State: Generator ID ' + convert(varchar(10), src.eq_generator_ID), 
		'Generator'
	FROM EQ_Extract..BiennialReportSourceData src
	LEFT JOIN StateAbbreviation lfs 
		on (isnull(src.generator_country, '') = lfs.country_code or isnull(src.generator_country, '') = lfs.epa_country_code )
		and isnull(src.generator_state, '') = lfs.abbr
	WHERE src.biennial_id = 2034 --@biennial_id
	AND (ltrim(rtrim(isnull(lfs.epa_state_code, ''))) <> isnull(src.generator_state, 'XX')
	OR ltrim(rtrim(isnull(lfs.epa_country_code, ''))) <> isnull(src.generator_country, 'XX'))

		
if @debug > 0 select getdate(), 'sp_biennial_validate_address: finished loading #test'	

	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation (validation_message, rowid, biennial_id)
	
	SELECT validation_message, row_number() over (order by validation_message) as rowid, @biennial_id
	FROM #test
	
if @debug > 0 select getdate(), 'sp_biennial_validate_address: finished inserting to validation table'	


	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_address] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_address] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_address] TO [EQAI]
    AS [dbo];

