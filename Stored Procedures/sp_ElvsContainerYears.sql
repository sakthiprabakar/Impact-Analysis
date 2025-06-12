CREATE PROCEDURE sp_ElvsContainerYears	
AS	
--======================================================
-- Description: Returns the DISTINCT list of years to show on the public elvs recycler webpage
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 08/25/2008  Chris Allen       Formatted
--
--
--======================================================
BEGIN	
	SELECT distinct	
		datepart(yyyy, date_received),
		datepart(yyyy, date_received)
	FROM ElvsContainer c	
		WHERE datepart(yyyy, date_received) > 1900
	ORDER BY datepart(yyyy, date_received) desc	
END -- CREATE PROCEDURE sp_ElvsContainerYears

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerYears] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerYears] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerYears] TO [EQAI]
    AS [dbo];

