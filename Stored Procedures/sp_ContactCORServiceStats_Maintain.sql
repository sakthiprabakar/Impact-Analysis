-- drop proc sp_ContactCORServiceStats_Maintain

go

create proc sp_ContactCORServiceStats_Maintain
as
/***********************************************************
-- Creating a table (#out) of Service Count & Spend stats for scheduled/ondemand work orders available per contact

-- Doing this on the fly (sp_cor_dashboard_service_count_spend) is slow
-- when a whole year is chosen, and clickthroughs permit all years not just 1 recent

-- Thought process is to only calculate 1 or 2 recent years' on the fly, AND
-- pre-process older years into a stats table weekly or nightly instead of hourly

-- The question left open: A new contact would only get the latest year of data refreshed 
-- every 10m/hour until the next all-history job.   Is that ok?

***********************************************************/

SET Transaction isolation level read uncommitted  

if object_id('tempdb..#bar') is not null drop table #bar
if object_id('tempdb..#rex') is not null drop table #rex
if object_id('tempdb..#out') is not null drop table #out


create table #bar (
	contact_id				int
	, workorder_id			int
	, company_id			int
	, profit_ctr_id			int
	, customer_id			int
	, generator_id			int
	, off_schedule_flag		char(1)
	, _year					int
	, _month				int
	, prices				int
	, wtotal				money
	, currency_code			char(3)
)

create table #rex (
	contact_id				int
	, workorder_id			int
	, company_id			int
	, profit_ctr_id			int
	, customer_id			int
	, generator_id			int
	, off_schedule_flag		char(1)
	, _year					int
	, _month				int
	, prices				int
	, rtotal				money
	, currency_code			char(3)
)

create table #out (
	contact_id					int
	, _year						int
	, _month					int
	, offschedule_service_flag	char(1)
	, customer_id				int
	, generator_id				int
	, total_count				int
	, total_spend				money
	, currency_code				char(3)
	, last_updated				datetime
)

declare @generatestats int = 0
	, @now datetime = getdate()

begin try
	if not exists (select 1 from sysobjects where name = 'ContactCORStatsServiceCountSpend')
		set @generatestats = 1
	else	
		if not exists (select 1 from sysobjects o join syscolumns c on o.id = c.id where o.name = 'ContactCORStatsServiceCountSpend' and c.name = 'last_updated')
			set @generatestats = 1
				else -- NOTE: You have to create a dummy table named ContactCORStatsServiceCountSpend before the first run to get this to work
					if (select isnull(min(last_updated), '1/1/2000') from ContactCORStatsServiceCountSpend) < convert(date, getdate())
						set @generatestats = 1
end try
begin catch
	set @generatestats = 1
end catch

if @generatestats = 1 begin

	insert #bar
	(
		contact_id			
		, workorder_id		
		, company_id		
		, profit_ctr_id		
		, customer_id		
		, generator_id		
		, off_schedule_flag	
		, _year				
		, _month			
		, prices			
		, wtotal			
		, currency_code		
	)
	select 
		f.contact_id
		, f.workorder_id
		, f.company_id
		, f.profit_ctr_id
		, f.customer_id
		, f.generator_id
		, isnull(h.offschedule_service_flag, 'F')
		, year(f.service_date) 
		, month(f.service_date)
		, f.prices
		, isnull(sum(b.total_extended_amt), 0)
		, b.currency_code
	from ContactCORWorkorderHeaderBucket f
	join workorderheader h (nolock)
		on f.workorder_id = h.workorder_id and f.company_id = h.company_id and f.profit_ctr_id = h.profit_ctr_id
	inner join billing b
		on f.workorder_id = b.receipt_id
		and f.company_id = b.company_id
		and f.profit_ctr_id = b.profit_ctr_id
		and b.trans_source = 'W'
		and b.status_code = 'I'
	where
		f.service_date > dateadd(mm, -11, getdate())
	GROUP BY 
		f.contact_id
		, f.workorder_id
		, f.company_id
		, f.profit_ctr_id
		, f.customer_id
		, f.generator_id
		, isnull(h.offschedule_service_flag, 'F')
		, f.prices
		, year(f.service_date) 
		, month(f.service_date)
		, b.currency_code

	-- 28s


	insert #rex
	(
		contact_id			
		, workorder_id		
		, company_id		
		, profit_ctr_id		
		, customer_id		
		, generator_id		
		, off_schedule_flag	
		, _year				
		, _month			
		, prices			
		, rtotal			
		, currency_code		
	)
	select 
		b.contact_id
		, b.workorder_id
		, b.company_id
		, b.profit_ctr_id
		, b.customer_id
		, b.generator_id
		, b.off_schedule_flag
		, b._year
		, b._month
		, b.prices
		, isnull(sum(br.total_extended_amt), 0) rtotal
		, b.currency_code
	from #bar b
	join billinglinklookup bll
		on b.workorder_id = bll.source_id
		and b.company_id = bll.source_company_id
		and b.profit_ctr_id = bll.source_profit_ctr_id
	join billing br
		on bll.receipt_id = br.receipt_id
		and bll.company_id = br.company_id
		and bll.profit_ctr_id = br.profit_ctr_id
		and br.trans_source = 'R'
		and br.status_code = 'I'
	GROUP BY 
		b.contact_id
		, b.workorder_id
		, b.company_id
		, b.profit_ctr_id
		, b.customer_id
		, b.generator_id
		, b.off_schedule_flag
		, b.prices
		, b._year
		, b._month
		, b.currency_code

	--29s



	--declare @i_date_start datetime, @i_date_end datetime
	--select @i_date_start = convert(varchar(2), min(_month) ) + '/1/' + convert(varchar(4), min(_year))
	--	, @i_date_end = convert(varchar(2), max(_month) ) + '/1/' + convert(varchar(4), max(_year))
	--from #bar

	--declare @time table (
	--	m_yr int,
	--	m_mo int
	--);


	--insert @time
	--	select distinct _year, _month
	--	from #bar

	/*
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
	*/

	-- SELECT  *  FROM    @time order by m_yr, m_mo

-- declare @now datetime = getdate()

	insert #out
	(
	contact_id					
	, _year						
	, _month					
	, offschedule_service_flag	
	, customer_id				
	, generator_id				
	, total_count				
	, total_spend				
	, currency_code				
	, last_updated				
	)
	select
		b.contact_id
		, b._year
		, b._month
		, b.off_schedule_flag
		, b.customer_id
		, b.generator_id
		, count(b.workorder_id) _count
		, sum(isnull(b.wtotal,0) + isnull(r.rtotal, 0)) _total
		, b.currency_code
		, @now as last_updated
	from #bar b
	left join #rex r
		on 
		b.contact_id = r.contact_id
		and b.workorder_id = r.workorder_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and b.off_schedule_flag = r.off_schedule_flag
		and b._year = r._year
		and b._month = r._month
		and b.prices = r.prices
	GROUP BY 
		b.contact_id
		, b._year
		, b._month
		, b.off_schedule_flag
		, b.customer_id
		, b.generator_id
		, b.currency_code
	--ORDER BY 
	--	t.m_yr
	--	, t.m_mo	

	-- all of old history into #out:
	-- 2m, 20.  128770 rows.
	-- Plus 60-ish seconds for #bar & #rex.


-- SELECT  *  FROM    #out ORDER BY _year desc, _month desc

-- Now current year stuff...


	delete from #bar
	delete from #rex

end -- end of generating old stats

-- generate just past year's stats

insert #bar
(
	contact_id			
	, workorder_id		
	, company_id		
	, profit_ctr_id		
	, customer_id		
	, generator_id		
	, off_schedule_flag	
	, _year				
	, _month			
	, prices			
	, wtotal			
	, currency_code		
)
select 
	f.contact_id
	, f.workorder_id
	, f.company_id
	, f.profit_ctr_id
	, f.customer_id
	, f.generator_id
	, isnull(h.offschedule_service_flag, 'F')
	, year(f.service_date) 
	, month(f.service_date)
	, f.prices
	, isnull(sum(b.total_extended_amt), 0)
	, b.currency_code
from ContactCORWorkorderHeaderBucket f
join workorderheader h (nolock)
	on f.workorder_id = h.workorder_id and f.company_id = h.company_id and f.profit_ctr_id = h.profit_ctr_id
inner join billing b
	on f.workorder_id = b.receipt_id
	and f.company_id = b.company_id
	and f.profit_ctr_id = b.profit_ctr_id
	and b.trans_source = 'W'
	and f.prices = 1
	and b.status_code = 'I'
where
	f.service_date >= convert(varchar(2), month(dateadd(yyyy, -2, getdate()))) + '/1/' + convert(varchar(4), year(dateadd(yyyy, -2, getdate())))
GROUP BY 
	f.contact_id
	, f.workorder_id
	, f.company_id
	, f.profit_ctr_id
	, f.customer_id
	, f.generator_id
	, isnull(h.offschedule_service_flag, 'F')
	, f.prices
	, year(f.service_date) 
	, month(f.service_date)
	, b.currency_code

-- 5s



insert #rex
(
	contact_id			
	, workorder_id		
	, company_id		
	, profit_ctr_id		
	, customer_id		
	, generator_id		
	, off_schedule_flag	
	, _year				
	, _month			
	, prices			
	, rtotal			
	, currency_code		
)
select 
	b.contact_id
	, b.workorder_id
	, b.company_id
	, b.profit_ctr_id
	, b.customer_id
	, b.generator_id
	, b.off_schedule_flag
	, b._year
	, b._month
	, b.prices
	, isnull(sum(br.total_extended_amt), 0) rtotal
	, b.currency_code
from #bar b
join billinglinklookup bll
	on b.workorder_id = bll.source_id
	and b.company_id = bll.source_company_id
	and b.profit_ctr_id = bll.source_profit_ctr_id
join billing br
	on bll.receipt_id = br.receipt_id
	and bll.company_id = br.company_id
	and bll.profit_ctr_id = br.profit_ctr_id
	and br.trans_source = 'R'
	and br.status_code = 'I'
where
	b.prices = 1
GROUP BY 
	b.contact_id
	, b.workorder_id
	, b.company_id
	, b.profit_ctr_id
	, b.customer_id
	, b.generator_id
	, b.off_schedule_flag
	, b.prices
	, b._year
	, b._month
	, b.currency_code

--12s for 1 year
-- 20s for 2 years

--declare @i_date_start datetime, @i_date_end datetime
--select @i_date_start = convert(varchar(2), min(_month) ) + '/1/' + convert(varchar(4), min(_year))
--	, @i_date_end = convert(varchar(2), max(_month) ) + '/1/' + convert(varchar(4), max(_year))
--from #bar

--declare @time table (
--	m_yr int,
--	m_mo int
--);


--insert @time
--	select distinct _year, _month
--	from #bar

/*
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
*/

-- SELECT  *  FROM    @time order by m_yr, m_mo

delete from #out -- select *
from #out o
join 
( select distinct 
	_year, _month 
	from #bar b
) b on o._year = b._year
and o._month = b._month


-- declare @now datetime = getdate()

insert #out
(
	contact_id					
	, _year						
	, _month					
	, offschedule_service_flag	
	, customer_id				
	, generator_id				
	, total_count				
	, total_spend				
	, currency_code				
	, last_updated				
)
select
	b.contact_id
	, b._year
	, b._month
	, b.off_schedule_flag
	, b.customer_id
	, b.generator_id
	, count(b.workorder_id) _count
	, sum(isnull(b.wtotal,0) + isnull(r.rtotal, 0)) _total
	, b.currency_code
	, @now as last_updated
-- into #out
from #bar b
	left join #rex r
		on 
		b.contact_id = r.contact_id
		and b.workorder_id = r.workorder_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and b.off_schedule_flag = r.off_schedule_flag
		and b._year = r._year
		and b._month = r._month
		and b.prices = r.prices
GROUP BY 
	b.contact_id
	, b._year
	, b._month
	, b.off_schedule_flag
	, b.customer_id
	, b.generator_id
	, b.currency_code
--ORDER BY 
--	t.m_yr
--	, t.m_mo	

-- 2s, 9227 rows




if exists (select 1 from sysobjects where xtype = 'u' and name = 'ContactCORStatsServiceCountSpend')
	delete from ContactCORStatsServiceCountSpend -- select *
	from ContactCORStatsServiceCountSpend o
	join 
	( select distinct 
		_year, _month 
		from #out b
	) b on o._year = b._year
	and o._month = b._month

insert ContactCORStatsServiceCountSpend	
(
	contact_id
	,_year
	,_month
	,offschedule_service_flag
	,customer_id
	,generator_id
	,total_count
	,total_spend
	,currency_code
	,last_updated
)
select 
	contact_id
	,_year
	,_month
	,offschedule_service_flag
	, customer_id
	, generator_id
	,total_count
	,total_spend
	,currency_code
	,last_updated
from #out

--CREATE INDEX [IX_ContactCORStatsServiceCountSpend_contact_id] ON [dbo].ContactCORStatsServiceCountSpend (contact_id, _year, _month) INCLUDE (offschedule_service_flag, total_count, total_spend)
--grant select on ContactCORStatsServiceCountSpend to COR_USER
--grant select, insert, update, delete on ContactCORStatsServiceCountSpend to EQAI

GO

grant execute on sp_ContactCORServiceStats_Maintain to eqai, eqweb, cor_user

