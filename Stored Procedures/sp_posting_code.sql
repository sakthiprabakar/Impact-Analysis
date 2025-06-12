CREATE PROCEDURE sp_posting_code
	@debug		int,
	@company_id	int,
	@db_type	varchar(10)
AS
/***************************************************************************************************
LOAD TO PLT_AI

Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_posting_code.sql
PB Object(s):	d_posting_code (w_customer)

10/15/2003 JDB	Created
10/01/2007 WAC  Removed references to a database server.  Also removed lookup for server name
		since all related tables will be on the same server as the procedure is executing on.

sp_posting_code 1, 2, 'DEV'
***************************************************************************************************/
DECLARE @company_string	varchar(10),
	@server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(250),
	@posting_code	int

CREATE TABLE #tmp	(
	posting_code	int	NULL)

-- Initialize

-- Pad the company_id with a 0 on the left side if < 10
IF @company_id < 10
	SET @company_string = '0' + CONVERT(varchar(1), @company_id)
ELSE
	SET @company_string = CONVERT(varchar(2), @company_id)

-- Set up the database name
SET @database = 'PLT_' + @company_string + '_AI'

-- Get the posting code from the ProfitCenter table
SET @execute_sql = 'INSERT INTO #tmp '
+ 'SELECT MIN(posting_code) '
+ 'FROM ' + @database + '.dbo.ProfitCenter '
+ 'WHERE company_id = ' + CONVERT(varchar(2), @company_id)

IF @debug = 1 PRINT @execute_sql

EXECUTE (@execute_sql)
SELECT @posting_code = posting_code FROM #tmp
IF @debug = 1 SELECT * FROM #tmp

SELECT @posting_code AS posting_code

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_posting_code] TO [EQAI]
    AS [dbo];

