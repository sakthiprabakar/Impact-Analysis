-- DROP PROCEDURE [dbo].[sp_COR_Profile_Approved_List]
GO

CREATE  PROCEDURE [dbo].[sp_COR_Profile_Approved_List]
	@web_userid		varchar(100),
	@profileStatus	varchar(max) = 'all',
	@search			varchar(100),
	@Adv_Search		varchar(max),
	@CopyStatus	varchar(10),
	@sort			varchar(20) = 'Modified Date',
	@page			int = 1,
	@perpage		int = 20,
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
AS

/* ****************************************************************

sp_COR_Profile_Approved_List

History:

	10/15/2019	MPM	DevOps 11581: Added logic to filter the result set
					using optional input parameters @customer_id_list and
					@generator_id_list.

select avg(_ct) from (
select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
) x

select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
having count(*) = 12

SELECT  *  FROM    contact where first_name = 'jamie' and email 

select p.profile_id, p.approval_desc*
from [Contact] c
join [ContactXref] x
	on c.contact_id = x.contact_id
	and x.status = 'A'
	and x.web_access = 'A'
join [Profile] p
	on case x.type 
		when 'C' then 
			case when p.customer_id  = x.customer_id then 1 else 0 end 
		when 'G' then 
			case when p.generator_id = x.generator_id then 1 else 0 end
		else 0 end = 1
where convert(Varchar(20), c.contact_id) = 100913

select email from contact where last_name = 'huens'

Samples:

[sp_COR_Profile_List] 
	@web_userid = 'Jamie.Huens@Wal-Mart.com', 
	@status_list = null, 
	@search = '', 
	@adv_search = '', 
	@copy_status = null, 
	@sort = 'Waste Common Name',
	@page = 7, 
	@perpage = 20

[sp_COR_Profile_List] 
	@web_userid = 'customer.demo@usecology.com', 
	@status_list = '', 
	@search = '', 
	@adv_search= '', 
	@copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_Profile_List] 
	@web_userid = 'customer.demo@usecology.com', 
	@status_list = '', 
	@search = 'pesticide', 
	@adv_search = '' , 
	@copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_Profile_List_Dev] 
	@web_userid = 'Coruser1', 
	@profileStatus = 'draft, approved', 
	@search = '', 
	@adv_search = '', 
	@CopyStatus = null, 
	@sort = 'foo',
	@page = 1, 
	@perpage = 200

sp_COR_Profile_Approved_List 
	@web_userid				= 'wastetech435'
	, @profileStatus		= null
	, @search				= null
	, @adv_search			= null
	, @copyStatus			= null
	, @sort					= null
	, @page					= null
	, @perpage				= null
	, @customer_id_list		= '583'
    , @generator_id_list	= '23597'  

Pending is only forms
Submitted is a status of a form, is not profiles
Approved is only profiles
Expired is only profiles (approved) that have a past date

11/8/2018 call notes
 * Status Search Criteria
	Draft: All
	Draft: Draft
	Draft: Submitted
	Draft: Needs Customer Response

* Need to return count of results per status
	May need a separate procedure/service for returning just counts by types

**************************************************************** */

-- Avoid query plan caching:
declare
	@i_web_userid				varchar(100)	= isnull(@web_userid, '')
	, @i_profile_status			varchar(max)	= isnull(@profileStatus, 'all')			
	, @i_search					varchar(100)	= isnull(@search, '')			
	, @i_adv_search				varchar(max)	= isnull(@adv_search, '')
	, @i_copy_status			varchar(10)		= isnull(@copyStatus, '')		
	, @i_sort					varchar(20)		= isnull(@sort, 'Modified Date')
	, @i_page					int				= isnull(@page,1)
	, @i_perpage				int				= isnull(@perpage,20)
	, @i_customer_id_list		varchar(max)	= isnull(@customer_id_list, '')
	, @i_generator_id_list		varchar(max)	= isnull(@generator_id_list, '')

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

if isnull(@i_sort, '') not in ('Generator Name', 'Profile Number', 'Waste Common Name', 'RCRA Status', 'Modified Date') set @i_sort = ''

select 
	profile_id,
	approval_desc,
	generator_id,
	generator_name,
	generator_type,
	epa_id,
	customer_id,
	cust_name,
	curr_status_code,
	ap_expiration_date,
	prices,
	date_modified,
	display_status,
	copy_source,
	0 AS totalcount,
	_row
INTO #TMP
from (
	select 
		p.profile_id,
		p.approval_desc,
		p.generator_id,
		gn.generator_name,
		gn.epa_id,
		gt.generator_type,
		p.customer_id,
		cn.cust_name,
		p.curr_status_code,
		p.ap_expiration_date,
		b.prices,
		p.date_modified,
		CASE
           WHEN (DATEDIFF(d, b.ap_expiration_date, GETDATE()) >= 30 AND (YEAR(GETDATE()) = YEAR(b.ap_expiration_date) ))
               THEN 'Renewal'
           ELSE pds. display_status
       END  as display_status,
		null as copy_source,
		_row = row_number() over (order by 
			case when isnull(@i_sort, '') = 'Generator Name' then gn.generator_name end asc,
			case when isnull(@i_sort, '') = 'Profile Number' then p.profile_id end asc,
			case when isnull(@i_sort, '') = 'Waste Common Name' then p.approval_desc end asc,
			case when isnull(@i_sort, '') = 'RCRA Status' then gt.generator_type end asc,
			case when isnull(@i_sort, '') in ('', 'Modified Date') then p.date_modified end desc
		)
	from ContactCORProfileBucket b
	join CORcontact c on b.contact_id = c.contact_id
		and c.web_userid = @i_web_userid
	join [Profile] p
		on b.profile_id = p.profile_id
	join FormDisplayStatus pds on p.display_status_uid = pds.display_status_uid
		and pds.display_status in (
			select row from dbo.fn_SplitXsvText(',', 1, @i_profile_status) where row is not null
			union select display_status from FormDisplayStatus WHERE ((@i_profile_status = 'all' OR ISNULL(@i_profile_status, '') = '' )  AND display_status IN ('Approved','Renewal')) OR (@i_profile_status <> 'all' AND display_status = @i_profile_status) -- display_status IN (@statusType)--isnull(@profileStatus, '') in ('', 'all')
		)
	join Customer cn on p.customer_id = cn.customer_id
	join Generator gn on p.generator_id = gn.generator_id
		left join generatortype gt on gn.generator_type_id = gt.generator_type_id
	where 1=1 
	and 
	(
		isnull(@i_search, '') = ''
		or
		(
		isnull(@i_search, '') <> ''
		and 
		convert(varchar(20), p.profile_id) + ' ' +
		p.approval_desc + ' ' + 
		gn.generator_name + ' ' +
		gn.epa_id + ' ' +
		cn.cust_name
		like '%' + @i_search + '%'
		)
	)
	and 
	(
		@i_customer_id_list = ''
		or
		(
			@i_customer_id_list <> ''
			and
			b.customer_id in (select customer_id from @customer)
		)
	)
	and
	(
		@i_generator_id_list = ''
		or
		(
			@i_generator_id_list <> ''
			and
			b.generator_id in (select generator_id from @generator)
		)
	)	
)x

UPDATE #TMP SET totalcount=  ( Select COUNT(totalcount) FROM #TMP )
-- x
--where _row between ((@page-1) * @perpage ) + 1 and (@page * @perpage) 
--order by _row


--UPDATE #TMP SET total_profile_list=  ( Select COUNT(total_profile_list) FROM #TMP
--)

--select * from #TMP  
SELECT	profile_id, approval_desc AS pro_name,generator_name AS gen_by,generator_type AS RCRA_status,date_modified AS updated_date, 
cust_name AS updated_by,ap_expiration_date AS expired_date, copy_source AS profile,
  display_status as status, totalcount AS totalcount FROM #TMP 
where (((@i_profile_status = 'all' OR ISNULL(@i_profile_status, '') = '' ) AND display_status IN ('Approved','Renewal')) OR (@i_profile_status <> 'all' AND display_status = @i_profile_status) )
AND _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
order by _row
	 
-- ;with cte as
--(
--select fs.display_status as display_status,b.display_status as display_status_count,case when b.display_status is null then 0 end as nullcount
-- from FormDisplayStatus  fs Left outer join #TMP b ON (fs.display_status = b.display_status)
-- )
-- select display_status,count(display_status) as display_status_count INTO #tmpStatus from cte where nullcount is null
-- group by display_status
-- union
-- select display_status,nullcount from cte where nullcount=0 
--		SELECT (SELECT
--    (SELECT  *  FROM #TMP  FOR XML PATH(''), TYPE) AS 'approveList',
--    (select display_status , display_status_count  from #tmpStatus   FOR XML PATH(''), TYPE) AS 'displayStatus'
--FOR XML PATH(''), ROOT('ProfileApporvedList')) as Result

 drop table #TMP
 --drop table #tmpStatus
--RETURN 0
GO

GRANT EXEC ON [dbo].[sp_COR_Profile_Approved_List] TO COR_USER;
GO

