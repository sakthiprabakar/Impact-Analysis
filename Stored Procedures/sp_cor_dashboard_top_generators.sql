--drop proc sp_cor_dashboard_top_generators
go

CREATE PROCEDURE sp_cor_dashboard_top_generators (
	@web_userid		varchar(100)
	, @limit		int = 10
	, @measure		varchar(20) = 'volume' -- or 'spend'
	, @start_date	datetime = null
	, @end_date		datetime = null
	, @haz_flag		char(1) = 'A' /* 'A'll, 'H'az only, or 'N'on-haz only */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @excel_output	int = 0 /* 1 for excel */
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
sp_cor_dashboard_top_generators

10/02/2019 MPM  DevOps 11561: Added logic to filter the result set
				using optional input parameter @generator_id_list.
07/20/2021 DO:17669 - Added Pounds/Tons option
12/28/2021 DO:29399 - Updates for Order, Workorder Type, Disposal

Outputs the Top @limit Generators measured by @measure
over whole stats availability range (1 year at time of creation)

 sp_cor_dashboard_top_generators 
	@web_userid		= 'zachery.wright'
	, @limit = 5
	, @measure = 'volume'
	, @start_date = '7/1/2019'
	, @end_date = '7/31/2019'
	, @haz_flag = 'A'
	, @order = 'B'

 sp_cor_dashboard_top_generators 
	@web_userid		= 'court_c'
	, @limit = 10
	, @measure = 'volume'
	, @start_date = '1/1/2021'
	, @end_date = '12/31/2021'
	, @haz_flag = 'A'
	, @customer_id_list = '15622'
	, @order = 'B'

 sp_cor_dashboard_top_generators 
	@web_userid		= 'nyswyn100'
	, @limit = 10
	, @measure = 'volume'
	, @start_date = '1/1/2018'
	, @end_date = '10/03/2022'
	, @haz_flag = 'A'
	, @customer_id_list = null
	, @generator_id_list = ''
	, @excel_output = 1
	, @pounds_or_tons = 'P'

************************************************************** */

/*
-- Debugging:

DECLARE
	@web_userid		varchar(100) = 'court_c'
	, @limit		int = 10
	, @measure		varchar(20) = 'spend' -- 'volume' or 'spend'
	, @start_date	datetime = '1/1/2020'
	, @end_date		datetime = '12/31/2021'
	, @haz_flag		char(1) = 'A' /* 'A'll or 'H'az or 'N'on-haz */
	, @customer_id_list varchar(max)='15622'  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
	, @pounds_or_tons	char(1) = 'P'  /* 'P'ounds or 'T'ons */
	, @order	char(1) = 'T'  /* 'T'op (default) or 'B'ottom) */
	, @workorder_type varchar(40) = 'Retail Product Offering' /* leave blank/null to ignore this filter 
		otherwise require an exact match to workorder_type */
    , @excel_output	int = 0 /* 1 for excel */
	, @include_disposal_service bit = 1

*/

declare
	@i_web_userid		varchar(100)	= @web_userid
	, @i_limit			int				= isnull(@limit, 10)
	, @i_measure		varchar(20)		= isnull(@measure, 'volume')
	, @contact_id	int
	, @i_start_date	datetime = convert(date, @start_date)
	, @i_end_date		datetime = convert(date, @end_date)
	, @i_haz_flag	char(1) = isnull(@haz_flag, 'A')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_excel_output int = isnull(@excel_output, 0)
 	, @i_pounds_or_tons	char(1) = isnull(@pounds_or_tons, 'T')
	, @i_order	char(1) = isnull(nullif(@order, ''), 'T')
	, @i_workorder_type varchar(40) = isnull(nullif(@workorder_type, ''), '')
	, @i_include_disposal_service bit = isnull(@include_disposal_service, 0)


select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_start_date, '1/1/1999') = '1/1/1999' set @i_start_date = dateadd(m, -1, getdate())
if isnull(@i_end_date, '1/1/1999') = '1/1/1999' set @i_end_date = getdate()
if datepart(hh, @i_end_date) = 0 set @i_end_date = @i_end_date + 0.99999
if @i_haz_flag not in ('A', 'H', 'N') set @i_haz_flag = 'A'

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

declare @foo table (
	generator_id		int
	, total_weight decimal(10,2)
	, weight_unit varchar(10)
	, disposal_service_id int
	, total_spend money
	, currency_code char(3)
	, _row bigint
)

declare @bar table (
	generator_id		int
	, total_weight decimal(10,2)
	, weight_unit varchar(10)
	, disposal_service_id int
	, total_spend money
	, currency_code char(3)
	, _row bigint
)


insert @foo
select 
	x.generator_id
	, convert(decimal(10,2),x.total_weight) total_weight
	, convert(varchar(10),'Tons') as weight_unit
	, case @i_include_disposal_service when 1 then disposal_service_id else null end disposal_service_id
	, x.total_spend
	, x.currency_code
	, _row
 from (
	SELECT  
		y.contact_id
		, y.generator_id
		, y.total_weight
		, y.disposal_service_id
		, y.total_spend
		, y.currency_code
		, _row = dense_rank() over (
			order by
			case when @i_measure = 'volume' then y.total_weight end desc,
			case when @i_measure = 'spend' then y.total_spend end desc
		  )
	FROM (
		select 
			contact_id
			, generator_id
			, sum(total_pounds / 2000.00) as total_weight
			, case @i_include_disposal_service when 1 then disposal_service_id else null end disposal_service_id
			, sum(total_spend) as total_spend
			, isnull(currency_code, 'USD') currency_code
		FROM ContactCORStatsGeneratorTotal
		WHERE contact_id = @contact_id
		and _date between @i_start_date	and @i_end_date
		and haz_flag = case @i_haz_flag when 'A' then haz_flag else case when @i_haz_flag = 'H' then 'T' else 'F' end end
		and
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
		and
		(
			@i_workorder_type = ''
			or
			(
				@i_workorder_type <> ''
				and
				workorder_type = @i_workorder_type
			)
		)
		GROUP BY 
			contact_id
			, generator_id
			, case @i_include_disposal_service when 1 then disposal_service_id else null end
			, currency_code
	) y
	WHERE 0 < case @i_measure when 'spend' then total_spend when 'volume' then total_weight else 0 end
) x
--join generator g (nolock) on x.generator_id = g.generator_id
-- where _row <= @i_limit
order by _row

if @i_pounds_or_tons = 'P'
	update @foo set total_weight = total_weight * 2000.00
	, weight_unit = 'Pounds'

if @order = 'B' begin
	insert @bar 
	select 
		generator_id
		, total_weight
		, weight_unit
		, disposal_service_id
		, total_spend
		, currency_code
--		, _row = dense_rank() over (order by _row desc)
		, _row = dense_rank() over (
			order by
			case when @i_measure = 'volume' then total_weight end,
			case when @i_measure = 'spend' then total_spend end
		  )

	from @foo
	
	delete from @foo
	insert @foo select * from @bar 
end

if @i_excel_output = 0
	select 
		g.site_type
		, g.generator_name
		, g.epa_id
		, g.generator_city
		, g.generator_state
		, g.generator_country
		, g.site_code
		, g.generator_id
		, ds.disposal_service_desc
		, t.total_weight
		, t.weight_unit
		, t.total_spend
		, t.currency_code
		, t._row
	from @foo t
	join generator g on t.generator_id = g.generator_id 
	LEFT JOIN disposalservice ds
		on t.disposal_service_id = ds.disposal_service_id
	where _row <= @i_limit
	order by t._row
else
	select
		g.site_type
		, g.generator_name
		, g.epa_id
		, g.generator_city
		, g.generator_state
		, g.generator_country
		, g.site_code
		, g.generator_id
		, ds.disposal_service_desc
		, t.total_weight
		, t.weight_unit
		, t.total_spend
		, t.currency_code
		, t._row
	from @foo t
	join generator g on t.generator_id = g.generator_id 
	LEFT JOIN disposalservice ds
		on t.disposal_service_id = ds.disposal_service_id
	where _row <= @i_limit
	order by _row



return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_top_generators TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_top_generators TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_top_generators TO COR_USER;
GO


