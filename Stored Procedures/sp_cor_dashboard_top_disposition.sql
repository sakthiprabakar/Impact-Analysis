--drop proc sp_cor_dashboard_top_disposition
go

CREATE PROCEDURE sp_cor_dashboard_top_disposition (
	@web_userid		varchar(100)
	, @limit		int = 10
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @year			int = null
	, @quarter		int = null
	, @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_top_disposition

10/02/2019 MPM  DevOps 11560: Added logic to filter the result set
				using optional input parameter @generator_id_list.
10/22/2019 MPM	DevOps 12505:  Added logic to filter the result set
				using optional input parameter @customer_id_list.

Outputs the Top @limit Generators measured by @measure
over whole stats availability range (1 year at time of creation)

 sp_cor_dashboard_top_disposition 
	@web_userid		= 'vscheerer'
	, @limit = 500

exec sp_cor_dashboard_top_disposition 
	@web_userid		= 'erindira7'
	, @limit = 500
	, @customer_id_list = '15551'
	, @generator_id_list = '123056, 123057, 123058'

exec sp_cor_dashboard_top_disposition 
	@web_userid		= 'erindira7'
	, @limit = 500
	, @customer_id_list = '15551'
	, @generator_id_list = ''

************************************************************** */
/*
-- DEBUG:
declare 	@web_userid		varchar(100) = 'nyswyn100'
	, @limit			int = 10
*/

declare
	@i_web_userid		varchar(100)	= @web_userid
	, @i_limit			int				= isnull(@limit, 10)
	, @contact_id	int
 	, @i_date_start		datetime		= convert(date,@date_start)
	, @i_date_end		datetime		= convert(date, @date_end)
	, @i_period					varchar(2)		= @period
	, @i_year					int				= @year
	, @i_quarter				int				= @quarter
   , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(yyyy, -3, getdate())
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

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

if @i_period is not null
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'top_waste_streams')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'top_waste_streams')

		if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999


select 
d.disposal_service_id
, isnull(d.disposal_service_desc, 'Other') disposal_service_desc
, convert(decimal(10,2),total_tons) total_tons, _row
 from (
	SELECT  *
		, _row = row_number() over (order by total_tons desc)
	FROM (
		select contact_id, disposal_service_id
			, sum(total_pounds / 2000.00) as total_tons
		FROM ContactCORStatsDispositionTotal
		WHERE contact_id = @contact_id
		and _date between @i_date_start and @i_date_end
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
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				customer_id in (select customer_id from @customer)
			)
		)		
		GROUP BY contact_id, disposal_service_id
	) y
) x
left join DisposalService d (nolock) on x.disposal_service_id = d.disposal_service_id
where _row <= @i_limit
order by _row


return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_top_disposition TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_top_disposition TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_top_disposition TO COR_USER;
GO


