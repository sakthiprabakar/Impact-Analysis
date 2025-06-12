CREATE PROCEDURE sp_generator_usage_check
	@debug		int,
	@generator_id	int
AS

/***************************************************************************************************
LOAD TO PLT_AI, PLT_AI_TEST, PLT_AI_DEV

Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_generator_usage_check.sql
PB Object(s):	w_generator.wf_generator_usage

01/14/2002 SCC	Created
10/15/2003 JDB	Modified to be used with one company at a time.
03/25/2004 JDB	Modified to check for approvals where curr_status_code IN ('A', 'H')
11/05/2004 JDB	Replaced generator_code with generator_id
02/24/06   rg   removed restriction on company 
10/01/2007 WAC	Tables with EQAI prefix were changed to EQ prefix.  db_type added to where clause for 
		EQDatabase lookup.
08/21/2019 MPM	Samanage 14133 - Modified to look for generator usage in Plt_ai instead of the defunct
				company databases.

sp_generator_usage_check 0, 55
***************************************************************************************************/
DECLARE @gen_count	int = 0,
	@execute_sql	varchar(250)

CREATE TABLE #gen_count	(
generator_count	int	)

SET @execute_sql = 'INSERT INTO #gen_count '
+ 'SELECT COUNT(*) '
+ 'FROM dbo.Approval '
+ 'WHERE generator_id = ' + CONVERT(varchar(10), @generator_id) + ' '
+ 'AND curr_status_code IN ( ''A'', ''H'' )'

IF @debug = 1 PRINT @execute_sql

EXECUTE (@execute_sql)
SELECT @gen_count = sum(generator_count) FROM #gen_count
    IF @debug = 1 SELECT * FROM #gen_count
IF @debug = 1 AND @gen_count > 0 PRINT 'Generator found in Approval'

IF @gen_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #gen_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM dbo.TSDFApproval '
	+ 'WHERE generator_id = ' + CONVERT(varchar(10), @generator_id) + ' '
	+ 'AND tsdf_approval_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @gen_count = sum(generator_count) FROM #gen_count
	IF @debug = 1 SELECT * FROM #gen_count
	IF @debug = 1 AND @gen_count > 0 PRINT 'Generator found in TSDFApproval'
END

IF @gen_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #gen_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM dbo.Receipt '
	+ 'WHERE generator_id = ' + CONVERT(varchar(10), @generator_id) + ' '
	+ 'AND receipt_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @gen_count = sum(generator_count) FROM #gen_count
	IF @debug = 1 SELECT * FROM #gen_count
	IF @debug = 1 AND @gen_count > 0 PRINT 'Generator found in Receipt'
END

IF @gen_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #gen_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM dbo.WorkOrderHeader '
	+ 'WHERE generator_id = ' + CONVERT(varchar(10), @generator_id) + ' '
	+ 'AND workorder_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @gen_count = sum(generator_count) FROM #gen_count
	IF @debug = 1 SELECT * FROM #gen_count
	IF @debug = 1 AND @gen_count > 0 PRINT 'Generator found in WorkOrderHeader'
END

IF @gen_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #gen_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM dbo.Billing '
	+ 'WHERE generator_id = ' + CONVERT(varchar(10), @generator_id) + ' '
	+ 'AND status_code <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @gen_count = sum(generator_count) FROM #gen_count
	IF @debug = 1 SELECT * FROM #gen_count
	IF @debug = 1 AND @gen_count > 0 PRINT 'Generator found in Billing'
END

SELECT @gen_count AS generator_count

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_usage_check] TO [EQAI]
    AS [dbo];


