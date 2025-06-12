
CREATE PROCEDURE sp_web_find_profiles 
	@searchterm VARCHAR(max) = NULL
	,@count INT = 15
	,@page	INT = 1
	,@contact_id INT
	,@profile_type varchar(10) = 'approved'
	,@generators varchar(max) = NULL
	,@accounts varchar(max) = NULL
	,@waste_common_name	varchar(50) = NULL -- advanced optional, restrict search to approval_desc or waste_common_name
	,@waste_code_list varchar(100) = NULL -- advanced optional, restrict search to approvalwastecode.waste_code
	,@facility_list	varchar(max) = NULL
	,@receipt_start_date	datetime = NULL
	,@receipt_end_date	datetime = NULL
	,@haz_flag	char(1) = null
	,@debug int = 0
AS
/**************************************************`*******************************
sp_web_find_profiles

-- clear cache for perf testing
DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

Search for profile to be displayed on the web. 

select * from formwcr where locked = 'L' and status = 'A' and profile_id is null

SELECT * FROM profilequoteapproval where approval_code = 'PHL 003'
218304

exec sp_web_find_profiles '218304', @contact_id = 0, @profile_type = 'approved'
exec sp_web_find_profiles 'AUR LP #29', @contact_id = 0, @profile_type = 'approved'
exec sp_web_find_profiles 'WAS PEST #3', @contact_id = 0, @profile_type = 'approved', @debug=1

exec sp_web_find_profiles @contact_id = 0
exec sp_web_find_profiles '1558', @contact_id = 0, @profile_type = 'pending'
exec sp_web_find_profiles '1558', @contact_id = 0, @profile_type = 'draft'
exec sp_web_find_profiles @contact_ID='10913000'
exec sp_web_find_profiles @contact_ID='169075'
exec sp_web_find_profiles @contact_ID='0', @profile_type = 'pending', @count=2000
exec sp_web_find_profiles @contact_ID='0', @profile_type = 'pending', @page=2315
exec sp_web_find_profiles 'junk', @contact_ID='0', @profile_type = 'draft', @count = 5, @page=1
exec sp_web_find_profiles 'soil', @contact_ID='0', @profile_type = 'draft', @count = 5, @page=2
exec sp_web_find_profiles 'soil', @contact_ID='0', @profile_type = 'draft', @count = 10, @page=1
exec sp_web_find_profiles 'soil', @contact_ID='0', @profile_type = 'approved', @count = 5, @page=4
exec sp_web_find_profiles @contact_ID='10913', @profile_type = 'draft'

exec sp_web_find_profiles @waste_common_name = 'fire extinguisher', @contact_id = 0,  @profile_type = 'expired', @facility_list = '22|0', @count=30
exec sp_web_find_profiles '270257', @contact_id = 0, @profile_type = 'approved'
exec sp_web_find_profiles '270257', @contact_id = 0, @profile_type = 'expired'

exec sp_web_find_profiles @debug = 1, @searchterm ='acids', @receipt_start_date = '1/1/2013', @receipt_end_date = '5/1/2013', @contact_id = 0, @profile_type = 'approved', @Facility_list = '25|0'
exec sp_web_find_profiles @debug = 1, @searchterm ='', @contact_id = 0, @profile_type = 'approved', @accounts='888880'
exec sp_web_find_profiles @debug = 1, @searchterm ='acids', @receipt_start_date = '1/1/2013', @receipt_end_date = '5/1/2013', @contact_id = 0, @profile_type = 'approved'
exec sp_web_find_profiles @debug = 1, @searchterm ='soil', @receipt_start_date = '9/5/2012', @receipt_end_date = '9/5/2013', @contact_id = 0, @profile_type = 'approved', @Facility_list = '32|0', @count=10

exec sp_web_find_profiles @debug = 1, @waste_code_list ='5017319H' , @profile_type = 'pending', @contact_id = 0

SELECT * FROM ProfileQuoteApproval where profile_id = 421663

SELECT * FROM Profile where profile_id = 422367
SELECT * FROM ProfileTracking where profile_id = 422367
SELECT * FROM ProfileLookup where code = 'COMP'


	After  a WCR is created & linked to Profile and profile is not approved, should we show Profile 
	or WCR data ? New date field in profile for view/not view  to let user see the WPF related data 
	on the pending Profile from WEB. Pending_profile_available_date	
	JPB, SK		
	Show pending Profile Data if the new date field on Profile says so.
	ò	Added Pending_profile_available_web flag, Pending_profile_available_date to Profile
	- Converted that check to a function for use in EQAI/Web.
	fn_is_pending_profile_available_online

2012/12/12	JPB	Changes:
	Pending Profiles don't require an attached WCR to appear in results anymore.
	Hold Profiles are Pending Profiles
	Pending Profiles only appear if modified since 1/1/2012
	Add @facility_list search option (2|21,3|1 format)
	
2013/01/14	JPB	Changes:
	The #AccessFilter queries build lists of profile_id's that are curr_status_code = 'A'
	Which is rather stupid since they MIGHT Be pending or hold now too.

2013/04/02	JPB	Changes:
	Found out that some queries against FormWCR were not checking against the requirement that
	any found form records be created after 10/1/2012 (or whatever date it was).  Added date check.

08/01/2013 JPB	Modified for TX Waste Codes

2013/08/30	JPB	Profile Search by TSDF and Expired Profile Tab work	
	added @receipt_start_date, @receipt_end_date params.
	removed @profile_status, @expiration_start, @expiration_end parameters
	reworked the layout/logic to speed it up.

2013/10/29	JPB	Added @haz_flag for LDR work which will only want Hazardous (via wastecode) results

2014/05/27	JPB	Added a search method to match entire @searchterms, instead of just parts.

2017/03/01 JPB There's been poor performance - lots of timeouts.  Adding trans isolation specification
	Looks like one instance of a search clause was making things slow, but that made no logical sense.

sp_web_find_profiles
	@searchterm = 'B175195DET'
	, @count =10
	, @contact_id = 163087
	, @page = 1
	, @profile_type = 'approved'

sp_web_find_profiles
	@searchterm = 'B175195DET'
	, @count =10
	, @contact_id = 163087
	, @page = 1
	, @profile_type = 'approved'
	, @debug = 1

   Name: searchterm Value: B175195DET
   Name: count Value: 10
   Name: contact_id Value: 163087
   Name: page Value: 1
   Name: profile_type Value: approved

sp_web_find_profiles
	@searchterm = 'C140045DET'
	, @count =10
	, @contact_id = 186412
	, @page = 1
	, @generators = '18630'
	, @profile_type = 'expired'

sp_web_find_profiles
	@searchterm = 'C140045DET'
	, @count =10
	, @contact_id = 186412
	, @page = 1
	, @generators = '18630'
	, @profile_type = 'expired'


Path: /secured/net/profile/GetProfileList.aspx/GetProfileList
Parameters: 
   Name: searchterm Value: 21074
   Name: count Value: 10
   Name: contact_id Value: 5597
   Name: page Value: 1
   Name: profile_type Value: approved
User: mrusso@tecwaste.com
User IP: 71.186.165.43

	sp_web_find_profiles
	@searchterm = '21074'
	, @count =10
	, @contact_id = 5597
	, @page = 1
	, @profile_type = 'approved'

	sp_web_find_profiles
	@searchterm = '21074'
	, @count =10
	, @contact_id = 5597
	, @page = 1
	, @profile_type = 'approved'

   Name: searchterm Value: b170055wdi
   Name: count Value: 10
   Name: contact_id Value: 0
   Name: page Value: 1
   Name: profile_type Value: approved

	sp_web_find_profiles
	@searchterm = 'b170055wdi'
	, @count =10
	, @contact_id = 0
	, @page = 1
	, @profile_type = 'approved'
	
*********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@count_active int = 0
	, @count_expired int = 0
	, @count_pending int = 0
	, @count_draft int = 0
	, @email varchar(60) = 'XXXXXX'
	, @starttime datetime = getdate()

CREATE TABLE #search_generator_ids (ID INT)
CREATE TABLE #search_customer_ids (ID INT)
CREATE TABLE #receipt_profile_ids (profile_id INT)
CREATE NONCLUSTERED INDEX idx_profile_id ON #receipt_profile_ids([profile_id])
create table #facility (copc varchar(5), company_id int, profit_ctr_id int)
CREATE TABLE #profiles (
	record_type varchar(20) null, 
	profile_id INT null, 
	form_id INT null, 
	revision_id INT null, 
	tmp_status char(1) null,
	date_added datetime null,
	date_modified datetime null  -- Calling it date_modified, but it's actually the sort-order date column per search result type
)
CREATE TABLE #wcrs (
	record_type varchar(20) null, 
	form_id INT null, 
	revision_id INT null, 
	date_added datetime null, 
	date_modified datetime null
)
CREATE TABLE #termMatches (
	record_type varchar(20) null,
	profile_id INT null,
	profile_type char(1) null,
	form_id INT null, 
	revision_id INT null
)
-- 8/8: JPB added this to avoid running queries twice, when we could collect the id's just once,
-- and order them at that same time, instead of doing triple-nested top (@something) from (top @something)
-- "creativity"
CREATE TABLE #profiles_all (
	row_id int not null identity(1,1), 
	record_type varchar(20) null, 
	profile_id INT null, 
	form_id INT null, 
	revision_id INT null, 
	tmp_status char(1) null,
	date_added datetime null,
	date_modified datetime null	-- Calling it date_modified, but it's actually the sort-order date column per search result type
)
CREATE TABLE #wcrs_all (
	row_id int not null identity(1,1), 
	record_type varchar(20), 
	form_id INT, 
	revision_id INT, 
	date_added datetime null, 
	date_modified datetime null
)

--wcr access
	create table #customer (customer_id int)
	create table #generator(generator_id int)
	CREATE TABLE #WasteCodeList(waste_code varchar(10))

-- Define Access Filter 
	create table #access_filter (  
		ID int IDENTITY,    
		profile_id int
	)
	CREATE NONCLUSTERED INDEX idx_profile_id ON #access_filter([profile_id])

-- Debug logging
	create table #debug (row_id int not null identity(1,1), aff_records int, status varchar(max), ms bigint)

if @debug > 0 insert #debug select 0, 'Finished Initialization' as status, datediff(ms, @starttime, getdate()) as ms

-- Parse input lists into tables:	
	IF @accounts IS NOT NULL
		INSERT #search_customer_ids
		SELECT convert(int, row)
		from dbo.fn_SplitXsvText(',', 1, @accounts)
		where row is not null

	IF @generators IS NOT NULL
		INSERT #search_generator_ids
		SELECT convert(int, row)
		from dbo.fn_SplitXsvText(',', 1, @generators)
		where row is not null

	if isnull(@waste_code_list, '') <> ''
		set @waste_code_list = replace(@waste_code_list, ' ', ',')
		INSERT #WasteCodeList
		select row
		from dbo.fn_SplitXsvText(',', 1, @waste_code_list)
		where row is not null

	IF @facility_list IS NOT NULL
		INSERT #facility (copc, company_id, profit_ctr_id)
		SELECT row, company_id, profit_ctr_id
		from dbo.fn_SplitXsvText(',', 1, @facility_list)
		INNER JOIN ProfitCenter (nolock) on row = convert(varchar(5), company_id) + '|' + convert(varchar(5), profit_ctr_id) and status = 'A'
		where row is not null

if @debug > 0 insert #debug select 0, 'Finished Input Tabling' as status, datediff(ms, @starttime, getdate()) as ms

-- Populate #AccessFilter
	IF @contact_id <> 0
	BEGIN

		--set email - enables finding records prev. saved by a user
			SELECT TOP(1) @email = email 
			from contact (nolock) 
			WHERE contact_ID = @contact_id

		-- Populate #Customer id's for this contact
			insert #customer (customer_id)
			select customer_id 
			from ContactXRef cxr (nolock)
			Where cxr.contact_id = @contact_id
			AND cxr.customer_id is not null
			AND cxr.type = 'C' AND cxr.status = 'A' and cxr.web_access = 'A'

		-- Populate #Generator id's for this contact (direct assignments AND customergenerator connections)
			insert #generator (generator_id)
			select generator_id 
			from ContactXRef cxr (nolock)
			Where cxr.contact_id = @contact_id
			AND cxr.generator_id is not null
			AND cxr.type = 'G' AND cxr.status = 'A' and cxr.web_access = 'A' 
			union
			Select cg.generator_id 
			from CustomerGenerator cg (nolock)
			inner join ContactXRef cxr (nolock) on cg.customer_id = cxr.customer_id
			inner join Customer c (nolock) on c.customer_id = cxr.customer_id AND c.generator_flag = 'T'
			Where cxr.contact_id = @contact_id
			AND cxr.customer_id is not null
			AND cxr.type = 'C' AND cxr.status = 'A' AND cxr.web_access = 'A'
		
		-- Load #Access_Filter for profile_ids
			Insert #access_filter
			SELECT DISTINCT p.profile_id
			FROM PROFILE p (NOLOCK)
			INNER JOIN #Customer c on p.customer_id = c.customer_id

			UNION
			
			-- Generators (direct or via CustomerGenerator, they're all in #Generator)
			SELECT DISTINCT p.profile_id
			FROM PROFILE p (NOLOCK)
			INNER JOIN #Generator g on p.generator_id = g.generator_id

			UNION

			-- 4: explicit orig_customers
			SELECT DISTINCT p.profile_id
			FROM PROFILE p (NOLOCK)
			INNER JOIN #Customer c on p.orig_customer_id = c.customer_id
			INNER JOIN Customer ce (nolock) on p.customer_id = ce.customer_id and ce.eq_flag = 'T'
	END
	
if @debug > 0 insert #debug select 0, 'Finished Contact AccessFilter (Associates skipped it)' as status, datediff(ms, @starttime, getdate()) as ms
	
-- If search terms are given, set up to use them:
	IF (isnull(@searchterm, '') <> '') BEGIN
		CREATE TABLE #search_terms (term VARCHAR(255))

		CREATE TABLE #numerics (number INT)

		INSERT #search_terms values (left(@searchterm, 255)) 
		
		--replace spaces for commas
		SELECT @searchterm = REPLACE(@searchterm,' ',',')
		
		INSERT #search_terms SELECT row from dbo.fn_SplitXsvText(',', 1, @searchterm) 
		where row is not null and len(isnull(row,'')) >= 3

		INSERT INTO #numerics (number) SELECT CAST(term AS INT)
		FROM #search_terms WHERE ISNUMERIC(term) = 1 and len(term) <= 8
	END
	
-- If search terms are given, create a sub-set of accessxperm-approved profile_ids limited to term matches
-- per discussion with LT on 9/3/13, "score" doesn't matter, only the requested sort order does.

	IF (isnull(@searchterm, '') <> '') BEGIN
	
		-- search approved profiles on profile_id
			INSERT INTO #termMatches 
				(record_type,	profile_id,		profile_type,	form_id,	revision_id)
			SELECT
				'profile',		p.profile_id,	'A',			null,		null
			FROM dbo.PROFILE p (nolock) 
			WHERE p.curr_status_code = 'A'
			AND	EXISTS  (SELECT 1 FROM #numerics WHERE #numerics.number = p.profile_id union select 1 from #numerics where #numerics.number in (select form_id from formheader (nolock) where profile_id = p.profile_id))
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
			AND (isnull(@facility_list, '') = '' OR exists (select 1 from profilequoteapproval pqa (nolock) inner join #Facility f on pqa.status = 'A' and pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.profile_id = p.profile_id))
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			UNION
		-- search approved profiles on approval code
			SELECT
				'profile',		p.profile_id,	'A',			null,		null
			FROM dbo.PROFILE p (nolock) 
			INNER JOIN dbo.ProfileQuoteApproval pqa (nolock) ON p.profile_id = pqa.profile_id AND pqa.STATUS = 'A'
			WHERE p.curr_status_code = 'A'
			AND	EXISTS (SELECT 1 FROM #search_terms WHERE #search_terms.term = pqa.approval_code)
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
			AND (isnull(@facility_list, '') = '' OR exists (select 1 from profilequoteapproval pqa (nolock) inner join #Facility f on pqa.status = 'A' and pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.profile_id = p.profile_id))
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			UNION
		-- search approved profiles on approval (waste) description
			SELECT 
				'profile',		p.profile_id,	'A',			null,		null
			FROM dbo.PROFILE p (nolock) 
			WHERE p.curr_status_code = 'A'
			AND EXISTS (SELECT 1 FROM #search_terms WHERE p.approval_desc LIKE '%' + #search_terms.term + '%')
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
			AND (isnull(@facility_list, '') = '' OR exists (select 1 from profilequoteapproval pqa (nolock) inner join #Facility f on pqa.status = 'A' and pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.profile_id = p.profile_id))
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			UNION
		-- search approved profiles on waste codes
			SELECT 
				'profile',		p.profile_id,	'A',			null,		null
			FROM dbo.PROFILE p (nolock) 
			WHERE p.curr_status_code = 'A'
			AND	EXISTS (SELECT 1 FROM #search_terms st inner join wastecode wc (nolock) on st.term = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id)
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@facility_list, '') = '' OR exists (select 1 from profilequoteapproval pqa (nolock) inner join #Facility f on pqa.status = 'A' and pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.profile_id = p.profile_id))
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			
if @debug > 0 insert #debug select @@rowcount, 'Finished SearchTerm Against Approved/Expired Profiles' as status, datediff(ms, @starttime, getdate()) as ms

		-- search pending profiles on profile_id
			INSERT INTO #termMatches 
				(record_type,	profile_id,		profile_type,	form_id,	revision_id)
			SELECT
				'profile',		p.profile_id,	'P',			null,		null
			FROM dbo.PROFILE p (nolock) 
			WHERE p.curr_status_code IN ('H', 'P')
			AND	EXISTS  (SELECT 1 FROM #numerics WHERE #numerics.number = p.profile_id union select 1 from #numerics where #numerics.number in (select form_id from formheader (nolock) where profile_id = p.profile_id))
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			-- 2017-03-01 - speed problems seem to center on the following line, which makes no sense.
			-- AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
			AND (isnull(@facility_list, '') = '')
			AND p.ap_expiration_date > GETDATE() -- Not expired already
			AND (
				isnull(pending_profile_available_date, getdate()-1) <= getdate()
				OR
				dbo.fn_is_pending_profile_available_online(p.profile_id) = 'T'
			)
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			UNION
		-- search pending profiles (signed WCRs) on form_id
			SELECT
				'form',			null,			'P',			form_id,		revision_id
			FROM dbo.FormWCR wcr (nolock)
			WHERE form_id > 0
			AND	EXISTS (SELECT 1 FROM #numerics WHERE #numerics.number = wcr.form_id)
			and status = 'A'
			AND locked = 'L' 
			AND isnull(wcr.profile_id, 0) = 0
			and wcr.date_created > '10/1/2012'
			AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id) OR (wcr.customer_id IS NULL AND (wcr.created_by = @email OR wcr.modified_by = @email)))
			AND (@generators IS NULL OR EXISTS (SELECT 1 FROM #search_generator_ids WHERE #search_generator_ids.ID = wcr.generator_id))
			AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
			AND (isnull(@waste_common_name, '') = '' OR wcr.waste_common_name like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR exists (select 1 from FormXWasteCode pwc (nolock) inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid inner join #WasteCodeList wcl on wc.display_name = wcl.waste_code where pwc.form_id = wcr.form_id and revision_id = wcr.revision_id))
			AND (isnull(@facility_list, '') = '')
			AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 
			UNION
		-- search pending profiles on approval (waste) descriptions
			SELECT
				'profile',		p.profile_id,	'P',			null,		null
			FROM dbo.PROFILE p (nolock) 
			WHERE p.curr_status_code IN ('H', 'P')
			AND EXISTS (SELECT 1 FROM #search_terms WHERE p.approval_desc LIKE '%' + #search_terms.term + '%')
			AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
			AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
			AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
			AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
			AND (isnull(@facility_list, '') = '')
			AND p.ap_expiration_date > GETDATE() -- Not expired already
			AND (
				isnull(pending_profile_available_date, getdate()-1) <= getdate()
				OR
				dbo.fn_is_pending_profile_available_online(p.profile_id) = 'T'
			)
			AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
			UNION
		-- search pending profiles (signed WCRs) on waste descriptions
			SELECT
				'form',			null,			'P',			form_id,		revision_id
			FROM dbo.FormWCR wcr (nolock)
			WHERE form_id > 0
			AND EXISTS (SELECT 1 FROM #search_terms WHERE wcr.waste_common_name LIKE '%' + #search_terms.term + '%')
			and status = 'A'
			AND locked = 'L' 
			AND isnull(wcr.profile_id, 0) = 0
			and wcr.date_created > '10/1/2012'
			AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id) OR (wcr.customer_id IS NULL AND (wcr.created_by = @email OR wcr.modified_by = @email)))
			AND (@generators IS NULL OR EXISTS (SELECT 1 FROM #search_generator_ids WHERE #search_generator_ids.ID = wcr.generator_id))
			AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
			AND (isnull(@waste_common_name, '') = '' OR wcr.waste_common_name like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR exists (select 1 from FormXWasteCode pwc (nolock) inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid inner join #WasteCodeList wcl on wc.display_name = wcl.waste_code where pwc.form_id = wcr.form_id and revision_id = wcr.revision_id))
			AND (isnull(@facility_list, '') = '')
			AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 

			if isnull(@waste_common_name, '') <> ''
				delete from #termMatches
				from #termMatches m
				inner join dbo.PROFILE p (nolock) on m.profile_id = p.profile_id
				WHERE p.curr_status_code IN ('H', 'P')
				AND m.profile_type = 'P'
				and m.profile_id is not null
				AND p.ap_expiration_date > GETDATE() -- Not expired already
				AND (
					isnull(pending_profile_available_date, getdate()-1) <= getdate()
					OR
					dbo.fn_is_pending_profile_available_online(p.profile_id) = 'T'
				)
				AND p.approval_desc NOT like '%' + replace(@waste_common_name, ' ', '%') + '%'
			
if @debug > 0 insert #debug select @@rowcount, 'Finished SearchTerm Against Pending Profiles' as status, datediff(ms, @starttime, getdate()) as ms

		-- search draft profiles (unsigned WCRs) on form_id
			INSERT INTO #termMatches 
				(record_type,	profile_id,		profile_type,	form_id,	revision_id)
			SELECT
				'form',			null,			'D',			form_id,		revision_id
			FROM dbo.FormWCR wcr (nolock)
			WHERE FORM_ID > 0
			AND	EXISTS (SELECT 1 FROM #numerics WHERE #numerics.number = wcr.form_id)
			and status = 'A'
			AND locked = 'U' 
			AND isnull(wcr.profile_id, 0) = 0
			and wcr.date_created > '10/1/2012'
			AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id) OR (wcr.customer_id IS NULL AND (wcr.created_by = @email OR wcr.modified_by = @email)))
			AND (@generators IS NULL OR EXISTS (SELECT 1 FROM #search_generator_ids WHERE #search_generator_ids.ID = wcr.generator_id))
			AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
			AND (isnull(@facility_list, '') = '')
			AND (isnull(@waste_common_name, '') = '' OR wcr.waste_common_name like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR exists (select 1 from FormXWasteCode pwc (nolock) inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid inner join #WasteCodeList wcl on wc.display_name = wcl.waste_code where pwc.form_id = wcr.form_id and pwc.revision_id = wcr.revision_id))
			AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 
			UNION
		-- search draft profiles (unsigned WCRs) on tracking_id
			SELECT
				'form',			null,			'D',			form_id,		revision_id
			FROM dbo.FormWCR wcr (nolock)
			WHERE FORM_ID > 0
			AND	EXISTS ( SELECT  1 FROM #numerics WHERE #numerics.number = wcr.tracking_id )
			and status = 'A'
			AND locked = 'U' 
			AND isnull(wcr.profile_id, 0) = 0
			and wcr.date_created > '10/1/2012'
			AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id) OR (wcr.customer_id IS NULL AND (wcr.created_by = @email OR wcr.modified_by = @email)))
			AND (@generators IS NULL OR EXISTS (SELECT 1 FROM #search_generator_ids WHERE #search_generator_ids.ID = wcr.generator_id))
			AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
			AND (isnull(@facility_list, '') = '')
			AND (isnull(@waste_common_name, '') = '' OR wcr.waste_common_name like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR exists (select 1 from FormXWasteCode pwc (nolock) inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid inner join #WasteCodeList wcl on wc.display_name = wcl.waste_code where pwc.form_id = wcr.form_id and revision_id = wcr.revision_id))
			AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 
			UNION
		-- search draft profiles (unsigned WCRs) on waste common name
			SELECT
				'form',			null,			'D',			form_id,		revision_id
			FROM dbo.FormWCR wcr (nolock)
			WHERE FORM_ID > 0
			AND EXISTS ( SELECT 1 FROM #search_terms WHERE wcr.waste_common_name LIKE '%' + #search_terms.term + '%' )
			and status = 'A'
			AND locked = 'U' 
			AND isnull(wcr.profile_id, 0) = 0
			and wcr.date_created > '10/1/2012'
			AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id) OR (wcr.customer_id IS NULL AND (wcr.created_by = @email OR wcr.modified_by = @email)))
			AND (@generators IS NULL OR EXISTS (SELECT 1 FROM #search_generator_ids WHERE #search_generator_ids.ID = wcr.generator_id))
			AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
			AND (isnull(@facility_list, '') = '')
			AND (isnull(@waste_common_name, '') = '' OR wcr.waste_common_name like '%' + replace(@waste_common_name, ' ', '%') + '%')
			AND (isnull(@waste_code_list, '') = '' OR exists (select 1 from FormXWasteCode pwc (nolock) inner join WasteCode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid inner join #WasteCodeList wcl on wc.display_name = wcl.waste_code where pwc.form_id = wcr.form_id and revision_id = wcr.revision_id))
			AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 

if @debug > 0 insert #debug select @@rowcount, 'Finished SearchTerm Against Draft Profiles' as status, datediff(ms, @starttime, getdate()) as ms

	END
if @debug > 0 insert #debug select @@rowcount, 'Finished SearchTerm Filtering' as status, datediff(ms, @starttime, getdate()) as ms

-- Retrieve Data for Tab: Approved Profiles
	insert #Profiles_All (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	SELECT * FROM (
		select 'profile' as record_type, p.profile_id, null as form_id, null as revision_id, 'A' as tmp_status, p.date_added
		, case when p.ap_expiration_date > getdate() then 
			(select max(date_added) from ProfileTracking where profile_id = p.profile_id and tracking_status = 'COMP')
		  else
			p.ap_expiration_date
		  end as date_modified
		FROM dbo.PROFILE p (nolock)
		WHERE p.curr_status_code = 'A'
		AND p.ap_expiration_date > getdate()
		AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
		AND (isnull(@searchterm, '') = ''
			OR
			EXISTS (select 1 from #termMatches m where m.record_type = 'profile' and m.profile_id = p.profile_id and m.profile_type = 'A')
		)
		AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
		AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
		AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
		AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
		AND (isnull(@facility_list, '') = '' OR exists (select 1 from #Facility f inner join ProfileQuoteApproval pqa (nolock) on pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.status = 'A' and pqa.profile_id = p.profile_id))
		AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
		
	) a	
	ORDER BY date_modified desc
	
if @debug > 0 insert #debug select @@rowcount, 'Finished Approved Profiles Tab Query' as status, datediff(ms, @starttime, getdate()) as ms

-- delay handling the paging until after the expired profiles query's receipt date filtering, so we only do that expensive work once.

-- Retrieve Data for Tab: Expired Profiles
	insert #Profiles_All (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	SELECT * FROM (
		select 'profile' as record_type, p.profile_id, null as form_id, null as revision_id, 'E' as tmp_status, p.date_added, p.ap_expiration_date as date_modified
		FROM dbo.PROFILE p (nolock)
		WHERE p.curr_status_code = 'A'
		AND p.ap_expiration_date < getdate()
		AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
		AND ((@receipt_start_date IS NULL OR @receipt_end_date IS NULL) OR p.profile_id in (select profile_id from #receipt_profile_ids))
		AND p.ap_expiration_date > GETDATE() - (365 * 2) -- Oldest data to show is from 2 years ago.
		AND (isnull(@searchterm, '') = ''
			OR
			-- Yes, even the Expired search type uses the 'A' profile_type flag in #termMatches. It's ok.
			EXISTS (select 1 from #termMatches m where m.record_type = 'profile' and m.profile_id = p.profile_id and m.profile_type = 'A')
		)
		AND (@generators IS NULL OR (p.generator_id in (SELECT id FROM #search_generator_ids)))
		AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
		AND (isnull(@waste_common_name, '') = '' OR p.approval_desc like '%' + replace(@waste_common_name, ' ', '%') + '%')
		AND (isnull(@waste_code_list, '') = '' OR EXISTS (SELECT 1 FROM #WasteCodeList wcl inner join wastecode wc (nolock) on wcl.waste_code = wc.display_name inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id))
		AND (isnull(@facility_list, '') = '' OR exists (select 1 from #Facility f inner join ProfileQuoteApproval pqa (nolock) on pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id where pqa.status = 'A' and pqa.profile_id = p.profile_id))
		AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
	) a	
	ORDER BY date_modified desc

if @debug > 0 insert #debug select @@rowcount, 'Finished Expired Profiles Tab Query' as status, datediff(ms, @starttime, getdate()) as ms

-- If receipt start&end date are given, create the profile_list possible
	IF (isnull(@receipt_start_date,'') <> '' AND isnull(@receipt_end_date, '') <> '') BEGIN
		select *
		into #ProfileReceiptFilter
		from #Profiles_All a where exists (
			select top 1 1
			from receipt r (nolock)
			where r.profile_id = a.profile_id
			and r.receipt_date between @receipt_start_date and @receipt_end_date
			and r.receipt_status in ('U', 'A') 
			and r.waste_accepted_flag = 'T' 
			and r.trans_mode = 'I'
		)
		truncate table #Profiles_All
		insert #Profiles_All select
			record_type,
			profile_id, 
			form_id,
			revision_id,
			tmp_status,
			date_added,
			date_modified
			from #ProfileReceiptFilter
			order by row_id
	END						

if @debug > 0 insert #debug select @@rowcount, 'Finished Approved/Expired Profiles Tab Receipt Date Filter' as status, datediff(ms, @starttime, getdate()) as ms
				
-- Now that we've filtered against reciepts, we can do the per-page grabbing for Approved, then Expired profiles.
	Insert #profiles (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	SELECT record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified FROM (
	SELECT TOP (@count) * FROM (
		SELECT DISTINCT TOP (@count*@page) 'profile' record_type, pa.profile_id, pa.form_id, pa.revision_id, pa.tmp_status, pa.row_id, pa.date_added, pa.date_modified
		FROM #Profiles_All pa
		WHERE pa.tmp_status = 'A'
		ORDER BY row_id ASC
		) AS t ORDER BY row_id DESC
	) AS t2 ORDER BY date_modified DESC

if @debug > 0 insert #debug select @@rowcount, 'Finished Approved Profiles Tab Page Limiting' as status, datediff(ms, @starttime, getdate()) as ms

	Insert #profiles (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	SELECT record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified FROM (
	SELECT TOP (@count) * FROM (
		SELECT DISTINCT TOP (@count*@page) 'profile' record_type, pa.profile_id, pa.form_id, pa.revision_id, pa.tmp_status, pa.row_id, pa.date_added, pa.date_modified
		FROM #Profiles_All pa
		WHERE pa.tmp_status = 'E'
		ORDER BY row_id ASC
		) AS t ORDER BY row_id DESC
	) AS t2 ORDER BY date_modified DESC

if @debug > 0 insert #debug select @@rowcount, 'Finished Expired Profiles Tab Page Limiting' as status, datediff(ms, @starttime, getdate()) as ms

-- Retrieve Data for Tab: Pending Profiles
	insert #Profiles_All (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	select record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified
	FROM (
		select 'profile' record_type, p.profile_id, null as form_id, null as revision_id, 'P' as tmp_status, p.date_added
			, isnull((select max(date_added) from ProfileTracking where profile_id = p.profile_id), p.date_modified) as date_modified
		FROM dbo.PROFILE p (nolock)
		WHERE p.curr_status_code IN ('H', 'P')
		AND p.date_modified > '1/1/2012' -- Modified since 2012
		AND ((@contact_id = 0) OR (p.profile_id in (select profile_id FROM #access_filter af)))
		AND (isnull(@searchterm, '') = ''
			OR
			EXISTS (select 1 from #termMatches m where m.record_type = 'profile' and m.profile_id = p.profile_id and m.profile_type = 'P')
		)
		AND 1 = (CASE WHEN @receipt_start_date IS NULL OR @receipt_end_date IS NULL THEN 1 ELSE 0 END)
		AND (isnull(@facility_list, '') = '')
		AND p.ap_expiration_date > GETDATE() -- Not expired already
		AND (
			isnull(pending_profile_available_date, getdate()-1) <= getdate()
			OR
			dbo.fn_is_pending_profile_available_online(p.profile_id) = 'T'
		)
		AND (@accounts IS NULL OR (p.customer_id in (SELECT id FROM #search_customer_ids)))
		AND (isnull(@haz_flag, 'F') <> 'T' OR (@haz_flag = 'T' AND EXISTS (SELECT 1 FROM wastecode wc (nolock) inner join profilewastecode pwc (nolock) on wc.waste_code_uid = pwc.waste_code_uid WHERE pwc.profile_id = p.profile_id and wc.haz_flag = 'T' and wc.waste_code_origin = 'F')))
		UNION ALL
		SELECT 'form', null, form_id ,revision_id, 'P' as tmp_status, date_created as date_added, isnull(signing_date, date_modified) as date_modified
		FROM dbo.FormWCR wcr (nolock)
		WHERE form_id > 0
		and status = 'A'
		AND locked = 'L' 
		AND isnull(wcr.profile_id, 0) = 0
		and wcr.date_created > '10/1/2012'
		AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id)
			OR (wcr.customer_id IS NULL AND wcr.created_by = @email OR wcr.modified_by = @email)
		)
		AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 
		AND (isnull(@searchterm, '') = ''
			OR
			EXISTS (select 1 from #termMatches m where m.record_type = 'form' and m.form_id = wcr.form_id and m.revision_id = wcr.revision_id and m.profile_type = 'P')
		)
		AND 1 = (CASE WHEN @receipt_start_date IS NULL OR @receipt_end_date IS NULL THEN 1 ELSE 0 END)
		AND (isnull(@facility_list, '') = '')
		AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
	) a
	ORDER BY date_modified desc

if @debug > 0 insert #debug select @@rowcount, 'Finished Pending Profiles Tab Query' as status, datediff(ms, @starttime, getdate()) as ms
		
	-- The above query got them all.  Now we just want the ones for this page set:
	Insert #profiles (record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified)
	SELECT record_type, profile_id, form_id, revision_id, tmp_status, date_added, date_modified FROM (
	SELECT TOP (@count) * FROM (
		SELECT DISTINCT TOP (@count*@page) pa.record_type, pa.profile_id, pa.form_id, pa.revision_id, pa.tmp_status, pa.date_added, pa.date_modified, row_id
		FROM #Profiles_All pa
		WHERE pa.tmp_status = 'P'
		ORDER BY row_id ASC
		) AS t ORDER BY row_id DESC
	) AS t2 ORDER BY date_modified DESC

if @debug > 0 insert #debug select @@rowcount, 'Finished Pending Profiles Tab Page Limiting' as status, datediff(ms, @starttime, getdate()) as ms
	
-- Retrieve Data for Tab: Draft Profiles (Not yet submitted/signed)
	insert #Wcrs_All (record_type, form_id,revision_id, date_added, date_modified)
	SELECT 'form', form_id ,revision_id, date_created, isnull(signing_date, date_modified) as date_modified
	FROM dbo.FormWCR wcr (nolock)
	WHERE form_id > 0
	AND date_created > '10/1/2012'
	AND locked = 'U'
	and status = 'A' 
	AND isnull(wcr.profile_id, 0) = 0
	AND NOT EXISTS (SELECT 1 FROM FormWCR wcr2 (nolock) where wcr2.form_id = wcr.form_id AND wcr2.revision_id > wcr.revision_id and wcr2.status = 'A') 
	AND (@contact_id = 0 OR EXISTS (SELECT 1 FROM #customer WHERE #customer.customer_id = wcr.customer_id)
		OR (wcr.customer_id IS NULL AND wcr.created_by = @email OR wcr.modified_by = @email)
	)
	AND (isnull(@searchterm, '') = ''
		OR
		EXISTS (select 1 from #termMatches m where m.record_type = 'form' and m.form_id = wcr.form_id and m.revision_id = wcr.revision_id and m.profile_type = 'D')
	)
	AND 1 = (CASE WHEN @receipt_start_date IS NULL OR @receipt_end_date IS NULL THEN 1 ELSE 0 END)
	AND (isnull(@facility_list, '') = '')
	AND (@accounts IS NULL OR EXISTS (SELECT 1 FROM #search_customer_ids WHERE #search_customer_ids.ID = wcr.customer_id))
	order by isnull(signing_date, date_modified) DESC

if @debug > 0 insert #debug select @@rowcount, 'Finished Draft Profiles Tab Query' as status, datediff(ms, @starttime, getdate()) as ms

	-- The above query got them all.  Now we just want the ones for this page set:
	insert #Wcrs (record_type, form_id, revision_id, date_added, date_modified)
	SELECT 'form', form_id, revision_id, date_added, date_modified FROM (
	SELECT TOP (@count) * FROM (
		SELECT DISTINCT TOP (@count*@page) wa.form_id, wa.revision_id, date_added, date_modified, wa.row_id
		FROM #Wcrs_All wa
		ORDER BY row_id ASC
		) AS t ORDER BY row_id DESC
	) AS t2 ORDER BY date_modified DESC

if @debug > 0 insert #debug select @@rowcount, 'Finished Draft Profiles Tab Page Limiting' as status, datediff(ms, @starttime, getdate()) as ms

-- Assign counts:
	SELECT @count_active = COUNT(*) FROM #Profiles_All where tmp_status = 'A'
	SELECT @count_expired = COUNT(*) FROM #Profiles_All where tmp_status = 'E'
	SELECT @count_pending = COUNT(*) FROM #Profiles_All where tmp_status = 'P'
	SELECT @count_draft = COUNT(*) FROM #Wcrs_All

if @debug > 0 insert #debug select 0, 'Finished Assigning Counts' as status, datediff(ms, @starttime, getdate()) as ms

--SELECT STATEMENTS--

	--get count
	SELECT 
		@count_active AS [count_active], 
		@count_expired as [count_expired],
		@count_draft as [count_wcr], 
		@count_pending as [count_pending], 
		(@count_draft + @count_active + @count_expired + @count_pending) AS [count]

if @debug > 0 insert #debug select @@rowcount, 'Finished Count Output' as status, datediff(ms, @starttime, getdate()) as ms

DECLARE @form_facility_ver int = (SELECT MAX(version) FROM FormFacility (nolock))

IF (@profile_type IN ('approved', 'expired', 'pending'))
BEGIN
	SELECT DISTINCT 
		pf.record_type
		,pf.profile_id
		, CASE pf.record_type
			WHEN 'profile' then dbo.fn_profile_wcr_form_id_list (pf.profile_id)
			WHEN 'form' then convert(varchar(20),pf.form_id)
		  END as form_id
		, CASE pf.record_type
			WHEN 'profile' then null /* No revision id's to bother with when returning the form id list */
			WHEN 'form' then pf.revision_id
		  END as revision_id
		,p.approval_desc
		,p.generator_id
		,g.generator_name
		,g.generator_state
		,p.customer_id
		,cust.cust_name
		,CONVERT(CHAR(10), ap_expiration_date, 126) AS [ap_expiration_date]
		--if this is a customer and they can have web access, then they have access to pricing info
		,(CASE WHEN tmp_status = 'E' THEN 'N' ELSE 
			CASE WHEN @contact_id > 0
			THEN 
				(CASE
					WHEN EXISTS (SELECT TOP 1 1 FROM ContactXRef cxr (nolock) where cxr.customer_id = p.customer_id AND cxr.contact_id = @contact_id AND cxr.web_access = 'A')
					THEN 'P' 
					ELSE 'N'
				END)
			ELSE 'P'
			END
			END) [pricing]
		,(CASE
			WHEN
				EXISTS (
					SELECT *
					FROM ProfileQuoteApproval (nolock)
					INNER JOIN formfacility (nolock) ON ProfileQuoteApproval.company_id = formfacility.company_ID
						AND ProfileQuoteApproval.profit_ctr_id = formfacility.profit_ctr_ID
					WHERE norm_applicable_flag = 'T'
						AND version = @form_facility_ver
						AND ProfileQuoteApproval.profile_id = p.profile_id
						AND ProfileQuoteApproval.status = 'A'
					)
			THEN 'T' ELSE 'F'
			END) [ntn_available]
		,(CASE
			WHEN
				EXISTS (
					SELECT *
					FROM ProfileQuoteApproval (nolock)
					INNER JOIN ProfitCenter (nolock) on ProfileQuoteApproval.company_id = ProfitCenter.company_ID
						AND ProfileQuoteApproval.profit_ctr_id = ProfitCenter.profit_ctr_ID
						AND ProfitCenter.EPA_ID like 'MI%'
					WHERE ProfileQuoteApproval.profile_id = p.profile_id
						AND ProfileQuoteApproval.status = 'A'
					)
			THEN 'T' ELSE 'F'
			END) [srec_available]
		,CASE pf.tmp_status
			WHEN 'A' then 'Approved'
			WHEN 'E' then 'Approved'
			/* WHEN 'P' then */
			ELSE isnull(pl.web_description, 'Customer Service Review')
			END as tracking_status
		, pf.date_added
		, pf.date_modified
	FROM PROFILE p (NOLOCK)
	INNER JOIN #profiles pf ON pf.profile_id = p.profile_id and pf.record_type = 'profile'
	LEFT JOIN dbo.Generator g (nolock) ON p.generator_id = g.generator_id
	LEFT JOIN dbo.Customer cust (nolock) ON cust.customer_ID = p.customer_id
	LEFT OUTER JOIN ProfileTracking pt (nolock) on p.profile_id = pt.profile_id and p.profile_tracking_id = pt.tracking_id
	left outer join ProfileLookup pl (nolock) on pt.tracking_status = pl.code and pl.type = 'TrackingStatus'
	WHERE pf.tmp_status = left(@profile_type, 1)
	UNION
	SELECT DISTINCT 
		pf.record_type
		,pf.profile_id
		, CASE pf.record_type
			WHEN 'profile' then dbo.fn_profile_wcr_form_id_list (pf.profile_id)
			WHEN 'form' then convert(varchar(20),pf.form_id)
		  END as form_id
		, CASE pf.record_type
			WHEN 'profile' then null /* No revision id's to bother with when returning the form id list */
			WHEN 'form' then pf.revision_id
		  END as revision_id
		,wcr.waste_common_name
		,g.generator_id
		,g.generator_name
		,g.generator_state
		,c.customer_id
		,c.cust_name
		,null AS [ap_expiration_date]
		--if this is a customer and they can have web access, then they have access to pricing info
		,'N' [pricing]
		,'F' [ntn_available]
		,'F' [srec_available]
		,'Customer Service Review' as tracking_status
		, pf.date_added
		, pf.date_modified
	FROM dbo.FormWCR wcr (nolock) 
	INNER JOIN #profiles pf ON pf.form_id = wcr.form_id and pf.revision_id = wcr.revision_id and pf.record_type = 'form'
	LEFT JOIN dbo.Generator g (nolock) ON wcr.generator_id = g.generator_id
	LEFT JOIN dbo.Customer c (nolock) ON wcr.customer_id = c.customer_id
	WHERE pf.tmp_status = left(@profile_type, 1) and wcr.status = 'A'
	ORDER BY pf.date_modified desc

if @debug > 0 insert #debug select @@rowcount, 'Finished Approved/Expired/Pending Output' as status, datediff(ms, @starttime, getdate()) as ms
	
	SELECT DISTINCT
		p.profile_id,
		pqa.approval_code
		,pqa.company_id
		,pqa.profit_ctr_id
		,pc.short_name AS [profit_ctr_name]
		,CAST(pqa.company_id AS VARCHAR) + '|' + CAST(pqa.profit_ctr_id AS VARCHAR) AS [copc]
		, pf.date_added
		, pf.date_modified
	FROM dbo.PROFILE p (NOLOCK)
	INNER JOIN #profiles pf ON pf.profile_id = p.profile_id
	INNER JOIN dbo.ProfileQuoteApproval pqa (nolock) ON p.profile_id = pqa.profile_id
		AND pqa.STATUS = 'A'
		AND (isnull(@facility_list, '') = '' OR exists (select 1 from #Facility f where pqa.status = 'A' and pqa.company_id = f.company_id and pqa.profit_ctr_id = f.profit_ctr_id))
	INNER JOIN dbo.ProfitCenter pc (nolock) ON pqa.company_id = pc.company_ID
		AND pqa.profit_ctr_id = pc.profit_ctr_ID
	AND pf.tmp_status = left(@profile_type, 1)
	ORDER BY pf.date_modified desc

if @debug > 0 insert #debug select @@rowcount, 'Finished Approved/Expired/Pending Approval Code Output' as status, datediff(ms, @starttime, getdate()) as ms

END

IF(@profile_type = 'draft') BEGIN
	--wcrs
	SELECT
		#wcrs.record_type,
		wcr.form_id
		,wcr.revision_id 
		,g.generator_name
		,g.generator_state
		,g.generator_city
		,c.cust_name
		,c.cust_city
		,c.cust_state
		,waste_common_name
		,wcr.modified_by
		,wcr.tracking_id
		,CONVERT(CHAR(10), wcr.date_modified, 126) AS [date_modified]
		,wcr.customer_id
		, #wcrs.date_added
		, #wcrs.date_modified
	FROM dbo.FormWCR wcr (nolock) 
	inner join #wcrs ON #wcrs.form_id = wcr.form_id AND #wcrs.revision_id = wcr.revision_id
	LEFT JOIN dbo.Generator g (nolock) ON wcr.generator_id = g.generator_id
	LEFT JOIN dbo.Customer c (nolock) ON wcr.customer_id = c.customer_id
	where wcr.status = 'A'
	order by  #wcrs.date_modified desc 
	
if @debug > 0 insert #debug select @@rowcount, 'Finished Draft Output' as status, datediff(ms, @starttime, getdate()) as ms
	
END		

if @debug > 0 select row_id, ms, aff_records, status from #debug order by row_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_find_profiles] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_find_profiles] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_find_profiles] TO [EQAI]
    AS [dbo];

