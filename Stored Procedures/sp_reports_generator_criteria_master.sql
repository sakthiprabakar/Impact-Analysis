-- drop proc sp_reports_generator_criteria_master
go

create proc sp_reports_generator_criteria_master (
	@customer_id_list		varchar(max)		= '-1'
	, @generator_id_list	varchar(max)		= '-1'
	, @site_type_list		varchar(max)		= ''
	, @generator_state_list	varchar(max)		= ''
	, @generator_country_list	varchar(max)		= ''
	, @contact_id			int					= 0
)
as
/* ****************************************************************************
sp_reports_generator_criteria_master

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report
This started out as a copy of sp_reports_GE_generator_onboarding_summary - same inputs/filter logic.
As sp_reports_generator_criteria_master, all it has to do is return generator_id.


exec sp_reports_generator_criteria_master
	@customer_id_list		= '-1'
	, @generator_id_list	= '169208'
	, @site_type_list	= 'GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas'
	, @generator_state_list	= ''
	, @generator_country_list	= ''
	, @contact_id		= -1 -- associates

select * from GeneratorSiteType


exec sp_reports_generator_criteria_master
	@customer_id_list		= '583'
	, @generator_id_list	= '-1'
	, @site_type_list	= ''
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


	DECLARE @icustomer_id_list		varchar(max)		= ltrim(rtrim(@customer_id_list))
	, @igenerator_id_list	varchar(max)		= ltrim(rtrim(@generator_id_list))
	, @isite_type_list		varchar(max)		= ltrim(rtrim(@site_type_list))
	, @igenerator_state_list	varchar(max)		= ltrim(rtrim(@generator_state_list))
	, @igenerator_country_list	varchar(max)		= ltrim(rtrim(@generator_country_list))
	, @icontact_id			int					= @contact_id


-- Handle text inputs into temp tables
	CREATE TABLE #CustomerInput (customer_id int)
	INSERT #CustomerInput SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 1, @icustomer_id_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #GeneratorInput (generator_id int)
	INSERT #GeneratorInput SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 1, @igenerator_id_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #SiteType (generator_site_type varchar(40))
	INSERT #SiteType SELECT row from dbo.fn_SplitXsvText(',', 1, @isite_type_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #State (abbr varchar(2))
	INSERT #State SELECT row from dbo.fn_SplitXsvText(',', 1, @igenerator_state_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #country (country varchar(3))
	INSERT #country SELECT row from dbo.fn_SplitXsvText(',', 1, @igenerator_country_list) WHERE ISNULL(row, '') <> ''


-- figure out if this user has inherent access to customers
	CREATE TABLE #generator (generator_id int)
	
	IF @icontact_id > 0
	BEGIN
		insert #generator
		select cg.generator_id
		from CustomerGenerator cg
		inner join ContactXRef cxr on cg.customer_id = cxr.customer_id
		Where cxr.contact_id = @icontact_id
		AND cxr.status = 'A' and cxr.web_access = 'A'
		union
		select cxr.generator_id
		from ContactXRef cxr
		Where cxr.contact_id = @icontact_id
		AND cxr.status = 'A' and cxr.web_access = 'A' 
		
		if not exists (select 1 from #generator)
			insert #generator
			select distinct generator_id
			from generator
			-- where site_type like 'GE %'
			
		select @genCount = count(*) from #generator
	END

	IF @icontact_id = -1 -- Associates:
	BEGIN
		if not (@icustomer_id_list = '-1' and @igenerator_id_list = '-1' and @isite_type_list = '' and @igenerator_state_list = '' and @igenerator_country_list = '') 
		begin
			insert #generator
			select cg.generator_id
			from CustomerGenerator cg
			inner join generator g on cg.generator_id = g.generator_id
			Where cg.customer_id in (select customer_id from #CustomerInput)
			-- and g.site_type like 'GE %'
			union
			select g.generator_id
			from Generator g
			Where generator_id in (select generator_id from #GeneratorInput)
			-- and g.site_type like 'GE %'
			union
			select g.generator_id
			from Generator g
			Where site_type in (select generator_site_type from #SiteType)
			-- and g.site_type like 'GE %'
		end

		if not exists (select 1 from #generator)
			insert #generator
			select distinct generator_id
			from generator
			-- where site_type like 'GE %'
			
		select @genCount = count(*) from #generator
		
	END

-- abort if there's nothing possible to see
	if @genCount + 
		(select count(*) from #SiteType) +
		(select count(*) from #State)
		= 0 RETURN

	IF @genCount <= 0
		RETURN

	if (select count(*) from #CustomerInput where customer_id <> -1) > 0
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join customergenerator cg on g1.generator_id = cg.generator_id
			where cg.customer_id in (select customer_id from #CustomerInput)
		)

	if (select count(*) from #GeneratorInput where generator_id <> -1) > 0
		delete from #generator
		WHERE generator_id not in (
			select generator_id from #GeneratorInput
		)

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

-- Remove various, if it slipped in somehow:
	delete from #generator where generator_id in (-1, 0)

-- Setup is finished.  On to work:

	select generator_id from #generator


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_criteria_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_criteria_master] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_criteria_master] TO [EQAI]
    AS [dbo];

