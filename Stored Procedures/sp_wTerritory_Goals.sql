CREATE procedure sp_wTerritory_Goals
@territory_code varchar(8),
@start_date datetime,
@end_date datetime
as
if len(@territory_code) > 0
begin
	declare @start int
	declare @next int
	declare @len int
	declare @more int
	declare @tmp varchar(8)
	select @more = 1
	select @start = 0
	create table #territorylist (territory varchar(8))
	while @more = 1
	begin
		select @next = charindex(',', @territory_code, @start + 1)
		if @next = 0
			select @len = len(@territory_code)
		else
			select @len = @next - @start
		select @tmp = replace(substring(@territory_code, @start + 1, @len), ',', '')
		insert into #territorylist values (@tmp)
		select @start = @next
		select @next = 0
		if @start = 0
			select @more = 0
	end
	select a.territory_code, a.ae_name, a.year, a.month, 0 as revenue_month, isnull(a.goal,0) as goal_month,
	isnull((select b.goal from territory_goals b where b.territory_code = a.territory_code
	and b.territory_code = a.territory_code
	and b.year = a.year -1
	and b.month = a.month
	),0) as goal_month_last_year,
	0 as revenue_ytd,
	isnull((select sum(b.goal) from territory_goals b where b.territory_code = a.territory_code
	and b.territory_code = a.territory_code
	and b.year = a.year
	and b.month >= 1 and b.month <= a.month
	),0) as goal_ytd,
	isnull((select sum(b.goal) from territory_goals b where b.territory_code = a.territory_code
	and b.territory_code = a.territory_code
	and b.year = a.year -1
	and b.month >= 1 and b.month <= a.month
	), 0) as goal_ytd_last_year
	from territory_goals a 
	where territory_code in (select territory from #territorylist)
	and year >= datepart(yyyy, @start_date) and year <= datepart(yyyy, @end_date)
	and month >= datepart(mm, @start_date) and month <= datepart(mm, @end_date)
	order by territory_code, year desc, month desc
end
else
begin
	select a.territory_code, a.ae_name, a.year, a.month, 0 as revenue_month, isnull(a.goal,0) as goal_month,
	isnull((select b.goal from territory_goals b where b.territory_code = a.territory_code 
	and b.territory_code = a.territory_code
	and b.year = a.year -1
	and b.month = a.month
	),0) as goal_month_last_year,
	0 as revenue_ytd,
	isnull((select sum(b.goal) from territory_goals b where b.territory_code = a.territory_code 
	and b.territory_code = a.territory_code
	and b.year = a.year
	and b.month >= 1 and b.month <= a.month
	),0) as goal_ytd,
	isnull((select sum(b.goal) from territory_goals b where b.territory_code = a.territory_code 
	and b.territory_code = a.territory_code
	and b.year = a.year -1
	and b.month >= 1 and b.month <= a.month
	),0) as goal_ytd_last_year
	from territory_goals a 
	where year >= datepart(yyyy, @start_date) and year <= datepart(yyyy, @end_date)
	and month >= datepart(mm, @start_date) and month <= datepart(mm, @end_date)
	order by territory_code, year desc, month desc
end
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wTerritory_Goals] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wTerritory_Goals] TO [COR_USER]
    AS [dbo];


