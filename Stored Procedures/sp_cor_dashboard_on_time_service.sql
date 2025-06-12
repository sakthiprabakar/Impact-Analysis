-- drop proc sp_cor_dashboard_on_time_service
go

CREATE PROCEDURE sp_cor_dashboard_on_time_service (
	@web_userid		varchar(100)
  , @customer_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
  , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_on_time_service

Outputs the Year-Mo percentage of scheduled services that were on time
on-time = date(WorkOrderStop.date_act_arrive) = date(WorkOrderStop.date_est_arrive)

2.2. Assumptions/constraints

2.2.1. To quality as a work order to appear on this report, the work order should be:

2.2.1.1. Completed

2.2.1.2. Work Order Off Schedule Service Flag should NOT be set to True.

2.2.2. On-Time should be considered as a work order that has an actual service date (WorkOrderStop.date_act_arrive) that matches the work order scheduled service date (WorkOrderStop.date_est_arrive).

2.2.3. Generate a calculation of the count of scheduled services that were performed during the month.

2.2.4. Generate a calculation of the count of scheduled services that were on-time during the month.

2.2.5. Calculation of the percentage should be made based on the count of on-time, scheduled services that were on-time during the month divided by the total count of scheduled services planned for the month.

 sp_cor_dashboard_on_time_service 
	@web_userid		= 'zachery.wright'

select * from contact where web_userid = 'zachery.wright'
select * from ContactCorStatsOnTimeService WHERE contact_id = 184522

************************************************************** */
/*
-- DEBUG:
declare 	@web_userid		varchar(100) = 'zachery.wright'
*/

declare
	@i_web_userid	varchar(100)	= @web_userid
	, @i_min_year	int
	, @i_min_mo		int
	, @i_min_date	datetime
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid

select @i_min_year = min(_year), @i_min_mo = min(_mo)
from ContactCorStatsOnTimeService
WHERE contact_id = @contact_id

set @i_min_date = convert(date, convert(varchar(2), @i_min_mo) + '/1/' + convert(varchar(4), @i_min_year))

if @i_min_date is not null
	if @i_min_date < dateadd(m, -5, getdate()) 
	begin
		set @i_min_date = dateadd(m, -5, getdate()) 
		set @i_min_date = convert(date, convert(varchar(2), datepart(m, @i_min_date)) + '/1/' + convert(varchar(4), datepart(yyyy, @i_min_date)))
	end

if @i_min_date is null set @i_min_date = getdate() - 365

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
    SELECT @i_min_date AS cte_start_date
    UNION ALL
    SELECT DATEADD(MONTH, 1, cte_start_date)
    FROM CTE
    WHERE DATEADD(MONTH, 1, cte_start_date) <= getdate()
)
insert @time
SELECT year(cte_start_date), month(cte_start_date)
FROM CTE

SELECT  t.m_yr as _year, t.m_mo as _month, isnull(s.scheduled_count, 0) scheduled_count, isnull(s.on_time_count, 0) on_time_count, isnull(s.on_time_scheduled_pct, 0) on_time_scheduled_pct
FROM    @time t
left join ContactCORStatsOnTimeService s
	on t.m_yr = s._year
	and t.m_mo = s._mo
	and s.contact_id = @contact_id
where
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				s.customer_id in (select customer_id from @customer)
			)
		)
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				s.generator_id in (select generator_id from @generator)
			)
		)

ORDER BY t.m_yr, t.m_mo


return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_on_time_service TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_on_time_service TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_on_time_service TO COR_USER;
GO


