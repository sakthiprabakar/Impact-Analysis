
-- IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'sp_reports_list_database') and OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE sp_reports_list_database
GO

CREATE PROCEDURE sp_reports_list_database
	@debug int,
	@database_list varchar(8000)
AS

/********************
The purpose of the sp_reports_list_database procedure is to parse the input list and put each entry into the table

LOAD TO PLT_AI* on NTSQL1, NTSQL3

sp_reports_list_database 1, '2|0,3|0,12|0'

sp_reports_list_database 1, '14|0, 14|4, 14|6, 14|12'
SELECT * FROM #tmp_database

SELECT * FROM profitcenter WHERE company_id = 2
SELECT * FROM profitcenter WHERE company_id = 3

07/30/2003 SCC Created
11/16/2005 JPB	Updated to work with C or P logic and deployed... Seems to have been missed during launch.
10/08/2007 JPB  Modified for Prod/Test/Dev changes: EQAIConnect, EQAIDatabase -> EQConnect, EQDatabase
04/22/2019 JPB	Added 'All' option. About time.

**********************/

DECLARE	@pos		int,
	@pcpos		int,
	@database	varchar(30),
	@company	varchar(30),
	@profitcenter	varchar(30),
	@tmp_list	varchar(8000)

-- Populate the temp database table
SELECT @tmp_list = REPLACE(@database_list, ' ', '')
IF @debug = 1 PRINT 'database List: ' + @database_list
if @database_list = 'ALL' begin
	insert #tmp_database
	select 'plt_ai'
	, company_id
	, profit_ctr_id
	, 0 as process
	from profitcenter
	WHERE status = 'A'
end
else
begin

	SELECT @pos = 0
	WHILE DATALENGTH(@tmp_list) > 0
	BEGIN
		-- Look for a comma
		SELECT @pos = CHARINDEX(',', @tmp_list)
		IF @debug = 1 PRINT 'Pos: ' + CONVERT(varchar(10), @pos)
	
		-- If we found a comma, there is a list of databases
		IF @pos > 0
		BEGIN
			SELECT @database = SUBSTRING(@tmp_list, 1, @pos - 1)
			SELECT @tmp_list = SUBSTRING(@tmp_list, @pos + 1, DATALENGTH(@tmp_list) - @pos)
			IF @debug = 1 PRINT 'database: ' + CONVERT(varchar(30), @database)
		END
	
		-- If we did not find a comma, there is only one database or we are at the end of the list
		IF @pos = 0
		BEGIN
			SELECT @database = @tmp_list
			SELECT @tmp_list = NULL
			IF @debug = 1 PRINT 'database: ' + CONVERT(varchar(30), @database)
		END
	
		-- Check for ProfitCenter attachment
		SELECT @pcpos = CHARINDEX('|', @database)
		IF @pcpos > 0
		BEGIN
			SELECT @company = LEFT(@database, @pcpos -1)
			SELECT @profitcenter = REPLACE(@database, @company+'|', '')
		END
		ELSE
		BEGIN
			SELECT @company = @database
			SELECT @profitcenter = null
		END
	
	
	
		-- Insert into table
		INSERT #tmp_database
		SELECT distinct
			database_name + '.DBO.' AS database_name,
			c.company_id,
			p.profit_ctr_id,
			0 AS process
		FROM
			EQdatabase d
			INNER JOIN EQconnect c ON c.db_name_share = d.database_name
			INNER JOIN profitcenter p ON c.company_id = p.company_id
		WHERE
			c.company_id = CONVERT(int, @company)
			AND c.db_name_share = DB_NAME(DB_ID())
			AND (
				p.view_on_web = (
				SELECT	view_on_web
				FROM	profitcenter
				WHERE	company_id = CONVERT(int, @company)
					AND profit_ctr_id = CONVERT(int, @profitcenter)
					AND view_on_web = 'C' )
				OR
				(
				p.view_on_web = 'P'
				AND c.company_id = CONVERT(int, @company)
				AND p.profit_ctr_id = CONVERT(int, @profitcenter)
				)
			)
			-- AND database_name + '.DBO.' not in (select database_name from #tmp_database)
	
	END
end
IF @debug = 1 SELECT distinct * FROM #tmp_database


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_list_database] TO [EQAI]
    AS [dbo];

