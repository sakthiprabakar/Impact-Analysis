-- drop proc [sp_COR_GeneratorRegionList]
go

CREATE  proc [dbo].[sp_COR_GeneratorRegionList] (
	@web_userid		varchar(100)
	, @search			varchar(max) = ''
	, @include_inactive	bit = 1 -- whether inactive generators (status = I) should be returned (default yes)
	, @page			int = NULL
	, @perpage		int = NULL
	, @customer_id_list varchar(max)='' /* Added 2019-08-05 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-08-05 by AA */
)
as
/* ******************************************************************
Generator Region LIst

09/27/2019 MPM  DevOps 11572: Added logic to filter the result set
				using optional input parameter @generator_id_list.
04/27/2021 JPB  Added addl parameters:
	, @search			varchar(max) = ''
	, @include_inactive	bit = 1 -- whether inactive generators (status = I) should be returned (default yes)
	, @page			int = NULL
	, @perpage		int = NULL
	, @excel_output	int = 0


inputs 
	
	Web User ID

Returns

	Distinct Generator Region values available to the user


Samples:
exec sp_COR_GeneratorRegionList 'vscheerer'
exec sp_COR_GeneratorRegionList 'nyswyn100'
exec sp_COR_GeneratorRegionList 'zachery.wright'
exec sp_COR_GeneratorRegionList 'customer.demo@usecology.com'
exec sp_COR_GeneratorRegionList 'erindira7', '', '134753, 134755'
exec sp_COR_GeneratorRegionList 'jodie.fleming'
	@web_userid		= 'dale.patton@wincofoods.com'
	@web_userid		= 'court_c'

exec sp_COR_GeneratorRegionList 
	@web_userid		= 'court_c'
	, @search		= '5'
	, @include_inactive	= 0 -- whether inactive generators (status = I) should be returned (default yes)
	, @page			= 1
	, @perpage		= 20
	, @customer_id_list  ='' 
    , @generator_id_list  ='' 
 
	

sp_columns generator
SELECT  *  FROM    sysobjects where name like '%region%'

select distinct x.contact_id, c.web_userid, g.generator_region_code from generator g
join ContactCorGeneratorBucket x on g.generator_id = x.generator_id
join contact c on x.contact_id = c.contact_id
WHERE x.contact_id in (select contact_id from contact where web_userid <> 'paul.kalinka@usecology.com')

SELECT  *  FROM    Region

****************************************************************** */

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @web_userid 
	, @i_search			varchar(max) = isnull(@search, '')
	, @i_include_inactive	bit = isnull(@include_inactive, 0)
	, @i_page			int = isnull(@page,1)
	, @i_perpage		int = isnull(@perpage, 20)
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
	, @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @i_contact_id		int

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

-- Main filter of generator_ids visible to this user
declare @foo table (
	generator_id bigint
)

insert @foo
select generator_id
from ContactCORGeneratorBucket
where contact_id = @i_contact_id


-- now trim by input customer_id_list
if @i_customer_id_list <> '' begin

	declare @foo_c table (
	Generator_id int
	)

	declare @g table (generator_id int)
	insert @g
	select generator_id from customergenerator
	where customer_id in (
		select row from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
		where row is not null
	)

	insert @foo_c (generator_id)
	select 
		f.generator_id
	from @foo f
	join @g g on f.generator_id = g.generator_id

	delete from @foo
	insert @foo
	(generator_id)
	select distinct
	generator_id
	from @foo_c
end


-- now trim by input generator_id_list
if @i_generator_id_list <> '' begin

	declare @generator table (
		generator_id	bigint
	)

	insert @generator select convert(bigint, row)
	from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
	where row is not null

	declare @foo_g table (
	Generator_id int
	)

	insert @foo_g (generator_id)
	select 
		f.generator_id
	from @foo f
	join @generator g on f.generator_id = g.generator_id

	delete from @foo
	insert @foo
	(generator_id)
	select distinct
	generator_id
	from @foo_c
end

declare @regions table (
	generator_region_code varchar(40)
	, _rowNumber int null
)

insert @regions (generator_region_code)
SELECT  DISTINCT
		case when ltrim(rtrim(isnull(d.generator_region_code, ''))) = '' then '(no region code)' else d.generator_region_code end generator_region_code
FROM  @foo x
join Generator d (nolock) on x.Generator_id = d.Generator_id
	and d.status = case @i_include_inactive when 1 then d.status else 'A' end
	and d.generator_region_code is not null
WHERE 
(
	@i_search = ''
	or
	(
		@i_search <> ''
		and
		isnull(d.generator_region_code, '') + ' '
		like '%' + @i_search + '%'
	)
and ltrim(rtrim(isnull(d.generator_region_code, ''))) 
 not in ('', '(no region code)')
)

update @regions set _rowNumber = x._row
from @regions r
join (
	select generator_region_code
	, rank() over (order by generator_region_code) _row
	from @regions
) x
on r.generator_region_code = x.generator_region_code
	
select
	r.generator_region_code
	, _rowNumber
	, (select max(_rowNumber) from @regions) _totalRows
from @regions r
	WHERE @i_perpage IS NULL OR (_rowNumber between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage))
ORDER BY _rowNumber

RETURN 0

GO

GRANT EXECUTE ON [dbo].[sp_COR_GeneratorRegionList] TO COR_USER;

GO

