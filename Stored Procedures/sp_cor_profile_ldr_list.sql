-- drop proc if exists sp_cor_profile_ldr_list
go
create proc [dbo].[sp_cor_profile_ldr_list] (
	@web_userid		varchar(100) = ''
	, @facility_id_list	varchar(max)  -- Searches/limits by company_id|profit_ctr_id csv input
	, @search			varchar(max) = ''  -- search in profile_id, approval_code or approval_desc
	, @profile_id			varchar(max) = ''	-- Can take a CSV list
	, @approval_code		varchar(max) = ''	-- Can take a CSV list
	, @waste_common_name	varchar(50) = ''
	, @ldr_builder_ready	char(1) = ''		-- 'Y', 'N', '', null ('', null = any)
    , @sort				varchar(20) = ''
    , @page				int = 1
    , @perpage			int = 20
	, @customer_id_list varchar(max) = ''  /*  Added 2019-08-07 by AA */
	, @generator_id_list varchar(max) = ''  /* Added 2019-08-07 by AA */
)
as
/* *************************************************************
sp_cor_profile_ldr_list

DO:17380
select * from sysobjects where name = 'sp_cor_profile_ldr_list'
Notes from a phone call...

-- talking with zach 2021-01-15 re:ldr builder
inputs: customer, generator, facility.
fields to return:
profile id, approval code, 
waste codes, uhc constituent value per approval (list haz constituents)
generic labpack flag
waste water flag (treatment standard)
ldr subcategory
ldr certification
results must contain 1 or more rcra waste codes

G3 Fields: 
	profile.waste_water_flag
	profile.waste_managed_id
	profile.exceed_ldr_standards
	profile.waste_meets_ldr_standards
	profile.section_g3_none_of_the_above_flag
	profilelab.meets_alt_soil_treatment_stds
	profilelab.more_than_50_pct_debris

SELECT  TOP 10 *
FROM    FormLDR
SELECT  TOP 10 *
FROM    FormLDRDetail

SELECT  * FROM    ldrwastemanaged WHERE version = 3


-- finding test cases:
SELECT  distinct TOP 100 co.contact_id, co.web_userid, b.*, c.*, con.*
FROM    ContactCORPRofileBucket b
join profile p (nolock) on b.profile_id = p.profile_id and p.document_update_status <> 'P'
join profilequoteapproval pqa on b.profile_id= pqa.profile_id and pqa.status = 'A'
join profilewastecode pwc (nolock) on b.profile_id = pwc.profile_id 
join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
	and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
-- JOIN ProfileLDRSubcategory pls (nolock) on pls.profile_id = p.profile_id
join ProfileConstituent c on b.profile_id = c.profile_id
join constituents con on c.const_id = con.const_id and uhc_flag = 'T'
join contact co on b.contact_id = co.contact_id
WHERE 
b.curr_status_code = 'A' and b.ap_expiration_date > getdate()

TODO:
- split approval code into specific output field
- inputs (profile_id + approval_code + approval_desc) for searching (one search input)
-- output will be limited to a specific input facility
-- add CSV constituent id's to output in existing field,
-- add ldr_subcategory_id to output
-- only profiles that have G3 selections are selectable, but show them all. So output needs a flag for whether it's selectable.
	-- grr.

sp_cor_profile_ldr_list
	@web_userid		 = 'iceman'
	, @facility_id_list	 = '21|0'  -- Searches/limits by company_id|profit_ctr_id csv input
	, @search			 = ''  -- search in profile_id, approval_code or approval_desc
	--, @profile_id		= '676124'
	-- , @approval_code = 'P210870'
	-- , @waste_common_name = 'acid'
	, @ldr_builder_ready = 'Y'
	, @customer_id_list ='10011'  /*  Added 2019-08-07 by AA */
	, @generator_id_list ='128236'  /* Added 2019-08-07 by AA */
	, @page =1
	, @perpage =2000

************************************************************* */

/*
-- Debug:
declare
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

select
	@web_userid		 = 'iceman'
	, @facility_id_list	 = '21|0'  -- Searches/limits by company_id|profit_ctr_id csv input
	, @search			 = ''  -- search in profile_id, approval_code or approval_desc
	, @customer_id_list ='10011'  /*  Added 2019-08-07 by AA */
	, @generator_id_list ='128236'  /* Added 2019-08-07 by AA */
	, @page =1
	, @perpage =20

*/
	
BEGIN
declare
    @i_web_userid			varchar(100) = isnull(@web_userid,''),
	@i_facility_id_list		varchar(max) = isnull(@facility_id_list, ''),
    @i_search				varchar(100) = isnull(@search, ''),
	@i_customer_id_list		varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
 	@i_profile_id			varchar(max) = isnull(@profile_id, ''),	-- Can take a CSV list
	@i_approval_code		varchar(max) = isnull(@approval_code, ''), -- Can take a CSV list
	@i_waste_common_name	varchar(50) = isnull(@waste_common_name, ''),
	@i_ldr_builder_ready	char(1) = isnull(@ldr_builder_ready, ''),
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

-- test values: declare @i_profile_id varchar(50) = '1324,abc,1.001,9999999999999'
declare @profile_ids table (
	profile_id	bigint
)
if @i_profile_id <> ''
insert @profile_ids
select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnumeric(row) = 1
and row not like '%.%'
-- test output: select * from @profile_ids

-- test values: declare @i_approval_code varchar(50) = '1324,abc,1.001,9999999999999'
declare @approval_codes table (
	idx int,
	approval_code varchar(20)
)
if @i_approval_code <> ''
insert @approval_codes
select idx, replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%')
from dbo.fn_SplitXsvText(',', 1, @i_approval_code)
where isnull(row,'') > ''
-- test output: select * from @approval_codes

-- DO:18422 - they want to combine approval codes with profile id's in search, via the @profile_id field.
-- This is easy if we treat @profile_id input as simply additional @approval_code input.
if @i_profile_id <> ''
insert @approval_codes (idx, approval_code)
select idx, case when isnumeric(row) = 1 then row else replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%') end
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnull(row,'') > ''
and not exists (select 1 from @approval_codes where approval_code = replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%'))
-- This means we can't rely on @i_profile_id <> '' anymore to mean there were profile_id search inputs.
-- Because now it could be in @approval_codes instead. So we need a new flag to indicate that a search
-- should happen against integer profile_id's.
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
        ,pqa.company_id
        ,pqa.profit_ctr_id
        ,pqa.approval_code
        ,p.approval_desc
        ,p.generator_id
        ,gn.generator_name
        ,gn.site_type
        ,gn.epa_id
        ,gt.generator_type
        ,p.customer_id
        ,cn.cust_name
        ,p.curr_status_code
        ,p.ap_expiration_date
		,p.generic_flag
		,p.labpack_flag
		,CASE WHEN P.waste_water_flag = 'W' THEN 'WW' ELSE 'NWW' END AS ww_or_nww
		,( select substring(
			(
				select ', ' + cast(ls.subcategory_id as varchar(10))
				from ProfileLDRSubcategory pls (nolock) 
				LEFT JOIN LDRSubcategory ls (nolock) on pls.ldr_subcategory_id = ls.subcategory_id
				where pls.profile_id = p.profile_id
				order by pls.ldr_subcategory_id
			for xml path, TYPE).value('.[1]','nvarchar(max)'),3,20000)
		) as ldr_subcategory_id_list
		,( select substring(
			(
				select ', ' + ls.short_desc
				from ProfileLDRSubcategory pls (nolock) 
				LEFT JOIN LDRSubcategory ls (nolock) on pls.ldr_subcategory_id = ls.subcategory_id
				where pls.profile_id = p.profile_id
				order by pls.ldr_subcategory_id
			for xml path, TYPE).value('.[1]','nvarchar(max)'),3,20000)
		) as ldr_subcat_short_description
		,( select substring(
			(
				select ', ' + ls.long_desc
				from ProfileLDRSubcategory pls (nolock) 
				LEFT JOIN LDRSubcategory ls (nolock) on pls.ldr_subcategory_id = ls.subcategory_id
				where pls.profile_id = p.profile_id
				order by pls.ldr_subcategory_id
			for xml path, TYPE).value('.[1]','nvarchar(max)'),3,20000)
		) as ldr_subcat_long_description
		
		,dbo.fn_profile_waste_code_list (p.profile_id, 'X')  as waste_code_list
		,dbo.fn_profile_waste_code_uid_list (p.profile_id, 'X')  as waste_code_uid_list
		,( select substring(
			(
				--<br/>Const_ID|Const_Desc|Min_Concentration|(Max)Concentration|Typical Concentration|Unit
				select '<br/>' + 
				+ convert(varchar(10), pc.const_id)
				+ '|' + 
				+ isnull(c.const_desc, '')
				+ '|' 
				+ isnull(convert(varchar(10), pc.min_concentration), '') 
				+ '|' 
				+ ltrim(rtrim(isnull(convert(varchar(10), pc.concentration), '')))
				+ '|'
				+ isnull(convert(varchar(10), pc.typical_concentration), '')
				+ '|'
				+ ltrim(rtrim(isnull(pc.unit, ''))) 
			FROM profileconstituent pc (nolock)
			join constituents c (nolock)
				on pc.const_id = c.const_id
				-- and c.UHC_flag = 'T' -- Don't look at the constituent value
				and pc.uhc = 'T'	-- look at the value attached to this profile's use of the const.
			where pc.profile_id = p.profile_id
			order by pc.typical_concentration desc, pc.min_concentration desc, pc.concentration desc, c.const_desc
			for xml path, TYPE).value('.[1]','nvarchar(max)'),6,20000)
		) as uhc_constituent_list

		,p.waste_water_flag
		,pl.meets_alt_soil_treatment_stds
		,pl.more_than_50_pct_debris
		,p.debris_separated
		,p.debris_not_mixed_or_diluted
		,p.waste_meets_ldr_standards
		,p.section_G3_none_of_the_above_flag
		,p.waste_managed_id
		,convert(varchar(max), lwm.regular_text) as regular_text
		,convert(varchar(max), lwm.underlined_text) as underlined_text
		--case when lwm.visible_flag = 0 then convert(varchar(max), lwm.underlined_text) else convert(varchar(max), lwm.regular_text) end underlined_text
		--,convert(varchar(max),lwm.underlined_text) underlined_text

		, case when 
			(
				(
				isnull(p.waste_water_flag, '') in ('', 'U') 
				and isnull(pl.meets_alt_soil_treatment_stds, 'N') in ('N', '', 'F', 'U') 
				and isnull(pl.more_than_50_pct_debris, 'N') in ('N', '', 'F', 'U') 
				and isnull(p.debris_separated, 'N') in ('N', '', 'F', 'U') 
				and isnull(p.debris_not_mixed_or_diluted, 'N') in ('N', '', 'F', 'U') 
				and isnull(p.waste_meets_ldr_standards, 'N') in ('N', '', 'F', 'U') 
				) 
				or
				(
				isnull(p.section_G3_none_of_the_above_flag, 'F') in ('T') 
				)
			)
			then 'No'
			else 'Yes'
			end as ldr_builder_ready

        ,_row = 0
		
		
	INTO #TMP
	
		
    from ContactCORProfileBucket b (nolock)
    join [Profile] p (nolock)
        on b.profile_id = p.profile_id
    join ProfileQuoteApproval pqa (nolock)
        on b.profile_id = pqa.profile_id and pqa.status = 'A'
	join @facility_id fac on pqa.company_id = fac.company_id
		and pqa.profit_ctr_id = fac.profit_ctr_id
    join Customer cn (nolock) on p.customer_id = cn.customer_id
    join Generator gn (nolock) on p.generator_id = gn.generator_id
    join profilewastecode pwc (nolock) on p.profile_id = pwc.profile_id 
	join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
    join [ProfileLab] pl (nolock)
        on b.profile_id = pl.profile_id
        and pl.type = 'A'
    LEFT JOIN ldrwastemanaged lwm (nolock) on p.waste_managed_id = lwm.waste_managed_id 
		and lwm.version  in (SELECT MAX(lwm.version) from LDRWasteManaged lwm WHERE lwm.waste_managed_id = p.waste_managed_id)
		--and lwm.visible_flag = 1
    left join generatortype gt (nolock) on gn.generator_type_id = gt.generator_type_id
	where b.contact_id = @i_contact_id
	and p.curr_status_code = 'A'
	and p.ap_expiration_date > getdate()
	--- 3/22/2020 (RE enabled this, it was previously removed)
	AND (
		p.document_update_status <> 'P'
		--OR
		--p.document_update_status = 'P' AND p.doc_status_reason in (
		--	'Rejection in Process', 
		--	'Amendment in Process', 
		--	'Renewal in Process',
		--	'Profile Sync Required')
	)
	and p.ap_expiration_date > dateadd(yyyy, -2, getdate())
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

	update #tmp
	set _row = x._row
	from #tmp j
	join (
		select t.profile_id,
		_row = row_number() over (order by 
            case when @i_sort = 'Generator Name' then gn.generator_name end asc,
            case when @i_sort = 'Site Type' then gn.site_type end asc,
            case when @i_sort = 'Profile Number' then p.profile_id end asc,
            case when @i_sort = 'Waste Common Name' then p.approval_desc end asc,
            case when @i_sort = 'RCRA Status' then gt.generator_type end asc,
            case when @i_sort in ('', 'Modified Date') then p.date_modified end desc,
			case when @i_sort = 'Expiration Date' then p.ap_expiration_date end desc
			, p.profile_id
        ) 
		from #tmp t
		join profile p (nolock) 
			on t.profile_id = p.profile_id
		join generator gn (nolock)
			on t.generator_id = gn.generator_id
		left join generatortype gt (nolock) on gn.generator_type_id = gt.generator_type_id
	) x
		on j.profile_id = x.profile_id

if @i_ldr_builder_ready in ('Y', 'N') begin

drop table if exists #tmplbr

    select distinct
        t.profile_id
        ,t.company_id
        ,t.profit_ctr_id
        ,t.approval_code
        ,t.approval_desc
        ,t.generator_id
        ,t.generator_name
        ,t.site_type
        ,t.epa_id
        ,t.generator_type
        ,t.customer_id
        ,t.cust_name
        ,t.curr_status_code
        ,t.ap_expiration_date
		,t.generic_flag
		,t.labpack_flag
		,t.ww_or_nww
		,t.ldr_subcategory_id_list
		,t.ldr_subcat_short_description
		,t.ldr_subcat_long_description
		,t.waste_code_list
		,t.waste_code_uid_list
		,t.uhc_constituent_list
		,t.waste_water_flag
		,t.meets_alt_soil_treatment_stds
		,t.more_than_50_pct_debris
		,t.debris_separated
		,t.debris_not_mixed_or_diluted
		,t.waste_meets_ldr_standards
		,t.section_G3_none_of_the_above_flag
		,t.waste_managed_id
		,t.regular_text
		,t.underlined_text
		,t.ldr_builder_ready
		,t._row
	into #tmplbr
	from #tmp t
	WHERE left(t.ldr_builder_ready,1) = @i_ldr_builder_ready
	
	truncate table #tmp
	insert #tmp
	select 
	distinct
        t.profile_id
        ,t.company_id
        ,t.profit_ctr_id
        ,t.approval_code
        ,t.approval_desc
        ,t.generator_id
        ,t.generator_name
        ,t.site_type
        ,t.epa_id
        ,t.generator_type
        ,t.customer_id
        ,t.cust_name
        ,t.curr_status_code
        ,t.ap_expiration_date
		,t.generic_flag
		,t.labpack_flag
		,t.ww_or_nww
		,t.ldr_subcategory_id_list
		,t.ldr_subcat_short_description
		,t.ldr_subcat_long_description
		,t.waste_code_list
		,t.waste_code_uid_list
		,t.uhc_constituent_list
		,t.waste_water_flag
		,t.meets_alt_soil_treatment_stds
		,t.more_than_50_pct_debris
		,t.debris_separated
		,t.debris_not_mixed_or_diluted
		,t.waste_meets_ldr_standards
		,t.section_G3_none_of_the_above_flag
		,t.waste_managed_id
		,t.regular_text
		,t.underlined_text
		,t.ldr_builder_ready
		,_row = row_number() over (order by _row)
		from #tmplbr t

end    
    
if exists (select 1 from @approval_codes) begin

drop table if exists #tmpac

    select distinct
        t.profile_id
        ,t.company_id
        ,t.profit_ctr_id
        ,t.approval_code
        ,t.approval_desc
        ,t.generator_id
        ,t.generator_name
        ,t.site_type
        ,t.epa_id
        ,t.generator_type
        ,t.customer_id
        ,t.cust_name
        ,t.curr_status_code
        ,t.ap_expiration_date
		,t.generic_flag
		,t.labpack_flag
		,t.ww_or_nww
		,t.ldr_subcategory_id_list
		,t.ldr_subcat_short_description
		,t.ldr_subcat_long_description
		,t.waste_code_list
		,t.waste_code_uid_list
		,t.uhc_constituent_list
		,t.waste_water_flag
		,t.meets_alt_soil_treatment_stds
		,t.more_than_50_pct_debris
		,t.debris_separated
		,t.debris_not_mixed_or_diluted
		,t.waste_meets_ldr_standards
		,t.section_G3_none_of_the_above_flag
		,t.waste_managed_id
		,t.regular_text
		,t.underlined_text
		,t.ldr_builder_ready
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
        ,t.company_id
        ,t.profit_ctr_id
        ,t.approval_code
        ,t.approval_desc
        ,t.generator_id
        ,t.generator_name
        ,t.site_type
        ,t.epa_id
        ,t.generator_type
        ,t.customer_id
        ,t.cust_name
        ,t.curr_status_code
        ,t.ap_expiration_date
		,t.generic_flag
		,t.labpack_flag
		,t.ww_or_nww
		,t.ldr_subcategory_id_list
		,t.ldr_subcat_short_description
		,t.ldr_subcat_long_description
		,t.waste_code_list
		,t.waste_code_uid_list
		,t.uhc_constituent_list
		,t.waste_water_flag
		,t.meets_alt_soil_treatment_stds
		,t.more_than_50_pct_debris
		,t.debris_separated
		,t.debris_not_mixed_or_diluted
		,t.waste_meets_ldr_standards
		,t.section_G3_none_of_the_above_flag
		,t.waste_managed_id
		,t.regular_text
		,t.underlined_text
		,t.ldr_builder_ready
		,_row = row_number() over (order by _row)
		from #tmpac t

end

select @i_totalcount = count(*) from #tmp

	SELECT    
        t.profile_id
        ,t.company_id
        ,t.profit_ctr_id
        ,t.approval_code
        ,t.approval_desc
        ,t.generator_id
        ,t.generator_name
        ,t.site_type
        ,t.epa_id
        ,t.generator_type
        ,t.customer_id
        ,t.cust_name
        ,t.curr_status_code
        ,t.ap_expiration_date
		,t.generic_flag
		,t.labpack_flag
		,t.ww_or_nww
		,t.ldr_subcategory_id_list
		,t.ldr_subcat_short_description
		,t.ldr_subcat_long_description
		,t.waste_code_list
		,t.waste_code_uid_list
		,t.uhc_constituent_list
		,t.waste_water_flag
		,t.meets_alt_soil_treatment_stds
		,t.more_than_50_pct_debris
		,t.debris_separated
		,t.debris_not_mixed_or_diluted
		,t.waste_meets_ldr_standards
		,t.section_G3_none_of_the_above_flag
		,t.waste_managed_id
		,t.regular_text
		,t.underlined_text
		,t.ldr_builder_ready
		,t._row
		,@i_totalcount AS totalcount 
	FROM #TMP t
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage) 
	order by _row

END

GO

GRANT EXECUTE ON sp_cor_profile_ldr_list TO EQAI
GO
GRANT EXECUTE ON sp_cor_profile_ldr_list TO COR_USER
GO
GRANT EXECUTE ON sp_cor_profile_ldr_list TO EQAI
GO


