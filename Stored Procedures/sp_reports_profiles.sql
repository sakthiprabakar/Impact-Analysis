CREATE PROCEDURE sp_reports_profiles 
 @debug    int,    -- 0 or 1 for no debug/debug mode  
 @customer_id_list text, -- Comma Separated Customer ID List - what customers to include  
 @generator_id_list text, -- Comma Separated Generator ID List - what generators to include  
 @start_date   varchar(30), -- Approval Expiration Range Start Date  
 @end_date   varchar(30), -- Approval Expiration Range End Date  
 @approval_code_list text, -- Approval Code 
 @description	varchar(100), -- Description 
 @contact_id   varchar(100), -- Contact_id  
 @include_brokered char(1) = 'Y', -- This is always 'Y' in the EQ Web application.  'Y' or 'N' for including waste where customer_id is not one of mine  
 @report_type  char(1),  -- 'L'ist or 'D'etail (Detail returns a 2nd recordset with detail info)  
 @session_key  varchar(100) = '', -- unique identifier key to a previously run query's results  
 @row_from   int = 1,   -- when accessing a previously run query's results, what row should the return set start at?  
 @row_to    int = 20,   -- when accessing a previously run query's results, what row should the return set end at (-1 = all)?  
 @profile_id   int = NULL, -- the profile ot see details on.  only used when report_type = 'D'  
 @company_id  int = NULL, -- only used when report_type = 'D'  
 @profit_ctr_id int = NULL, -- only used when report_type = 'D'  
 @return_all_prices char(1) = 'F' -- Optional flag, when 'T' returns full price info for all facilities in the price recordset
AS  
/****************************************************************************************************  
Returns the data for Profiles.  

sp_reports_profiles 0,'','','','','','','-1','Y','D','',NULL,NULL,'72847','2','0' 
sp_reports_profiles 0,'','','','','','','-1','Y','D','',NULL,NULL,'197081','21','0' 

SELECT * FROM profile where curr_status_code = 'P' and exists (SELECT 1 FROM ProfileQuoteApproval where profile_id= profile.profile_id)
SELECT * FROM ProfileQuoteApproval where profile_id = 241151

sp_reports_profiles 
 @debug    = 0,
 @customer_id_list = '',
 @generator_id_list = '', 
 @start_date   = '', 
 @end_date   = '', 
 @approval_code_list = '', 
 @description	= '', 
 @contact_id   = '10913', 
 @include_brokered = 'Y',
 @report_type  = 'D', 
 @session_key  = '',
 @row_from   = 1,
 @row_to    = 20,
 @profile_id    = '25756', -- 343472: ACIDS.   327176 = WMHW01  
 @company_id   = '2', 
 @profit_ctr_id  = '0',
 @return_all_prices = 'T' -- new test
  
SELECT  * FROM    ProfileQuoteDetail where profile_id is not null and hours_free_unloading is not null
  
LOAD TO PLT_AI*  

  
06/23/2006 JPB Created  
07/18/2006 JPB Commented out Query Governor Cost Limit statements because it was blocking simple queries.  
 - like all companies, all approvals for 888888.  There's < 20, and the query takes 5 seconds, yet it was  
 being blocked.  
11/08/2006 JPB Modified to look at EQAIDatabase for the PLT_Image Server  
05/31/2007 JPB Modified from varchar(8000) inputs to Text inputs  
09/21/2007 JDB Modified to use a "UNION" in the subselect for profile_id, instead of "OR".  
10/03/2007 JPB  Modified to remove NTSQL* references  
10/10/2007 JPB  Modified to combine speedup & prod/test/dev work.  
11/14/2007 JPB  Added a select of all customers if none were selected   
11/27/2007 JPB  Added "no criteria" handling (returns error_message field, ends processing)  
    NOTES ON error_message FORMAT:  
     Text returned in the error_message field is shown in a bulleted list online  
     under the heading Select Criteria Error:  
     To return multiple errors, separate each with ||  
     eg: 'Start Date must be a valid date||End Date must be a valid date||You really messed up'  
    Added CustomerGenerator and orig_customer_id handling in #generatorloginlist table population  
03/07/2008 JPB Added "AND pqa.status = ''A''" to WHERE clause to avoid showing Inactive approvals for a facility  
03/07/2008 JPB   
 Modified to handle profit_ctr_id and profit_ctr_name according to profitcenter.view_on_web rules  
 Addresses bad behavior from sp_reports_list_database: Doesn't use srld anymore  
 Properly renders the "display as" names for profitcenters that report as their parent company  
 Added pqa.confirm_update_date for displaying "Needs to be confirmed before use" on web page.  
  
#09/5/2008 JPB Fixed handling of profit_ctr_id -- the actual profit_ctr_id field isn't used in any way  
 to identify the company on the website, so it should not be handled according to profitcenter.view_on_web rules  
 because that skews (returns wrong!) data that is used in electronic forms, details, waste received, etc.  
 WAS:  
  dbo.fn_web_profitctr_display_id(pqa.company_id, pqa.profit_ctr_id) as pqa_profit_ctr_id,   
 NOW:  
  pqa.profit_ctr_id as pqa_profit_ctr_id,   
  
01/30/2009 RJG Modified code to include access filter (per JPB)  
03/06/2009 RJG and JPB -

	some result sets will return MORE data. Ones that have profiles related via customergenerator. 
	This is because the original query was not returning some of the records from the 
	"Indirectly Assigned generators via customergenerator related generators to contactxref related customers" case

	The two cases that prove this are:
	exec sp_reports_profiles 1,'11474','','06/01/2008','01/01/2009','','103686','Y','L',NULL,1,-1  ----- CASE: Contact with Customer on Inter-Company Transactions -----

	and

	exec sp_reports_profiles 1,'2277','20950','06/01/2005','01/01/2009','','1071','Y','L',NULL,1,-1  ----- CASE: Contact with Customer Accounts and related Generators -----

	--
	removed unecessary filtering from where clause that was messing up data.  this filtering is now done in the access filter
	--

	fixed broker query to use orig_customer_id
	---
	fixed the "Indirectly Assigned generators via customergenerator related generators to contactxref related customers"
	case by joining on CustomerGenerator.customer_id rather than profile.customer_id

	new 
		inner join contactxref x on ***cg***.customer_id = x.customer_id  

	old
		inner join contactxref x on ***prfi***.customer_id = x.customer_id
      
03/12/2009  JPB
	Added more debug/timing statements to track query progress while speed testing.

03/12/2009 RJG
	Reverted to old show_prices logic (doing subquery) because using the access_filter table returned duplicate rows
	Moved show_prices logic to the final output for performance

04/09/2009 - JPB
	Rewrote #AccessFilter query to better match other SPs (Waste Received) simplified logic
	for that select.  Had to add additional handling for profiles' orig_customer_id.
	Tested with...
	sp_reports_profiles 0,'10673','71493','2/1/2009','2/20/2009','WM8209HW001L','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','71493','2/1/2009','2/20/2009','WM8209HW001L','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','2/1/2009','2/20/2009','WM8209HW001L','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','','','WM8209HW001L','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','','','WM8209HW001L','','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','2/1/2009','2/20/2009','','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','71493','','2/20/2009','','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','71493','','2/20/2009','','','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','','','','sandals','100913','Y','L',NULL,1,-1
	sp_reports_profiles 0,'','','','','','sandals','','Y','L',NULL,1,-1

05/12/2009 JDB	Added ERG_suffix
	
	Added @description input to search approval_desc and dot_desc for partial matches.
	Fixed bad join condition on orig_customer_id cases... was checking eq_flag on the wrong table (eqcust, not cust)
	
09/16/2010 JPB  GEM:14825 - Fixed inclusion of attachments at different companies (was not including them)
02/20/2011 JPB	Bugfix: Prices from all co/pcs were shown in detail mode, though only 1 co/pc's prices were wanted.
08/15/2012 JPB	Changed how Prices are retrieved (don't returns Bundled rows) and added Description field
	consistent with current EQAI code.
08/19/2012 JPB	Added return_all_prices flag so this SP can power a web-version of the EQAI price Confirmation format	
11/20/2013	JPB	Added waste_water_flag to output.
				LDR SubCategory now comes from ProfileLDRSubcategory not profile.  This makes it a separate resultset.
01/08/2014	JPB	Pricing query replaced with latest & greatest copy of EQAI logic, ported to SQL.				

****************************************************************************************************/  
SET NOCOUNT ON  
-- SET QUERY_GOVERNOR_COST_LIMIT 20  
  
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF  
  
declare 
	@starttime 	datetime,
	@sql		varchar(8000)
	
set @starttime = getdate()  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description  
  
-- Housekeeping.  Gets rid of old paging records.  
DECLARE @eightHoursAgo as DateTime  
set @eightHoursAgo = DateAdd(hh, -8, getdate())  
if ((SELECT COUNT(session_added) FROM Work_ProfileListResult where session_added < @eightHoursAgo) > 0)  
BEGIN  
 delete from Work_ProfileListResult where session_added < @eightHoursAgo  
END  
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Housekeeping' as description  
  
-- Check to see if there's a @session_key provided with this query, and if that key is valid.  
if datalength(@session_key) > 0 begin  
 if not exists(select distinct session_key from Work_ProfileListResult where session_key = @session_key) begin  
  set @session_key = ''  
  set @row_from = 1  
  set @row_to = 20  
 end  
end  
  
-- If there's still a populated @session key, skip the query - just get the results.  
if datalength(@session_key) > 0 OR @report_type = 'D' goto returnresults   

-- If there was no session key, set it to a new value.
set @session_key = newid()  

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description  
  
-- Insert text-list values into table variables.  This validates that each element in the list is a valid data type (no sneaking in bad data/commands)  
  
-- Customer ID:  
 CREATE TABLE #Customer_id_list (ID int)  
 CREATE INDEX idx1 ON #Customer_id_list (ID)  
 Insert #Customer_id_list   
  select convert(int, row) from   
  dbo.fn_SplitXsvText(',', 0, @customer_id_list)   
  where isnull(row, '') <> ''  
  
-- Generator ID:  
 CREATE TABLE #generator_id_list (ID int)  
 CREATE INDEX idx2 ON #generator_id_list (ID)  
 Insert #generator_id_list   
  select convert(int, row)   
  from dbo.fn_SplitXsvText(',', 0, @generator_id_list)   
  where isnull(row, '') <> ''  

-- Approval Code ID:  
 CREATE TABLE #approval_code_list (approval_code varchar(20))  
 CREATE INDEX idx3 ON #approval_code_list (approval_code)  
 Insert #approval_code_list   
  select row   
  from dbo.fn_SplitXsvText(',', 1, @approval_code_list)   
  where isnull(row, '') <> ''  
  
---- Waste Code:  Not a valid input yet, but anticipated.
-- CREATE TABLE #waste_code_list (waste_code varchar(20))  
-- CREATE INDEX idx4 ON #waste_code_list (waste_code)  
-- Insert #waste_code_list   
--  select row   
--  from dbo.fn_SplitXsvText(',', 1, @waste_code_list)   
--  where isnull(row, '') <> ''  
    
-- Set/normalize defaults  
SET @include_brokered = 'Y'
  
-- IF len(@contact_id) > 0 and @contact_id <> '0' BEGIN  
	-- No contact_id specified - make sure user isn't running this with no other criteria  
	IF (select count(*) from #customer_id_list) +  
		(select count(*) from #generator_id_list) +   
		(select count(*) from #approval_code_list) +   
		len(ltrim(@description)) +  
		len(ltrim(@start_date)) +  
		len(ltrim(@end_date)) = 0 BEGIN  
			SELECT 'You must specify select criteria' as error_message  
			RETURN  
	END  
--END
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Var setup/abort' as description  
  
-- Define Access Filter -- Associates can see everything.  Customers can only see records tied to their explicit (or related) customer_id and generator_id assignments  

create table #access_filter (  
	ID int IDENTITY,  
	company_id int,   
	profit_ctr_id int,   
	profile_id int
)

create index idx_af on #access_filter (profile_id, company_id, profit_ctr_id)

IF len(@contact_id) > 0 and @contact_id <> '0' BEGIN
	-- Customer/Generator version
 
	set @sql = '
		-- 1: explicit customers
			select DISTINCT
				pqa.company_id,
				pqa.profit_ctr_id,
				prfi.profile_id
			from Profile prfi (nolock)
				inner join ContactXRef CXR WITH (nolock) ON prfi.customer_id = CXR.customer_id AND CXR.contact_id = ' + @contact_id  + ' AND CXR.type = ''C'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				inner join ProfileQuoteApproval pqa (nolock) on prfi.profile_id = pqa.profile_id and pqa.status = ''A''
				/* JOIN SLUG */
				inner join profilequotedetail pqd (nolock) on prfi.profile_id = pqd.profile_id and pqd.record_type = ''D''
				inner join profitcenter pfc (nolock) on pqa.company_id = pfc.company_id and pqa.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on pqa.company_id = co.company_id and co.view_on_web = ''T''
			WHERE prfi.curr_status_code = ''A''
				/* WHERE SLUG */
			UNION
		-- 2: explicit generators
			select DISTINCT
				pqa.company_id,
				pqa.profit_ctr_id,
				prfi.profile_id
			from Profile prfi (nolock)
				inner join ContactXRef CXR WITH (nolock) ON prfi.generator_id = CXR.generator_id AND CXR.contact_id = ' + @contact_id  + ' AND CXR.type = ''G'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				inner join ProfileQuoteApproval pqa (nolock) on prfi.profile_id = pqa.profile_id and pqa.status = ''A''
				/* JOIN SLUG */
				inner join profilequotedetail pqd (nolock) on prfi.profile_id = pqd.profile_id and pqd.record_type = ''D''
				inner join profitcenter pfc (nolock) on pqa.company_id = pfc.company_id and pqa.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on pqa.company_id = co.company_id and co.view_on_web = ''T''
			WHERE prfi.curr_status_code = ''A''
				/* WHERE SLUG */
			UNION
		-- 3: generators via customergenerator x explicit customers
			select DISTINCT
				pqa.company_id,
				pqa.profit_ctr_id,
				prfi.profile_id
			from Profile prfi (nolock)
				inner join CustomerGenerator cg (nolock) on prfi.generator_id = cg.generator_id
				inner join ContactXRef CXR WITH (nolock) ON cg.customer_id = CXR.customer_id AND CXR.contact_id = ' + @contact_id + ' and CXR.type = ''C'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				inner join ProfileQuoteApproval pqa (nolock) on prfi.profile_id = pqa.profile_id and pqa.status = ''A''
				/* JOIN SLUG */
				inner join profilequotedetail pqd (nolock) on prfi.profile_id = pqd.profile_id and pqd.record_type = ''D''
				inner join profitcenter pfc (nolock) on pqa.company_id = pfc.company_id and pqa.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on pqa.company_id = co.company_id and co.view_on_web = ''T''
			WHERE prfi.curr_status_code = ''A''
				/* WHERE SLUG */
			UNION
		-- 4: explicit orig_customers
			select DISTINCT
				pqa.company_id,
				pqa.profit_ctr_id,
				prfi.profile_id
			from Profile prfi (nolock)
				inner join ContactXRef CXR WITH (nolock) ON prfi.orig_customer_id = CXR.customer_id AND CXR.contact_id = ' + @contact_id  + ' AND CXR.type = ''C'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				inner join ProfileQuoteApproval pqa (nolock) on prfi.profile_id = pqa.profile_id and pqa.status = ''A''
				/* JOIN SLUG ORIG */
				inner join profilequotedetail pqd (nolock) on prfi.profile_id = pqd.profile_id and pqd.record_type = ''D''
				inner join profitcenter pfc (nolock) on pqa.company_id = pfc.company_id and pqa.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on pqa.company_id = co.company_id and co.view_on_web = ''T''
			WHERE prfi.curr_status_code = ''A''
				/* WHERE SLUG */
		'

	if (select count(*) from #customer_id_list) > 0 BEGIN
		set @sql = replace(@sql, '/* JOIN SLUG */', 'INNER JOIN #customer_id_list cil ON prfi.customer_id = cil.id /* JOIN SLUG */')
		set @sql = replace(@sql, '/* JOIN SLUG ORIG */', 'INNER JOIN #customer_id_list cil ON prfi.orig_customer_id = cil.id /* JOIN SLUG */')
	END ELSE BEGIN
		set @sql = replace(@sql, '/* JOIN SLUG ORIG */', '/* JOIN SLUG */')
	END

END ELSE BEGIN
	-- Associate version
 
	set @sql = '
		SELECT pqa.company_id, pqa.profit_ctr_id, prfi.profile_id 
		FROM profile prfi (nolock)
		inner join profilequoteapproval pqa (nolock) on prfi.profile_id = pqa.profile_id and pqa.status = ''A''
		/* JOIN SLUG */
		inner join profilequotedetail pqd (nolock) on prfi.profile_id = pqd.profile_id and pqd.record_type = ''D''
		inner join profitcenter pfc (nolock) on pqa.company_id = pfc.company_id and pqa.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
		inner join company co (nolock) on pqa.company_id = co.company_id and co.view_on_web = ''T''
		where prfi.curr_status_code = ''A''  
		/* WHERE SLUG */
		'
		
	if (select count(*) from #customer_id_list) > 0 BEGIN
		set @sql = replace(@sql, '/* JOIN SLUG */', 'INNER JOIN #customer_id_list cil ON prfi.orig_customer_id = cil.id /* JOIN SLUG */')
		set @sql = @sql + ' UNION ' + replace(@sql, 'ON prfi.orig_customer_id = cil.id', 'ON prfi.customer_id = cil.id')
	END
		
END

if (select count(*) from #generator_id_list) > 0
	set @sql = replace(@sql, '/* JOIN SLUG */', 'INNER JOIN #generator_id_list gil ON prfi.generator_id = gil.id /* JOIN SLUG */')

if (select count(*) from #approval_code_list) > 0
	set @sql = replace(@sql, '/* JOIN SLUG */', 'INNER JOIN #approval_code_list acl ON pqa.approval_code = acl.approval_code /* JOIN SLUG */')
	
if len(@start_date) > 0
	set @sql = replace(@sql, '/* WHERE SLUG */', 'and prfi.ap_expiration_date >= ''' + @start_date + ''' /* WHERE SLUG */')

if len(@end_date) > 0
	set @sql = replace(@sql, '/* WHERE SLUG */', 'and prfi.ap_expiration_date <= ''' + @end_date + ''' /* WHERE SLUG */')

if len(@description) > 0
	set @sql = replace(@sql, '/* WHERE SLUG */', 'and isnull(prfi.approval_desc, '''') + '' '' + isnull(prfi.dot_shipping_name, '''') LIKE ''%' + replace(@description, ' ', '%') + '%'' /* WHERE SLUG */')

set @sql = 'Insert #Access_filter ' + @sql

if @debug > 3 print @sql
if @debug > 3 select @sql as AccessFilter_query

exec (@sql)

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #AccessFilter' as description

-- select * from #access_filter

  
--RJG:  Jonathan (JPB) Moved calculated fields to the final select to increase performance
INSERT Work_ProfileListResult (  
	company_id,   
	approval_code,   
	profile_id,   
	customer_id,   
	approval_desc,   
	ots_flag,   
	ap_expiration_date,   
	generator_id,   
	cust_name,   
	generator_name,   
	epa_id,   
	reapproval_allowed,   
	broker_flag,   
	pqa_company_id,   
	pqa_profit_ctr_id,   
	confirm_update_date,   
	session_key,   
	session_added,
	orig_customer_id
)  
SELECT DISTINCT  
	af.company_id,  
	pqa.approval_code,  
	prfi.profile_id,  
	prfi.customer_id,  
	prfi.approval_desc,  
	prfi.ots_flag,  
	prfi.ap_expiration_date,  
	prfi.generator_id,  
	cust.cust_name,  
	gen.generator_name,  
	gen.epa_id,  
	prfi.reapproval_allowed,  
	prfi.broker_flag,  
	pqa.company_id as pqa_company_id,  
	pqa.profit_ctr_id as pqa_profit_ctr_id,   
	pqa.confirm_update_date,  
	@session_key as session_key,  
	GETDATE() as session_added,
	prfi.orig_customer_id
FROM 
	#access_filter af   WITH(NOLOCK)  
	INNER JOIN Profile prfi   WITH(NOLOCK) ON af.profile_id = prfi.profile_id  
	INNER JOIN ProfileQuoteApproval pqa  WITH(NOLOCK)  on prfi.profile_id = pqa.profile_id 
		and af.company_id = pqa.company_id AND pqa.status = 'A'   
	INNER JOIN ProfitCenter pfc  WITH(NOLOCK)  ON pqa.company_id = pfc.company_id  
		AND pqa.profit_ctr_id = pfc.profit_ctr_id  
		AND pfc.status = 'A' 
		AND isnull(pfc.view_on_web, 'F') <> 'F' 
		AND isnull(pfc.view_approvals_on_web, 'F') = 'T'  
	INNER JOIN Company c  WITH(NOLOCK) on c.company_id = pqa.company_id AND c.view_on_web = 'T'  
	INNER JOIN Customer cust  WITH(NOLOCK)  ON prfi.customer_id = cust.customer_id  
	INNER JOIN Generator gen  WITH(NOLOCK)  ON prfi.generator_id = gen.generator_id  
	INNER JOIN ProfileQuoteDetail pqd  WITH(NOLOCK)  on prfi.profile_id = pqd.profile_id AND pqd.record_type = 'D'   
WHERE prfi.curr_status_code = 'A'  
ORDER BY   
	pqa_company_id, 
	pqa_profit_ctr_id, 
	cust.cust_name, 
	gen.generator_name, 
	pqa.approval_code  


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_ProfileListResult insert' as description  


returnresults: -- Re-queries with an existing session_key that passes validation end up here.  So do 1st runs (with an empty, now brand-new session_key)  
  
if datalength(@session_key) > 0 BEGIN
	declare @start_of_results int, @end_of_results int  
	select @start_of_results = min(row_num)-1, @end_of_results = max(row_num) from Work_ProfileListResult where session_key = @session_key  
	
	set nocount off  
  
	select  
		wplr.company_id, 
		wplr.approval_code, 
		wplr.profile_id, 
		wplr.customer_id, 
		wplr.approval_desc, 
		wplr.ots_flag,   
		wplr.ap_expiration_date, 
		wplr.generator_id, 
		wplr.cust_name, 
		wplr.generator_name, 
		wplr.epa_id,   
		dbo.fn_web_profitctr_display_name(pqa_company_id, pqa_profit_ctr_id) as profit_ctr_name, 
		case when (len(@contact_id) > 0 and @contact_id <> '0') then
			case when exists (
				select customer_id  
				from contactxref  
				where contact_id = convert(int, @contact_id )  
				and customer_id = wplr.customer_id
				and type = 'C'  
				and web_access = 'A'  
				and status = 'A') then  
				'T'  
			else  
				'F'  
			end  
		else
			'T'
		end as show_prices,
		wplr.reapproval_allowed, 
		(SELECT dbo.fn_profile_form_list (wplr.profile_id)) as form_list,  
		(SELECT dbo.fn_profile_wcr_list (wplr.profile_id)) as wcr_list,   
	  	case when exists (  
	    	select top 1 s.image_id from Plt_Image.dbo.scan s where s.profile_id = wplr.profile_id  
	     	and s.document_source = 'approval'  
	     	and s.view_on_web = 'T'  
	     	and s.status = 'A'
	   		) then 'T' 
	   	else 
	   		'F'  
	  	end as images,  
	  	wplr.broker_flag,   
	  	wplr.pqa_company_id, 
	  	wplr.pqa_profit_ctr_id, 
	  	dbo.fn_web_profitctr_display_name(wplr.pqa_company_id, wplr.pqa_profit_ctr_id) as dest_profit_ctr_name,  
	  	wplr.confirm_update_date, 
	  	wplr.session_key,   
	  	wplr.session_added,  
	  	wplr.row_num - @start_of_results as row_number,  
	  	@end_of_results - @start_of_results as record_count,
	  	wplr.orig_customer_id,
	  	eqcust.cust_name as orig_cust_name
	from Work_ProfileListResult  wplr
    INNER JOIN Customer cust     
		ON wplr.customer_id = cust.customer_id    
	LEFT OUTER JOIN Customer eqcust on 
		wplr.orig_customer_id = eqcust.customer_id and cust.eq_flag = 'T'
	where 
		wplr.session_key = @session_key  
		and wplr.row_num >= @start_of_results + @row_from  
		and wplr.row_num <= case when @row_to = -1 then @end_of_results else @start_of_results + @row_to end  
	order by 
		wplr.row_num    
END
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS1 Select-out' as description  
  
if @report_type = 'D' BEGIN
     if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Begin Detail Select' as description  

     -- select detail record  
     declare 
        @images 		char(1),
  		@contact_id_num int  
  		
	set @contact_id_num = cast(@contact_id as int)  
	  
	create table #images (image_count int)    
	set @sql = '
		insert #images select count(image_id) as image_count     
		from Plt_Image.dbo.scan where profile_id = ' + convert(varchar(20), @profile_id) + '      
		and document_source = ''approval''    
		and view_on_web = ''T''    
		and status = ''A''    
	'    
       
	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #images query created' as description  
	
	exec(@sql)    
	
	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #images query executed' as description  
	   
	select @images = case when image_count = 0 then 'F' else 'T' end from #images    
	   
	drop table #images    
	set nocount off    
          
          
	-- Main Info Select    
	SELECT    
		prfi.profile_id,
		prfi.ap_expiration_date,
        prfi.approval_desc,
        prfi.comments_1,
        prfi.comments_2,
        prfi.comments_3,
        prfi.dot_shipping_name,
        prfi.manifest_dot_sp_number,
        CONVERT(varchar(5), prfi.erg_number) + ISNULL(prfi.erg_suffix, '') AS erg_number,
        prfi.generic_flag,
        prfi.hazmat,    
        prfi.hazmat_class,    
        -- prfi.ldr_subcategory,    
        prfi.waste_water_flag,
        prfi.ots_flag,    
        prfi.package_group,    
        prfi.un_na_flag,    
        prfi.un_na_number,    
        prfi.reapproval_allowed,    
           
        pqa.approval_code,    
        pqa.ldr_req_flag,    
        pqa.sr_type_code,    
        pqa.company_id,    
        pqa.profit_ctr_id,    
           
        plab.color,    
        plab.consistency,    
        plab.free_liquid
		,plab.ignitability	--ignitability
		,plab.ignitability_lt_90
		,plab.ignitability_90_139  
		,plab.ignitability_140_199
		,plab.ignitability_gte_200
		,plab.ignitability_NA  
		
        , plab.ph_from,    
        plab.ph_to

		,plab.ph_lte_2	--ph_lte_2
		,plab.ph_gt_2_lt_5	--ph_gt_2_lt_5
		,plab.ph_gte_5_lte_10	--ph_gte_5_lte_10
		,plab.ph_gt_10_lt_12_5	--ph_gt_10_lt_12_5
		,plab.ph_gte_12_5	--ph_gte_12_5
           
        ,ldrwm.waste_managed_flag     
         + '. - <u>'     
         + convert(varchar(8000), ldrwm.underlined_text)     
         + '</u> ' + convert(varchar(8000), ldrwm.regular_text)     
         as waste_managed_flag,    
        ldrwm.contains_listed,    
        ldrwm.exhibits_characteristic,    
        ldrwm.soil_treatment_standards,    
           
        cust.customer_id,    
        cust.cust_name,    
           
        gen.epa_id,    
        gen.gen_mail_addr1,    
        gen.gen_mail_addr2,    
        gen.gen_mail_addr3,    
        gen.gen_mail_addr4,    
        gen.gen_mail_city,    
        isnull(xGMC.name, xGC.name) as gen_mail_contact,    
        isnull(xGMC.title, xGC.title) as gen_mail_contact_title,     
        gen.gen_mail_name,    
        gen.gen_mail_state,    
        gen.gen_mail_zip_code,    
        gen.generator_address_1,    
        gen.generator_address_2,    
        gen.generator_address_3,    
        gen.generator_address_4,    
        gen.generator_city,    
        xGC.name as generator_contact,    
        xGC.title as generator_contact_title,    
        gen.generator_fax,    
        gen.generator_id,    
        gen.generator_name,    
        gen.generator_phone,    
        gen.generator_state,    
        gen.generator_zip_code,    
            
        pc.name,    
        pc.title,    
           
   		dbo.fn_web_profitctr_display_name(pqa.company_id, pqa.profit_ctr_id) as profit_ctr_name, 
            
        (SELECT dbo.fn_profile_form_list (prfi.profile_id))     
         as form_list,    
            
        (SELECT dbo.fn_profile_wcr_list (prfi.profile_id))     
         as wcr_list,    
          
        @images as images,    
            
        pqa.company_id as pqa_company_id,    
        pqa.profit_ctr_id as pqa_profit_ctr_id,
        
        prfi.orig_customer_id,
        eqcust.cust_name as orig_cust_name

		,prfi.subsidiary_haz_mat_class	--subsidiary_haz_mat_class
		,prfi.reportable_quantity_flag	--reportable_quantity_flag
		,prfi.rq_reason
             
	FROM
        Profile prfi    
        INNER JOIN ProfileQuoteApproval pqa     
        	ON prfi.profile_id = pqa.profile_id    
			AND pqa.status = 'A'
        INNER JOIN ProfileLab plab     
			ON pqa.profile_id = plab.profile_id     
			AND plab.type='A'    
        INNER JOIN Customer cust     
			ON prfi.customer_id = cust.customer_id    
        INNER JOIN Generator gen     
			ON prfi.generator_id = gen.generator_id    
        LEFT OUTER JOIN ContactXRef xContact     
			ON gen.generator_id = xContact.generator_id     
			AND xContact.type = 'G'     
			AND xContact.status = 'A'     
			AND xContact.primary_contact = 'T'    
        LEFT OUTER JOIN Contact xGC     
			ON xContact.contact_id = xGC.contact_id     
			AND xGC.contact_status = 'A'    
        LEFT OUTER JOIN ContactXRef xMailContact     
			ON gen.generator_id = xMailContact.generator_id     
			AND xMailContact.type = 'G'     
			AND xMailContact.status = 'A'     
			AND xMailContact.primary_contact <> 'T'    
        LEFT OUTER JOIN Contact xGMC     
			ON xMailContact.contact_id = xGMC.contact_id     
			AND xGMC.contact_status = 'A'    
        LEFT OUTER JOIN LDRWasteManaged ldrwm     
			ON prfi.waste_managed_id = ldrwm.waste_managed_id    
        LEFT OUTER JOIN Contact pc    
			ON prfi.contact_id = pc.contact_id     
		LEFT OUTER JOIN Customer eqcust
			ON prfi.orig_customer_id = eqcust.customer_id and cust.eq_flag = 'T'
             
	WHERE 1=1    
        AND prfi.profile_id = @profile_id    
        AND pqa.company_id = isnull(@company_id, pqa.company_id)
        AND pqa.profit_ctr_id = isnull(@profit_ctr_id, pqa.profit_ctr_id)
          

   if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Main Info Select' as description  
      
   -- Determine whether prices should be shown    
   set nocount on    
       
   declare @showprices char(1)    
   set @showprices = 'F'    
          
	if @contact_id_num > 0     
		SELECT
			@showprices = 'T'    
		FROM
			Profile prfi    
			INNER JOIN ContactXRef cxr     
				ON prfi.customer_id = cxr.customer_id    
				AND cxr.type = 'C'    
				AND cxr.status = 'A'    
				AND cxr.web_access = 'A'    
			INNER JOIN Customer cust     
				ON prfi.customer_id = cust.customer_id    
				AND cxr.customer_id = cust.customer_id    
				AND cust.terms_code <> 'NOADMIT'    
			INNER JOIN Contact con     
				ON cxr.contact_id = con.contact_id    
				AND con.contact_status = 'A'    
		WHERE    
			prfi.profile_id = @profile_id    
			AND con.contact_id = @contact_id    

	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Show-Prices Select' as description  
	     
	if @contact_id = -1    
		set @showprices = 'T' -- Associate    
           
	set nocount off    
            
            
	-- Prices / Bill Unit Select
	
	set nocount on
	
	-- Service/Trans, Not bundled OR Bundled and print on pc.
		SELECT 
			pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			, pqa.approval_code
			, profile.ap_expiration_date
			, pqa.confirm_update_date
			, pqa.ldr_req_flag
			, profitcenter.profit_ctr_name
			, profitcenter.epa_id
			, case when pqd.record_type IN ('T', 'S') then 
					case when pqd.bill_method = 'B' then '  Includes ' + pqd.service_Desc else pqd.service_Desc end
				else
					case when pqa.sr_type_code = 'E' then
						case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'
							else
								'Treatment and Disposal'
							end
					else
						case when pqa.sr_type_code = 'H' then 'Treatment and Disposal - Additional $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.surcharge_price)) end + ' Hazardous Surcharge per unit'
							else
								case when pqa.sr_type_code = 'P' then 'Treatment and Disposal - Additional $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.surcharge_price)) end + ' Perpetual Care Surcharge per unit'
									else
										'Treatment and Disposal'
									end
						end
					end
				end as type_of_service
			, case when pqd.bill_method = 'B' then null else case when @showprices <> 'T' then '$<i>Not Shown</i>' else '$' + convert(varchar(20), convert(money, pqd.price)) end end as price
			, case when pqd.bill_method = 'B' then null else pqd.bill_unit_code end as bill_unit_code
			, case when pqd.bill_method = 'B' then null else case when pqd.min_quantity is null then 'N/A' else convert(varchar(20), pqd.min_quantity) + ' ' + pqd.bill_unit_code end end as min_quantity
			, ''
				+ case when pqd.hours_free_unloading is not null then 'Hours Free Unloading: ' + convert(varchar(20), pqd.hours_free_unloading) + '  ' else '' end 
				+ case when pqd.hours_free_loading is not null then 'Hours Free Loading: ' + convert(varchar(20), pqd.hours_free_loading) + '  ' else '' end 
				+ case when pqd.demurrage_price is not null then 'Demurrage is $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.demurrage_price)) end + ' per hour after two free hours loading and unloading.  ' else '' end 
				+ case when pqd.unused_truck_price is not null then 'Trucks ordered and not used are $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.unused_truck_price)) end + ' per truck.  ' else '' end 
				+ case when pqd.lay_over_charge is not null then 'Layovers are $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.lay_over_charge)) end + ' per day per truck.  ' else '' end
				as line_detail
				
			,	case when isnull(ref_sequence_id, 0) > 0 then 
					-- determine the order_by value of the sequence_id to which ref_sequence_id points:
					(select pqd2.sequence_id * case pqd2.record_type when 'D' then 10000 when 'T' then 20000 when 'S' then 30000 else 40000 end from profilequotedetail pqd2 where pqd.quote_id = pqd2.quote_id and pqd.profile_id = pqd2.profile_id and pqd.company_id = pqd2.company_id and pqd.profit_ctr_id = pqd2.profit_ctr_id and pqd2.sequence_id = pqd.ref_sequence_id) + pqd.sequence_id
				else 
					-- use this row's own order_by info:
					sequence_id * case record_type when 'D' then 10000 when 'T' then 20000 when 'S' then 30000 else 40000 end
				end as order_by
				
		INTO #PrePrice
		FROM Profile
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type IN ('S', 'T')
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND ((isnull(pqd.bill_method, '') = 'B' and pqd.show_cust_flag = 'T') OR isnull(pqd.bill_method, '') <> 'B')
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
			   AND pqa.status = 'A'
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND profile.profile_id = @profile_id
	UNION ALL
	-- Disposal, not bundled.
		SELECT 
			pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			, pqa.approval_code
			, profile.ap_expiration_date
			, pqa.confirm_update_date
			, pqa.ldr_req_flag
			, profitcenter.profit_ctr_name
			, profitcenter.epa_id
			, case when pqd.record_type IN ('T', 'S') then 
					case when pqd.bill_method = 'B' then '  Includes ' + pqd.service_Desc else pqd.service_Desc end
				else
					case when pqa.sr_type_code = 'E' then
						case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'
							else
								'Treatment and Disposal'
							end
					else
						case when pqa.sr_type_code = 'H' then 'Treatment and Disposal - Additional $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.surcharge_price)) end + ' Hazardous Surcharge per unit'
							else
								case when pqa.sr_type_code = 'P' then 'Treatment and Disposal - Additional $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.surcharge_price)) end + ' Perpetual Care Surcharge per unit'
									else
										'Treatment and Disposal'
									end
						end
					end
				end as type_of_service
			, case when pqd.bill_method = 'B' then null else case when @showprices <> 'T' then '$<i>Not Shown</i>' else '$' + convert(varchar(20), convert(money, pqd.price)) end end as price
			, case when pqd.bill_method = 'B' then null else pqd.bill_unit_code end as bill_unit_code
			, case when pqd.bill_method = 'B' then null else case when pqd.min_quantity is null then 'N/A' else convert(varchar(20), pqd.min_quantity) + ' ' + pqd.bill_unit_code end end as min_quantity
			, ''
				+ case when pqd.hours_free_unloading is not null then 'Hours Free Unloading: ' + convert(varchar(20), pqd.hours_free_unloading) + '  ' else '' end 
				+ case when pqd.hours_free_loading is not null then 'Hours Free Loading: ' + convert(varchar(20), pqd.hours_free_loading) + '  ' else '' end 
				+ case when pqd.demurrage_price is not null then 'Demurrage is $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.demurrage_price)) end + ' per hour after two free hours loading and unloading.  ' else '' end 
				+ case when pqd.unused_truck_price is not null then 'Trucks ordered and not used are $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.unused_truck_price)) end + ' per truck.  ' else '' end 
				+ case when pqd.lay_over_charge is not null then 'Layovers are $' + case when @showprices <> 'T' then '<i>Not Shown</i>' else convert(varchar(20), convert(money, pqd.lay_over_charge)) end + ' per day per truck.  ' else '' end
				as line_detail
			,	case when isnull(ref_sequence_id, 0) > 0 then 
					-- determine the order_by value of the sequence_id to which ref_sequence_id points:
					(select pqd2.sequence_id * case pqd2.record_type when 'D' then 10000 when 'T' then 20000 when 'S' then 30000 else 40000 end from profilequotedetail pqd2 where pqd.quote_id = pqd2.quote_id and pqd.profile_id = pqd2.profile_id and pqd.company_id = pqd2.company_id and pqd.profit_ctr_id = pqd2.profit_ctr_id and pqd2.sequence_id = pqd.ref_sequence_id) + pqd.sequence_id
				else 
					-- use this row's own order_by info:
					sequence_id * case record_type when 'D' then 10000 when 'T' then 20000 when 'S' then 30000 else 40000 end
				end as order_by

		FROM Profile 
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type = 'D'
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND IsNull(pqd.bill_method, '') <> 'B'
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
			   AND pqa.status = 'A'
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND profile.profile_id = @profile_id
	order by
		profit_ctr_name
		, approval_code
		, order_by

	CREATE TABLE #comments (
			profile_id		INT
		,	company_id		INT
		,	profit_ctr_id	INT
		,	comment			VARCHAR(max)
	)
	
	declare @CARRIAGE_RETURN varchar(5) = CHAR(13) + CHAR(10)

	INSERT  INTO #comments
	SELECT DISTINCT
		PQD.profile_id
	,   PQD.company_id
	,   PQD.profit_ctr_id
	,   comment = (ISNULL(d.description, '') + CASE d.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END +
				   ISNULL(t.description, '') + CASE t.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END + ISNULL(s.description, '')
				   )
	FROM ProfileQuoteApproval PQA
	JOIN ProfileQuoteDetail PQD
		ON PQA.profile_id = PQD.profile_id
		AND PQA.quote_id = PQD.quote_id
		AND PQD.status = 'A'
	LEFT OUTER JOIN ProfileQuoteDetailDesc d
		ON d.profile_id = PQD.profile_id
		   AND d.company_id = PQD.company_id
		   AND d.profit_ctr_id = PQD.profit_ctr_id
		   AND d.quote_id = PQD.quote_id
		   AND d.record_type = 'D'
	LEFT OUTER JOIN ProfileQuoteDetailDesc t
		ON t.profile_id = PQD.profile_id
		   AND t.company_id = PQD.company_id
		   AND t.profit_ctr_id = PQD.profit_ctr_id
			AND t.quote_id = PQD.quote_id
		   AND t.record_type = 'T'
	LEFT OUTER JOIN ProfileQuoteDetailDesc s
		ON s.profile_id = PQD.profile_id
		   AND s.company_id = PQD.company_id
		   AND s.profit_ctr_id = PQD.profit_ctr_id
		   AND s.quote_id = PQD.quote_id
		   AND s.record_type = 'S'
	WHERE PQA.status = 'A'
	 AND PQA.profile_id = @profile_ID
	 
	 
	set nocount off    

	select 
		p.company_id, p.profit_ctr_id, p.approval_code, p.ap_expiration_date, p.confirm_update_date, p.ldr_req_flag, p.profit_ctr_name, p.epa_id, p.type_of_service, p.price, p.bill_unit_code, p.min_quantity, p.line_detail
		, x.comment
		, p.order_by
	from #PrePrice p
	left join #comments x on p.company_id = x.company_id and p.profit_ctr_id = x.profit_ctr_id
	where p.price is not null
	union
	select 
		p.company_id, p.profit_ctr_id, p.approval_code,  p.ap_expiration_date, p.confirm_update_date, p.ldr_req_flag, p.profit_ctr_name, p.epa_id, p.type_of_service, p.price, p.bill_unit_code, p.min_quantity, p.line_detail
		, x.comment
		, min(p.order_by) as order_by
	from #PrePrice p
	left join #comments x on p.company_id = x.company_id and p.profit_ctr_id = x.profit_ctr_id
	where p.price is null
	group by 
		p.company_id, p.profit_ctr_id, p.approval_code,  p.ap_expiration_date, p.confirm_update_date, p.ldr_req_flag, p.profit_ctr_name, p.epa_id, p.type_of_service, p.price, p.bill_unit_code, p.min_quantity, p.line_detail
		, x.comment
	order by
			profit_ctr_name
			, approval_code
			, order_by


	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Unit/Price Select' as description  
           
           
	-- Constituents Info Select    
	SELECT    
		prco.uhc,    
		prco.concentration,    
		prco.unit,    
		    
		cons.const_desc,    
		cons.ldr_id    
	FROM    
		ProfileConstituent prco    
		INNER JOIN Constituents cons     
			ON prco.const_id = cons.const_id    
	WHERE    
		prco.profile_id = @profile_id    

	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Constituents Info Select' as description  
	
	
	-- Waste Codes Select      
	SELECT    
		display_name as waste_code
	FROM    
		ProfileWasteCode pwc    
		INNER JOIN Wastecode wc on pwc.waste_code_uid = wc.waste_code_uid
	WHERE    
		profile_id = @profile_id    
    order by 
        case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'D' then 1 else
            case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'P' then 2 else
                case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'U' then 3 else
                    case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'K' then 4 else
                        case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'F' then 5 else
                            6
                        end
                    end
                end
            end
        end
        , wc.display_name

	
	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Waste Codes Select' as description  

	-- LDRSubCategory Select
	Select 
		l.subcategory_id, 
		l.short_desc, 
		l.long_desc 
	from ProfileLDRSubcategory p 
	inner join LDRSubcategory l 
		on p.ldr_subcategory_id = l.subcategory_id 
	WHERE l.status = 'A' 
	AND p.profile_id = @profile_id 
	order by l.short_desc

        
    /*** END SELECT DETAIL RECORD ***/  
    END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profiles] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profiles] TO [COR_USER]
    AS [dbo];


