CREATE PROCEDURE sp_quoteprice_usage
	@debug		int,
	@company_id	int,
	@profit_ctr_id	int,
	@quote_id	int,
	@sequence_id	int,
	@db_type	varchar(10)
AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	F:\EQAI\SQL\EQAI\PLT_AI\sp_quoteprice_usage
06/19/2006 SCC	Created
10/01/2007 WAC	Changed tables with EQAI prefix to EQ.  Added db_type to EQDatabase query.

sp_quoteprice_usage 1, 22, 0, 241581, 1, 'DEV'
***************************************************************************************************/
DECLARE @usage_count	int,
	@server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(2000)

CREATE TABLE #usage_count (
	usage_count	int
)

-- Initialize
SET @usage_count = 0

SELECT	@server = D.server_name, @database = D.database_name
FROM EQConnect C, EQDatabase D
WHERE C.db_name_eqai = D.database_name
AND C.db_type = D.db_type
AND C.db_type = @db_type
AND C.company_id = @company_id

-- Look for usage in the company database
IF @usage_count = 0
BEGIN
	SET @execute_sql = 'INSERT INTO #usage_count '
	+ ' SELECT COUNT(*) '
	+ ' FROM ' + @server + '.' + @database + '.dbo.ReceiptPrice RP, '
	+ @server + '.' + @database + '.dbo.Receipt R '
	+ ' WHERE RP.quote_id = ' + CONVERT(varchar(10), @quote_id) + ' '
	+ ' AND RP.quote_sequence_id = ' + CONVERT(varchar(10), @sequence_id) + ' '
	+ ' AND RP.company_id = R.company_id '
	+ ' AND RP.profit_ctr_id = R.profit_ctr_id '
	+ ' AND RP.receipt_id = R.receipt_id '
	+ ' AND RP.line_id = R.line_id '
	+ ' AND R.receipt_status IN ( ''N'', ''L'', ''U'', ''A'' )'
	+ ' AND R.trans_mode = ''I'' '
	+ ' AND R.profit_ctr_id = ' + convert(varchar(2), @profit_ctr_id) 

	IF @debug = 1 PRINT @execute_sql
	EXECUTE (@execute_sql)
	SELECT @usage_count = usage_count FROM #usage_count
	IF @debug = 1 SELECT * FROM #usage_count
	IF @debug = 1 AND @usage_count > 0 PRINT 'Quote Price found in Receipt'
END

SELECT @usage_count AS usage_count
GO

GRANT EXECUTE ON sp_quoteprice_usage TO EQAI

GO
