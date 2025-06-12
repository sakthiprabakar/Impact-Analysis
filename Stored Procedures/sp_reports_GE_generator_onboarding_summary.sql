
create proc sp_reports_GE_generator_onboarding_summary (
	@customer_id		int					= -1
	, @generator_id		int					= -1
	, @site_type_list	varchar(max)		= ''
	, @generator_state_list	varchar(max)	= ''
	, @generator_country_list	varchar(max)	= ''
	, @contact_id		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */ 
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_summary

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

sp_reports_GE_generator_onboarding_summary @site_type_list='GE Aviation,GE Healthcare,GE Oil & Gas,GE Power,GE Transportation, GE Transportation', @contact_id=-1

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

exec sp_reports_GE_generator_onboarding_summary
	@customer_id		= -1
	, @generator_id	= -1
	, @site_type_list	= 'GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas'
	, @generator_state_list	= ''
	, @generator_country_list	= ''
	, @contact_id		= -1 -- associates

**************************************************************************** */
-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@genCount 		INT = 0

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

	insert #Generator
	exec sp_reports_GE_generator_criteria_master
		@customer_id_list		= @Icustomer_id
		, @generator_id_list	= @Igenerator_id
		, @site_type_list	= @Isite_type_list
		, @generator_state_list	= @Igenerator_state_list
		, @generator_country_list	= @Igenerator_country_list
		, @contact_id		= @Icontact_id


-- Setup is finished.  On to work:

---  Onboarding percentage calculation for all site types
select g.site_type, g.generator_id, g.epa_id, g.generator_name, g.generator_city, g.generator_state, g.generator_country, sum(gtd.overall_percentage) percentage from generatortimelineheader gth 
join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
join generator g 
	on gth.generator_id = g.generator_id
join #generator gen on g.generator_id = gen.generator_id
where 
--gth.generator_id = 168770--@generator_id
g.site_type in ( select generator_site_type from generatorsitetype where generator_site_type like 'GE %' )
and gtd.parent_task_id is null
and gtd.task_external_view = 'Y'
and gtd.task_actual_end is not null
group by g.generator_id, g.epa_id,g.site_type, g.generator_name, g.generator_city, g.generator_state, g.generator_country
order by g.site_type


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_summary] TO [EQAI]
    AS [dbo];

