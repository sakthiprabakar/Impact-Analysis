--DROP  PROCEDURE [dbo].[sp_COR_Profile_Expired_Count]
--GO

CREATE  PROCEDURE [dbo].[sp_COR_Profile_Expired_Count]
	@web_userid		varchar(100),
	@status_list	varchar(max) = 'all',
	@search			varchar(100)='',
	@adv_search		varchar(max)='',
	@copy_status	varchar(20)='',
	@sort			varchar(20) = 'Modified Date',
	@page			int = 1,
	@perpage		int = 20,
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
AS

/* ****************************************************************

sp_COR_Profile_Expired_Count

History:

	10/15/2019	MPM	DevOps 11584: Added logic to filter the result set
					using optional input parameters @customer_id_list and
					@generator_id_list.

sp_COR_Profile_Expired_Count 
	@web_userid				= 'wastetech435'
	, @status_list			= null
	, @search				= null
	, @adv_search			= null
	, @copy_status			= null
	, @sort					= null
	, @page					= null
	, @perpage				= null
	, @customer_id_list		= '583'
    , @generator_id_list	= '170110, 175880'  

**************************************************************** */

-- Avoid query plan caching:
declare
	@i_web_userid				varchar(100)	= isnull(@web_userid, '')
	, @i_status_list			varchar(max)	= isnull(@status_list, 'all')			
	, @i_search					varchar(100)	= isnull(@search, '')			
	, @i_adv_search				varchar(max)	= isnull(@adv_search, '')
	, @i_copy_status			varchar(20)		= isnull(@copy_status, '')		
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
	copy_source
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
           WHEN (DATEDIFF(d, p.ap_expiration_date, GETDATE()) >= 30 AND (YEAR(GETDATE()) = YEAR(p.ap_expiration_date) ))
               THEN 'Renewal'
           ELSE pds.display_status
       END  as display_status,
		null as copy_source
	from ContactCORProfileBucket b
	join CORcontact c 
		on b.contact_id = c.contact_id
		and c.web_userid = @i_web_userid
	join Profile p
		on b.profile_id = p.profile_id
	join FormDisplayStatus pds on p.display_status_uid = pds.display_status_uid
	join Customer cn on p.customer_id = cn.customer_id
	join Generator gn on p.generator_id = gn.generator_id
	left join generatortype gt on gn.generator_type_id = gt.generator_type_id
	where 1=1
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
) x
where display_status IN ('Approved','Renewal')  AND CONVERT(DATE, ap_expiration_date,103) < CONVERT(DATE, GETDATE(),103)

DECLARE @statusTMP TABLE  (display_status varchar(30))
	
Insert @statusTMP values ('All')
Insert @statusTMP values ('Approved')
Insert @statusTMP values ('Renewal')

SELECT COUNT(*) AS display_Status_Count,B.display_status
FROM #TMP A JOIN @statusTMP B ON B.display_status=A.display_status 
GROUP BY B.display_status
UNION
SELECT COUNT(*) AS display_Status_Count, 'all' FROM #TMP

DROP TABLE #TMP
--RETURN 0
GO

grant execute on sp_COR_Profile_Expired_Count to eqweb,COR_USER
go

