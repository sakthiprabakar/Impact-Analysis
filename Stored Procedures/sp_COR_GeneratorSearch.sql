GO
DROP PROC IF EXISTS sp_COR_GeneratorSearch
GO

CREATE PROC [dbo].[sp_COR_GeneratorSearch] (
	  @web_userid				VARCHAR(100)
	, @generator_name			VARCHAR(75) = NULL
	, @epa_id					VARCHAR(MAX) = NULL	-- Can take CSV list
	, @site_code				VARCHAR(MAX) = NULL	-- Can take CSV list
	, @state_code				VARCHAR(MAX) = NULL
	, @address					VARCHAR(MAX) = NULL 
	, @city						VARCHAR(25) = NULL
	, @generator_size			VARCHAR(MAX) = NULL	-- Can take CSV list
	, @search					VARCHAR(MAX) = NULL -- General Search
	, @sort						VARCHAR(50) = 'Generator Name'
	, @generator_id_list		VARCHAR(MAX)=''  /* Added 2019-08-07 by AA */
	, @include_various			BIT = 1 -- whether the Various generator (id 0) should be returned (default yes)
	, @include_inactive			BIT = 1 -- whether inactive generators (status = I) should be returned (default yes)
	, @status_filter			CHAR(1) = 'B' -- 'A'ctive, 'I'nactive, or 'B'oth
	, @page						INT = NULL
	, @perpage					INT = NULL
	, @excel_output				INT = 0
	, @customer_id_list			VARCHAR(MAX)=''  /*  Added 2019-08-07 by AA */
	, @profile_id_list			VARCHAR(MAX) = NULL
	, @generator_division_list	VARCHAR(max) = ''
)
AS
/* ******************************************************************
Generator Name Search
	Updated By		: MONISH V
	Updated On		: 23RD Nov 2022
	Type			: Stored Procedure
	Object Name		: [sp_COR_GeneratorSearch]

inputs 
	
	Web User ID
	Generator Name

Returns

	Generator Name
	Generator Address Lines
	City
	State
	Zip
	Country
	Contact?
	Phone?
	Email?
	
History (partial, anyway):
	02/22/2021	JPB	DO-18689 - removed images logic for speed.
				sp_cor_generator_details exists for pulling the same image info for a single generator
	09/15/2021  JPB DO-16179 - add division input

Samples:
exec sp_COR_GeneratorSearch 'sam', null
exec sp_COR_GeneratorSearch 'nyswyn100'
exec sp_COR_GeneratorSearch 'nyswyn100',null,'007','all',0,'City',1,2000
exec sp_COR_GeneratorSearch 'akalinka', @generator_division_list = 'TPS'

exec [sp_COR_GeneratorSearch] 
	@web_userid		= 'nyswyn100'
	, @generator_id_list			= ''
	, @generator_name		= ''
	, @epa_id				= ''	-- Can take CSV list
	, @site_code			= ''	-- Can take CSV list
	, @address				= ''
	, @state_code			= ''
	, @city					= ''
	, @generator_size		= ''	-- Can take CSV list
	, @include_inactive = 1
	, @status_filter = 'I'
	, @sort			= 'Generator Name'
	, @page			= 1
	, @perpage		= 1000
	, @customer_id_list = ''
	, @profile_id_list = '343472'	

SELECT  * FROM    ContactCORProfileBucket WHERE  contact_id= 11289
SELECT  * FROM    plt_image..scan WHERE generator_id = 171748 and document_source = 'generator'
SELECT  *  FROM    generator WHERE generator_name like 'harbor fre%' and generator_type_id is null

sp_columns generator
SELECT  *  FROM    generatortype

SELECT  *  FROM    plt_image..scan
WHERE generator_id in (122850,
122851,
122853,
122858,
125349,
125253
)
and document_source = 'generator'

	02/15/2021 JPB	DO-18689 - Remove Scan lookups FROM this SP


****************************************************************** */
BEGIN
-- Avoid query plan caching:
DECLARE @i_web_userid				VARCHAR(100) = @web_userid
	, @i_generator_name				VARCHAR(MAX) = ISNULL(@generator_name, '')
	, @i_epa_id						VARCHAR(MAX) = ISNULL(@epa_id, '')
	, @i_site_code					VARCHAR(MAX) = ISNULL(@site_code, '')
	, @i_state_code					VARCHAR(MAX) = ISNULL(@state_code,'')
	, @i_address					VARCHAR(MAX) = ISNULL(@address, '')
	, @i_city						VARCHAR(25)	 = ISNULL(@city,'')
	, @i_generator_size				VARCHAR(MAX) = ISNULL(@generator_size, '')
	, @i_search						VARCHAR(MAX) = dbo.fn_cleanPunctuation(ISNULL(@search, ''))
	, @i_generator_id_list			VARCHAR(MAX)= ISNULL(@generator_id_list,'')
	, @i_include_various			BIT = ISNULL(@include_various, 1)
	, @i_include_inactive			BIT = ISNULL(@include_inactive, 1)
	, @i_status_filter				CHAR(1) = ISNULL(@status_filter, 'B')
	, @i_sort						VARCHAR(50) = @sort
	, @i_page						INT = @page
	, @i_perpage					INT = @perpage
	, @i_customer_id_list			VARCHAR(MAX)= ISNULL(@customer_id_list,'')
	, @i_contact_id					INT
	, @NA_Generator_Type			INT
	, @i_profile_id_list			VARCHAR(MAX) = ISNULL(@profile_id_list, '')
	, @i_generator_division_list	VARCHAR(MAX) = ISNULL(@generator_division_list, '')

	SELECT TOP 1 @i_contact_id = contact_id 
	FROM CORcontact 
	WHERE web_userid = @i_web_userid

	SELECT TOP 1 @NA_Generator_Type = generator_type_id 
	FROM GeneratorType 
	WHERE generator_type = 'N/A' -- use n/a WHERE none is set.

DECLARE @generatorids TABLE (generator_id INT)
IF @i_generator_id_list <> ''
	INSERT @generatorids (generator_id)
	SELECT ROW 
	FROM dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
	WHERE ROW IS NOT NULL


DECLARE @epaids TABLE (epa_id VARCHAR(20))
IF @i_epa_id <> ''
	INSERT @epaids (epa_id)
	SELECT LEFT(ROW, 20) 
		FROM dbo.fn_SplitXsvText(',', 1, @i_epa_id)
		WHERE ROW IS NOT NULL

-- DECLARE @i_site_code varchar(max) = '18'
DECLARE @sitecodes TABLE ( idx INT NOT NULL, site_code	VARCHAR(16))
IF @i_site_code <> ''
	INSERT @sitecodes (idx, site_code)
	SELECT idx, replace(LEFT(ROW, 16), '*', '%') 
		FROM dbo.fn_SplitXsvText(',', 1, @i_site_code)
		WHERE ROW IS NOT NULL

DECLARE @generatorsizes TABLE (generator_type VARCHAR(20))
IF @i_generator_size <> ''
	INSERT @generatorsizes (generator_type)
	SELECT LEFT(ROW, 20) 
		FROM dbo.fn_SplitXsvText(',', 1, @i_generator_size)
		WHERE ROW IS NOT NULL

DECLARE @division TABLE (generator_division	VARCHAR(40))
IF @i_generator_division_list <> ''
	INSERT @division (generator_division)
	SELECT LEFT(ROW, 40) 
		FROM dbo.fn_SplitXsvText('|', 1, @i_generator_division_list)
		WHERE ROW IS NOT NULL
-- NOTE: There are generator_division values that contain commas!!

DECLARE @statecodes TABLE (state_name VARCHAR(50), country	VARCHAR(3))
IF @i_state_code <> ''
	INSERT @statecodes (state_name, country)
	SELECT sa.abbr, sa.country_code
		FROM dbo.fn_SplitXsvText(',', 1, @i_state_code) x
		JOIN stateabbreviation sa
		ON (
			sa.state_name = x.ROW AND x.ROW NOT LIKE '%-%'
			OR
			sa.abbr = x.ROW AND x.ROW NOT LIKE '%-%'
			OR
			sa.abbr + '-' + sa.country_code = x.ROW AND x.ROW LIKE '%-%'
			OR
			sa.country_code  + '-' + sa.abbr= x.ROW AND x.ROW LIKE '%-%'
			)
		WHERE ROW IS NOT NULL

--SELECT * FROM @statecodes

--SELECT abbr, state_name FROM [dbo].[StateAbbreviation]
--		 WHERE country_code IN ('USA', 'CAN', 'MEX', 'PRI') AND state_name in (SELECT state_name FROM @statecodes)

DECLARE @profile TABLE (
	profile_id		INT,
	customer_id		INT,
	generator_id	INT
)
	INSERT @profile
	SELECT b.profile_id, b.customer_id, b.generator_id
		FROM dbo.fn_SplitXsvText(',', 1, @i_profile_id_list) x
		JOIN ContactCORProfileBucket b ON convert(INT, x.ROW) = b.profile_id
		WHERE ROW IS NOT NULL
		AND b.contact_id = @i_contact_id
		AND ISNUMERIC(ROW) = 1

IF EXISTS (SELECT 1 FROM @profile WHERE generator_id = 0) 
BEGIN
	INSERT @profile (profile_id, customer_id, generator_id)
	SELECT a.profile_id, a.customer_id, pgg.generator_id 
	FROM @profile a
	JOIN ProfileGeneratorSiteType pgst ON a.profile_id = pgst.profile_id
	JOIN generator pgg ON pgst.site_type = pgg.site_type
	JOIN ContactCORGeneratorBucket gb ON contact_id = @i_contact_id 
	AND pgg.generator_id = gb.generator_id
	WHERE a.generator_id = 0
	UNION
	SELECT a.profile_id, a.customer_id, cg.generator_id 
	FROM @profile a
	JOIN CustomerGenerator cg ON a.customer_id = cg.customer_id
	JOIN generator cgg ON cg.generator_id = cgg.generator_id
	JOIN ContactCORGeneratorBucket gb ON contact_id = @i_contact_id 
	and cg.generator_id = gb.generator_id
	WHERE a.generator_id = 0

	DELETE FROM @profile WHERE generator_id = 0
	
END

IF @i_customer_id_list <> '' AND @i_profile_id_list <> ''
DELETE FROM @profile WHERE customer_id NOT IN (
	SELECT ROW FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
	WHERE ROW IS NOT NULL)

DECLARE @bar TABLE (Generator_id INT, _reason VARCHAR(100))
DECLARE @foo TABLE (Generator_id INT,
_rowNumber INT,
_reason varchar(100))


-- The total set of possible Generators (assignments + history)
-- DECLARE @i_contact_id int = 11289
INSERT @bar (generator_id)
SELECT generator_id
--, 'In ContactCORGeneratorBucket'
FROM ContactCORGeneratorBucket b
WHERE contact_id = @i_contact_id
AND (
	@i_generator_id_list = ''
	OR
	(
		@i_generator_id_list <> ''
		AND
		b.generator_id IN (SELECT generator_id 
							FROM @generatorids 
							UNION 
							SELECT 0 
							WHERE @i_include_various = 1)
	)
)
AND @i_profile_id_list = ''
UNION
--INSERT @bar (generator_id, _reason)
SELECT generator_id
-- , 'In ContactCORFormWCRBucket'
FROM ContactCORFormWCRBucket b
--JOIN profilequoteapproval pqa ON b.profile_id = pqa.profile_id and pqa.status = 'A'
WHERE contact_id = @i_contact_id
AND generator_id <>-1
AND (
	@i_generator_id_list = ''
	OR
	(
		@i_generator_id_list <> ''
		AND
		b.generator_id IN (SELECT generator_id 
							FROM @generatorids 
							UNION 
							SELECT 0 
							WHERE @i_include_various = 1)
	)
)
AND @i_profile_id_list = ''
--and not exists (SELECT 1 FROM @bar WHERE generator_id = b.generator_id)
UNION
--INSERT @bar (generator_id, _reason)
SELECT COALESCE(p.generator_id, b.generator_id)
--, 'In ContactCORProfileBucket'
FROM ContactCORProfileBucket b
LEFT JOIN @profile p ON b.profile_id = p.profile_id AND p.generator_id <> 0
--JOIN profilequoteapproval pqa ON b.profile_id = pqa.profile_id and pqa.status = 'A'
WHERE b.contact_id = @i_contact_id
AND ap_expiration_date > DATEADD(yyyy, -2, GETDATE())
-- and (@i_include_various = 1 and b.generator_id = 0 or @i_include_various = 0 and b.generator_id <> 0)
--and not exists (SELECT 1 FROM @bar WHERE generator_id = b.generator_id)
AND b.curr_status_code = 'A'
AND (
	@i_generator_id_list = ''
	OR
	(
		@i_generator_id_list <> ''
		AND
		b.generator_id IN (SELECT generator_id 
							FROM @generatorids 
							UNION 
							SELECT 0 
							WHERE @i_include_various = 1)
	)
)
AND
(
	@i_profile_id_list = ''
	OR 
	(
	@i_profile_id_list <> ''
	AND b.profile_id IN (SELECT profile_id FROM @profile)
	)
)
UNION
--INSERT @bar (generator_id, _reason)
SELECT generator_id
-- , 'In ContactCORReceiptBucket'
FROM ContactCORReceiptBucket b
WHERE contact_id = @i_contact_id
AND receipt_date > DATEADD(yyyy, -2, GETDATE())
--and not exists (SELECT 1 FROM @bar WHERE generator_id = b.generator_id)
AND (
	@i_generator_id_list = ''
	OR
	(
		@i_generator_id_list <> ''
		AND
		b.generator_id IN (SELECT generator_id 
							FROM @generatorids 
							UNION 
							SELECT 0 WHERE @i_include_various = 1)
	)
)
AND @i_profile_id_list = ''
UNION
--INSERT @bar (generator_id, _reason)
SELECT generator_id
-- , 'In ContactCORWorkorderHeaderBucket'F
FROM ContactCORWorkorderHeaderBucket b
WHERE contact_id = @i_contact_id
AND START_DATE > DATEADD(yyyy, -2, GETDATE())
--and not exists (SELECT 1 FROM @bar WHERE generator_id = b.generator_id)
AND (
	@i_generator_id_list = ''
	OR
	(
		@i_generator_id_list <> ''
		AND
		b.generator_id IN (SELECT generator_id 
							FROM @generatorids 
							UNION 
							SELECT 0 
							WHERE @i_include_various = 1)
	)
)
AND @i_profile_id_list = ''
UNION
--INSERT @bar (generator_id, _reason)
SELECT 0
-- , 'Various' 
WHERE @i_include_various = 1 -- Various generator obeys input control
AND NOT EXISTS (SELECT 1 FROM @bar WHERE 0 = generator_id)

--SELECT  *  FROM    @bar WHERE generator_id = 0
DELETE FROM @bar WHERE generator_id IS NULL


INSERT @foo
SELECT 0, 1, 'Various'
WHERE ISNULL(@generator_name, '') +
		ISNULL(@epa_id, '') +
		ISNULL(@site_code, '') +
		ISNULL(@state_code, '') +
		ISNULL(@city, '') +
		ISNULL(@generator_size, '') +
		ISNULL(@search, '') +
		ISNULL(@profile_id_list, '') = ''
		AND @i_include_various = 1
UNION
SELECT  
		x.Generator_id
		,ROW_NUMBER() OVER (ORDER BY 
			CASE WHEN ISNULL(@i_sort, '') = 'Generator Number' THEN x.Generator_id END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'Generator Name' THEN d.generator_name END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'EPA ID' THEN d.epa_id END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'Site Code' THEN d.site_code END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'City' THEN d.generator_city END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'State' THEN d.generator_state END ASC,
			CASE WHEN ISNULL(@i_sort, '') = 'Country' THEN d.generator_country END ASC
		) + CASE WHEN  ISNULL(@generator_name, '') +
		ISNULL(@epa_id, '') +
		ISNULL(@site_code, '') +
		ISNULL(@state_code, '') +
		ISNULL(@city, '') +
		ISNULL(@generator_size, '') +
		ISNULL(@search, '') +
		ISNULL(@profile_id_list, '')
		= '' and @i_include_various = 1 THEN 1 ELSE 0 END
		, x._reason
FROM    @bar x 
JOIN Generator d (NOLOCK) 
	on x.Generator_id = d.Generator_id 
	AND d.status = CASE @i_include_inactive WHEN 1 THEN d.status ELSE 'A' END
	AND d.status = CASE @i_status_filter WHEN 'B' THEN d.status WHEN 'A' THEN 'A' WHEN 'I' THEN 'I' ELSE '-' END
LEFT JOIN @sitecodes s ON d.site_code LIKE s.site_code
WHERE  
1 = CASE WHEN x.generator_id = 0
	AND ISNULL(@generator_name, '') +
		ISNULL(@epa_id, '') +
		ISNULL(@site_code, '') +
		ISNULL(@state_code, '') +
		ISNULL(@city, '') +
		ISNULL(@generator_size, '') +
		ISNULL(@search, '') +
		ISNULL(@profile_id_list, '')
		<> '' AND @i_include_various = 1 THEN 1 ELSE CASE WHEN x.generator_id > 0 THEN 1 ELSE 0 END END
AND 
(
	@i_generator_name = ''
	OR
	(
		@i_generator_name <> ''
		AND
		d.generator_name LIKE '%' + REPLACE(@i_generator_name, ' ', '%') + '%'
	)
)

AND 
(
	@i_epa_id = ''
	OR
	(
		@i_epa_id <> ''
		AND
		d.epa_id IN (SELECT epa_id FROM @epaids)
	)
)

AND 
(
	@i_site_code = ''
	OR
	(
		@i_site_code <> '' --and @i_site_code not like '%*%'
		AND
		s.idx IS NOT NULL
	)
)
AND 
(
	@i_generator_size = ''
	OR
	(
		@i_generator_size <> ''
		AND
		ISNULL(d.generator_type_id, @NA_Generator_Type) IN (SELECT generator_type_id 
															FROM GeneratorType 
															WHERE generator_type IN (SELECT generator_type 
																						FROM @generatorsizes))
	)
)
AND 
(
	@i_generator_division_list = ''
	OR
	(
		@i_generator_division_list <> ''
		AND
		ISNULL(d.generator_division, '') IN (SELECT generator_division FROM @division WHERE generator_division is not null)
	)
)
AND 
(
	@i_address = ''
	OR
	(
		@i_address <> ''
		AND
		ISNULL(d.generator_address_1 + ' ', '')
			+ ISNULL(d.generator_address_2 + ' ', '')
			+ ISNULL(d.generator_address_3 + ' ', '')
			+ ISNULL(d.generator_address_4 + ' ', '')
			+ ISNULL(d.generator_address_5 + ' ', '')
			+ ISNULL(d.gen_mail_addr1 + ' ', '')
			+ ISNULL(d.gen_mail_addr2 + ' ', '')
			+ ISNULL(d.gen_mail_addr3 + ' ', '')
			+ ISNULL(d.gen_mail_addr4 + ' ', '')
			+ ISNULL(d.gen_mail_addr5 + ' ', '')
			LIKE '%' + @i_address + '%'
	)
)
AND 
(
	@i_city = ''
	OR
	(
		@i_city <> ''
		AND
		d.generator_city LIKE '%' + @i_city + '%'
	)
)
AND
(
	@i_state_code = ''
	OR
	(
		@i_state_code <> ''
		AND
		EXISTS(
			SELECT 1 FROM @statecodes t 
			WHERE ISNULL(nullif(d.generator_country, ''), 'USA') = t.country
			AND ISNULL(d.generator_state, '') = t.state_name
		)
	)
)
AND
(
	@i_search = ''
	OR
	(
		@i_search <> ''
		AND
		ISNULL(CONVERT(VARCHAR(20), d.Generator_id), '') + ' ' +
		ISNULL(d.generator_name, '') + ' ' +
		ISNULL(d.epa_id, '') + ' ' +
		ISNULL(d.site_code, '') + ' ' +
		ISNULL(d.generator_address_1 + ' ', '')
			+ ISNULL(d.generator_address_2 + ' ', '')
			+ ISNULL(d.generator_address_3 + ' ', '')
			+ ISNULL(d.generator_address_4 + ' ', '')
			+ ISNULL(d.generator_address_5 + ' ', '')
			+ ' ' +
		ISNULL(d.generator_city, '') + ' '
		LIKE '%' + @i_search + '%'
	)
)


IF @i_customer_id_list <> '' 
BEGIN

	DECLARE @foo_c table (
	Generator_id int,
	_rowNumber int,
	_reason varchar(100)
	)

	DECLARE @g TABLE (generator_id INT)
	INSERT @g
	SELECT generator_id FROM customergenerator
	WHERE customer_id IN (
		SELECT ROW FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
		WHERE ROW IS NOT NULL
	)
	UNION SELECT 0 WHERE @i_include_various = 1


	INSERT @foo_c (generator_id, _rowNumber, _reason)
	SELECT 
		f.generator_id
		,_rowNumber --row_number() over (order by _rowNumber)
		, _reason
	FROM @foo f
	JOIN @g g ON f.generator_id = g.generator_id

	DELETE FROM @foo
	INSERT @foo (generator_id, _rowNumber, _reason)
	SELECT DISTINCT
	generator_id
	, row_number() over (order by _rowNumber)
	, _reason
	FROM @foo_c
	-- order by _rowNumber
END


--SELECT  *  FROM    @bar ORDER BY generator_id
--SELECT  *  FROM    @foo ORDER BY generator_id

IF @i_site_code like '%*%' 
BEGIN
--if exists (SELECT 1 FROM @sitecodes) begin

	DECLARE @foo_sc table (
	Generator_id int,
	_rowNumber int,
	_reason varchar(100)
	)

	IF @i_site_code NOT LIKE '%*%'
	INSERT @foo_sc (generator_id, _rowNumber, _reason)
	select
		f.generator_id
		,_rowNumber --row_number() over (order by _rowNumber)
		, _reason
	FROM @foo f
	JOIN generator g (nolock) ON f.generator_id = g.generator_id
	JOIN @sitecodes s ON g.site_code = s.site_code 

	IF @i_site_code like '%*%'
	INSERT @foo_sc (generator_id, _rowNumber, _reason)
	SELECT
		f.generator_id
		,_rowNumber --row_number() over (order by _rowNumber)
		, _reason
	FROM @foo f
	JOIN generator g (nolock) ON f.generator_id = g.generator_id
	JOIN @sitecodes s ON g.site_code like s.site_code

	DELETE FROM @foo
	INSERT @foo 
	(generator_id, _rowNumber, _reason)
	SELECT 
	generator_id
	, row_number() over (order by _rowNumber)
	, _reason
	FROM @foo_sc
END

IF ISNULL(@excel_output, 0) = 0 
BEGIN
	-- Non Excel Version...

	DECLARE @s table (generator_id int)
/*
	INSERT @s (generator_id)
	SELECT distinct f.generator_id
	FROM @foo f
	JOIN plt_image..scan s
		on f.generator_id = s.generator_id
		and s.status = 'A'
		and s.view_on_web = 'T'
		and s.document_source = 'generator'
	WHERE 
	@i_perpage IS NULL OR (f._rowNumber between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage))
*/
	SELECT
		g.Generator_id
		, g.generator_name
		, g.epa_id
		, g.site_code
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_address_4
		, g.generator_address_5
		, ISNULL(g.generator_address_1 + ' ', '')
			+ ISNULL(g.generator_address_2 + ' ', '')
			+ ISNULL(g.generator_address_3 + ' ', '')
			+ ISNULL(g.generator_address_4 + ' ', '')
			+ ISNULL(g.generator_address_5 + ' ', '')
			AS generator_address
		, generator_phone
		, g.generator_state
		, g.generator_country
		, g.generator_city
		, g.generator_zip_code
		, g.emergency_phone_number
		, gen_mail_name
		, gen_mail_addr1
		, gen_mail_addr2
		, gen_mail_addr3
		, gen_mail_addr4
		, gen_mail_addr5
		, ISNULL(g.gen_mail_addr1 + ' ', '')
			+ ISNULL(g.gen_mail_addr2 + ' ', '')
			+ ISNULL(g.gen_mail_addr3 + ' ', '')
			+ ISNULL(g.gen_mail_addr4 + ' ', '')
			+ ISNULL(g.gen_mail_addr5 + ' ', '')
			AS gen_mail_addr
		, gen_mail_city
		, gen_mail_state
		, gen_mail_zip_code
		, gen_mail_country
		, ISNULL(g.generator_type_id, @NA_Generator_Type) AS generator_type_ID
		, ISNULL(gt.generator_type, 'N/A') generator_type
		, NAICS_code,
		 (SELECT top 1 CAST(g.NAICS_code AS NVARCHAR(15)) + '-' +[description] 
							FROM  NAICSCode 
							WHERE NAICS_code = g.NAICS_code) AS [description]
		, state_id
		, g.generator_division
		/*
		, CASE WHEN s.generator_id is null THEN '-'
			else
			(SELECT substring(
				(
				SELECT ', ' + ISNULL(document_type + ': ', '') + coalesce(document_name, 'Document')+
				'|'+coalesce(convert(varchar(3),page_number),'1') + '|'+ coalesce(file_type, '') + 
				'|' + convert(Varchar(10), image_id)
				FROM 
				dbo.fn_cor_scan_lookup (@i_web_userid, 'generator', s.generator_id, null, null, 0, '')
				WHERE s.generator_id is not null
				order by coalesce(document_name, 'Document'), page_number, image_id
				for xml path, TYPE).value('.[1]','nvarchar(max)'

				),2,20000)
			) 
			end
			as images
		*/ 
		, '' AS images
		, CASE g.status WHEN 'A' THEN 'Active' WHEN 'I' THEN 'Inactive' ELSE g.status END AS generator_status
		,(SELECT COUNT(*) FROM  @foo)AS totalCount
		, x._reason AS [Internal reason Do Not Display]
		, x._rowNumber
	FROM @foo x
	JOIN Generator g (NOLOCK) ON x.Generator_id = g.Generator_id
	LEFT JOIN generatortype gt (NOLOCK) ON g.generator_type_id = gt.generator_type_id
	LEFT JOIN @s s ON x.generator_id = s.generator_id
	WHERE @i_perpage IS NULL OR (_rowNumber BETWEEN ((@i_page-1) * @i_perpage ) + 1 AND (@i_page * @i_perpage))
	order by x._rowNumber

END
ELSE
	-- Excel Version...

	SELECT
		g.Generator_id
		, g.generator_name
		, g.epa_id
		, g.site_code
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_address_4
		, g.generator_address_5
		, ISNULL(g.generator_address_1 + ' ', '')
			+ ISNULL(g.generator_address_2 + ' ', '')
			+ ISNULL(g.generator_address_3 + ' ', '')
			+ ISNULL(g.generator_address_4 + ' ', '')
			+ ISNULL(g.generator_address_5 + ' ', '')
			AS generator_address
		, generator_phone
		, g.generator_state
		, g.generator_country
		, g.generator_city
		, g.generator_zip_code		
		, gen_mail_addr1
		, gen_mail_addr2
		, gen_mail_addr3
		, gen_mail_addr4
		, gen_mail_addr5
		, ISNULL(g.gen_mail_addr1 + ' ', '')
			+ ISNULL(g.gen_mail_addr2 + ' ', '')
			+ ISNULL(g.gen_mail_addr3 + ' ', '')
			+ ISNULL(g.gen_mail_addr4 + ' ', '')
			+ ISNULL(g.gen_mail_addr5 + ' ', '')
			AS gen_mail_addr
		, gen_mail_city
		, gen_mail_state
		, gen_mail_zip_code
		, gen_mail_country
		, ISNULL(g.generator_type_id, @NA_Generator_Type) AS generator_type_ID
		, ISNULL(gt.generator_type, '') generator_type
		, NAICS_code,
		 (SELECT TOP 1 CAST(g.NAICS_code AS NVARCHAR(15)) + '-' +[description] 
				FROM  NAICSCode 
				WHERE NAICS_code = g.NAICS_code) AS [description]
		, state_id
		, g.emergency_phone_number
		, g.emergency_contract_number
		, g.generator_division
		, g.generator_district
		, g.generator_region_code
		, CASE g.status WHEN 'A' THEN 'Active' WHEN 'I' THEN 'Inactive' ELSE g.status END AS generator_status
		, x._reason AS [Internal reason Do Not Display]
		, x._rowNumber

	FROM @foo x
	JOIN Generator g (NOLOCK) ON x.Generator_id = g.Generator_id and g.status = CASE @i_include_inactive WHEN 1 THEN g.status ELSE 'A' END
	LEFT JOIN generatortype gt (NOLOCK) ON ISNULL(g.generator_type_id,@NA_Generator_Type) = gt.generator_type_id
	WHERE @i_perpage IS NULL OR (_rowNumber BETWEEN ((@i_page-1) * @i_perpage ) + 1 AND (@i_page * @i_perpage))
	order by x._rowNumber


END


GO

GRANT EXECUTE ON [dbo].[sp_COR_GeneratorSearch] TO COR_USER;

GO

