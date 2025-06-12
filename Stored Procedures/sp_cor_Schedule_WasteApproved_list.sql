GO
DROP PROCEDURE IF EXISTS [sp_cor_Schedule_WasteApproved_list]
GO
CREATE PROC [dbo].[sp_cor_Schedule_WasteApproved_list] (
	@web_userid		varchar(100) = ''
	, @facility_id_list	varchar(max)  -- Searches/limits by company_id|profit_ctr_id csv input
	, @search			varchar(max) = ''  -- search in profile_id, approval_code or approval_desc
	, @profile_id			varchar(max) = ''	-- Can take a CSV list
	, @approval_code		varchar(max) = ''	-- Can take a CSV list
	, @waste_common_name	varchar(50) = ''
    , @sort				varchar(20) = ''
    , @page				int = 1
    , @perpage			int = 20
	, @customer_id_list varchar(max) = ''  /*  Added 2019-08-07 by AA */
	, @generator_id_list varchar(max) = ''  /* Added 2019-08-07 by AA */
)
as

	
BEGIN
DECLARE
    @i_web_userid			varchar(100) = isnull(@web_userid,''),
	@i_facility_id_list		varchar(max) = isnull(@facility_id_list, ''),
    @i_search				varchar(100) = isnull(@search, ''),
	@i_customer_id_list		varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
 	@i_profile_id			varchar(max) = isnull(@profile_id, ''),	-- Can take a CSV list
	@i_approval_code		varchar(max) = isnull(@approval_code, ''), -- Can take a CSV list
	@i_waste_common_name	varchar(50) = isnull(@waste_common_name, ''),
    @i_sort				varchar(20) = isnull(@sort, ''),
    @i_page				int = isnull(@page, 1),
    @i_perpage			int = isnull(@perpage, 20),
	@i_totalcount		int = 0,
	@i_contact_id		int


select top 1 
	@i_contact_id = contact_id
from CORcontact c 
WHERE web_userid = @i_web_userid
and web_userid <> ''

if @i_sort not in ('Generator Name', 'Profile Number', 'Waste Common Name', 'RCRA Status', 'Modified Date', 'Expiration Date') set @i_sort = ''
if @i_sort = '' set @i_sort = 'Modified Date'

declare @profile_ids table (
	profile_id	bigint
)
if @i_profile_id <> ''
insert @profile_ids
select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnumeric(row) = 1
and row not like '%.%'

declare @approval_codes table (
	idx int,
	approval_code varchar(20)
)
if @i_approval_code <> ''
insert @approval_codes
select idx, replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%')
from dbo.fn_SplitXsvText(',', 1, @i_approval_code)
where isnull(row,'') > ''
if @i_profile_id <> ''
insert @approval_codes (idx, approval_code)
select idx, case when isnumeric(row) = 1 then row else replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%') end
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnull(row,'') > ''
and not exists (select 1 from @approval_codes where approval_code = replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%'))
declare @search_profile_id bit = 0
select @search_profile_id = 1 where exists (select 1 from @profile_ids)


declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	int
)
if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @facility_id table (
	company_id	int,
	profit_ctr_id	int
)
if @i_facility_id_list <> ''
insert @facility_id 
select distinct company_id, profit_ctr_id
from USE_Profitcenter upc
join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_id_list, ',', ' '))
	where row is not null
) x
on isnull(convert(varchar(2),upc.company_id), '') + '|' + isnull(convert(varchar(2),upc.profit_ctr_id), '') = row

drop table if exists #tmp
drop table if exists #output



    select distinct
        p.profile_id
        ,pqa.approval_code
        ,p.approval_desc
		,dbo.fn_profile_waste_code_list (p.profile_id, 'X')  as waste_code_list
		,dbo.fn_profile_waste_code_uid_list (p.profile_id, 'X')  as waste_code_uid_list
        ,_row = 0
		
		
	INTO #TMP
	
		
    from ContactCORProfileBucket b (nolock)
    join [Profile] p (nolock)
        on b.profile_id = p.profile_id
    join ProfileQuoteApproval pqa (nolock)
        on b.profile_id = pqa.profile_id and pqa.status = 'A'
	join @facility_id fac on pqa.company_id = fac.company_id
		and pqa.profit_ctr_id = fac.profit_ctr_id
	where b.contact_id = @i_contact_id
	and p.curr_status_code = 'A'
	and p.ap_expiration_date > getdate()
	and
    (
        @i_customer_id_list = ''
        or
        (
			@i_customer_id_list <> ''
			and
			(
				p.customer_id in (select customer_id from @customer)
				or
				p.orig_customer_id in (select customer_id from @customer)
			)
		)
	)
	and
    (
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			(
				p.generator_id in (select generator_id from @generator)
				or
				(
					p.generator_id = 0 and exists (
						select 1 from ProfileGeneratorSiteType pgst 
						join generator pgg on pgst.site_type = pgg.site_type
						join @generator gg on pgg.generator_id = gg.generator_id
						WHERE pgst.profile_id = p.profile_id
						union
						select 1 from CustomerGenerator cg
						join generator cgg on cg.generator_id = cgg.generator_id
						join @generator gg on gg.generator_id = cgg.generator_id
						WHERE cg.customer_id = p.customer_id
						)
				)
			)
		)
	)
     and 
    (
        @i_waste_common_name = ''
        or
        (
			@i_waste_common_name <> ''
			and
			p.approval_desc like '%' + replace(@i_waste_common_name, ' ', '%') + '%'
		)
	)
   and 
    (
        @i_search = ''
        or
        (
			@i_search <> ''
			and 
			convert(varchar(20), p.profile_id) + ' ' +
			p.approval_desc + ' ' + 
			isnull(( select substring(
				(
					select ', ' + 
					isnull(pqa.approval_code, '')
				FROM profilequoteapproval pqa (nolock)
				where pqa.profile_id = p.profile_id
				and pqa.status = 'A'
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			) , '')	
			like '%' + replace(@i_search, ' ', '%') + '%'
        )
    )

	--select * from #tmp

	update #tmp
	set _row = x._row
	from #tmp j
	join (
		select t.profile_id,
		_row = row_number() over (order by 
            case when @i_sort = 'Profile Number' then p.profile_id end asc,
            case when @i_sort = 'Waste Common Name' then p.approval_desc end asc,
            case when @i_sort in ('', 'Modified Date') then p.date_modified end desc,
			case when @i_sort = 'Expiration Date' then p.ap_expiration_date end desc
			, p.profile_id
        ) 
		from #tmp t
		join profile p (nolock) 
			on t.profile_id = p.profile_id
	) x
		on j.profile_id = x.profile_id
 
    
if exists (select 1 from @approval_codes) begin

drop table if exists #tmpac

    select distinct
        t.profile_id
        ,t.approval_code
        ,t.approval_desc
		,t.waste_code_list
		,t.waste_code_uid_list
		,t._row
	into #tmpac
	from #tmp t
	left JOIN profilequoteapproval pqa (nolock)
		on t.profile_id = pqa.profile_id
		and pqa.status = 'A'
	left join @approval_codes ac
		on (pqa.approval_code like ac.approval_code	 or convert(varchar(20),pqa.profile_id) = ac.approval_code)
	WHERE (
			pqa.approval_code like ac.approval_code	
			or
			(isnumeric(ac.approval_code) = 1 and convert(varchar(20), t.profile_id) = ac.approval_code)
			)
	
	truncate table #tmp
	insert #tmp
	select 
	distinct
        t.profile_id
        ,t.approval_code
        ,t.approval_desc
		,t.waste_code_list
		,t.waste_code_uid_list
		,_row = row_number() over (order by _row)
		from #tmpac t

end

select @i_totalcount = count(*) from #tmp

	SELECT    
        t.profile_id
        ,t.approval_code
        ,t.approval_desc
		,t.waste_code_list
		,t.waste_code_uid_list
		,t._row
		,@i_totalcount AS totalcount 
	FROM #TMP t
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage) 
	order by _row

END
GO
GRANT EXECUTE ON [dbo].[sp_cor_Schedule_WasteApproved_list] TO COR_USER;
GO
