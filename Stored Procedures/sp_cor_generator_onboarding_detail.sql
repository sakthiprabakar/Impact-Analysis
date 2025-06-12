-- drop proc sp_cor_generator_onboarding_detail 
go

create proc sp_cor_generator_onboarding_detail  (
	@web_userid		varchar(100),
	@site_type		varchar(max) = '',
	@epa_id			varchar(max) = '',
	@generator_name	varchar(max) = '',
	@generator_city	varchar(max) = '',
	@generator_state	varchar(max) ='',
	@generator_country	varchar(max) = '',
	@customer_id_list varchar(max)='',  /* Added 2019-07-16 by AA */
    @generator_id_list varchar(max)='',  /* Added 2019-07-16 by AA */
	@sort				varchar(20) = '', -- 'site_type', 'epa_id', 'generator_name', 'generator_city', 'generator_state', 'generator_country', 'percentage'
	@page				bigint = 1,
	@perpage			bigint = 20, 
    @excel_output	int = 0	/* 0= screen output, 1 = excel 1 (FDD), 2= excel 2 (FDD) */
)
as
/* ****************************************************************************
sp_cor_generator_onboarding_detail 

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_cor_generator_onboarding_detail 
	@web_userid = 'jennifer.chopp'
	, @customer_id_list = '12263'
	, @generator_state = ''
	, @excel_output =0
	
	-- 169109 = incomplete
	-- 168770 = finished


select web_userid from contact where web_userid is not null and contact_id in (
SELECT  contact_id  FROM    ContactCorCustomerBucket where customer_id = 18459
)
	
select * from 	generatortimelineheader
select * from 	generatortimelinedetail where generator_id = 183049 and task_external_view = 'Y'

-- update generatortimelinedetail set task_actual_start = null, task_actual_end = null where generator_id = 183049
and task_external_view = 'Y'
-- update generatortimelinedetail set task_actual_start = '10/1/2019', task_actual_end = '10/5/2019' where generator_id = 183049 and sort_order = 1
-- update generatortimelinedetail set task_target_start = dateadd(yyyy, 2, task_target_start), task_target_end = dateadd(yyyy, 2, task_target_end)  where generator_id = 183049
-- update generatortimelinedetail set task_target_start = dateadd(yyyy, -2, task_target_start), task_target_end = dateadd(yyyy, -2, task_target_end)  where generator_id = 183049


having sum(isnull(gtd.overall_percentage,0)) = 0


**************************************************************************** */
/*
declare
	@web_userid varchar(100) = 'nyswyn100',
	@site_type		varchar(max) = '',
	@epa_id			varchar(max) = '',
	@generator_name	varchar(max) = '',
	@generator_city	varchar(max) = '',
	@generator_state	varchar(max) ='',
	@generator_country	varchar(max) = '',
	@sort				varchar(20) = 'generator_city', -- 'site_type', 'epa_id', 'generator_name', 'generator_city', 'generator_state', 'generator_country', 'percentage'
	@page				bigint = 2,
	@perpage			bigint = 10, 
    @excel_output	int = 1	/* 0= screen output, 1 = excel 1 (FDD), 2= excel 2 (FDD) */
	, @customer_id_list varchar(max) = ''
	, @generator_id_list varchar(max) = '' -- '169109, 168770, 169225, 183049' 

*/

declare @i_contact_id	int
	, @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_site_type		varchar(max) = isnull(@site_type, '')
	, @i_epa_id			varchar(max) = isnull(@epa_id, '')
	, @i_generator_name	varchar(max) = isnull(@generator_name, '')
	, @i_generator_city	varchar(max) = isnull(@generator_city, '')
	, @i_generator_state	varchar(max) =isnull(@generator_state, '')
	, @i_generator_country	varchar(max) = isnull(@generator_country, '')
	, @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')
	, @i_sort				varchar(20) = isnull(@sort, 'site_type')
	, @i_page				bigint = isnull(@page, 1)
	, @i_perpage			bigint = isnull(@perpage, 20)
	, @i_excel_output	int = isnull(@excel_output, 0)
	
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid
if @i_sort not in ('site_type', 'epa_id', 'generator_name', 'generator_city', 'generator_state', 'generator_country', 'percentage')
	set @i_sort = 'site_type'

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @tsitetype table (
	site_type	varchar(40)
)
if @i_site_type <> ''
insert @tsitetype select left(row, 40)
from dbo.fn_SplitXsvText(',', 1, @i_site_type)
where row is not null

declare @tepaid table (
	epa_id	varchar(12)
)
if @i_epa_id <> ''
insert @tepaid select left(row, 12)
from dbo.fn_SplitXsvText(',', 1, @i_epa_id)
where row is not null

declare @tgeneratorname table (
	generator_name	varchar(75)
)
if @i_generator_name <> ''
insert @tgeneratorname select left(row, 75)
from dbo.fn_SplitXsvText(',', 1, @i_generator_name)
where row is not null

declare @tgeneratorcity table (
	generator_city	varchar(40)
)
if @i_generator_city <> ''
insert @tgeneratorcity select left(row, 40)
from dbo.fn_SplitXsvText(',', 1, @i_generator_city)
where row is not null

declare @tgeneratorstate table (
	generator_state	varchar(2)
)
if @i_generator_state <> ''
insert @tgeneratorstate select left(row, 2)
from dbo.fn_SplitXsvText(',', 1, @i_generator_state)
where row is not null

declare @tgeneratorcountry table (
	generator_country	varchar(3)
)
if @i_generator_country <> ''
insert @tgeneratorcountry select left(row, 3)
from dbo.fn_SplitXsvText(',', 1, @i_generator_country)
where row is not null



-- If a site has a calculated percentage of 0%, only show this item on 
-- the dashboard if the implementation timeline target start date of 
-- task 1 is TODAY or BEFORE today.

declare @foo table (
	generator_id	int,
	task_target_start	datetime,
	percentage		float
)


insert @foo
select 
	gth.generator_id
	,gtd1.task_target_start
 	, sum(isnull(case when gtd.task_actual_end is not null then gtd.overall_percentage else 0 end,0)) percentage 
from ContactCORGeneratorBucket b 
join generator g
	on b.generator_id = g.generator_id
join generatortimelineheader gth 
	on b.generator_id = gth.generator_id
left join generatortimelinedetail gtd1
	on gth.timeline_id = gtd1.timeline_id and gth.generator_id = gtd1.generator_id
	and gtd1.task_external_view = 'Y'
	and gtd1.parent_task_id is null
	and gtd1.sort_order = 1
left join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
	and gtd.task_actual_end is not null
	and gtd.task_external_view = 'Y'
	and gtd.parent_task_id is null
where
	b.contact_id = @i_contact_id
	and	(
		@i_customer_id_list = ''
		or
		(
		@i_customer_id_list <> ''
		and g.generator_id in (select cg.generator_id from customergenerator cg join @customer c on cg.customer_id = c.customer_id
		   -- and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
			)
		)
	)
	and	(
		@i_generator_id_list = ''
		or
		(
		@i_generator_id_list <> ''
		and g.generator_id in (select generator_id from @generator)
		)
	)
	and	(
		@i_site_type = ''
		or
		(
		@i_site_type <> ''
		and g.site_type in (select site_type from @tsitetype)
		)
	)
	and	(
		@i_epa_id = ''
		or
		(
		@i_epa_id <> ''
		and exists (
			select 1
			from generator gnm
			inner join @tepaid tgn
			on gnm.epa_id like '%' + replace(tgn.epa_id, ' ', '%') + '%'
			where gnm.generator_id = g.generator_id)
		)
	)
	and	(
		@i_generator_name = ''
		or
		(
		@i_generator_name <> ''
		and exists (
			select 1
			from generator gnm
			inner join @tgeneratorname tgn
			on gnm.generator_name like '%' + replace(tgn.generator_name, ' ', '%') + '%'
			where gnm.generator_id = g.generator_id)
		)
	)
	and	(
		@i_generator_city = ''
		or
		(
		@i_generator_city <> ''
		and g.generator_city in (select generator_city from @tgeneratorcity)
		)
	)
	and	(
		@i_generator_state = ''
		or
		(
		@i_generator_state <> ''
		and g.generator_state in (select generator_state from @tgeneratorstate)
		)
	)
	and	(
		@i_generator_country = ''
		or
		(
		@i_generator_country <> ''
		and g.generator_country in (select generator_country from @tgeneratorcountry)
		)
	)
group by gth.generator_id
	, gth.timeline_id
	,gtd1.task_target_start
	
--SELECT  *  FROM    @foo

declare @bar table (
	generator_id	bigint
)

insert @bar
select generator_id
from @foo
where percentage > 0
or task_target_start <= getdate()

--select * from @bar

if object_id('tempdb..#stats') is not null drop table #stats

	--Onboarding timeline data
	select 
		g.generator_id
		, g.generator_name
		, g.epa_id
		, g.site_type
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_city
		, g.generator_state
		, g.generator_country
		, gt.generator_type
		, g_all.percentage as overall_percentage
		, gth.description
		, gtd.task_id
		, gtd.sort_order		
		, gtd.task_short_desc
		, gtd.task_actual_start
		, gtd.task_actual_end
		, gtd.overall_percentage as task_percentage
		, case when gtd.task_actual_end is not null then 'T' else 'F' end as completed_flag
--		, row_number() over (order by g.generator_id, gth.timeline_id, gtd.sort_order) as overall_row
		, row_number() over (partition by g.generator_id order by g.generator_id, gth.timeline_id, gtd.sort_order)  as generator_row
	into #stats
	from @bar bar
	join @foo g_all on bar.generator_id = g_all.generator_id
	join generator g on bar.generator_id = g.generator_id
	join generatortimelineheader gth  on bar.generator_id = gth.generator_id
	join generatortimelinedetail gtd on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
	left join generatortype gt on g.generator_type_id = gt.generator_type_id
	where gtd.parent_task_id is null
	and gtd.task_external_view = 'Y'
-- 	order by g.generator_id, gth.timeline_id, gtd.sort_order


if object_id('tempdb..#output') is not null drop table #output

create table #output (
	generator_id		int,
	generator_name		varchar(75),
	epa_id				varchar(12),
	site_type			varchar(40),
	generator_address_1	varchar(85),
	generator_address_2	varchar(40),
	generator_address_3	varchar(40),
	generator_city		varchar(40),
	generator_state	varchar(2),
	generator_country	varchar(3),
	generator_type	varchar(20),
	overall_percentage	float,
	description	varchar(100),
	task_id		int,
	sort_order	int,
	task_short_desc	varchar(50),
	task_actual_start	datetime,
	task_actual_end	datetime,
	task_percentage	money,
	completed_flag	char(1),
	generator_row	bigint,
	overall_row		bigint
)
	
	-- Screen
	if @i_excel_output = 0
	insert #output (generator_id, generator_name, epa_id, site_type, 
		generator_address_1
		, generator_address_2
		, generator_address_3
	, generator_city, generator_state, generator_country, generator_type, overall_percentage, overall_row)
	select generator_id, generator_name, epa_id, site_type, 
	generator_address_1,
	generator_address_2,
	generator_address_3,
	generator_city, generator_state, generator_country, generator_type, overall_percentage
		,overall_row = row_number() over (order by 
			case when @i_sort in ('', 'site_type') then site_type end,
			case when @i_sort = 'epa_id' then epa_id end ,
			case when @i_sort = 'generator_name' then generator_name end ,
			case when @i_sort = 'generator_city' then generator_city end , -- Fix when field exist
			case when @i_sort = 'generator_state' then generator_state end , 
			case when @i_sort = 'generator_country' then generator_country end , 
			case when @i_sort = 'percentage' then overall_percentage  end desc 
		)
	from #stats
	where generator_row = 1
	
	-- Excel 1
	if @i_excel_output = 1
	insert #output (generator_id, generator_name, epa_id, site_type
		, generator_address_1
		, generator_address_2
		, generator_address_3
	, generator_city, generator_state, generator_country, generator_type, overall_percentage, overall_row)
	select generator_id, generator_name, epa_id, site_type
		, generator_address_1
		, generator_address_2
		, generator_address_3
	, generator_city, generator_state, generator_country, generator_type, overall_percentage
		,overall_row = row_number() over (order by 
			case when @i_sort in ('', 'site_type') then site_type end,
			case when @i_sort = 'epa_id' then epa_id end ,
			case when @i_sort = 'generator_name' then generator_name end ,
			case when @i_sort = 'generator_city' then generator_city end , -- Fix when field exist
			case when @i_sort = 'generator_state' then generator_state end , 
			case when @i_sort = 'generator_country' then generator_country end , 
			case when @i_sort = 'percentage' then overall_percentage  end desc 
		)
	from #stats
	where generator_row = 1
	
	-- Excel 2
	if @i_excel_output = 2
	insert #output (generator_id, generator_name, epa_id, site_type
		, generator_address_1
		, generator_address_2
		, generator_address_3
	, generator_city, generator_state, generator_country, generator_type,task_id,task_short_desc,task_actual_start, task_actual_end, task_percentage, completed_flag, overall_row)
	select generator_id, generator_name, epa_id, site_type
		, generator_address_1
		, generator_address_2
		, generator_address_3
	, generator_city, generator_state, generator_country, generator_type,
	task_id,
	task_short_desc,
	task_actual_start, task_actual_end, task_percentage, completed_flag
		,overall_row = row_number() over (order by 
			case when @i_sort in ('', 'site_type') then site_type end,
			case when @i_sort = 'epa_id' then epa_id end ,
			case when @i_sort = 'generator_name' then generator_name end ,
			case when @i_sort = 'generator_city' then generator_city end , -- Fix when field exist
			case when @i_sort = 'generator_state' then generator_state end , 
			case when @i_sort = 'generator_country' then generator_country end , 
			case when @i_sort = 'percentage' then overall_percentage  end desc 
		)
	from #stats

	declare @totalcount bigint
	select @totalcount= count(*) from #output
	
	select * , @totalcount as total_count
	from #output 
	where 
	(
	@i_excel_output = 0
	and overall_row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	)
	or @i_excel_output <> 0
	order by overall_row

GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_generator_onboarding_detail  TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_generator_onboarding_detail  TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_generator_onboarding_detail  TO [EQAI]
    AS [dbo];

