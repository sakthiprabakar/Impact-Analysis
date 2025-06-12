-- 
drop proc sp_cor_dashboard_service_count_spend

go

create proc sp_cor_dashboard_service_count_spend (
	@web_userid	varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @year			int = null
	, @quarter		int = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @schedule_flag	varchar(20) = 'both' -- 'scheduled', 'on demand' or 'both'
    , @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
)
as
/* ***********************************************************
sp_cor_dashboard_service_count_spend 


sp_cor_dashboard_service_count_spend 'nyswyn100'


sp_cor_dashboard_service_count_spend
	@web_userid = 'zachery.wright'
	, @date_start = '1/1/2018'
	, @date_end = '12/31/2018'
	, @schedule_flag = 'both'

_year	_month	_count	_total
2018	1	310	1332380.25
2018	2	273	1070499.86
2018	3	288	1096348.82
2018	4	239	1090497.41
2018	5	270	1213330.36
2018	6	254	1099295.37
2018	7	254	1159289.13
2018	8	263	1347863.84
2018	9	232	1150305.44
2018	10	324	1468018.31
2018	11	315	1389770.53
2018	12	267	1038895.36
--33s



exec sp_cor_dashboard_service_count_spend
	@web_userid = 'court_c'
	, @date_start = '1/1/2021'
	, @date_end = '12/31/2021'
	, @schedule_flag = 'scheduled'
;
exec sp_cor_dashboard_service_count_spend
	@web_userid = 'court_c'
	, @date_start = '1/1/2021'
	, @date_end = '12/31/2021'
	, @schedule_flag = 'on demand'
;
exec sp_cor_dashboard_service_count_spend
	@web_userid = 'court_c'
	, @date_start = '1/1/2021'
	, @date_end = '12/31/2021'
	, @schedule_flag = 'both'


	
*********************************************************** */
/*
-- DEBUG:
declare
	@web_userid varchar(100) = 'zachery.wright'
	, @date_start datetime = '1/1/2018'
	, @date_end datetime = '12/31/2018'
	, @schedule_flag	varchar(20) = 'both' -- 'scheduled', 'on demand' or 'both'
*/

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= convert(date, @date_start)
	, @i_date_end				datetime		= convert(date, @date_end)
	, @i_year					int				= @year
	, @i_quarter				int				= @quarter
	, @i_period					varchar(2)		= @period
	, @i_schedule_flag			varchar(20)		= isnull(@schedule_flag, 'both')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @contact_id	int

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
  
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = '1/1/' + convert(varchar(4), year(getdate()))
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
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'service_count_spend')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'service_count_spend')

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


select
	t.m_yr _year
	, t.m_mo _month
	, sum(b.total_count) _count
	, sum(b.total_spend) _total
	, sum(b.total_spend) / sum(b.total_count) _avg_cost_per_stop
	, isnull(b.currency_code, 'USD') currency_code
from @time t
left join ContactCORStatsServiceCountSpend b
	on t.m_yr = b._year
	and t.m_mo = b._month
	and b.contact_id = @contact_id
	and isnull(b.offschedule_service_flag, 'F') =
	case @i_schedule_flag
		when 'scheduled' then 'F'
		when 'on demand' then 'T'
		when 'both' then isnull(b.offschedule_service_flag, 'F')
		else 'X' -- screw up the argument, you get to see nothing.
	end
where
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				customer_id in (select customer_id from @customer)
			)
		)
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				generator_id in (select generator_id from @generator)
			)
		)
GROUP BY 
	t.m_yr
	, t.m_mo
	, isnull(b.currency_code, 'USD')
ORDER BY 
	t.m_yr
	, t.m_mo

 
return 0

go

grant execute on sp_cor_dashboard_service_count_spend to eqai, eqweb, cor_user
go
