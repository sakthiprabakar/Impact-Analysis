DROP PROCEDURE IF EXISTS sp_cor_dashboard_er_type
GO

create proc sp_cor_dashboard_er_type  (
	@web_userid	varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @period		varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			int = null
	, @quarter		int = null
	, @excel_flag	char(1) = 'F'
    , @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
)
as
/* *************************************************************
sp_cor_dashboard_er_type

dev ops ticket 3494

Returns summary & detail information about work order ER jobs
for the cor dashboard

Note, the NON excel version returns a bunch of empty (null) fields at the end, but only the
first few fields are revelvant.
Enabling the Excel flag populates the other fields

Samples:

exec sp_cor_dashboard_er_type	'nyswyn100', 'F'
exec sp_cor_dashboard_er_type	'nyswyn100', 'T'
exec sp_cor_dashboard_er_type	'zachery.wright', 'F'

exec sp_cor_dashboard_er_type 
	@web_userid		= 'court_c'
	, @date_start	= '1/1/2019'
	, @date_end		= '1/1/2021'
	, @period		= null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			= null
	, @quarter		= null
	, @excel_flag	= 'F'

SELECT  * 
	from workordertypedescription
	where workorder_type_id in (3,63) -- **
	ORDER BY workorder_type_id , description

exec sp_cor_dashboard_er_type 
	@web_userid		= 'nyswyn100'
	, @date_start	= null
	, @date_end		= null
	, @period		= null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			= 2019
	, @quarter		= 3
	, @excel_flag	= 'F'

select c.customer_id, c.cust_name, w.workorder_type_id, w.workorder_type_desc_uid, * 
from workorderheader w 
join customer c on w.customer_id = c.customer_id
left outer join WorkOrderTypeDescription w2
on w.workorder_type_desc_uid = w2.workorder_type_desc_uid
where w.workorder_type_id in (3, 63) 
and c.customer_id in(15940, 18462)--= '601113'
and w.submitted_flag = 'T' 
 


History:
	2019-07-19	JPB	Created
	2/22/2022	MPM	DevOps 19126 - Added "fuzzy logic" for emergency response workorder_type_ids.

************************************************************* */

/* -- debugging
---	declare @web_userid	varchar(100) = 'nyswyn100'		, @excel_flag char(1) = 'F'
---
declare
	@web_userid		varchar(100)= 'court_c'
	, @date_start	datetime = '1/1/2019'
	, @date_end		datetime = '1/1/2021'
	, @period		varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			int = null
	, @quarter		int = null
	, @excel_flag	char(1) = 'F'
    , @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */

*/

declare @contact_id int 
	, @months_backward int = -6 -- How far back to look?  Should be -6 in prod.
	, @i_date_start		datetime		= convert(date,@date_start)
	, @i_date_end		datetime		= convert(date, @date_end)
	, @i_period					varchar(2)		= @period
	, @i_year					int				= @year
	, @i_quarter				int				= @quarter
	, @i_excel_flag char(1) = isnull(@excel_flag, 'F')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	
select top 1 @contact_id = contact_id from CORcontact where web_userid = @web_userid

if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, @months_backward +1, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()

if @i_year is not null and @i_year not between 1990 and year(getdate()) set @i_year = null
if @i_quarter is not null and @i_quarter not in (1,2,3,4) set @i_quarter = null

if @i_year is not null
	if @i_quarter is null
		select @i_date_start = '1/1/' + convert(varchar(4), @i_year)
			, @i_date_end = '12/31/' + convert(varchar(4), @i_year)
	else
		select @i_date_start = convert(varchar(2), @i_quarter * 3 -2) + '/1/' + convert(varchar(4), @i_year)
			, @i_date_end = dateadd(qq, 1, convert(varchar(2), @i_quarter * 3 -2) + '/1/' + convert(varchar(4), @i_year)) - 0.000001
		-- Dumb trick: Q1,Q2,Q3,Q4 start month = Q X 3 -2.  ie. Q4 = 4 X 3 (12) -2 = 10.
		-- Dumb trick 2: Q end date = Q start date + 1q, minus -1s.

if @i_period is not null
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'er_type')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'er_type')

		if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

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

declare @time table (
	[year]	 int,
	[month]	int
)
declare @looptime datetime = @i_date_start
while @looptime < @i_date_end begin
	insert @time select year(@looptime), month(@looptime)
	set @looptime = dateadd(m, 1, @looptime)
end

declare @foo table (
	contact_id		int
	, workorder_id	int
	, company_id	int
	, profit_ctr_id	int
	, service_date		datetime
	, workorder_type_desc_uid	int
	, workorder_status char(1)
	, customer_id int
	, generator_id int
	, workorder_type_id	int
)
insert @foo (contact_id, workorder_id, company_id, profit_ctr_id, service_date, workorder_type_desc_uid, workorder_status, customer_id, generator_id, workorder_type_id)
SELECT  b.contact_id, b.workorder_id, b.company_id, b.profit_ctr_id, isnull(b.service_date, b.start_date), h.workorder_type_desc_uid, h.workorder_status, b.customer_id, b.generator_id, h.workorder_type_id
FROM    contactcorworkorderheaderbucket b (nolock) 
	join workorderheader h on b.workorder_id = h.workorder_id and b.company_id = h.company_id and b.profit_ctr_id = h.profit_ctr_id
	JOIN WorkOrderTypeHeader t
		ON t.workorder_type_id = h.workorder_type_id
WHERE b.contact_id = @contact_id
and h.submitted_flag = 'T'
and h.workorder_status = 'A'
AND (t.account_desc like '%emergency response%' OR h.workorder_type_id in (3, 63, 77, 78, 79, 80))
and isnull(b.service_date, b.start_date) between @i_date_start and @i_date_end
and		(
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

/*
update @foo set workorder_type_desc_uid = (
	select workorder_type_desc_uid 
	from workordertypedescription
	where workorder_type_id in (3,63)
	and description = 'Other'
)
where workorder_type_desc_uid is null
*/

update f 
	set workorder_type_desc_uid = d.workorder_type_desc_uid 
from @foo f 
join workordertypedescription d 
	on d.workorder_type_id = f.workorder_type_id
	and d.description = 'Other'
JOIN WorkOrderTypeHeader h
	ON h.workorder_type_id = f.workorder_type_id
	AND (h.account_desc like '%emergency response%' OR f.workorder_type_id in (3, 63, 77, 78, 79, 80))
where f.workorder_type_desc_uid is null


declare @bar table (
	workorder_type_desc_uid	int
	, label varchar(100)
	, [workorder_billed_amount] money
	, workorder_id	int
	, company_id	int
	, profit_ctr_id	int
	, service_date		datetime
	, workorder_status char(1)
	, customer_id int
	, generator_id int
	, workorder_type_id int
)

insert @bar
select 
	f.workorder_type_desc_uid
	, wtd.description as label
	, sum(b.total_extended_amt) as [workorder_billled_amount]
	, f.workorder_id
	, f.company_id
	, f.profit_ctr_id
	, f.service_date
	, f.workorder_status
	, f.customer_id
	, f.generator_id
	, f.workorder_type_id
from @foo f
inner join billing b (nolock)
	on f.workorder_id = b.receipt_id
	and f.company_id = b.company_id
	and f.profit_ctr_id = b.profit_ctr_id
	and b.trans_source = 'W'
	and b.status_code = 'I'
inner join workordertypedescription wtd
	on f.workorder_type_desc_uid = wtd.workorder_type_desc_uid
GROUP BY 
	f.workorder_type_desc_uid
	, wtd.description 
	, f.workorder_id
	, f.company_id
	, f.profit_ctr_id
	, f.service_date
	, f.workorder_status
	, f.customer_id
	, f.generator_id
	, f.workorder_type_id

-- select * from @bar
declare @label table (
	label varchar(100)
)
insert @label
select distinct label
from @bar

--select year(service_date), month(service_date), label from @bar order by  year(service_date), month(service_date), label

select 
	x.year
	, x.month
	, left(datename(month, convert(varchar(2), x.month) + '/1/' + convert(Varchar(4), x.year)),3) + ' ' + convert(varchar(4), x.year) as month_label
	, x.label
	, count(f.workorder_id) [count]
	, sum(f.workorder_billed_amount) workorder_billed_amount
	, case when isnull(@excel_flag, 'F') = 'T' then f.company_id else null end			as company_id
	, case when isnull(@excel_flag, 'F') = 'T' then f.profit_ctr_id else null end		as profit_ctr_id
	, case when isnull(@excel_flag, 'F') = 'T' then f.workorder_id else null end		as workorder_id
	, case when isnull(@excel_flag, 'F') = 'T' then f.workorder_status else null end	as workorder_status
	, case when isnull(@excel_flag, 'F') = 'T' then f.customer_id else null end			as customer_id
	, case when isnull(@excel_flag, 'F') = 'T' then cust.cust_name else null end		as cust_name
	, case when isnull(@excel_flag, 'F') = 'T' then f.generator_id else null end		as generator_id
	, case when isnull(@excel_flag, 'F') = 'T' then g.epa_id else null end				as epa_id
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_name else null end		as generator_name
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_city else null end		as generator_city
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_state else null end		as generator_state
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_zip_code else null end	as generator_zip_code
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_country else null end	as generator_country
from (

	select l.label
	, t.year
	, t.month
	from @time t
	cross join @label l
) x
left join @bar f
	on x.year = year(f.service_date)
	and x.month = month(f.service_date)
	and x.label = f.label
left join customer cust (nolock)
	on f.customer_id = cust.customer_id
left join generator g  (nolock)
	on f.generator_id = g.generator_id
GROUP BY 
	x.year
	, x.month
	, x.label
	, case when isnull(@excel_flag, 'F') = 'T' then f.company_id else null end			
	, case when isnull(@excel_flag, 'F') = 'T' then f.profit_ctr_id else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then f.workorder_id else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then f.workorder_status else null end	
	, case when isnull(@excel_flag, 'F') = 'T' then f.customer_id else null end			
	, case when isnull(@excel_flag, 'F') = 'T' then cust.cust_name else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then f.generator_id else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then g.epa_id else null end				
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_name else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_city else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_state else null end		
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_zip_code else null end	
	, case when isnull(@excel_flag, 'F') = 'T' then g.generator_country else null end	
ORDER BY 
	x.year desc
	, x.month desc
	, x.label

return 0
GO

grant execute on sp_cor_dashboard_er_type to eqweb, cor_user
GO
