CREATE PROCEDURE sp_ElvsStates		
AS		
--======================================================
-- Description: Returns all state information
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 12/08/2007  JPB               add '(Out Of Scope Items)' fake state last in the list
-- 08/25/2008  Chris Allen       Formatted
-- 06/06/2016	JPB				 Added country_code to StateAbbreviation query
--
--======================================================
BEGIN
	SELECT	
		s.state_name,
		e.state,
		e.bounty_flag,
		e.bounty_rate,
		e.number_contacted,
		vin_required,
		vin_based_switch_count,
		switches_per_abs_assembly,
		show_detail_or_total,
		modified_by,
		date_modified,
		0 AS orderby
	FROM	
		ElvsState e INNER JOIN StateAbbreviation s on e.state = s.abbr and s.country_code = 'USA'
	UNION	
	SELECT	
		'(Out Of Scope Items)' AS state_name,
		e.state,
		e.bounty_flag,
		e.bounty_rate,
		e.number_contacted,
		vin_required,
		vin_based_switch_count,
		switches_per_abs_assembly,
		show_detail_or_total,
		modified_by,
		date_modified,
		1 AS orderby
	FROM	
		ElvsState e 
	WHERE	
		state = 'Z'
	ORDER BY orderby, state_name	
END -- CREATE PROCEDURE sp_ElvsStates

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStates] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStates] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStates] TO [EQAI]
    AS [dbo];

