CREATE PROC sp_phonelist_search (
	@search_text			varchar(40),
	@location_list			varchar(40) = null,
	@include_inactive		char(1) = null,
	@debug					int = 0
)
AS
/* ***********************************************************

	7/26/2011 - Rewrote the old one. It was slow and inaccurate.
	Simpler is better.
	
	03/05/2014 - Added user_code.  Can't believe it wasn't in here already.


sp_phonelist_search_test 'natl account mgr'
sp_phonelist_search_test 'national account manager'
sp_phonelist_search_test 'smita'
select * from users where user_name like '%smita%'

sp_phonelist_search 'jonathan', @include_inactive = 'T'
sp_phonelist_search_test 'jaz robinsen'

sp_phonelist_search 'carry durnham'
sp_phonelist_search_test 'carry durnhan'
sp_phonelist_search 'lorainne t'
sp_phonelist_search_test 'lorainne t'
sp_phonelist_search 'jon broom'
sp_phonelist_search_test 'jon broom'
sp_phonelist_search 'jonathan'
sp_phonelist_search 'j boyet'
sp_phonelist_search_test 'j boyet'
sp_phonelist_search 'liz'
sp_phonelist_search 'bob doyle'
sp_phonelist_search 'o''neill'
sp_phonelist_search 'oneill'
sp_phonelist_search 'oneil'
sp_phonelist_search 'katy o''neil'
sp_phonelist_search_test 'katy o''neil'
sp_phonelist_search 'network'
sp_phonelist_search_test 'network'
sp_phonelist_search 'belleville conference'
sp_phonelist_search_test 'belleville conference'
sp_phonelist_search 'truck wash'
sp_phonelist_search_test 'truck wash'

sp_phonelist_search 'customer service 800'
sp_phonelist_search_test 'customer service 800'

sp_phonelist_search 'atlanta'
sp_phonelist_search_test 'atlanta'

sp_phonelist_search 'atlanta, ga'
sp_phonelist_search_test 'atlanta, ga'

sp_phonelist_search 'connecticut'
sp_phonelist_search 'conn'
sp_phonelist_search 'mdi'
sp_phonelist_search 'eqis dispatch'
sp_phonelist_search_test 'eqis dispatch'

sp_phonelist_search '', '34', 1

sp_phonelist_search 'john', '9,34'
sp_phonelist_search_test 'john', '9,34'

*********************************************************** */

	if len(@search_text) = 0 and len(@location_list) = 0 return
	
	set nocount on
	
	declare 
		@orig_text varchar(40), 
		@score int, 
		@source_table varchar(20), 
		@clean_text varchar(40),
		@location_check int = 0
	
	set @location_list = replace(@location_list, ' ', ',')	
	set @orig_text = @search_text
	
	-- Clean up the search text
	set @search_text = replace(@search_text, '''', '')
	set @search_text = replace(@search_text, ',', ' ')
	set @search_text = replace(@search_text, '-', ' ')
	set @clean_text = @search_text


	-- Result storage:
	CREATE TABLE #results (
		source		varchar(40),
		score		float,
		match		varchar(200),
		id			int,
		method		varchar(100),
		searchword	varchar(200),
	)

	-- Break out locations into rows:
	create table #location (phone_list_location_id int)
	insert #location select row from dbo.fn_SplitXSVText(',', 1, @location_list) where isnull(row, '') <> ''
	if @@rowcount = 0
		insert #location select distinct phone_list_location_id from users
			union
			select distinct phone_list_location_id from PhoneListLocation
	

	-- Break out the search words into rows:
	CREATE TABLE #searchwords (
		row_id	int NOT NULL identity,
		searchword	varchar(200)
	)
	INSERT #searchwords SELECT @clean_text where not exists (select row_id from #searchwords where searchword = @clean_text)
	-- INSERT #searchwords SELECT row from dbo.fn_SplitXsvText(' ', 1, @clean_text) where not exists (select row_id from #searchwords where searchword = row)

	-- Create every other combination of the words possible:
	CREATE TABLE #permutation (
		row_id	int NOT NULL identity,
		word		varchar(200)
	)
	INSERT #permutation SELECT row from dbo.fn_SplitXsvText(' ', 1, @clean_text)

	declare 
		@ranstrip int = 0, -- flag to mark if we've re-run CreateVariety without first/last chars yet.
		@select varchar(max) = 'ltrim(rtrim('' '' ', 
		@from varchar(max) = ' from #permutation a1 ', 
		@where varchar(max) = ' where 1=1 ', 
		@i int = 1,
		@counter int = 0, 
		@thisword varchar(200)

	-- Create Variety from #Permutation:
	CreateVariety:
		select 
			@select = 'ltrim(rtrim('' '' ', 
			@from = ' from #permutation a1 ', 
			@where = ' where 1=1 ', 
			@i = 1
			
		while @i <= (select max(row_id) from #permutation) begin
			select 
				@select = @select + '+ a' + convert(varchar(4), @i) + '.word + '' '' ',
				@from = @from + case when @i = 1 then '' else ' cross join #permutation a' + convert(varchar(4), @i) end,
				@where = @where + case when @i = 1 then '' else ' and a' + convert(varchar(4), @i-1) + '.word <> a' + convert(varchar(4), @i) + '.word and (a' + convert(varchar(4), @i) + '.row_id > a' + convert(varchar(4), @i-1) + '.row_id or a' + convert(varchar(4), @i-1) + '.word = '' '')' end + ' ',
				@i = @i + 1
		end
		select
			@select = @select + '))',
			@where = @where + 'and ' + @select + ' not like ''%  %'' ',
			@select = 'select distinct /* plt_export.dbo.NeedlemanWunch(' + @select + ', ''' + @clean_text + ''') */ 1 as score, ' + @select + ' as term '

		if (select count(*) from #permutation ) > 1		
			insert #permutation values (' ')

		exec('insert #searchwords select term from (' + @select + @from + @where + ') terms where not exists (select row_id from #searchwords where searchword = term) and len(ltrim(rtrim(term))) > 2 order by terms.score desc')
	-- Variety done.

	-- Also: Strip first/last chars off words.  Should fix account vs accounts junk.
		if (select count(*) from #permutation ) > 1	and @ranstrip = 0 begin
			set @ranstrip = 1
			delete from #permutation where word = ' '
			update #permutation set word = substring(word, 2, len(word)-2)
			where len(word) > 2
			goto CreateVariety
		end
		

	IF @debug > 0 BEGIN
		PRINT 'Search Words List:'
		SELECT * FROM #searchwords
	end

WHILE EXISTS (select 1 FROM #searchwords WHERE row_id > @counter) BEGIN
	SET @counter = @counter + 1
	SELECT @thisword = searchword FROM #searchwords WHERE row_id = @counter

	-- plain words: exact text match
	set @score = 200
	insert #results
	SELECT 'Users' as source, @score-0 as score, u.user_name, u.user_id, 'exact whole name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.user_name = @thisword
	and isnull(u.user_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-10 as score, u.last_name, u.user_id, 'exact last name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.last_name = @thisword
	and isnull(u.last_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, u.first_name, u.user_id, 'exact first name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.first_name = @thisword
	and isnull(u.first_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, n.match, u.user_id, 'exact first nickname' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	inner join nickname n on u.first_name = n.name
	where (@include_inactive = 'T' or group_id > 0)
	and n.match = @thisword
	and isnull(n.match, '') <> ''
	union all
	SELECT 'Users' as source, @score-30 as score, u.alias_name, u.user_id, 'exact alias name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.alias_name = @thisword
	and isnull(u.alias_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-40 as score, u.title, u.user_id, 'exact title' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.title = @thisword
	and isnull(u.title, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.phone, u.user_id, 'exact phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.phone = @thisword
	and isnull(u.phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.fax, u.user_id, 'exact fax' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.fax = @thisword
	and isnull(u.fax, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.pager, u.user_id, 'exact pager' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.pager = @thisword
	and isnull(u.pager, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.cell_phone, u.user_id, 'exact cell_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.cell_phone = @thisword
	and isnull(u.cell_phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.internal_phone, u.user_id, 'exact internal_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.internal_phone = @thisword
	and isnull(u.internal_phone, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-0 as score, pli.name, pli.item_id, 'exact name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pli.name = @thisword
	and isnull(pli.name, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-30 as score, pli.alias_name, pli.item_id, 'exact alias_name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pli.alias_name = @thisword
	and isnull(pli.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-0 as score, pll.name, pll.phone_list_location_id, 'exact name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.name = @thisword
	and isnull(pll.name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.name,  pll.phone_list_location_id, 'exact alias_name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.alias_name = @thisword
	and isnull(pll.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.city,  pll.phone_list_location_id, 'exact city' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.city = @thisword
	and isnull(pll.city, '') <> ''
	

	-- plain words, LIKE: 
	set @score = 100
	insert #results
	SELECT 'Users' as source, @score-0 as score, u.user_name, u.user_id, 'like whole name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.user_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.user_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-10 as score, u.last_name, u.user_id, 'like last name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.last_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.last_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, u.first_name, u.user_id, 'like first name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.first_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.first_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, n.match, u.user_id, 'like first nickname' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	inner join nickname n on u.first_name = n.name
	where (@include_inactive = 'T' or group_id > 0)
	and n.match LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(n.match, '') <> ''
	union all
	SELECT 'Users' as source, @score-30 as score, u.alias_name, u.user_id, 'like alias name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.alias_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.alias_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-40 as score, u.title, u.user_id, 'like title' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.title LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.title, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.phone, u.user_id, 'like phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.phone LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.fax, u.user_id, 'like fax' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.fax LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.fax, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.pager, u.user_id, 'like pager' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.pager LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.pager, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.cell_phone, u.user_id, 'like cell_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.cell_phone LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.cell_phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.internal_phone, u.user_id, 'like internal_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and u.internal_phone LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(u.internal_phone, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-0 as score, pli.name, pli.item_id, 'like name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pli.name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(pli.name, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-30 as score, pli.alias_name, pli.item_id, 'like alias_name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pli.alias_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(pli.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-0 as score, pll.name, pll.phone_list_location_id, 'like name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(pll.name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.name,  pll.phone_list_location_id, 'like alias_name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.alias_name LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(pll.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.city,  pll.phone_list_location_id, 'like city' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where pll.city LIKE '%' + replace(@thisword, ' ', '%') + '%'
	and isnull(pll.city, '') <> ''


	-- plain words, LIKE, reversed: 
	set @score = 100
	insert #results
	SELECT 'Users' as source, @score-0 as score, u.user_name, u.user_id, 'reverse-like whole name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.user_name, ' ', '%') + '%'
	and isnull(u.user_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-10 as score, u.last_name, u.user_id, 'reverse-like last name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.last_name, ' ', '%') + '%'
	and isnull(u.last_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, u.first_name, u.user_id, 'reverse-like first name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.first_name, ' ', '%') + '%'
	and isnull(u.first_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-20 as score, n.match, u.user_id, 'reverse-like first nickname' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	inner join nickname n on u.first_name = n.name
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(n.match, ' ', '%') + '%'
	and isnull(n.match, '') <> ''
	union all
	SELECT 'Users' as source, @score-30 as score, u.alias_name, u.user_id, 'reverse-like alias name' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.alias_name, ' ', '%') + '%'
	and isnull(u.alias_name, '') <> ''
	union all
	SELECT 'Users' as source, @score-40 as score, u.title, u.user_id, 'reverse-like title' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.title, ' ', '%') + '%'
	and isnull(u.title, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.phone, u.user_id, 'reverse-like phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.phone, ' ', '%') + '%'
	and isnull(u.phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.fax, u.user_id, 'reverse-like fax' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.fax, ' ', '%') + '%'
	and isnull(u.fax, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.pager, u.user_id, 'reverse-like pager' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.pager, ' ', '%') + '%'
	and isnull(u.pager, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.cell_phone, u.user_id, 'reverse-like cell_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.cell_phone, ' ', '%') + '%'
	and isnull(u.cell_phone, '') <> ''
	union all
	SELECT 'Users' as source, @score-0 as score, u.internal_phone, u.user_id, 'reverse-like internal_phone' as method, @thisword as searchword
	from users u
	inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where (@include_inactive = 'T' or group_id > 0)
	and @thisword LIKE '%' + replace(u.internal_phone, ' ', '%') + '%'
	and isnull(u.internal_phone, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-0 as score, pli.name, pli.item_id, 'reverse-like name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where @thisword LIKE '%' + replace(pli.name, ' ', '%') + '%'
	and isnull(pli.name, '') <> ''
	union all
	SELECT 'PhoneListItem' as source, 5*@score-30 as score, pli.alias_name, pli.item_id, 'reverse-like alias_name' as method, @thisword as searchword
	from PhoneListItem pli
	inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where @thisword LIKE '%' + replace(pli.alias_name, ' ', '%') + '%'
	and isnull(pli.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-0 as score, pll.name, pll.phone_list_location_id, 'reverse-like name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where @thisword LIKE '%' + replace(pll.name, ' ', '%') + '%'
	and isnull(pll.name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.name,  pll.phone_list_location_id, 'reverse-like alias_name' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where @thisword LIKE '%' + replace(pll.alias_name, ' ', '%') + '%'
	and isnull(pll.alias_name, '') <> ''
	union all
	SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.city,  pll.phone_list_location_id, 'reverse-like city' as method, @thisword as searchword
	from PhoneListLocation pll
	inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
	where @thisword LIKE '%' + replace(pll.city, ' ', '%') + '%'
	and isnull(pll.city, '') <> ''

	if (select count(*) from #results where score >= 300) = 0 begin
		-- plain words: cruddy SQL soundex (sounds like)
		set @score = 50
		insert #results
		SELECT 'Users' as source, @score-0 as score, u.user_name, u.user_id, 'exact whole name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.user_name, @thisword) = 4
		and isnull(u.user_name, '') <> ''
		union all
		SELECT 'Users' as source, @score-10 as score, u.last_name, u.user_id, 'exact last name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.last_name, @thisword) = 4
		and isnull(u.last_name, '') <> ''
		union all
		SELECT 'Users' as source, @score-20 as score, u.first_name, u.user_id, 'exact first name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.first_name, @thisword) = 4
		and isnull(u.first_name, '') <> ''
		union all
		SELECT 'Users' as source, @score-20 as score, n.match, u.user_id, 'exact first nickname' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		inner join nickname n on u.first_name = n.name
		where (@include_inactive = 'T' or group_id > 0)
		and difference(n.match, @thisword) = 4
		and isnull(n.match, '') <> ''
		union all
		SELECT 'Users' as source, @score-30 as score, u.alias_name, u.user_id, 'exact alias name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.alias_name, @thisword) = 4
		and isnull(u.alias_name, '') <> ''
		union all
		SELECT 'Users' as source, @score-40 as score, u.title, u.user_id, 'exact title' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.title, @thisword) = 4
		and isnull(u.title, '') <> ''
		union all
		SELECT 'PhoneListItem' as source, 5*@score-0 as score, pli.name, pli.item_id, 'exact name' as method, @thisword as searchword
		from PhoneListItem pli
		inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where difference(pli.name, @thisword) = 4
		and isnull(pli.name, '') <> ''
		union all
		SELECT 'PhoneListItem' as source, 5*@score-30 as score, pli.alias_name, pli.item_id, 'exact alias_name' as method, @thisword as searchword
		from PhoneListItem pli
		inner join #location l on isnull(pli.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where difference(pli.alias_name, @thisword) = 4
		and isnull(pli.alias_name, '') <> ''
		union all
		SELECT 'PhoneListLocation' as source, 5*@score-0 as score, pll.name, pll.phone_list_location_id, 'exact name' as method, @thisword as searchword
		from PhoneListLocation pll
		inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where difference(pll.name, @thisword) = 4
		and isnull(pll.name, '') <> ''
		union all
		SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.name,  pll.phone_list_location_id, 'exact alias_name' as method, @thisword as searchword
		from PhoneListLocation pll
		inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where difference(pll.alias_name, @thisword) = 4
		and isnull(pll.alias_name, '') <> ''
		union all
		SELECT 'PhoneListLocation' as source, 5*@score-30 as score, pll.city,  pll.phone_list_location_id, 'exact city' as method, @thisword as searchword
		from PhoneListLocation pll
		inner join #location l on isnull(pll.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where difference(pll.city, @thisword) = 4
		and isnull(pll.city, '') <> ''
			
			
			
		insert #results
		SELECT 'Users' as source, @score-0 as score, u.user_name, u.user_id, 'soundex whole name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.user_name, @thisword) = 4
		union all
		SELECT 'Users' as source, @score-10 as score, u.last_name, u.user_id, 'soundex last name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.last_name, @thisword) = 4
		union all
		SELECT 'Users' as source, @score-20 as score, u.first_name, u.user_id, 'soundex first name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.first_name, @thisword) = 4
		union all
		SELECT 'Users' as source, @score-20 as score, n.match, u.user_id, 'soundex first nickname' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		inner join nickname n on u.first_name = n.name
		where (@include_inactive = 'T' or group_id > 0)
		and difference(n.match, @thisword) = 4
		union all
		SELECT 'Users' as source, @score-30 as score, u.alias_name, u.user_id, 'soundex alias name' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.alias_name, @thisword) = 4
		union all
		SELECT 'Users' as source, @score-40 as score, u.title, u.user_id, 'soundex title' as method, @thisword as searchword
		from users u
		inner join #location l on isnull(u.phone_list_location_id, -54321) = isnull(l.phone_list_location_id, -54321)
		where (@include_inactive = 'T' or group_id > 0)
		and difference(u.title, @thisword) = 4
	end

END

IF @debug > 0 BEGIN
	PRINT 'Prelim Results:'
	SELECT * FROM #results ORDER BY score desc
end

SELECT sum(score) AS sum_score, id
INTO #sumresults
FROM #results
GROUP BY source, id

IF @debug > 0 BEGIN
	PRINT 'Summed Result Scores:'
	SELECT * FROM #sumresults
end

declare @best float, @min_score float
select @best = max(sum_score) from #sumresults
set @min_score = -100
set nocount off

/*
SELECT round(sum(score),0), u.user_id, u.user_code, u.group_id, user_name,first_name,last_name,user_code,title,phone,fax,cell_phone,pager,alias_name
from #results inner join users u on #results.user_id = u.user_id
group by  u.user_id, u.user_code, u.group_id, user_name,first_name,last_name,user_code,title,phone,fax,cell_phone,pager,alias_name
HAVING sum(score) >= (@best /4)
order by round(sum(score),0) desc, last_name, first_name

*/

	SELECT distinct
		'users' as type,
		users.user_code,
		users.first_name, 
		users.last_name, 
		users.alias_name,
		users.title,
		Department.department_description,
		case when users.group_id = 0 then '(Terminated)' else '' end as Terminated_Status,
		users.addr1, 
		users.addr2, 
		users.addr3, 
		users.internal_phone, 
		users.phone, 
		users.fax, 
		users.pager, 
		users.email, 
		users.cell_phone, 
		users.pic_url,
		pll.name as location_name,
		pll.address_1 as location_address_1,
		pll.address_2 as location_address_2,		
		pll.address_3 as location_address_3,
		pll.city as location_city,
		pll.state as location_state,
		pll.zip_code as location_zip_code,
		pll.phone as location_phone,
		pll.toll_free_phone as location_toll_free_phone,	
		pll.fax as location_fax,
		pll.comment as location_comment,
		pll.internal_phone as location_internal_phone,
		pll.short_name as location_short_name,
		f.id,
		sum(f.score)
		/* select list */
	FROM #Results f
	INNER JOIN users on f.id = users.user_id and f.source = 'users'
	LEFT OUTER JOIN PhoneListLocation pll on users.phone_list_location_id = pll.phone_list_location_id
	LEFT OUTER JOIN Department on users.department_id = Department.department_id
	/* from-clause */
	WHERE (@include_inactive = 'T' or (users.group_id > 0 and users.phone_list_flag = 'A'))
	/* where-clause */
	GROUP BY
		users.user_code,
		users.first_name, 
		users.last_name, 
		users.alias_name,
		users.title,
		Department.department_description,
		users.group_id,
		users.addr1, 
		users.addr2, 
		users.addr3, 
		users.internal_phone, 
		users.phone, 
		users.fax, 
		users.pager, 
		users.email, 
		users.cell_phone, 
		users.pic_url,
		pll.name,
		pll.address_1,
		pll.address_2,
		pll.address_3,
		pll.city,
		pll.state,
		pll.zip_code,
		pll.phone,
		pll.toll_free_phone,
		pll.fax,
		pll.comment,
		pll.internal_phone,
		pll.short_name,
		f.id
	HAVING
		sum(f.score) > @min_score
		
	UNION ALL
	SELECT distinct
		'PhoneListItem' as type,						-- 'users' as type,
		null,											-- users.user_code,
		null,											-- users.first_name, 
		PhoneListItem.name,								-- users.last_name, 
		PhoneListItem.alias_name,						-- users.alias_name,
		null,											-- users.title,
		null,											-- Department.department_description,
		null,											-- case when users.group_id = 0 then ' - Terminated' el
		null,											-- users.addr1, 
		null,											-- users.addr2, 
		null,											-- users.addr3, 
		PhoneListItem.internal_phone,					-- users.internal_phone, 
		PhoneListItem.phone,							-- users.phone, 
		PhoneListItem.fax,								-- users.fax, 
		null,											-- users.pager, 
		null,											-- users.email, 
		null,											-- users.cell_phone, 
		null,											-- users.pic_url,
		pll.name,										-- pll.name as location_name,
		pll.address_1,									-- pll.address_1 as location_address_1,
		pll.address_2,									-- pll.address_2 as location_address_2,		
		pll.address_3,									-- pll.address_3 as location_address_3,
		pll.city,										-- pll.city as location_city,
		pll.state,										-- pll.state as location_state,
		pll.zip_code,									-- pll.zip_code as location_zip_code,
		pll.phone,										-- pll.phone as location_phone,
		pll.toll_free_phone,							-- pll.toll_free_phone as location_toll_free_phone,	
		pll.fax,										-- pll.fax as location_fax,
		pll.comment,									-- pll.comment as location_comment,
		pll.internal_phone,								-- pll.internal_phone as location_internal_phone,
		pll.short_name,									-- pll.short_name as location_short_name,
		f.id,											-- f.id,
		sum(f.score)									-- sum(f.score)
		/* select list */									
	FROM #Results f											
	INNER JOIN PhoneListItem on f.id = PhoneListItem.item_id and f.source = 'PhoneListItem'
	LEFT OUTER JOIN PhoneListLocation pll on PhoneListItem.phone_list_location_id = pll.phone_list_location_id
	/* from-clause */
	GROUP BY
		PhoneListItem.name, 
		PhoneListitem.alias_name,
		PhoneListItem.internal_phone, 
		PhoneListItem.phone, 
		PhoneListItem.fax, 
		pll.name,
		pll.address_1,
		pll.address_2,
		pll.address_3,
		pll.city,
		pll.state,
		pll.zip_code,
		pll.phone,
		pll.toll_free_phone,
		pll.fax,
		pll.comment,
		pll.internal_phone,
		pll.short_name,
		f.id
	HAVING
		sum(f.score) > @min_score
		
	UNION ALL
	SELECT distinct
		'PhoneListLocation' as type,						-- 'users' as type,
		null,												-- users.user_code,
		null,												-- users.first_name, 
		PhoneListLocation.name,								-- users.last_name, 
		PhoneListLocation.alias_name,						-- users.alias_name,
		null,												-- users.title,
		null,												-- Department.department_description,
		null,												-- case when users.group_id = 0 then ' - Terminated'
		PhoneListLocation.address_1,						-- users.addr1, 
		PhoneListLocation.address_2,						-- users.addr2, 
		PhoneListLocation.address_3,						-- users.addr3, 
		PhoneListLocation.internal_phone,					-- users.internal_phone, 
		PhoneListLocation.phone,							-- users.phone, 
		PhoneListLocation.fax,								-- users.fax, 
		null,												-- users.pager, 
		null,												-- users.email, 
		null,												-- users.cell_phone, 
		null,												-- users.pic_url,
		pll.name as location_name,							-- pll.name as location_name,
		pll.address_1 as location_address_1,				-- pll.address_1 as location_address_1,
		pll.address_2 as location_address_2,				-- pll.address_2 as location_address_2,		
		pll.address_3 as location_address_3,				-- pll.address_3 as location_address_3,
		pll.city as location_city,							-- pll.city as location_city,
		pll.state as location_state,						-- pll.state as location_state,
		pll.zip_code as location_zip_code,					-- pll.zip_code as location_zip_code,
		pll.phone as location_phone,						-- pll.phone as location_phone,
		pll.toll_free_phone as location_toll_free_phone,	-- pll.toll_free_phone as location_toll_free_phone,	
		pll.fax as location_fax,							-- pll.fax as location_fax,
		pll.comment,										-- pll.comment as location_comment,
		pll.internal_phone,									-- pll.internal_phone as location_internal_phone,
		pll.short_name,										-- pll.short_name as location_short_name,
		f.id,												-- f.id,
		sum(f.score)										-- sum(f.score)
		/* select list */
	FROM #Results f
	INNER JOIN PhoneListLocation on f.id = PhoneListLocation.phone_list_location_id and f.source = 'PhoneListLocation'
	LEFT OUTER JOIN PhoneListLocation pll on f.id = pll.phone_list_location_id
	/* from-clause */
	GROUP BY
		PhoneListLocation.name, 
		PhoneListLocation.alias_name, 
		PhoneListLocation.address_1, 
		PhoneListLocation.address_2, 
		PhoneListLocation.address_3, 
		PhoneListLocation.internal_phone, 
		PhoneListLocation.phone, 
		PhoneListLocation.fax, 
		pll.name,
		pll.address_1,
		pll.address_2,
		pll.address_3,
		pll.city,
		pll.state,
		pll.zip_code,
		pll.phone,
		pll.toll_free_phone,
		pll.fax,
		pll.comment,
		pll.internal_phone,
		pll.short_name,
		f.id
	HAVING
		sum(f.score) > @min_score
		
	ORDER BY 
	/* order-clause */
	sum(f.score) desc,
	last_name, 
	first_name




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_phonelist_search] TO [EQAI]
    AS [dbo];

