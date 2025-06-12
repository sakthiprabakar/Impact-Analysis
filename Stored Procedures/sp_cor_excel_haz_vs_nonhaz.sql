-- drop proc sp_cor_excel_haz_vs_nonhaz
go

create proc sp_cor_excel_haz_vs_nonhaz (
	@web_userid		varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @customer_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
	, @generator_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
)
as 
/* ********************************************************************
sp_cor_excel_haz_vs_nonhaz

	per dev Ops item 3477.  Returns RCRA Haz vs NonHaz waste totals

Samples:
sp_cor_dashboard_haz_vs_nonhaz
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2018'
	, @date_end = '1/1/2020'

sp_cor_excel_haz_vs_nonhaz
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2018'
	, @date_end = '1/1/2020'
	, @customer_id_list = '15551'
	, @generator_id_list = '122973'
	
History:	
	2019-07-16	JPB	Created




SELECT  *  FROM    contact WHERE web_userid = 'nyswyn100'
SELECT  *  FROM  ContactCorReceiptBucket WHERE   contact_id = 200959
SELECT  *  FROM    contactxref WHERE contact_id = 185547
SELECT  *  FROM  ContactCorReceiptBucket WHERE receipt_date between '1/1/2019' and '1/1/2020'
	
******************************************************************** */

/*
-- debug info
declare	@web_userid		varchar(100) = 'nyswyn100'
	, @date_start	datetime = '1/1/2018'
	, @date_end		datetime = '1/1/2020'
*/

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= convert(date, @date_start)
	, @i_date_end				datetime		= convert(date, @date_end)
	, @contact_id	int
	, @i_customer_id_list		varchar(max)	= isnull(@customer_id_list, '')
	, @i_generator_id_list		varchar(max)	= isnull(@generator_id_list, '')


select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
   
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(yyyy, -1, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

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


declare @r table (
	receipt_id int
	, company_id int
	, profit_ctr_id int
)

declare @s table (
	[year] int
	, [month] int
	, haz_flag char(1)
	, tons	float
	, receipt_date datetime
	, profile_id int
	, generator_id int
	, company_id int
	, profit_ctr_id int
	, pickup_date datetime
	, manifest varchar(15)
	, manifest_page_num int
	, manifest_line int
	, manifest_quantity float
	, manifest_unit char(1)
	, container_count float
	, manifest_container_code varchar(15)
)

insert @r
select 
	h.receipt_id
	, h.company_id
	, h.profit_ctr_id
from ContactCORReceiptBucket h (nolock) 
WHERE h.contact_id = @contact_id
and isnull(h.pickup_date, h.receipt_date) between @i_date_start and @i_date_end
and (
	@i_customer_id_list = ''
	or h.customer_id in (select customer_id from @customer)
)
and (
	@i_generator_id_list = ''
	or h.generator_id in (select generator_id from @generator)
)

insert @s
select 
	year(isnull(r.pickup_date, r.receipt_date)) [year]
	, month(isnull(r.pickup_date, r.receipt_date)) [month]
	, r.haz_flag
	, round(sum(r.tons),2) tons
	, r.receipt_date
	, r.profile_id
	, r.generator_id
	, r.company_id
	, r.profit_ctr_id
	, r.pickup_date
	, r.manifest
	, r.manifest_page_num
	, r.manifest_line
	, r.manifest_quantity
	, r.manifest_unit
	, r.quantity container_count
	, r.manifest_container_code
from @r h
join ContactCORStatsReceiptTons r (nolock) 
	on h.receipt_id = r.receipt_id
	and h.company_id = r.company_id
	and h.profit_ctr_id = r.profit_ctr_id
GROUP BY 
	year(isnull(r.pickup_date, r.receipt_date))
	, month(isnull(r.pickup_date, r.receipt_date))
	, r.haz_flag
	, r.receipt_date
	, r.profile_id
	, r.generator_id
	, r.company_id
	, r.profit_ctr_id
	, r.pickup_date
	, r.manifest
	, r.manifest_page_num
	, r.manifest_line
	, r.manifest_quantity
	, r.manifest_unit
	, r.quantity
	, r.manifest_container_code

/*
select
	[year]
	, [month]
	, haz_flag
	, sum(tons) tons
from @s
GROUP BY 
	[year]
	, [month]
	, haz_flag
ORDER BY 
	[year]
	, [month]
	, haz_flag
*/

SELECT  
	@contact_id contact_id
	,s.*
	, p.approval_desc
	, g.epa_id
	, g.state_id
	, g.generator_id
	, g.generator_name
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_country
	, g.site_type
	, g.site_code
	FROM    @s s
	join profile p (nolock) on s.profile_id = p.profile_id
join generator g (nolock) on s.generator_id = g.generator_id
join tsdf t (nolock) on s.company_id = t.eq_company	and s.profit_ctr_id = t.eq_profit_ctr
	and t.eq_flag = 'T'
order by s.[year], s.[month], s.haz_flag desc	

RETURN 0
go


grant execute on sp_cor_excel_haz_vs_nonhaz to cor_user, eqweb, eqai
go


