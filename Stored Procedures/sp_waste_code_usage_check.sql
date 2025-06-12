

CREATE PROCEDURE sp_waste_code_usage_check
	@debug		int,
	@waste_code_uid	int,
	@company_id	int,
	@profit_ctr_id	int,
	@db_type	varchar(10)
AS
/***************************************************************************************************
LOAD TO PLT_AI, PLT_AI_TEST, PLT_AI_DEV

Filename:	F:\EQAI\SQL\EQAI\PLT_AI\sp_waste_code_usage_check.sql
PB Object(s):	d_waste_code_usage (used in w_wastecode)

08/02/2004 JDB	Created (Copied from sp_generator_usage_check)
07/03/06   rg   revised to use profile tables
10/01/2007 WAC	Changed reference to EQAIDatabase to EQDatabase.  Added db_type to the where clause of the query.
07/17/2014 SK	Removed reference to company databases as they are obsolete, and added company_id join where necessary
08/10/2015 AM   Modified code to use waste_code_uid instead of waste_code

sp_waste_code_usage_check 1, 'ASBE', 14, 3, 'DEV'
sp_waste_code_usage_check 1, 1662, 14, 3, 'DEV'

***************************************************************************************************/


DECLARE @waste_code_count	int,
	@company_string	varchar(10),
	@profit_ctr_string	varchar(10),
	@waste_code_uid_string varchar(40),
	@server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(1000)

CREATE TABLE #waste_code_count	(
	waste_code_count	int	)

-- Initialize
SET @waste_code_count = 0

-- Pad the company_id with a 0 on the left side if < 10
IF @company_id < 10
	SET @company_string = '0' + CONVERT(varchar(1), @company_id)
ELSE
	SET @company_string = CONVERT(varchar(2), @company_id)

SET @profit_ctr_string = CONVERT(varchar(4), @profit_ctr_id)

SET @waste_code_uid_string = CONVERT(varchar(40), @waste_code_uid)

--SET @database = 'PLT_' + @company_string + '_AI'
SET @database = 'PLT_AI'
SELECT @server = server_name FROM EQDatabase WHERE database_name = @database AND db_type = @db_type

-- Look for waste_code usage in the company database
IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.ProfileQuoteApproval a'
        +       ', ' + + @server + '.' + @database + '.dbo.Profile p  '
	+ 'WHERE p.profile_id = a.profile_id '
        + 'and p.waste_code_uid = ' + @waste_code_uid_string + ' '  -- ''' + @waste_code + ''' '
	+ 'AND a.profit_ctr_id = ' + @profit_ctr_string + ' '
        + 'AND a.company_id = ' + @company_string + ' '
	+ 'AND p.curr_status_code IN ( ''A'', ''H'' )'

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in Profile'
END

IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.ProfileQuoteApproval a'
        +       ', ' + + @server + '.' + @database + '.dbo.Profile p'
        +       ', ' + + @server + '.' + @database + '.dbo.ProfileWasteCode w  '
	+ 'WHERE p.profile_id = a.profile_id '
        + 'and w.profile_id = a.profile_id '
        + 'and p.waste_code_uid = ' + @waste_code_uid_string + ' '  --''' + @waste_code + ''' '
	+ 'AND a.profit_ctr_id = ' + @profit_ctr_string + ' '
        + 'AND a.company_id = ' + @company_string + ' '
	+ 'AND p.curr_status_code IN ( ''A'', ''H'' )'

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in ProfileWasteCode'
END

IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.TSDFApproval '
	+ 'WHERE waste_code_uid = ' + @waste_code_uid_string + ' ' --''' + @waste_code_uid + ''' '
	+ 'AND profit_ctr_id = ' + @profit_ctr_string + ' '
	+ 'AND company_id = ' + @company_string + ' '
	+ 'AND tsdf_approval_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in TSDFApproval'
END

IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.TSDFApprovalWasteCode '
	+ 'WHERE waste_code_uid = ' + @waste_code_uid_string + ' '  --''' + @waste_code + ''' '
	+ 'AND profit_ctr_id = ' + @profit_ctr_string + ' '
	+ 'AND company_id = ' + @company_string + ' '

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in TSDFApprovalWasteCode'
END

IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.Receipt '
	+ 'WHERE waste_code_uid = ' + @waste_code_uid_string + ' ' -- ''' + @waste_code + ''' '
	+ 'AND profit_ctr_id = ' + @profit_ctr_string + ' '
	+ 'AND company_id = ' + @company_string + ' '
	+ 'AND receipt_status <> ''V'''

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in Receipt'
END

IF @waste_code_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #waste_code_count '
	+ 'SELECT COUNT(*) '
	+ 'FROM ' + @server + '.' + @database + '.dbo.ReceiptWasteCode '
	+ 'WHERE waste_code_uid = ' + @waste_code_uid_string + ' ' -- ''' + @waste_code+ ''' '
	+ 'AND profit_ctr_id = ' + @profit_ctr_string + ' '
	+ 'AND company_id = ' + @company_string + ' '

	IF @debug = 1 PRINT @execute_sql

	EXECUTE (@execute_sql)
	SELECT @waste_code_count = waste_code_count FROM #waste_code_count
	IF @debug = 1 SELECT * FROM #waste_code_count
	IF @debug = 1 AND @waste_code_count > 0 PRINT 'Waste Code found in ReceiptWasteCode'
END


IF @debug = 1
BEGIN
	IF @waste_code_count = 0
	BEGIN
		PRINT '------------------------------------------------------------------------'
		PRINT '------------------------------------------------------------------------'
		PRINT 'This waste code is not used anywhere in company ' + @company_string + ', profit center ' + @profit_ctr_string
		PRINT '------------------------------------------------------------------------'
		PRINT '------------------------------------------------------------------------'
		PRINT ''
	END
END

SELECT @waste_code_count AS waste_code_count



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_waste_code_usage_check] TO [EQAI]
    AS [dbo];

