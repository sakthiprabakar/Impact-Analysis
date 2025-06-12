-- drop proc sp_cor_dashboard_on_time_final_manifest
go

CREATE PROCEDURE sp_cor_dashboard_on_time_final_manifest (
	@web_userid		varchar(100)
  , @customer_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
  , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_on_time_final_manifest

	Return search results for manifest/bol searches

10/04/2019 MPM  DevOps 11554: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.
09/20/2021 JPB	Speed focus. Was taking near 20 seconds for some retail.
	

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'brieac1'

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'zachery.wright'

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'vscheerer'

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'thames', 
	@customer_id_list = '14164', 
	@generator_id_list = '137729'

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'thames', 
	@customer_id_list = '', 
	@generator_id_list = '137729'

SELECT  * FROM    contact WHERE web_userid = 'court_c'
SELECT  * FROM    contactcorcustomerbucket WHERE  contact_id = 175531
 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'court_c', 
	@customer_id_list = '601113', 
	@generator_id_list = ''

 sp_cor_dashboard_on_time_final_manifest 
	@web_userid		= 'nyswyn100'


***************************************************************/

/*
-- DEBUG:
-- SELECT  * FROM    contact WHERE web_userid = 'court_c'
-- SELECT  * FROM    ContactCORCustomerBucket WHERE contact_id = 175531

declare 	@web_userid		varchar(100) = 'court_c'
  , @customer_id_list varchar(max)='15940'  /* Added 2019-07-12 by AA */
  , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */

*/

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= convert(date,getdate()-365)
	, @i_date_end				datetime		= convert(date,getdate()			)
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

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

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999;

declare @time table (
	m_yr int,
	m_mo int
);

	
WITH CTE AS
(
    SELECT @i_date_start AS cte_start_date
    UNION ALL
    SELECT DATEADD(MONTH, 1, cte_start_date)
    FROM CTE
    WHERE DATEADD(MONTH, 1, cte_start_date) <= @i_date_end
)
insert @time
SELECT year(cte_start_date), month(cte_start_date)
FROM CTE


declare @ttype table (
	type_id	int
)
insert @ttype
select type_id
from plt_image..scandocumenttype (nolock)
where document_type like '%manifest%'
and document_type not like '%initial%'
and document_type not like '%pickup%'
and document_type not like '%return%'
and document_type not like '%reject%'

declare @foo table (
	trans_source		char(1)
	, receipt_id		int
	, company_id		int
	, profit_ctr_id		int
	, generator_id		int
	, service_date		datetime
)


insert @foo
SELECT 
	'R' trans_source,
	x.receipt_id,
	x.company_id,
	x.profit_ctr_id,
	x.generator_id,
	x.receipt_date
FROM    ContactCORReceiptBucket x  (nolock) 
join generator g on x.generator_id = g.generator_id and not (isnull(g.generator_country, 'USA') = 'USA' and g.generator_state in  ('AK', 'GU', 'HI', 'PW', 'VI'))
WHERE x.contact_id = @contact_id
and x.pickup_date between @i_date_start and @i_date_end
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		x.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		x.generator_id in (select generator_id from @generator)
	)
) union
SELECT
	'W' trans_source,
	x.workorder_id,
	x.company_id,
	x.profit_ctr_id,
	x.generator_id,
	x.service_date
FROM    ContactCORWorkOrderHeaderBucket x  (nolock) 
join generator g on x.generator_id = g.generator_id and not (isnull(g.generator_country, 'USA') = 'USA' and g.generator_state in  ('AK', 'GU', 'HI', 'PW', 'VI'))
WHERE x.contact_id = @contact_id
and x.service_date between @i_date_start and @i_date_end
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		x.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		x.generator_id in (select generator_id from @generator)
	)
)

drop table if exists #bar

select distinct
	z.trans_source	
	, z.receipt_id	
	, z.company_id	
	, z.profit_ctr_id	
	, z.generator_id
	, z.service_date
	, r.manifest
into #bar
from @foo z
join Receipt r (nolock) on r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and z.trans_source = 'R' and r.trans_mode = 'I'
WHERE z.trans_source = 'R' and r.manifest_flag = 'M' and r.manifest_form_type like '%H%'

drop table if exists #baw

select distinct 
	z.trans_source	
	, z.receipt_id	
	, z.company_id	
	, z.profit_ctr_id	
	, z.generator_id
	, z.service_date	
	, d.manifest
into #baw
from @foo z
join workorderheader h (nolock)
	on z.receipt_id = h.workorder_id and z.company_id = h.company_id and z.profit_ctr_id = h.profit_ctr_id and z.trans_source = 'W'
join workorderdetail d (nolock)
	on z.receipt_id = d.workorder_id and z.company_id = d.company_id and z.profit_ctr_id = d.profit_ctr_id and z.trans_source = 'W'
	and d.resource_type = 'D' and d.bill_rate > -2 and isnull(d.manifest, 'manifest') not like '%manifest%'
join workordermanifest m (nolock)
	on z.receipt_id = m.workorder_id and z.company_id = m.company_id and z.profit_ctr_id = m.profit_ctr_id and z.trans_source = 'W'
	and d.manifest = m.manifest and m.manifest_flag = 'T' and m.manifest_state like '%H%'
where z.trans_source = 'W'

insert #bar select * from #baw w
WHERE not exists (select manifest from #bar r where w.manifest = r.manifest)

-- SELECT  * FROM    #bar


	
drop table if exists #images
	
	-- insert @images
	select 
		s.image_id
		, b.trans_source	
		, b.receipt_id	
		, b.company_id	
		, b.profit_ctr_id	
		, b.generator_id
		, b.service_date	
		, b.manifest		
		, coalesce(s.upload_date, s.date_modified, s.date_added) as scan_date
		, s.date_modified
	into #images
	from #bar b
	join plt_image..scan s (nolock)
		on b.receipt_id = s.receipt_id
		and b.profit_ctr_id = s.profit_ctr_id
		and b.company_id = s.company_id
		and s.status = 'A'
		and s.view_on_web = 'T'
	WHERE b.trans_source = 'R'
	and s.type_id in (select type_id from @ttype)
--	and exists (select image_id from plt_image..scanimage where image_id = s.image_id)
	union all
	select 
		s.image_id
		, b.trans_source	
		, b.receipt_id	
		, b.company_id	
		, b.profit_ctr_id	
		, b.generator_id
		, b.service_date	
		, b.manifest			
		, coalesce(s.upload_date, s.date_modified, s.date_added) as scan_date
		, s.date_modified
	from #bar b
	join plt_image..scan s (nolock)
		on b.receipt_id = s.workorder_id
		and b.profit_ctr_id = s.profit_ctr_id
		and b.company_id = s.company_id
		and s.status = 'A'
		and s.view_on_web = 'T'
	WHERE b.trans_source = 'W'
	and s.type_id in (select type_id from @ttype)
--	and exists (select image_id from plt_image..scanimage where image_id = s.image_id)

-- SELECT  * FROM    #images		WHERE trans_source = 'W'

drop table if exists #rex

select distinct
		b.trans_source	
		, b.receipt_id	
		, b.company_id	
		, b.profit_ctr_id	
		, b.generator_id
		, b.service_date	
		, b.manifest
		, x.scan_date
		, i.date_modified scan_date_modified
		, convert(int, null) as _datediff
		, convert(int, null) as _datediff_modified
into #rex
from #bar b
inner join
	(
		SELECT  
			b.trans_source	
			, b.receipt_id	
			, b.company_id	
			, b.profit_ctr_id	
			, b.service_date	
			, b.manifest			
			, min(scan_date) scan_date
		FROM    #images b
		GROUP BY 
			b.trans_source	
			, b.receipt_id	
			, b.company_id	
			, b.profit_ctr_id	
			, b.service_date	
			, b.manifest			
	)	x
		on b.trans_source = x.trans_source
		and b.receipt_id = x.receipt_id
		and b.company_id = x.company_id
		and b.profit_ctr_id = x.profit_ctr_id
		and b.service_date = x.service_date
		and b.manifest = x.manifest
inner join #images i
		on b.trans_source = i.trans_source
		and b.receipt_id = i.receipt_id
		and b.company_id = i.company_id
		and b.profit_ctr_id = i.profit_ctr_id
		and b.service_date = i.service_date
		and b.manifest = i.manifest
		and i.scan_date = x.scan_date
		

-- so far #rex only contains definite scan matches.
-- we need it to contain all the transactions possible, INCLUDING scan matches.
-- so add the other transactions

insert #rex
	select distinct 
		b.trans_source
		, b.receipt_id
		, b.company_id
		, b.profit_ctr_id
		, b.generator_id
		, b.service_date
		, b.manifest
		, null as scan_date
		, null as scan_date_modified
		, null -- datediff(d, b.service_date, s.date_modified) as _datediff
		, null
	from #bar b
	where not exists (
		select 1 from #rex i
		WHERE i.manifest = b.manifest
	)		
	
	update #rex set _datediff = datediff(d, service_date, scan_date) WHERE  scan_date is not null
	update #rex set _datediff_modified = datediff(d, service_date, scan_date_modified) WHERE scan_date_modified is not null


-- SELECT  * FROM    #rex


select t.m_yr _year
	, t.m_mo _month
	, isnull(
		(
			case when x.total > 0 then 
				convert(decimal(5,2),
					((x.on_time * 1.00) / x.total) * 100
				)					 
			else 0 end
		)
	  , 0) pct_on_time
	, isnull(
		(
			case when x.total > 0 then 
				convert(decimal(5,2),
					((x.on_time_modified * 1.00) / x.total) * 100
				) 
			else 0 end
		)
	  , 0) pct_on_time_modified
from @time t
left join
(
	select 
		year(service_date) s_year
		, month(service_date) s_month
		, count(*) as total
		, sum(case when isnull(_datediff, 999) <= 30 then 1 else 0 end) as on_time
		, sum(case when isnull(_datediff_modified, 999) <= 30 then 1 else 0 end) as on_time_modified
	from #rex
	GROUP BY year(Service_date), month(service_date)
) x
	on t.m_yr = x.s_year
	and t.m_mo = x.s_month
order by t.m_yr, t.m_mo


return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_on_time_final_manifest TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_on_time_final_manifest TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_on_time_final_manifest TO COR_USER;
GO
