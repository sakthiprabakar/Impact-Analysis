-- drop proc sp_reports_generator_onboarding_summary
go

create proc sp_reports_generator_onboarding_summary (
	@customer_id		int					= -1
	, @generator_id		int					= -1
	, @site_type_list	varchar(max)		= ''
	, @generator_state_list	varchar(max)	= ''
	, @generator_country_list	varchar(max)	= ''
	, @contact_id		int = 0
	, @search_field		varchar(40) = null
	, @search_value		varchar(100) = null
    , @sort				varchar(20) = 'Site Type'
		/* options: Site Type, Generator Name, EPA ID, City, State, Country, Percentage */
    , @page				int = -1	-- -1 defaults cause paging to be ignored since this was an 
    , @perpage			int = -1	-- existing SP used already in other cases that don't expect paging
    , @excel_output		int = 0 -- or 1
    , @customer_id_list varchar(max)=''  
    , @generator_id_list varchar(max)=''  
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_summary

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report

Query Type		Returns
-----------------------
percent_done	1 row, 1 field: The percentage of onboarding tasks done


select * from generator g where g.generator_state = 'TX' and g.generator_city = 'Fort Worth'
and g.generator_name like '%general%'

select site_type, * from generator where site_type is not null and site_type like 'GE %'
--3 options
--generator_id
--117871
--168770
--169109

	@generator_id		int	= 168770 

sp_reports_generator_onboarding_summary @site_type_list='GE Aviation,GE Healthcare,GE Oil & Gas,GE Power,GE Transportation, GE Transportation', @contact_id=-1

select * from GeneratorSiteType

---  Onboarding percentage calculation for all site types
select g.site_type, g.generator_id, g.generator_name, g.generator_city, g.generator_state, g.generator_country, sum(gtd.overall_percentage) from generatortimelineheader gth 
join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
join generator g 
	on gth.generator_id = g.generator_id
where 
--gth.generator_id = 168770--@generator_id
g.site_type in ( select generator_site_type from generatorsitetype where generator_site_type like 'GE %' )
and gtd.parent_task_id is null
and gtd.task_external_view = 'Y'
and gtd.task_actual_end is not null
group by g.generator_id, g.site_type, g.generator_name, g.generator_city, g.generator_state, g.generator_country
order by g.site_type

168770

exec sp_reports_generator_onboarding_summary
	@customer_id		= -1
	, @generator_id	= -1
	, @site_type_list	= 'GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas'
	, @generator_state_list	= ''
	, @generator_country_list	= ''
	, @contact_id		= -1 -- associates
	, @search_field = 'generator_name'
	, @search_value = ''
    , @page				= 1	-- -1 defaults cause paging to be ignored since this was an 
    , @perpage			= 20	-- existing SP used already in other cases that don't expect paging
    , @excel_output		= 1

    , @sort				= 'City'
		/* options: Site Type, Generator Name, EPA ID, City, State, Country, Percentage */
    , @page				= 1	-- -1 defaults cause paging to be ignored since this was an 
    , @perpage			= 20	-- existing SP used already in other cases that don't expect paging
    , @excel_output		int = 0 -- or 1


**************************************************************************** */
-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@i_search_field		varchar(40) = isnull(@search_field, ''),
		@i_search_value		varchar(100) = replace(replace(isnull(@search_value, ''), '''', ''''''), ' ', '%'),
		@i_sort				varchar(20) = isnull(@sort, ''),
		@i_page				int = isnull(@page, -1),
		@i_perpage			int = isnull(@perpage, -1)
		
/*
	So it turns out that I created this SP, then had to duplicate the logic in
	sp_reports_GE_generator_timeline_master.  And that "master" sp does the same things
	but then got improvements, AND it only returns a list of generator_ids.
	
	I've decided to avoid having 2 copies of the logic when one is better than the other
	so I'm calling sp_reports_GE_generator_timeline_master and passing it this sp's
	inputs, retrieving its list of generator_ids for use in this data return.
	

-- Handle text inputs into temp tables
	CREATE TABLE #SiteType (generator_site_type varchar(40))
	INSERT #SiteType SELECT row from dbo.fn_SplitXsvText(',', 1, @site_type_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #State (abbr varchar(2))
	INSERT #State SELECT row from dbo.fn_SplitXsvText(',', 1, @generator_state_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #country (country varchar(3))
	INSERT #country SELECT row from dbo.fn_SplitXsvText(',', 1, @generator_country_list) WHERE ISNULL(row, '') <> ''


-- figure out if this user has inherent access to customers
	CREATE TABLE #generator (generator_id int)
	
	IF @contact_id > 0
	BEGIN
		insert #generator
		select cg.generator_id
		from CustomerGenerator cg
		inner join ContactXRef cxr on cg.customer_id = cxr.customer_id
		Where cxr.contact_id = @contact_id
		AND cxr.status = 'A' and cxr.web_access = 'A'
		union
		select cxr.generator_id
		from ContactXRef cxr
		Where cxr.contact_id = @contact_id
		AND cxr.status = 'A' and cxr.web_access = 'A' 
		
		select @genCount = count(*) from #generator
	END

	IF @contact_id = -1 -- Associates:
	BEGIN
		if not (@customer_id = -1 and @generator_id = -1 and @site_type_list = '' and @generator_state_list = '' and @generator_country_list = '') 
		begin
			insert #generator
			select cg.generator_id
			from CustomerGenerator cg
			Where cg.customer_id = @customer_id
			union
			select g.generator_id
			from Generator g
			Where generator_id = @generator_id
			union
			select g.generator_id
			from Generator g
			Where site_type in (select generator_site_type from #SiteType)
		
			set @genCount = @@rowcount
		end
	END

-- abort if there's nothing possible to see
	if @genCount + 
		(select count(*) from #SiteType) +
		(select count(*) from #State)
		= 0 RETURN

	IF @genCount <= 0
		RETURN

	if (select count(*) from #SiteType) > 0
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join generator g2 on g1.generator_id = g2.generator_id
			where g2.site_type in (select generator_site_type FROM #SiteType)
		)
	
	if (select count(*) from #State) > 0
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join generator g2 on g1.generator_id = g2.generator_id
			where g2.generator_state in (select abbr FROM #State)
		)

	if (select count(*) from #country) > 0
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join generator g2 on g1.generator_id = g2.generator_id
			where g2.generator_country in (select country FROM #country)
		)

Re-using Timeline Master for the criteria:
*/

	CREATE TABLE #generator (generator_id int)

	declare -- This amounts to parameter spoofing too, to avoid bad cached execution plans:
	@Icustomer_id		varchar(max)		= convert(varchar(max), @customer_id)
	, @Igenerator_id	varchar(max)		= convert(varchar(max), @generator_id)
	, @Isite_type_list	varchar(max)		= @site_type_list
	, @Igenerator_state_list	varchar(max)	= @generator_state_list
	, @Igenerator_country_list	varchar(max)	= @generator_country_list
	, @Icontact_id		int = @contact_id
    , @Icustomer_id_list varchar(max)= @customer_id_list + isnull(',' + convert(varchar(max), @customer_id), '')
    , @Igenerator_id_list varchar(max)= @generator_id_list + isnull(',' + convert(varchar(max), @generator_id), '')

	insert #Generator
	exec sp_reports_generator_criteria_master
		@customer_id_list		= @Icustomer_id_list
		, @generator_id_list	= @Igenerator_id_list
		, @site_type_list	= @Isite_type_list
		, @generator_state_list	= @Igenerator_state_list
		, @generator_country_list	= @Igenerator_country_list
		, @contact_id		= @Icontact_id


-- Setup is finished.  On to work:

-- COR Search handling

	-- Limit choices to output fields
	if @i_search_field not in ('site_type','generator_id','epa_id','generator_name','generator_city','generator_state','generator_country')
		set @i_search_field = ''

	if @i_search_field <> '' and @i_search_value <> '' begin
		-- The only fields we return that are searchable are generator fields, so this is straight-forward

		declare  @foo table (generator_id int)
		insert @foo
		select x.generator_id from #generator x
			join generator g on x.generator_id = g.generator_id
		where 1 = 
			case when @i_search_field = 'site_type' and g.site_type like '%' + @i_search_value + '%' then 1 else
				case when @i_search_field = 'generator_id' and g.generator_id = convert(int, @i_search_value) then 1 else
					case when @i_search_field = 'epa_id' and g.epa_id like '%' + @i_search_value + '%' then 1 else
						case when @i_search_field = 'generator_name' and g.generator_name like '%' + @i_search_value + '%' then 1 else
							case when @i_search_field = 'generator_city' and g.generator_city like '%' + @i_search_value + '%' then 1 else
								case when @i_search_field = 'generator_state' and g.generator_state like '%' + @i_search_value + '%' then 1 else
									case when @i_search_field = 'generator_country' and g.generator_country like '%' + @i_search_value + '%' then 1 else
										0
									end
								end
							end
						end
					end
				end
			end

		delete from #generator
		insert #generator select generator_id from @foo
		
	end

---  Onboarding percentage calculation for all site types
select 
	g.site_type
	, g.generator_id
	, g.epa_id
	, g.generator_name
	, g.generator_city
	, g.generator_state
	, g.generator_country
	, sum(gtd.overall_percentage) percentage 
    , _row = row_number() over (order by 
        case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
        case when isnull(@i_sort, '') = 'EPA ID' then g.epa_id end asc,
        case when isnull(@i_sort, '') = 'City' then g.generator_city end asc,
        case when isnull(@i_sort, '') = 'State' then g.generator_state end asc,
        case when isnull(@i_sort, '') = 'Country' then g.generator_country end asc,
        case when isnull(@i_sort, '') = 'Percentage' then sum(gtd.overall_percentage) end desc,
        case when isnull(@i_sort, '') in ('', 'Site Type') then  g.site_type end asc
    ) 
into #foo
from generatortimelineheader gth 
join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
join generator g 
	on gth.generator_id = g.generator_id
join #generator gen on g.generator_id = gen.generator_id
where 
--gth.generator_id = 168770--@generator_id
1=1 
and gtd.parent_task_id is null
and gtd.task_external_view = 'Y'
and gtd.task_actual_end is not null
group by g.generator_id, g.epa_id,g.site_type, g.generator_name, g.generator_city, g.generator_state, g.generator_country




select *
, (select count(*) from #foo) as total_count
from #foo x
where (
	isnull(@excel_output,0) = 1
	OR
	@page = -1 
	OR 
	_row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage))
order by _row



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_summary] TO [EQAI]
    AS [dbo];

