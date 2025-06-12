/*

DO-42620 ELVS - Add mercury weight to stats

*/

use plt_ai
go

drop proc if exists sp_ElvsStateInfo
go

CREATE PROCEDURE sp_ElvsStateInfo (
  @state varchar(3), 
  @omitlist varchar(8000) = ''
)					
AS					
--======================================================
-- Description: Returns state information in the ELVS program					
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 09/20/2006  JPB				       total_switches_accepted modified so it does not ignore ineligible switches, per Judie, Mary Bills, et al.					
-- 11/12/2007  JPB 				       Participating Recyclers = # of Active recyclers (removed participation_flag = T FROM WHERE)					
-- 12/08/2007  JPB 				       added '(Out Of Scope Items)' fake state last in the list					
-- 08/20/2008  Chris Allen       - returns NVMSRP count as nvmsrp_participants (participation_flag = 'N')
--                               - Formatted
-- 08/08/2008  Chris Allen       returns participating_recyclers count without NVMSRP added ==> NOT(participation_flag = 'N')
-- 06/06/2016  JPB				 Added country_code to StateAbbreviation query
--
--             Testing
--							  sp_ElvsStateInfo 'all'					
--							  sp_ElvsStateInfo 'mi'					
--							  sp_ElvsStateInfo 'nj'					
--======================================================
BEGIN
	SET nocount on					
						
	DECLARE @intcount int					
						
	CREATE TABLE #1 (omitState char(2))					
						
	IF Len(@omitlist) > 0					
	BEGIN  					
		INSERT INTO #1
		select row
		from dbo.fn_SplitXsvText(',',1,@omitlist)
		WHERE row is not null
	END					
	SET nocount OFF					
						
	SELECT					
		IsNull(				
			(	SELECT Sum(number_contacted)		
				FROM ElvsState		
				WHERE state = CASE WHEN @state <> 'ALL' THEN @state ELSE state END		
				AND state not in (SELECT omitState FROM #1)		
			)			
			,0) AS number_contacted,			
		CASE WHEN @state <> 'ALL' THEN state_name ELSE 'All States' END AS state_name,				
		IsNull(				
			(			
				SELECT Sum(IsNull(c.quantity_received,0) /* - IsNull(c.quantity_ineligible, 0) */) 		
				FROM ElvsContainer c		
				INNER JOIN ElvsRecycler ri2 on c.recycler_id = ri2.recycler_id AND ri2.status = 'A'		
				INNER JOIN ElvsState si2 on ri2.shipping_state = si2.state		
				WHERE ri2.shipping_state = CASE WHEN @state <> 'ALL' THEN @state ELSE ri2.shipping_state END		
				AND c.status = 'A'		
				AND ri2.shipping_state not in (SELECT omitState FROM #1)		
			)			
			,0) AS total_switches_accepted,			
		IsNull(				
			(	SELECT Count(ri3.recycler_id)		
				FROM ElvsRecycler ri3		
				INNER JOIN ElvsState si3 on ri3.shipping_state = si3.state		
				WHERE ri3.shipping_state = CASE WHEN @state <> 'ALL' THEN @state ELSE ri3.shipping_state END		
				AND ri3.shipping_state not in (SELECT omitState FROM #1)		
				AND ri3.status = 'A'		
				AND NOT (ri3.participation_flag = 'N')  --09/08/2008 CMA Added 
			),0) AS participating_recyclers,			

    --BEG 08/08/08 CMA Added (below)
		IsNull(				
			(	SELECT Count(ri.recycler_id)		
				FROM ElvsRecycler ri		
				INNER JOIN ElvsState si on ri.shipping_state = si.state		
				WHERE ri.shipping_state = CASE WHEN @state <> 'ALL' THEN @state ELSE ri.shipping_state END		
				AND ri.shipping_state not in (SELECT omitState FROM #1)		
				AND ri.status = 'A'		
				AND ri.participation_flag = 'N'  --08/20/2008 CMA Added 
			),0) AS nvmsrp_participants,			
    --END 08/08/08 CMA Added (above)

		IsNull(				
			(   SELECT bounty_flag FROM ElvsState WHERE state = @state )			
			, 'F') AS bounty_flag,			
		IsNull(				
			(	SELECT Sum(c.abs_count)		
				FROM ElvsContainer c		
				INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
				INNER JOIN ElvsState es on r.shipping_state = es.state AND es.bounty_flag = 'T'		
				WHERE es.state = CASE WHEN @state <> 'ALL' THEN @state ELSE '0' END		
				AND es.state not in (SELECT omitState FROM #1)		
				AND c.status = 'A'		
			)			
			,0) AS total_abs_accepted,			
		IsNull(				
			(	SELECT Sum(c.light_count)		
				FROM ElvsContainer c		
				INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
				INNER JOIN ElvsState es on r.shipping_state = es.state AND es.bounty_flag = 'T'		
				WHERE es.state = CASE WHEN @state <> 'ALL' THEN @state ELSE '0' END		
				AND es.state not in (SELECT omitState FROM #1)		
				AND c.status = 'A'		
			)			
			,0) AS total_light_accepted,			
		IsNull(				
			(	SELECT Sum(c.misc_count)		
				FROM ElvsContainer c		
				INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
				INNER JOIN ElvsState es on r.shipping_state = es.state AND es.bounty_flag = 'T'		
				WHERE es.state = CASE WHEN @state <> 'ALL' THEN @state ELSE '0' END		
				AND es.state not in (SELECT omitState FROM #1)		
				AND c.status = 'A'		
			)			
			,0) AS total_misc_count,			
		IsNull(				
			(			
				SELECT Sum(IsNull(c.quantity_received,0) /* - IsNull(c.quantity_ineligible, 0) */) 		
				FROM ElvsContainer c		
				INNER JOIN ElvsRecycler ri2 on c.recycler_id = ri2.recycler_id AND ri2.status = 'A'		
				INNER JOIN ElvsState si2 on ri2.shipping_state = si2.state		
				WHERE ri2.shipping_state = CASE WHEN @state <> 'ALL' THEN @state ELSE ri2.shipping_state END		
				AND c.status = 'A'		
				AND ri2.shipping_state not in (SELECT omitState FROM #1)		
			)			
			,0) * 0.0022
			AS total_mercury_weight_accepted		
			
	FROM					
		(SELECT state_name, abbr FROM StateAbbreviation where country_code = 'USA' UNION SELECT '(Out Of Scope Items)', 'Z') sa				
		LEFT OUTER JOIN ElvsState s on s.state = sa.abbr				
	WHERE					
		((@state <> 'ALL' AND sa.abbr = @state)				
		or				
		@state = 'ALL')				
		AND sa.abbr not in (SELECT omitState FROM #1)				
	GROUP BY					
		CASE WHEN @state <> 'ALL' THEN state_name ELSE 'All States' END				
	ORDER BY					
		state_name				

END -- CREATE PROCEDURE sp_ElvsStateInfo

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInfo] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInfo] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInfo] TO [EQAI]
    AS [dbo];

