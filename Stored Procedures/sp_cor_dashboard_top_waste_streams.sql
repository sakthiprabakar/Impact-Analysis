-- drop proc sp_cor_dashboard_top_waste_streams
go

CREATE PROCEDURE sp_cor_dashboard_top_waste_streams (
	@web_userid		varchar(100)
	, @limit		int = 10
	, @measure		varchar(20) = 'volume' -- or 'spend'
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			int = null
	, @quarter		int = null
	, @haz_flag		char(1) = 'A' /* 'A'll or 'H'az or 'N'on-haz */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @pounds_or_tons	char(1) = 'T'  /* 'P'ounds or 'T'ons */
	, @order	char(1) = 'T'  /* 'T'op (default) or 'B'ottom) */
	, @workorder_type varchar(40) = '' /* leave blank/null to ignore this filter 
		otherwise require an exact match to workorder_type 
		Courtney's use case is 'Retail Product Offering'
		*/
	, @include_disposal_service bit = 0
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_top_waste_streams

10/03/2019 MPM  DevOps 11562: Added logic to filter the result set
				using optional input parameter @generator_id_list.

Outputs the Top @limit Waste Streams measured by @measure
over whole stats availability range (1 year at time of creation)

 sp_cor_dashboard_top_waste_streams 
	@web_userid		= 'nyswyn100'
	, @limit =50
	, @year = 2019
	, @quarter = 2
	, @measure = 'volume'
	
 sp_cor_dashboard_top_waste_streams 
	@web_userid		= 'court_c'
	, @limit = 100
	, @measure = 'spend'
	, @date_start = '12/1/2019'
	, @date_end = '12/31/2019'
	, @period = null 
	, @customer_id_list =''  /* Added 2019-07-15 by AA */
    , @generator_id_list =''  /* Added 2019-07-15 by AA */
    , @include_disposal_service =1



waste_stream                   total_tons  total_spend  _row
------------------------------ ----------- ------------ ----
NON-REGULATED WASTE            4212.35     2145400.28   1
Lith Ion Batt cont. in equip   47.63       815057.62    2
ELECTRONIC WASTE               555.67      743791.94    3
TOXIC LIQUID LOOSEPACK         120.23      642946.98    4
OTC SUPPLEMENTS AND COSMETICS  67.37       367868.69    5

sp_cor_dashboard_top_waste_streams 
	@web_userid	 = 'erindira7'
	, @limit = 10
	, @measure = 'spend'
	, @date_start = '1/1/2018'
	, @date_end = '10/03/2019'
	, @period = null 
	, @customer_id_list = ''  
    , @generator_id_list = '123056, 123057, 123058'

************************************************************** */
/*

-- Debugging:

DECLARE
	@web_userid		varchar(100) = 'court_c'
	, @limit		int = 20
	, @measure		varchar(20) = 'volume' -- or 'spend'
	, @date_start	datetime = '1/1/2020'
	, @date_end		datetime = '12/31/2021'
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			int = null
	, @quarter		int = null
	, @haz_flag		char(1) = 'A' /* 'A'll or 'H'az or 'N'on-haz */
	, @customer_id_list varchar(max)='15622'  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @pounds_or_tons	char(1) = 'P'  /* 'P'ounds or 'T'ons */
	, @order	char(1) = 'T'  /* 'T'op (default) or 'B'ottom) */
	, @workorder_type varchar(40) = 'Retail Product Offering' /* leave blank/null to ignore this filter 
		otherwise require an exact match to workorder_type */

*/

declare
	@i_web_userid		varchar(100)	= @web_userid
	, @i_limit			int				= isnull(@limit, 10)
	, @i_measure		varchar(20)		= isnull(@measure, 'volume')
	, @i_date_start		datetime		= convert(date,@date_start)
	, @i_date_end		datetime		= convert(date, @date_end)
	, @i_period					varchar(2)		= @period
	, @i_year					int				= @year
	, @i_quarter				int				= @quarter
	, @contact_id	int
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_haz_flag		char(1) = isnull(@haz_flag, 'A')
	, @i_pounds_or_tons char(1) = isnull(nullif(@pounds_or_tons, ''), 'T')
	, @i_order	char(1) = isnull(nullif(@order, ''), 'T')
	, @i_workorder_type varchar(40) = isnull(nullif(@workorder_type, ''), '')
	, @i_include_disposal_service bit = isnull(@include_disposal_service, 0)

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(yyyy, -1, getdate())
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

if @i_haz_flag not in ('A', 'H', 'N') set @i_haz_flag = 'A'

-- select @contact_id, @i_date_start, @i_date_end

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

if isnull(@i_period, '') <> ''
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'top_waste_streams')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'top_waste_streams')

		if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

/*
ContactCORStatsGeneratorTotal doesn't have real dates. It has _month and _year
so we have to translate the date ranges entered into a list of month+year to include
*/

declare @time table (
	m_date datetime
);

	
WITH CTE AS
(
	SELECT @i_date_start AS cte_start_date
	UNION ALL
	SELECT DATEADD(DAY, 1, cte_start_date)
	FROM CTE
	WHERE DATEADD(DAY, 1, cte_start_date) <= @i_date_end   
)
insert @time
SELECT convert(date,cte_start_date)
FROM CTE
  OPTION (MAXRECURSION 0)

--SELECT  *  FROM    @time

-- Now just join against @time in the same query above?

declare @foo table (
	waste_stream	varchar(50)
	, total_weight	decimal(10,2)
	, weight_unit	varchar(10)
	, disposal_service_id int
	, total_spend	money
	, currency_code	char(3)
	, _row			int
)

declare @bar table (
	waste_stream	varchar(50)
	, total_weight	decimal(10,2)
	, weight_unit	varchar(10)
	, disposal_service_id int
	, total_spend	money
	, currency_code	char(3)
	, _row			int
)


insert @foo
select waste_stream, convert(decimal(10,2),total_weight) total_weight, weight_unit
, case @i_include_disposal_service when 1 then disposal_service_id else null end disposal_service_id, total_spend, isnull(currency_code, 'USD') currency_code, _row
 from (
	SELECT  *
		, _row = dense_rank() over (order by
			case when @i_measure = 'volume' then total_weight end desc,
			case when @i_measure = 'spend' then total_spend end desc
		)
	FROM (
		select contact_id, waste_stream, case @i_include_disposal_service when 1 then disposal_service_id else null end disposal_service_id
			, sum(total_pounds / case when @i_pounds_or_tons = 'T' then 2000.00 else 1.0 end) as total_weight
			, case when @i_pounds_or_tons = 'T' then 'Tons' else 'Pounds' end as weight_unit
			, sum(total_spend) as total_spend
			, isnull(currency_code, 'USD') currency_code
		FROM ContactCORStatsGeneratorTotal c
		JOIN @time t
			on c._date = t.m_date
		WHERE contact_id = @contact_id
		and
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				c.customer_id in (select customer_id from @customer)
			)
		)		
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				c.generator_id in (select generator_id from @generator)
			)
		)		
		and
		(
			@i_workorder_type = ''
			or
			(
				@i_workorder_type <> ''
				and
				c.workorder_type = @i_workorder_type
			)
		)		
		and haz_flag = case @i_haz_flag when 'A' then haz_flag when 'H' then 'T' when 'N' then 'F' else haz_flag end
		GROUP BY contact_id, waste_stream, case @i_include_disposal_service when 1 then disposal_service_id else null end, isnull(currency_code, 'USD')
	) y
	WHERE 0 < case @i_measure when 'spend' then total_spend when 'volume' then total_weight else 0 end
) x



if @order = 'B' begin
	insert @bar select 
	waste_stream	
	, total_weight	
	, weight_unit	
	, disposal_service_id
	, total_spend	
	, currency_code	
	, _new_row = dense_rank() over (order by _row desc)
	from @foo
	
	delete from @foo
	insert @foo select * from @bar 
end

declare @all_weight decimal(20,2), @all_spend money
select @all_weight = sum(total_weight) 
	, @all_spend = sum(total_spend)
from @foo


select 
	f.waste_stream
	, f.total_weight
	, case when isnull(@all_weight, 0) > 0 then convert(decimal(20,2),(f.total_weight / @all_weight) * 100) else 0 end pct_weight
	, f.weight_unit
	, ds.disposal_service_desc
	, f.total_spend
	, case when isnull(@all_spend, 0) > 0 then convert(decimal(20,2),(f.total_spend / @all_spend) * 100) else 0 end pct_spend
	, isnull(f.currency_code, 'USD') currency_code
	, f._row
from @foo f
LEFT JOIN disposalservice ds
	on f.disposal_service_id = ds.disposal_service_id
where _row <= @i_limit
order by _row

return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_top_waste_streams TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_top_waste_streams TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_top_waste_streams TO COR_USER;
GO
