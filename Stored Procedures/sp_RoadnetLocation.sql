
Create Proc sp_RoadnetLocation (
	@customer_id_list				varchar(max) = null
	, @customer_type_list			varchar(max) = null
	, @customer_category_list		varchar(max) = null
	, @geocode_quality_pattern_list	varchar(max) = null
	, @generator_site_type_list		varchar(max) = null
) as
/* ****************************************************************
sp_RoadnetLocation

Renders data from RoadnetDriver as flatfile

sp_columns RoadnetLocation

select 

select 
'+ left(isnull(convert(varchar(' + convert(Varchar(10), c.length) +' ), [' + c.name + ']), '''') + space(' + + convert(Varchar(10), c.length) + '), ' + convert(Varchar(10), c.length) + ')'
, c.*
from syscolumns c
join sysobjects o on c.id  = o.id
where o.name = 'RoadnetLocation' and o.xtype = 'V'
order by c.colorder

select distinct cust_category from customer
select distinct geocode_quality from generator

exec sp_RoadnetLocation 
	@customer_id_list				= '10673'
	, @geocode_quality_pattern_list	= 'none'

exec sp_RoadnetLocation 
	@generator_site_type_list		= 'Publix Supermarket'
	, @geocode_quality_pattern_list	= 'none'


SELECT * FROM GeneratorSiteType

exec sp_RoadnetLocation 
--	@customer_id_list				= '10673'
	@customer_type_list			= 'WALMART'
--	@customer_category_list		= 'Retail'
	, @geocode_quality_pattern_list	= 'none'

select * from RoadnetLocation where generator_id = 89258

sp_help generator

create index idx_geocode_quality on Generator(geocode_quality)

History:
	2016-08-10	JPB	Changed location_id to generator_id as first field per GEM:38880
	2016-09-08	JPB	GEM:38883 - Added @generator_site_type_list input, rewrote #generator logic for speed.

**************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

create table #customer (
	customer_id			int
)
create table #geocode_quality (
	quality				varchar(200)
)
create table #generator_site_type (
	site_type			varchar(40)
)
create table #generator (
	generator_id		int
)
create index idx_g on #generator (generator_id)

if isnull(@customer_id_list, '') <> ''
	insert #customer
	select convert(int, row)
	from dbo.fn_SplitXsvText('|', 0, @customer_id_list) x
	where x.row is not null
	and isnumeric(row) = 1

if isnull(@customer_type_list, '') <> ''
	insert #customer
	select customer_id
	from customer
	join dbo.fn_SplitXsvText('|', 1, @customer_type_list) x
	on customer.customer_type = x.row
	where x.row is not null
	and customer.cust_prospect_flag = 'C'

if isnull(@customer_category_list, '') <> ''
	insert #customer
	select customer_id
	from customer
	join dbo.fn_SplitXsvText('|', 1, @customer_category_list) x
	on customer.cust_category = x.row
	where x.row is not null
	and customer.cust_prospect_flag = 'C'

if isnull(@generator_site_type_list, '') <> ''
	insert #generator_site_type
	select distinct site_type
	from generator
	join dbo.fn_SplitXsvText('|', 1, @generator_site_type_list) x
	on generator.site_type = x.row
	where x.row is not null

---- If they filtered none, retrieve all.
--if (select count(*) from #customer) = 0
--	insert #customer
--	select customer_id
--	from customer
--	where customer.cust_prospect_flag = 'C'

if isnull(@geocode_quality_pattern_list, '') <> ''
	insert #geocode_quality
	select x.row
	from dbo.fn_SplitXsvText('|', 1, @geocode_quality_pattern_list) x
	where isnull(x.row, '') <> ''
	
update #geocode_quality set
	quality = '' where quality = 'none'

-- If they filtered none, retrieve all.
if (select count(*) from #geocode_quality) = 0
	insert #geocode_quality
	select distinct isnull(geocode_quality, '')
	from generator
	-- where isnull(geocode_quality, '') <> ''
	
---- If they filtered none, retrieve all.
--if (select count(*) from #generator_site_type) = 0
--	insert #generator_site_type
--	select distinct isnull(site_type, '')
--	from generator
--	-- where isnull(geocode_quality, '') <> ''

declare @sql varchar(max) = 'insert #generator select generator_id from generator where 1=1 '

if 0 < (select count(*) from #customer)
	set @sql = @sql + ' and generator_id in (select generator_id from customergenerator cg join #customer c on cg.customer_id = c.customer_id) '

if 0 < (select count(*) from #geocode_quality)
	set @sql = @sql + ' and isnull(geocode_quality, '''') in (select quality from #geocode_quality) '

if 0 < (select count(*) from #generator_site_type)
	set @sql = @sql + ' and site_type in (select site_type from #generator_site_type) '

-- select @sql
exec ( @sql )

select distinct
	left(isnull(convert(varchar(16 ), rl.[generator_id]), '') + space(16), 16)
	+ left(isnull(convert(varchar(60 ), rl.[location name]), '') + space(60), 60)
	+ left(isnull(convert(varchar(3 ), rl.[Location Type]), '') + space(3), 3)
--	+ left(isnull(convert(varchar(100 ), rl.[Location Description]), '') + space(100), 100)
	+ left(isnull(convert(varchar(50 ), rl.[Address Line 1]), '') + space(50), 50)
	+ left(isnull(convert(varchar(20 ), rl.[Address Line 2]), '') + space(20), 20)
	+ left(isnull(convert(varchar(30 ), rl.[City]), '') + space(30), 30)
	+ left(isnull(convert(varchar(20 ), rl.[State]), '') + space(20), 20)
	+ left(isnull(convert(varchar(10 ), rl.[Zip Code]), '') + space(10), 10)
	+ left(isnull(convert(varchar(7 ), rl.[Delivery Days]), '') + space(7), 7)
	+ left(isnull(convert(varchar(11 ), rl.[Latitude]), '') + space(11), 11)
	+ left(isnull(convert(varchar(12 ), rl.[Longitude]), '') + space(12), 12)
	+ left(isnull(convert(varchar(20 ), rl.[Phone Number]), '') + space(20), 20)
	+ left(isnull(convert(varchar(20 ), rl.[User Field 1]), '') + space(20), 20)
	+ left(isnull(convert(varchar(20 ), rl.[User Field 2]), '') + space(20), 20)
	+ left(isnull(convert(varchar(5 ), rl.[Open Time]), '') + space(5), 5)
	+ left(isnull(convert(varchar(5 ), rl.[Close Time]), '') + space(5), 5)
	+ left(isnull(convert(varchar(5 ), rl.[Time Window 1 Start]), '') + space(5), 5)
	+ left(isnull(convert(varchar(5 ), rl.[Time Window 1 Stop]), '') + space(5), 5)
	+ left(isnull(convert(varchar(5 ), rl.[Time Window 2 Start]), '') + space(5), 5)
	+ left(isnull(convert(varchar(5 ), rl.[Time Window 2 Stop]), '') + space(5), 5)
	+ left(isnull(convert(varchar(1 ), rl.[Force Geocode]), '') + space(1), 1)
	+ left(isnull(convert(varchar(15 ), rl.[Store Number]), '') + space(15), 15)
from RoadnetLocation rl
inner join #generator g on rl.generator_id = g.generator_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetLocation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetLocation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetLocation] TO [EQAI]
    AS [dbo];

