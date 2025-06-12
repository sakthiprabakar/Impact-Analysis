
/***************************************************************************************************
-- LOAD TO PLT_AI, PLT_AI_TEST, PLT_AI_DEV
-- Filename:	F:\EQAI\SQL\EQAI\PLT_AI\sp_profile_count
-- 07/20/2006 SCC	Created
-- 04/08/2024 KS	DevOps 80058 - Replaced COUNT(*) with COUNT(1). 

-- sp_profile_count 1, 'FROM Profile WHERE profile_id = 215580'
***************************************************************************************************/
CREATE PROCEDURE sp_profile_count
	@debug		int,
	@from_clause	varchar(8000)
AS
DECLARE 
	@count_limit	int,
	@execute_sql	varchar(8000)

CREATE TABLE #count_profile (
	count_profile	int NULL
)

-- Set the limit for retrieval
SET @count_limit = 1000

-- Retrieve
SET @execute_sql = 'INSERT INTO #count_profile SELECT COUNT(1) ' + @from_clause
IF @debug = 1 PRINT @execute_sql
EXECUTE (@execute_sql)

SELECT count_profile, @count_limit as count_limit FROM #count_profile


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profile_count] TO [EQAI]
    AS [dbo];

