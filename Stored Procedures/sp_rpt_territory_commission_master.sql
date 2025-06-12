CREATE PROCEDURE sp_rpt_territory_commission_master 
	@date_from		datetime,
	@date_to		datetime,
	@territory_list		varchar(255),
	@report_type		int,
	@user_id		varchar(8),
	@criteria		varchar(255),
	@debug			int
AS
/*  Territory Commission Report Master

DEPLOY TO PLT_AI

Modifications:
09/18/2003 JDB	Created
		Report type to call a specific report:
		1 - Commission Report (Actual Revenue)
		2 - AE Commission Report
		3 - ISA Commission Report
		Added tables for the commission values
		Added intercompanyapprovals as a view on PLT_AI, PLT_AI_TEST, PLT_AI_DEV
11/10/2005 SCC	Modified to run for a set of territories
03/08/2006 rg  changed select into  to insert select operation to 
               insure column definitions.
10/02/2007 WAC	Changed tables with prefixes of EQAI to EQ.  Added db_type to EQDatabase query.
10/17/2007 JDB	Modified the insert into #tmp_database (no longer needed server and server_avail).

DROP TABLE TerritoryCommissionReport

CREATE TABLE TerritoryCommissionReport (
	orig_company	int		NULL,
	territory	varchar(8)	NULL,
	company		int		NULL,
	ae_name		varchar(30)	NULL,
	isa_name	varchar(30)	NULL,
	goal		float		NULL,
	month		int		NULL,
	year		int		NULL,
	base0		float		NULL,
	base1		float		NULL,
	base2		float		NULL,
	base3		float		NULL,
	base4		float 		NULL,
	base5		float		NULL,
	event0		float		NULL,
	event1		float		NULL,
	event2		float		NULL,
	event3		float		NULL,
	event4		float		NULL,
	event5		float		NULL,
	user_id		varchar(8)	NULL	)

GRANT ALL ON TerritoryCommissionReport TO eqai

sp_rpt_territory_commission_master '11-01-2005', '11-05-2005', '03', 1, 'SA', 1
*/

DECLARE @database		varchar(30),
	@calling_server		varchar(30),
	@calling_database	varchar(30),
	@execute_sql		varchar(1000),
	@company_id		smallint,
	@db_count		int,
	@unassigned_territory	varchar(8) 


create table #tmp_database ( company_id int null,
	database_name varchar(30) null,
	process_flag int null )


CREATE TABLE #Output (
	record_type	int		NULL,
	orig_company	int		NULL,
	territory	varchar(8)	NULL,
	company		int		NULL,
	ae_name		varchar(30)	NULL,
	isa_name	varchar(30)	NULL,
	goal		float		NULL,
	month		int		NULL,
	year		int		NULL,
	base0		float		NULL,
	base1		float		NULL,
	base2		float		NULL,
	base3		float		NULL,
	base4		float 		NULL,
	base5		float		NULL,
	event0		float		NULL,
	event1		float		NULL,
	event2		float		NULL,
	event3		float		NULL,
	event4		float		NULL,
	event5		float		NULL	)

CREATE TABLE #tmp_company (
	company_id	int	NULL,
	process_flag	int	NULL	)

CREATE TABLE #tmp_territory_master (
	territory_code varchar(8) NULL)

EXEC sp_list @debug, @territory_list, 'STRING', '#tmp_territory_master'

SELECT @unassigned_territory = IsNull(territory_code, 'JUNK') FROM #tmp_territory_master WHERE territory_code = 'UN'
IF @unassigned_territory = 'UN'
	SET @unassigned_territory = ''
IF @debug = 1 print '@unassigned_territory: ' + @unassigned_territory
IF @debug = 1 print 'SELECT * FROM #tmp_territory_master'
IF @debug = 1 SELECT * FROM #tmp_territory_master

DELETE FROM TerritoryCommissionReport WHERE user_id = @user_id

SELECT @calling_server = @@SERVERNAME
SELECT @calling_database = DB_NAME()

-- Create a temp table to hold the databases
INSERT #tmp_database
SELECT	EQConnect.company_id,
	EQConnect.db_name_eqai AS database_name,
	0 AS process_flag
FROM EQConnect
WHERE db_type = 'PROD'

IF @debug = 1 SELECT * FROM #tmp_database

/************************************************************/
-- Process each database in the list
SELECT @db_count = COUNT(*) FROM #tmp_database
WHILE @db_count > 0
BEGIN
	-- Get the database
	SET rowcount 1
	SELECT @database = database_name
		FROM #tmp_database WHERE process_flag = 0
	SET rowcount 0
	
	-- Run the commission report
	SET @execute_sql =  @database + '.dbo.sp_rpt_territory_commission '
	IF @debug = 1 PRINT @execute_sql
	EXECUTE @execute_sql @date_from, @date_to, @territory_list, @calling_server, @calling_database, @report_type, @user_id, @debug
	IF @debug = 1 PRINT 'After running ' + @execute_sql

	-- Update to process the next database
	SET rowcount 1
	UPDATE #tmp_database SET process_flag = 1 WHERE database_name = @database AND process_flag = 0
	SET rowcount 0
	SELECT @db_count = @db_count - 1
END

/************************************************************/
INSERT INTO #Output
SELECT	DISTINCT
	1,
	orig_company,
	territory, 
	company, 
	ae_name,
	isa_name,
	goal,
	month,
	year,
	base0,
	base1,
	base2,
	base3,
	base4,
	base5,
	event0,
	event1,
	event2,
	event3,
	event4,
	event5
FROM 	TerritoryCommissionReport
WHERE	user_id = @user_id
	
UNION 
	
SELECT DISTINCT
	1,
	0,
	territory = territory_code,
	company = 0,
	ae_name,
	isa_name,
	goal,
	month,
	year,
	0.0, --base0 = ISNULL(adj_base0, 0),
	0.0, --base1 = ISNULL(adj_base1, 0),
	0.0, --base2 = ISNULL(adj_base2, 0),
	0.0, --base3 = ISNULL(adj_base3, 0),
	0.0, --base4 = ISNULL(adj_base4, 0),
	0.0, --base5 = ISNULL(adj_base5, 0),
	0.0, --event0 = ISNULL(adj_event0, 0),
	0.0, --event1 = ISNULL(adj_event1, 0),
	0.0, --event2 = ISNULL(adj_event2, 0),
	0.0, --event3 = ISNULL(adj_event3, 0),
	0.0, --event4 = ISNULL(adj_event4, 0),
	0.0  --event5 = ISNULL(adj_event5, 0)
FROM	territory_goals
WHERE	CONVERT(varchar(4), year) + CASE WHEN month < 10 THEN '0' +CONVERT(varchar(1), month) ELSE CONVERT(varchar(2), month) END
	IN (SELECT DISTINCT CONVERT(varchar(4), year) + CASE WHEN month < 10 THEN '0' +CONVERT(varchar(1), month) ELSE CONVERT(varchar(2), month) END
		FROM TerritoryCommissionReport WHERE user_id = @user_id)
	AND (IsNull(territory_code,'') = @unassigned_territory OR 
             territory_code IN (SELECT territory_code FROM #tmp_territory_master))
	ORDER BY territory, orig_company, company

/************************************************************/
-- Process each company in the list
INSERT INTO #tmp_company SELECT DISTINCT orig_company, 0 FROM #Output
SELECT @db_count = COUNT(*) FROM #tmp_company
WHILE @db_count > 0
BEGIN
	-- Get the company
	SET ROWCOUNT 1
	SELECT @company_id = company_id FROM #tmp_company WHERE process_flag = 0
	SET ROWCOUNT 0

	-- Subtotals get record_type = 2
	INSERT INTO #Output
	SELECT	2, 
		@company_id, 
		'', 
		@company_id, 
		'', 
		'', 
		0.0, 
		month, 
		year,
		ISNULL(SUM(base0), 0.0),
		ISNULL(SUM(base1), 0.0),
		ISNULL(SUM(base2), 0.0),
		ISNULL(SUM(base3), 0.0),
		ISNULL(SUM(base4), 0.0),
		ISNULL(SUM(base5), 0.0),
		ISNULL(SUM(event0), 0.0),
		ISNULL(SUM(event1), 0.0),
		ISNULL(SUM(event2), 0.0),
		ISNULL(SUM(event3), 0.0),
		ISNULL(SUM(event4), 0.0),
		ISNULL(SUM(event5), 0.0)
	FROM #Output 
	WHERE orig_company = @company_id
	AND record_type = 1
	GROUP BY year, month

	-- Update to process the next database
	SET ROWCOUNT 1
	UPDATE #tmp_company SET process_flag = 1 WHERE company_id = @company_id AND process_flag = 0
	SET ROWCOUNT 0
	SELECT @db_count = @db_count - 1
END

/************************************************************/

-- Totals get record_type = 3
INSERT INTO #Output
SELECT	3, 
	0, 
	'', 
	0, 
	'', 
	'', 
	ISNULL(SUM(goal), 0.0), 
	month, 
	year,
	ISNULL(SUM(base0), 0.0), 
	ISNULL(SUM(base1), 0.0), 
	ISNULL(SUM(base2), 0.0), 
	ISNULL(SUM(base3), 0.0), 
	ISNULL(SUM(base4), 0.0), 
	ISNULL(SUM(base5), 0.0),
	ISNULL(SUM(event0), 0.0), 
	ISNULL(SUM(event1), 0.0), 
	ISNULL(SUM(event2), 0.0), 
	ISNULL(SUM(event3), 0.0), 
	ISNULL(SUM(event4), 0.0), 
	ISNULL(SUM(event5), 0.0)
FROM #Output
WHERE record_type = 1
GROUP BY year, month

SELECT * FROM #Output

DROP TABLE #tmp_database
DROP TABLE #tmp_company
DROP TABLE #Output

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_commission_master] TO [EQAI]
    AS [dbo];

