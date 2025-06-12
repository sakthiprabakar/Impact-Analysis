CREATE Procedure sp_wAE_Funnel_List
	@logon	varchar(30),
	@territory_list	varchar(255),
	@status_list	varchar(255),
	@start_date	varchar(20),
	@end_date	varchar(20)
as

set nocount on

declare @tmpCount int
declare @start int
declare @next int
declare @len int
declare @more int
declare @tmp varchar(8)
declare @sdate datetime
declare @edate datetime

create table #TerritoryRestriction (territory varchar(8))
insert into #TerritoryRestriction select Territory_Code as territory from plt_12_ai.dbo.Users Where user_code = @logon and territory_code >= 0
select @tmpCount = count(*) from #TerritoryRestriction
if @tmpCount = 0
begin
	insert into #TerritoryRestriction select distinct Territory_Code as territory from Territory  Where territory_code >= 0
end
select @more = 1
select @start = 0
create table #TerritoryFilter (territory varchar(8))
if len(@territory_list) > 0
begin
	while @more = 1
	begin
		select @next = charindex(',', @territory_list, @start + 1)
		if @next = 0
			select @len = len(@territory_list)
		else
			select @len = @next - @start
		select @tmp = replace(substring(@territory_list, @start + 1, @len), ',', '')
		insert into #TerritoryFilter values (@tmp)
		select @start = @next
		select @next = 0
		if @start = 0
			select @more = 0
	end
end
else
begin
	insert into #TerritoryFilter select distinct territory from wtbl_AE_Funnel_Update
end

select @more = 1
select @start = 0
create table #StatusFilter (status char(1))
if len(@status_list) > 0
begin
	while @more = 1
	begin
		select @next = charindex(',', @status_list, @start + 1)
		if @next = 0
			select @len = len(@status_list)
		else
			select @len = @next - @start
		select @tmp = replace(substring(@status_list, @start + 1, @len), ',', '')
		insert into #StatusFilter values (@tmp)
		select @start = @next
		select @next = 0
		if @start = 0
		select @more = 0
	end
end
else
begin
	insert into #StatusFilter select distinct status from wtbl_AE_Funnel_Update
end
if isdate(@start_date) = 0
	select @sdate = dateadd(yy, -20, getdate())
else
	select @sdate = @start_date
	

if isdate(@end_date) = 0
	select @edate = dateadd(yy, 20, getdate())
else
	select @edate = @end_date

-- select territory from #TerritoryRestriction
-- select territory from #TerritoryFilter
-- select status from #StatusFilter
-- select @sdate
-- select @edate

set nocount off

select record_id, 
	status, 
	isnull(territory + ' (' + (select isnull(user_code, '') from plt_12_ai.dbo.users where territory = territory_code and group_id <> 0) + ')', territory), 
	company_02_flag, 
	company_03_flag, 
	company_12_flag, 
	company_14_00_flag, 
	company_14_01_flag, 
	company_14_02_flag, 
	company_14_03_flag, 
	company_14_04_flag, 
	company_14_05_flag, 
	company_14_06_flag, 
	company_14_07_flag, 
	company_14_08_flag, 
	company_14_09_flag, 
	company_14_10_flag, 
	company_14_11_flag, 
	company_14_12_flag, 
	company_15_flag, 
	direct_flag, 
	job_type, 
	project_type, 
	customer_id, 
	customer_name, 
	customer_contact, 
	generator_name, 
	generator_id, 
	price, 
	bill_unit_code, 
	quantity, 
	project_interval, 
	number_of_intervals, 
	calc_revenue_flag, 
	est_revenue, 
	probability, 
	0,
	est_start_date, 
	est_end_date, 
	description, 
	added_by, 
	modified_by, 
	date_added, 
	date_modified, 
	record_status
from 
	wtbl_ae_funnel_update
where
	record_status = 'A'
	and territory in (select territory from #TerritoryRestriction)
	and territory in (select territory from #TerritoryFilter)
	and status in (select status from #StatusFilter)
	and est_start_date between @sdate and @edate
order by
	territory, est_start_date, est_end_date



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wAE_Funnel_List] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wAE_Funnel_List] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wAE_Funnel_List] TO [EQAI]
    AS [dbo];

