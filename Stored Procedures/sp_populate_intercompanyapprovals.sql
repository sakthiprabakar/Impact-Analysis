
-- This sp is called from EQAI w_report_child_territory.
-- Data is inserted into the target database InterCompanyApprovals table (PLT_14_AI). 

-- LOAD TO:   PLT_AI, PLT_AI_DEV, PLT_AI_TEST

-- 04/18/02 SCC Created
-- 07/31/03 SCC Changed to support adding new companies

-- CMD Line:  sp_populate_intercompanyapprovals 0, 14, 'DEV', ''

CREATE PROCEDURE sp_populate_intercompanyapprovals 
	@debug int,
	@target_company_id int, 
	@db_type varchar(10),
	@msg varchar(255) OUTPUT
AS

DECLARE @company_id int,
	@company_count int,
	@database varchar(30),
	@execute_sql varchar(1000),
	@server varchar(10),
	@server_avail varchar(3),
	@target varchar(100)
	
-- Loop to get all company intercompany approvals
SELECT DISTINCT company_ID, 0 as process_flag INTO #company FROM EQAIConnect WHERE db_type = @db_type
SELECT @company_count = @@rowcount

-- Setup target database
SELECT @database = db_name_eqai FROM EQAIConnect WHERE company_id = @target_company_id and db_type = @db_type
SELECT @server = server_name FROM EQAIDatabase WHERE database_name = @database
SELECT @server_avail = server_avail FROM EQAIServer WHERE server_name = @server
SELECT @target = @server + '.' + @database + '.dbo.InterCompanyApprovals'
IF @debug = 1 print '@target: ' + @target

IF @server_avail = 'yes'
BEGIN	
	-- Clean out the table
	SELECT @execute_sql = 'DELETE FROM ' + @target
	EXECUTE (@execute_sql)
END

WHILE @company_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @company_id = company_id FROM #company WHERE process_flag = 0
	SET ROWCOUNT 0

	-- Skip the target company
	IF @company_id <> @target_company_id
	BEGIN 

	   -- Identify this company database
	   SELECT @database = db_name_eqai FROM EQAIConnect WHERE company_id = @company_id and db_type = @db_type

	   -- Identify the server where this database lives
	   SELECT @server = server_name FROM EQAIDatabase WHERE database_name = @database

	   -- Identify if this server is available
	   SELECT @server_avail = server_avail FROM EQAIServer WHERE server_name = @server

	   IF @debug = 1 print 'Database: ' + @database + ' server: ' + @server + ' server_avail: ' + @server_avail

	   IF @server_avail = 'yes'
	   BEGIN
	      SELECT @execute_sql = 'INSERT ' + @target + ' SELECT '
			+ 'APPR.company_id, '
			+ 'APPR.approval_code, '
			+ 'APPR.bill_unit_code, '
			+ 'APPR.treatment_id, '
			+ 'APPR.waste_code, '
			+ 'CUST.customer_ID  ' 
			+ 'FROM ' 
			+ @server + '.' + @database + '.dbo.Approval APPR, ' 
			+ @server + '.' + @database + '.dbo.Customer CUST  ' 
			+ 'WHERE APPR.customer_id = CUST.customer_id '  	  
			+ 'AND APPR.curr_status_code = ''A'' '  	  
			+ 'AND CUST.customer_type = ''IC'''
	      IF @debug = 1 print @execute_sql
	      EXECUTE (@execute_sql)
	   END
		ELSE
			SELECT @msg = @msg + @server + '.' + @database + ' not available. '

	END

	-- Update process flag
	SET ROWCOUNT 1
	UPDATE #company SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0
	SET @company_count = @company_count - 1
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_intercompanyapprovals] TO [EQAI]
    AS [dbo];

