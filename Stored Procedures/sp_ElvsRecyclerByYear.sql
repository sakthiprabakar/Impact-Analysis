
drop proc if exists sp_ElvsRecyclerByYear 
go

CREATE PROCEDURE sp_ElvsRecyclerByYear (@year varchar(4))		
AS		
--======================================================
-- Description: Returns elvs program information for display on the website in list format
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 02/08/2007	 JPB               Modified sort order AND excluded 0-participant states per year.
-- 12/08/2007  JPB               Modified the StateAbbreviation SELECT to appEND a new '(Out of Scope Items)' "state"	AND adjusted the ORDER BY clause to match.	
-- 08/25/2008  Chris Allen       Formatted
-- 08/08/2008  Chris Allen       returns participating_recyclers_per_state count without NVMSRP added ==> NOT(participation_flag = 'N')
-- 06/06/2016 JPB				 Added country_code to StateAbbreviation query
--
--
--
--             Testing
-- 										sp_ElvsRecyclerByYear '2005'		
-- 										sp_ElvsRecyclerByYear '2006'		
-- 										sp_ElvsRecyclerByYear 'all'		
--======================================================
BEGIN
	SET nocount on		
			
	drop table if exists #stats
	drop table if exists #years		
	
	-- declare @year varchar(4) = 'all'			

	-- Create 'Years' temp table to hold DISTINCT years recyclers joined.		
	SELECT distinct		
		datepart(yyyy, c.date_received) AS year	
	INTO #years		
	FROM elvsContainer c
	join elvsRecycler r on c.recycler_id = r.recycler_id
	WHERE r.date_joined > '1/1/1900'		
	and c.date_received > '1/1/1900'
	AND r.status='A'		
	AND c.status <> 'R'		
			
	SET nocount OFF		
	drop table if exists #stats

	-- declare @year varchar(4) = 'all'			
	SELECT		
		y.year,	
		s.state,
		a.state_name,	
		--(SELECT Count(recycler_id) FROM ElvsRecycler r WHERE datepart(yyyy, r.date_joined) <= y.year AND r.shipping_state = s.state AND r.status='A' AND NOT(r.participation_flag='N')) AS participating_recyclers_per_state,	--09/08/2008 CMA Added AND NOT(r.participation_flag='N')
		convert(int, null) as participating_recyclers_per_state,
		-- (SELECT IsNull(Sum(IsNull(quantity_received,0) - IsNull(quantity_ineligible, 0)),0) FROM ElvsContainer c INNER JOIN ElvsRecycler r2 on c.recycler_id = r2.recycler_id AND r2.status = 'A' INNER JOIN ElvsState s2 on r2.shipping_state = s2.state WHERE datepart(yyyy, c.date_received) = y.year AND r2.shipping_state = s.state AND c.status = 'A') AS switches,	
		convert(int, null) as switches,
		-- SELECT IsNull(Sum(IsNull(quantity_ineligible, 0)),0) FROM ElvsContainer c INNER JOIN ElvsRecycler r3 on c.recycler_id = r3.recycler_id AND r3.status = 'A' INNER JOIN ElvsState s3 on r3.shipping_state = s3.state WHERE datepart(yyyy, c.date_received) = y.year AND r3.shipping_state = s.state AND c.status = 'A') AS ineligible_switches,	
		convert(int, null) as ineligible_switches,
		s.vin_required,	
		s.vin_based_switch_count,	
		s.switches_per_abs_assembly,	
		s.show_detail_or_total	
		, a.order_num
	into #stats
	FROM #years y		
		cross apply ElvsState s 
		INNER JOIN (SELECT 0 AS order_num, state_name, abbr FROM StateAbbreviation where country_code = 'USA' UNION SELECT 1 AS order_num, '(Out Of Scope Items)', 'Z') a on s.state = a.abbr	
	WHERE y.year = CASE WHEN @year <> 'all' THEN @year ELSE y.year END		
	AND 0 < (SELECT Count(recycler_id) FROM ElvsRecycler r WHERE datepart(yyyy, r.date_joined) <= y.year AND r.shipping_state = s.state AND r.status='A')		
--	ORDER BY year desc, a.order_num, state_name		
			
/*			
	SELECT  * FROM    #stats
	update #stats set participating_recyclers_per_state = null
	, switches = null
	, ineligible_switches = null
*/
	
	update y set 
		participating_recyclers_per_state = isnull((SELECT Count(recycler_id) FROM ElvsRecycler r WHERE datepart(yyyy, r.date_joined) <= y.year AND r.shipping_state = y.state AND r.status='A' AND NOT(r.participation_flag='N')),0)
	from #stats y

	-- SELECT  * FROM    #stats
	/*
	update #stats set participating_recyclers_per_state = null
	, switches = null
	, ineligible_switches = null
	*/
	
	update #stats
	set switches = d.switches-- - d.ineligible_switches
		, ineligible_switches = d.ineligible_switches
	from #stats
	join (
		select y.year, y.state
			, switches = Sum(IsNull(quantity_received,0))
			, ineligible_switches = sum(IsNull(c.quantity_ineligible, 0))
		from #stats y
		join ElvsRecycler r
			on r.shipping_state = y.state
			and r.status = 'A'
		join ElvsContainer c
			on c.recycler_id = r.recycler_id
			and c.status = 'A'
			and datepart(yyyy, c.date_received) = y.year 
		GROUP BY y.year, y.state
	) d
	on #stats.year = d.year
	and #stats.state = d.state

	update #stats set switches = 0 WHERE switches is null
	update #stats set ineligible_switches = 0 WHERE ineligible_switches is null
	update #stats set participating_recyclers_per_state = 0 WHERE participating_recyclers_per_state is null

	SET nocount OFF		
	
	select 
	year	
	,state_name	
	,participating_recyclers_per_state	
	,switches	
	,ineligible_switches	
	,vin_required	
	,vin_based_switch_count	
	,switches_per_abs_assembly	
	,show_detail_or_total	
	,order_num	
	, switches * 0.0022 as total_mercury_collected
	from #stats
	order by year desc, order_num, state_name
END -- CREATE PROCEDURE sp_ElvsRecyclerByYear

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByYear] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByYear] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByYear] TO [EQAI]
    AS [dbo];
