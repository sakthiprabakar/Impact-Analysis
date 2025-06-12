CREATE PROCEDURE sp_customer_usage_check
	@debug 		int,
	@customer_id 	int,
	@company_id	int,
	@db_type	varchar(10)
AS
/***************************************************************************************************
LOAD TO PLT_AI

Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_customer_usage_check.sql
PB Object(s):	d_customer_usage (w_customer)

The purpose of this SP is to check for customer usage before allowing user to delete the customer OR
to remove company access to customer

05/03/2002 SCC	Created
03/24/2003 JDB	Modified to use company 15
10/20/2003 JDB	Modified to use any company
10/01/2007 WAC	Changed table references with EQAI Prefix to EQ.  Added db_type to WHERE clause of EQDatabase
		query. 

sp_customer_usage_check 1, 70, 12, 'DEV'
***************************************************************************************************/
DECLARE @cust_count	int,
	@company_string	varchar(10),
	@server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(250)

CREATE TABLE #tmp	(
	cust_count	int	)

-- Initialize
SELECT @cust_count = 0

-- Pad the company_id with a 0 on the left side if < 10
IF @company_id < 10
	SET @company_string = '0' + CONVERT(varchar(1), @company_id)
ELSE
	SET @company_string = CONVERT(varchar(2), @company_id)

-- Set up the database name based on the db_type
SET @database = 'PLT_' + @company_string + '_AI'

SELECT @server = server_name FROM EQDatabase WHERE database_name = @database AND db_type = @db_type

-- Look for Customer usage in the company database
IF @cust_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #tmp '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.Approval '
	+ 'WHERE customer_id = ' + CONVERT(varchar(10), @customer_id) + ' '
	+ 'AND curr_status_code = ''A'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @cust_count = cust_count FROM #tmp
	IF @debug = 1 SELECT * FROM #tmp
	IF @debug = 1 AND @cust_count > 0 PRINT 'Customer found in Approval'
END

IF @cust_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #tmp '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.TSDFApproval '
	+ 'WHERE customer_id = ' + CONVERT(varchar(10), @customer_id) + ' '
	+ 'AND tsdf_approval_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @cust_count = cust_count FROM #tmp
	IF @debug = 1 SELECT * FROM #tmp
	IF @debug = 1 AND @cust_count > 0 PRINT 'Customer found in TSDFApproval'
END

IF @cust_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #tmp '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.Receipt '
	+ 'WHERE customer_id = ' + CONVERT(varchar(10), @customer_id) + ' '
	+ 'AND receipt_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @cust_count = cust_count FROM #tmp
	IF @debug = 1 SELECT * FROM #tmp
	IF @debug = 1 AND @cust_count > 0 PRINT 'Customer found in Receipt'
END

IF @cust_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #tmp '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.WorkOrderHeader '
	+ 'WHERE customer_id = ' + CONVERT(varchar(10), @customer_id) + ' '
	+ 'AND workorder_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @cust_count = cust_count FROM #tmp
	IF @debug = 1 SELECT * FROM #tmp
	IF @debug = 1 AND @cust_count > 0 PRINT 'Customer found in WorkOrderHeader'
END

IF @cust_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #tmp '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.Billing '
	+ 'WHERE customer_id = ' + CONVERT(varchar(10), @customer_id) + ' '
	+ 'AND status_code <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @cust_count = cust_count FROM #tmp
	IF @debug = 1 SELECT * FROM #tmp
	IF @debug = 1 AND @cust_count > 0 PRINT 'Customer found in Billing'
END

SELECT @cust_count AS customer_count

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_usage_check] TO [EQAI]
    AS [dbo];

