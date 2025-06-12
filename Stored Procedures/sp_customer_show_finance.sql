CREATE PROCEDURE sp_customer_show_finance
	@customer_code		varchar(6),
	@db_type		varchar(4),
	@debug			int = 0
AS
/***************************************************************************************
This SP show the customer information for e01 and any differences between
e01 and the other finance databases

Filename:	L:\Apps\SQL\EQAI\Plt_AI\sp_customer_show_finance.sql
PB Object(s):	None

LOAD TO PLT_AI

03/18/2007 SCC	Created

sp_customer_show_finance '8888898', 'test', 1
****************************************************************************************/
DECLARE	@column_id	int,
	@column_name	sysname,
	@database_name	varchar(10),
	@db_count	int,
	@object_id	int,
	@process_count	int,
	@server_name	varchar(20),
	@sql_cmd	varchar(8000)

-- Set the database type if necessary
IF @db_type = '' SET @db_type = 'PROD'

-- These are the databases to select financial data from
CREATE TABLE #finance_db (
	database_name	varchar(10) NULL,
	process_flag 	int NULL
)
------------------------------------------------------------------------------------
-- Add e01
------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EQConnect WHERE db_name_epic = 'e01' AND db_type = @db_type)
	INSERT #finance_db VALUES ('e01', 0)

INSERT #finance_db
SELECT DISTINCT
	C.db_name_epic,
	0 as process_flag
FROM EQConnect C
WHERE C.db_type = @db_type

-- SELECT @server_name = server_name
-- FROM EQServer
-- WHERE server_type = 'Epicor' + @db_type
SELECT @server_name = 'NTSQLFINANCE'

SELECT @db_count = COUNT(*) FROM #finance_db

-- This table holds the results
CREATE TABLE #finance (
	database_name		varchar(10) NOT NULL,
	customer_code		varchar (8) NULL ,
	address_name		varchar (40) NULL ,
	addr1			varchar (40) NULL ,
	addr2			varchar (40) NULL ,
	addr3			varchar (40) NULL ,
	addr4			varchar (40) NULL ,
	addr5			varchar (40) NULL ,
	addr6			varchar (40) NULL ,
	status_type 		smallint NULL ,
	attention_name		varchar (40) NULL ,
	attention_phone		varchar (30) NULL ,
	contact_name		varchar (40) NULL ,
	contact_phone		varchar (30) NULL ,
	phone_1			varchar (30) NULL ,
	terms_code		varchar (8) NULL ,
	territory_code		varchar (8) NULL ,
	salesperson_code	varchar (8) NULL ,
	credit_limit 		float NULL ,
	added_by_user_name	varchar (30) NULL ,
	added_by_date 		datetime NULL ,
	modified_by_user_name	varchar (30) NULL ,
	modified_by_date 	datetime NULL ,
	city			varchar (40) NULL ,
	state			varchar (40) NULL ,
	postal_code		varchar (15) NULL ,
	country			varchar (40) NULL ,
	contact_email		varchar (255) NULL 
)

-- Data from each Finance database
WHILE @db_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @database_name = database_name FROM #finance_db WHERE process_flag = 0
	SET ROWCOUNT 0

	SET @sql_cmd = 'INSERT #finance '
	+ 'SELECT '
	+ '''' + @database_name + ''', '
	+ 'customer_code, '
	+ 'address_name,'
	+ 'addr1,'
	+ 'addr2,'
	+ 'addr3,'
	+ 'addr4,'
	+ 'addr5,'
	+ 'addr6,'
	+ 'status_type,'
	+ 'attention_name,'
	+ 'attention_phone,'
	+ 'contact_name,'
	+ 'contact_phone,'
	+ 'phone_1,'
	+ 'terms_code,'
	+ 'territory_code,'
	+ 'salesperson_code,'
	+ 'credit_limit,'
	+ 'added_by_user_name,'
	+ 'added_by_date ,'
	+ 'modified_by_user_name ,'
	+ 'modified_by_date,'
	+ 'city,'
	+ 'state,'
	+ 'postal_code,'
	+ 'country,'
	+ 'contact_email '
	+ 'FROM '
	+ @server_name + '.' + @database_name + '.dbo.armaster armaster '
	+ 'WHERE armaster.customer_code = ''' + @customer_code + ''''

	IF @debug = 1 print 'SQL cmd: ' + @sql_cmd
	EXECUTE (@sql_cmd)
	
	-- Go on to the next database
	SET ROWCOUNT 1
	UPDATE #finance_db SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0
	SET @db_count = @db_count - 1
END

SELECT * FROM #finance

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_show_finance] TO [EQAI]
    AS [dbo];

