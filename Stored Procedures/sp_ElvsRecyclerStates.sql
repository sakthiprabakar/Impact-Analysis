CREATE PROCEDURE sp_ElvsRecyclerStates (					
	@omitlist	varchar(8000) = ''			
)					
AS					
--======================================================
-- Description:  Returns the DISTINCT list of states to show on the public elvs recycler webpage
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 04/11/2007  JPB 							 Modified to work with shipping_state					
-- 12/08/2007  JPB 							 Modified to add '(Out Of Scope Items)' fake state last in the list					
-- 08/25/2008  Chris Allen       Formatted
-- 06/06/2016 JPB				 Added country_code to StateAbbreviation query
--
--								sp_ElvsRecyclerStates					
--								sp_ElvsRecyclerStates 'CA'					
--								sp_ElvsRecyclerStates 'CA,MI '					
--======================================================
BEGIN
	SET nocount on					
						
	DECLARE @intcount int					
						
	CREATE TABLE #1 (omitState char(2))					
						
	IF Len(@omitlist) > 0					
	BEGIN 					
		/* Check to see IF the number parser table exists, create IF necessary */				
		SELECT @intCount = Count(*) FROM syscolumns c INNER JOIN sysobjects o on o.id = c.id AND o.name = 'tblToolsStringParserCounter' AND c.name = 'ID'				
		IF @intCount = 0				
		BEGIN 				
			CREATE TABLE tblToolsStringParserCounter (			
				ID	int	)
						
			DECLARE @i INT			
			SELECT  @i = 1			
						
			WHILE (@i <= 8000)			
			BEGIN 			
				INSERT INTO tblToolsStringParserCounter SELECT @i		
				SELECT @i = @i + 1		
			END			
		END				
						
		/* INSERT the generator_id_list data INTO a temp table for use later */				
		INSERT INTO #1				
		SELECT  NULLIF(SUBSTRING(',' + @omitlist + ',' , ID ,				
			CHARINDEX(',' , ',' + @omitlist + ',' , ID) - ID) , '') AS omitState			
		FROM tblToolsStringParserCounter				
		WHERE ID <= Len(',' + @omitlist + ',') AND SUBSTRING(',' + @omitlist + ',' , ID - 1, 1) = ','				
		AND CHARINDEX(',' , ',' + @omitlist + ',' , ID) - ID > 0				
	END					
	SET nocount OFF					
						
	SELECT abbr, state_name FROM					
	(					
		SELECT distinct				
			s.abbr,			
			s.state_name,			
			0 AS orderby			
		FROM ElvsRecycler r				
			INNER JOIN StateAbbreviation s 
			on r.shipping_state = s.abbr 
			and s.country_code = 'USA'
			WHERE s.abbr NOT IN (SELECT omitState FROM #1)			
			AND r.status = 'A'			
		UNION				
		SELECT distinct				
			'Z' AS abbr,			
			'(Out Of Scope Items)' AS state_name,			
			1 AS orderby			
			WHERE 'Z' not in (SELECT omitState FROM #1)			
	) a					
	ORDER BY orderby, state_name					
						
	SET nocount on					
	DROP TABLE #1					
	SET nocount OFF					

END -- CREATE PROCEDURE sp_ElvsRecyclerStates

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerStates] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerStates] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerStates] TO [EQAI]
    AS [dbo];

