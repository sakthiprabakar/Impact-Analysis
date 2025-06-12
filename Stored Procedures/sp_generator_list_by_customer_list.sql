Create Procedure sp_generator_list_by_customer_list (
	@customerlist 		varchar(8000) = '',
	@search_mode		varchar(20) = 'AND', -- OR or AND
	@search_term		varchar(50) = '', -- 
	@gen_name 			varchar(20) = '',
	@gen_epa_id 		varchar(20) = '',
	@contact_id			varchar(20) = '',
	@generator_city 	varchar(40) = '',
	@generator_state 	varchar(40) = '',
	@site_code			varchar(40) = ''
)
as
/************************************************************
Procedure	: sp_generator_list_by_customer_list
Database	: PLT_AI*
Created		: 12-3-2004 - Jonathan Broome
Description	: Finds all the generators related to the list
			  of accounts input.
Modified	: 05/23/2005 - JPB - Gutted the 'is it converted yet?' logic, switched
			: to using count(*) to see if the whole thing should run, and started
			: using a single select with union's between db's to return results

History:			
	01/09/2006 JPB - Switched lookup to PLT_RPT database for speed.
	09/08/2006 JPB - Added Name & EPA ID Parameters.
	11/01/2006 JPB - Added unions to select from customergenerator & contactxref
	11/28/2006 JPB - Added 'and a.customer_id is not null' to avoid duplicates due to null id's.
	12/19/2006 JPB - Added code to ignore blank inputs
	04/02/2007 JPB - Rewrote for clarity, added original_customer_id clause to Approval instance
	04/03/2007 JPB - Added Generator_State & Generator_City query options
	05/16/2007 JPB - Added quote escaping, converted to db-mode aware code, switched from Approval to Profile
	09/13/2007 JPB - Modified to shortcut for Associates: No customer id list, no contact_id? Don't bother using
		profile workorder customergenerator tables, just look in generator.
		Also added checks for Active generators
		Also rearranged standard (not very selective) clauses to the end of the WHERE to make selects faster
	4/10/2009 - JPB - Added @site_code input, rewrote for speed/clarity.	
	06/01/2011 - RJG - Added the @search_mode and @search_term fields for 'OR' style basic searching	
	09/09/2012 - JPB -
		Added some return fields:
			generator_address (combined 1-5),
			emergency_phone_number,
			gen_mail_city,
			gen_mail_state,
			gen_mail_zip_code,
			gen_mail_address (combined 1-5)			
	02/06/2013 - JPB - Bugfix: OR version of lookup allowed inactive generators in results, AND did not.
		Made OR work like AND.  Also: OR version ignored input @customerlist values.  Fixed that too.	
	11/19/2013	JPB		Now returning generator.tab in results.  part of GEM:24131, I think.
	08/10/2015	JPB	Removed status = A requirement in Generator join/lookup. Still valid in CXR, etc.

Examples:
	@customerlist 		varchar(8000),
	@gen_name 			varchar(20) = '',
	@gen_epa_id 		varchar(20) = '',
	@contact_id			varchar(20) = '',
	@generator_city 	varchar(40) = '',
	@generator_state 	varchar(40) = '',
	@site_code			varchar(40) = ''

	sp_generator_list_by_customer_list '10673', '', '', '100913', '', '', '6666'
--  sp_generator_list_by_customer_list '5287', 'Veolia', '', '3216', '', '', ''
	sp_generator_list_by_customer_list '5287', 'OR', 'Veolia', '', '', '3216', '', '', ''
	
sp_generator_list_by_customer_list (
	@customerlist 		varchar(8000) = '',
	@search_mode		varchar(20) = 'AND', -- OR or AND
	@search_term		varchar(50) = '', -- 
	@gen_name 			varchar(20) = '',
	@gen_epa_id 		varchar(20) = '',
	@contact_id			varchar(20) = '',
	@generator_city 	varchar(40) = '',
	@generator_state 	varchar(40) = '',
	@site_code			varchar(40) = ''
)	

	
	sp_generator_list_by_customer_list '', 'finn'
	sp_generator_list_by_customer_list '', 'finn', '', '', '', 'GA'
	sp_generator_list_by_customer_list '888888, 2492'
	sp_generator_list_by_customer_list '888888, 2492', 'adv', ''
	sp_generator_list_by_customer_list '888888, 2492', '', 'pad'
	sp_generator_list_by_customer_list '10673', '', '', '100913'
	sp_generator_list_by_customer_list '10673', '', '', '100913', '', 'tn,ms,al,fl,ga,sc,nc'
	sp_generator_list_by_customer_list '10673', '8212', '', '100913', '', 'tn,ms,al,fl,ga,sc,nc'
	sp_generator_list_by_customer_list '10673', '', '', '100913', 'irondale', 'tn,ms,al,fl,ga,sc,nc'
	sp_generator_list_by_customer_list '10673', '', '', '100913', 'canton', ''
	sp_generator_list_by_customer_list '10673', '', '', '100913', '', 'mi'
	sp_generator_list_by_customer_list '10673', '', '', '100913', '', 'michigan, ohio'
	sp_generator_list_by_customer_list '', '', '', '101298'
	sp_generator_list_by_customer_list '10877', '', 'vap000004671' --> NiSource account & generator via original_customer_id
	sp_generator_list_by_customer_list '404', 'fletch''s', '', '', '', ''

************************************************************/

	SET NOCOUNT ON

	if isnull(@customerlist, '') 
		+ isnull(@gen_name, '') 
		+ isnull(@gen_epa_id, '') 
		+ isnull(@contact_id, '')  
		+ isnull(@generator_city, '') 
		+ isnull(@generator_state, '')  
		+ isnull(@site_code, '')
		+ isnull(@search_term, '')
		+ isnull(@search_mode, '') = ''
		 return

	declare	@sql 				varchar(8000) = '', 
			@where 				varchar(1000) = '',
			@cwhere				varchar(1000) = '',
			@debug				int
	
	select 	@gen_name = replace(isnull(@gen_name, ''), '''', ''''''),
			@gen_epa_id = replace(isnull(@gen_epa_id, ''), '''', ''''''),
			@generator_city = replace(isnull(@generator_city, ''), '''', ''''''),
			@site_code = replace(isnull(@site_code, ''), '''', ''''''),
			@debug = 0
	
	-- Create temp table to store results
		create table #generators (
			generator_id			int
		)
		create index idx1 on #generators (generator_id)
	
	-- Break @customerlist values into a temp table...
		create table #customer (customer_id int)
		create index idx1 on #customer (customer_id)
		insert #customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @customerlist) where isnull(row, '') <> ''	

	-- Break @generator_state values into a temp table...
		create table #generator_state (state varchar(40))
		create index idx1 on #generator_state (state)
		insert #generator_state select row from dbo.fn_SplitXsvText(',', 1, @generator_state) where isnull(row, '') <> ''	

	-- Update any temp table values to the 2-letter abbrev.
		update #generator_state set 
			state = abbr
		from stateabbreviation
		where state = state_name
		and state is not null

	-- There is a common set of criteria applied to each source-search:
		set @where = 'where 1=1 '
		
		
			if (LEN(ISNULL(@search_mode,'')) > 0 AND LEN(ISNULL(@search_term,'')) > 0 AND @search_mode = 'OR')
			BEGIN
				set @where = 'where 1=2 OR (1=1'
				-- begin the custom "OR" criteria
				if isNumeric(@search_term) = 1
					set @where = @where + ' and (( 1=1 '
				if len(@search_term) = 1
					set @where = @where + ' and g.generator_name like ''' + @search_term + '%'' '
				else if @search_term = 'numbers'
					set @where = @where + ' and ''0123456789'' like ''%'' + left(g.generator_name,1) + ''%'' '
				else
					set @where = @where + ' and g.generator_name like ''%' + replace(@search_term, ' ', '%') + '%'' '
				if isNumeric(@search_term) = 1
					set @where = @where + ' ) or g.generator_id = ' + @search_term + ') '				
					
				set @where = @where + ' OR g.epa_id like ''%' + replace(@search_term, ' ', '%') + '%'' '
				set @where = @where + ' OR isnull(g.generator_city, '''') + '' '' + isnull(g.gen_mail_city, '''') like ''%' + replace(@search_term, ' ', '%') + '%'' '
				--set @where = @where + ' OR g.generator_state in (select state from #generator_state) '
				set @where = @where + ' OR isnull(g.site_code, '''') like ''%' + replace(@search_term, ' ', '%') + '%'' '					
				set @where = @where + ')'
				-- always-present conditions:
					set @where = @where + ' and g.epa_id <> ''DRUMTRANSFER'' /* and g.status = ''A'' */ '
				-- in some cases, #customer is used in a where clause, not a join...
					if (select count(*) from #customer) > 0
						set @cwhere = ' and /*prefix*/customer_id in (select customer_id from #customer) '
					else
						set @cwhere = ''			
			END		
			ELSE
			BEGIN -- begin normal 'AND' search
			
				if len(isnull(@gen_name, '')) = 0 and len(isnull(@search_term, '')) > 0
					set @gen_name = @search_term
			
				-- gen_name type matches:	
					if ltrim(rtrim(isnull(@gen_name, ''))) <> '' begin
						if isNumeric(@gen_name) = 1
							set @where = @where + ' and (( 1=1 '
						if len(@gen_name) = 1
							set @where = @where + ' and g.generator_name like ''' + @gen_name + '%'' '
						else if @gen_name = 'numbers'
							set @where = @where + ' and ''0123456789'' like ''%'' + left(g.generator_name,1) + ''%'' '
						else
							set @where = @where + ' and g.generator_name like ''%' + replace(@gen_name, ' ', '%') + '%'' '
						if isNumeric(@gen_name) = 1
							set @where = @where + ' ) or g.generator_id = ' + @gen_name + ') '
					end
			
				-- epa_id type matches:
					if ltrim(rtrim(isnull(@gen_epa_id, ''))) <> ''
						set @where = @where + ' and g.epa_id like ''%' + replace(@gen_epa_id, ' ', '%') + '%'' '

				-- city type matches:	
					if ltrim(rtrim(isnull(@generator_city, ''))) <> ''
						set @where = @where + ' and isnull(g.generator_city, '''') + '' '' + isnull(g.gen_mail_city, '''') like ''%' + replace(@generator_city, ' ', '%') + '%'' '

				-- state type matches:	
					if ltrim(rtrim(isnull(@generator_state, ''))) <> ''
						set @where = @where + ' and g.generator_state in (select state from #generator_state) '

				-- site_code type matches:	
					if ltrim(rtrim(isnull(@site_code, ''))) <> ''
						set @where = @where + ' and isnull(g.site_code, '''') like ''%' + replace(@site_code, ' ', '%') + '%'' '

				-- always-present conditions:
					set @where = @where + ' and g.epa_id <> ''DRUMTRANSFER'' /* and g.status = ''A'' */ '
					
				-- in some cases, #customer is used in a where clause, not a join...
					if (select count(*) from #customer) > 0
						set @cwhere = ' and /*prefix*/customer_id in (select customer_id from #customer) '
					else
						set @cwhere = ''			
			END


				

			

-- print @where

-- print @cwhere

	-- Major Searching Method...
	-- There are 3 types of searches possible:
	-- 1: You have a contact_id
	-- 2: You submitted a list that's now in #customers
	-- 3: You did neither of the above, but gave other search criteria.
	
	
	-- 1: You have a contact_id
	if isnull(@contact_id, '') <> '' and @contact_id <> '0' begin
		-- Minor Searching Method (@contact_id branch):
		-- 1. Generator (direct from contactxref type 'G')
		-- 2. CustomerGenerator (indirect from contactxref type 'C')
		-- 3. Profile (indirect from contactxref type 'C' to profile customer_id)
		-- 4. Profile (indirect from contactxref type 'C' to profile orig_customer_id)
		-- 5. Workorder (indirect from contactxref type 'C')
		

		-- 1. Generator (direct from contactxref type 'G')
		set @sql = 'insert #generators
			select g.generator_id 
			from contactxref cxr inner join generator g
				on cxr.contact_id = ' + @contact_id + ' and cxr.web_access = ''A'' and cxr.status = ''A'' and cxr.type = ''G''
				and cxr.generator_id = g.generator_id '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
		-- 2. CustomerGenerator (indirect from contactxref type 'C')
		set @sql = 'insert #generators
			select g.generator_id
			from contactxref cxr inner join customergenerator cg
				on cxr.contact_id = ' + @contact_id + ' and cxr.web_access = ''A'' and cxr.status = ''A'' and cxr.type = ''C''
				and cxr.customer_id = cg.customer_id
			inner join generator g on cg.generator_id = g.generator_id '
				+ @where
				+ replace(@cwhere, '/*prefix*/', 'cg.')
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
		-- 3. Profile (indirect from contactxref type 'C' to profile customer_id)
		set @sql = 'insert #generators
			select g.generator_id
			from contactxref cxr inner join profile p
				on cxr.contact_id = ' + @contact_id + ' and cxr.web_access = ''A'' and cxr.status = ''A'' and cxr.type = ''C''
				and cxr.customer_id = p.customer_id
			inner join generator g on p.generator_id = g.generator_id '
				+ @where
				+ replace(@cwhere, '/*prefix*/', 'p.')
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
		-- 4. Profile (indrect from contactxref type 'C' to profile orig_customer_id)
		set @sql = 'insert #generators
			select g.generator_id
			from contactxref cxr inner join profile p
				on cxr.contact_id = ' + @contact_id + ' and cxr.web_access = ''A'' and cxr.status = ''A'' and cxr.type = ''C''
				and cxr.customer_id = p.orig_customer_id
			inner join generator g on p.generator_id = g.generator_id '
				+ @where
				+ replace(@cwhere, '/*prefix*/', 'p.')
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)

		-- 5. Workorder (indirect from contactxref type 'C')
		set @sql = 'insert #generators
			select g.generator_id
			from contactxref cxr inner join workorderheader w
				on cxr.contact_id = ' + @contact_id + ' and cxr.web_access = ''A'' and cxr.status = ''A'' and cxr.type = ''C''
				and cxr.customer_id = w.customer_id
			inner join generator g on w.generator_id = g.generator_id '
				+ @where
				+ replace(@cwhere, '/*prefix*/', 'w.')
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
	end else if @cwhere <> '' begin

	-- 2: You submitted a list that's now in #customers
	
		-- Minor Searching Method (#customer branch):
		-- 1. CustomerGenerator (indirect from contactxref type 'C')
		-- 2. Profile (indirect from contactxref type 'C' to profile customer_id)
		-- 3. Profile (indirect from contactxref type 'C' to profile orig_customer_id)
		-- 4. Workorder (indirect from contactxref type 'C')
	
		-- 1. CustomerGenerator
		set @sql = 'insert #generators
			select g.generator_id
			from #customer c inner join customergenerator cg
				on c.customer_id = cg.customer_id
			inner join generator g on cg.generator_id = g.generator_id '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
		-- 2. Profile
		set @sql = 'insert #generators
			select g.generator_id
			from #customer c inner join profile p
				on c.customer_id = p.customer_id
			inner join generator g on p.generator_id = g.generator_id '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
		-- 3. Profile (orig_customer_id)
		set @sql = 'insert #generators
			select g.generator_id
			from #customer c inner join profile p
				on c.customer_id = p.orig_customer_id
			inner join generator g on p.generator_id = g.generator_id '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)

		-- 4. Workorder
		set @sql = 'insert #generators
			select g.generator_id
			from #customer c inner join workorderheader w
				on c.customer_id = w.customer_id
			inner join generator g on w.generator_id = g.generator_id '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
		
	end else begin
	
	-- 3: You did neither of the above, but gave other search criteria.
	
		-- Minor Searching Method (#customer branch):
		-- 1. Generator (for search criteria)

		set @sql = 'insert #generators
			select g.generator_id
			from generator g '
				+ @where
		-- print @sql
		if @debug > 0 select @sql as sql
		exec (@sql)
	end
	
	--print @sql

	
	-- #generators is now as populated as it can get.
	-- Select results out to the user.
	
	select distinct
		null as customer_id,
		g.generator_id, 
		g.generator_name, 
		g.epa_id, 
		g.generator_address_1, 
		g.generator_city, 
		g.generator_state, 
		g.generator_zip_code,
		g.site_code,
		g.site_type,
		case when ltrim(rtrim(isnull(@generator_state, ''))) <> '' or ltrim(rtrim(isnull(@generator_city, ''))) <> '' then
			g.generator_state
		else
			null
		end as ord_gs,
		
		case when ltrim(rtrim(isnull(@generator_state, ''))) <> '' or ltrim(rtrim(isnull(@generator_city, ''))) <> '' then
			g.generator_city
		else
			null
		end as ord_gc
		
		, LTRIM(RTRIM( 
            LTRIM(RTRIM(ISNULL(generator_address_1,''))) +   
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)+generator_address_2,''))) +   
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)++generator_address_3,''))) +  
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)++generator_address_4,''))) +  
            LTRIM(ISNULL(CHAR(13)+CHAR(10)++generator_address_5,'')) 
            )) as generator_address
        , emergency_phone_number
        , gen_mail_city
        , gen_mail_state
        , gen_mail_zip_code
        , LTRIM(RTRIM( 
            LTRIM(RTRIM(ISNULL(gen_mail_addr1,''))) +   
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)++gen_mail_addr2,''))) +   
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)+gen_mail_addr3,''))) +  
            LTRIM(RTRIM(ISNULL(CHAR(13)+CHAR(10)++gen_mail_addr4,''))) +  
            LTRIM(ISNULL(CHAR(13)+CHAR(10)++gen_mail_addr5,'')) 
            )) as gen_mail_address
        , g.tab
	from #generators gs
		inner join generator g on gs.generator_id = g.generator_id
	order by
		ord_gs,
		ord_gc,
		g.generator_name, 
		g.epa_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_list_by_customer_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_list_by_customer_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_list_by_customer_list] TO [EQAI]
    AS [dbo];

