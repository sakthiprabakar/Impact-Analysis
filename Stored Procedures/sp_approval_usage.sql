CREATE PROCEDURE sp_approval_usage 
	@debug		int,
	@company_id	int,
	@profit_ctr_id	int,
	@approval_code	varchar(15)
AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_approval_usage
PB Object(s):	d_profile_approval_usage

06/19/2006 SCC	Created
08/09/2006 JDB	Added check for usage in work orders
05/02/2007 WAC  If @approval_code begins with 'TBD' exit this procedure returning 0.  There
		is no way that a TBD% approval code could be used anywhere so don't bother
		looking at all of the databases.  In the future, EQAI w_profile script should
		be modified to not even call this procedure when the approval_code is "", NULL or
		begins with 'TBD'.
10/02/2007 WAC	Changed tables with EQAI prefix to EQ.  Added db_type to EQDatabase query.
03/11/2008 JDB	Fixed bug where approval_code was getting converted to varchar(10).
01/23/2017 MPM	Modified so that checks are done against PLT_AI instead of against company databases.

sp_approval_usage 1, 2, 21, 'A0724514MDIWTS', 'PROD'
sp_approval_usage 1, 32, 0, '11372'

***************************************************************************************************/
DECLARE @usage_count	int,
	@server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(2000),
	@db_count	int

CREATE TABLE #usage_count (
	usage_count	int	)

-- Initialize
SET @usage_count = 0

IF Upper(Left(@approval_code, 3)) = 'TBD' OR LTrim(@approval_code) = ''
BEGIN
	-- don't bother with the rest of this SQL since this approval_code can't be in use
	SELECT @usage_count AS usage_count
	RETURN
END

-- Look for receipt usage
IF @usage_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #usage_count'
	+ ' SELECT COUNT(*)'
	+ ' FROM Receipt R'
	+ ' WHERE R.approval_code = ''' + @approval_code + ''' '
	+ ' AND R.receipt_status IN ( ''N'', ''L'', ''U'', ''A'' )'
	+ ' AND R.trans_mode = ''I'''
	+ ' AND R.trans_type IN (''D'', ''W'')'
	+ ' AND R.profit_ctr_id = ' + CONVERT(varchar(2), @profit_ctr_id)
	+ ' AND R.company_id = ' + CONVERT(varchar(2), @company_id)

	IF @debug = 1 PRINT @execute_sql
	EXECUTE (@execute_sql)
	SELECT @usage_count = usage_count FROM #usage_count
	IF @debug = 1 SELECT * FROM #usage_count
	IF @debug = 1 AND @usage_count > 0 PRINT 'Approval found in Receipt'
END


IF @usage_count = 0
BEGIN

	SET @execute_sql = 'INSERT INTO #usage_count'
	+ ' SELECT COUNT(*)'
	+ ' FROM WorkOrderDetail wod'
	+ ' WHERE wod.TSDF_approval_code = ''' + @approval_code + ''''
	+ '   AND wod.profile_company_id = ' + CONVERT( varchar(10), @company_id )
	+ '   AND wod.profile_profit_ctr_id = ' + CONVERT( varchar(10), @profit_ctr_id )
	
	IF @debug = 1 PRINT @execute_sql
	EXECUTE (@execute_sql)

	-- when this insert added a row to #usage_count does the sum of the rows show usage > 0?
	SELECT @usage_count = SUM(usage_count) FROM #usage_count 
	IF @debug = 1 AND @usage_count > 0 PRINT 'Approval found in Work Order'
	
END

--  There could be multiple records in #usage_count so return the usage as a sum of what is 
--  in #usage_count
SELECT SUM(usage_count) AS usage_count FROM #usage_count 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_approval_usage] TO [EQAI]
    AS [dbo];

